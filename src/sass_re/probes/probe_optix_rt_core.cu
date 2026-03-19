/*
 * SASS RE Probe: OptiX RT Core and Ray Tracing Pipeline
 * Isolates: RT core traversal, closest-hit/any-hit shader SASS
 *
 * REQUIRES: OptiX SDK 8.0+ headers (optix.h, optix_stubs.h)
 * Install from: https://developer.nvidia.com/designworks/optix/download
 * Set: -I/path/to/OptiX-SDK/include when compiling
 *
 * If OptiX headers are not available, this file documents the expected
 * SASS patterns without compilation. The closest-hit shader code below
 * compiles to standard CUDA SASS (FFMA chains for trilinear interpolation)
 * while the BVH traversal runs on dedicated RT cores (not visible in SASS).
 *
 * Ada Lovelace RT Core (3rd generation):
 *   - Hardware BVH traversal: ~1-2 billion rays/sec on RTX 4070 Ti
 *   - AABB intersection: hardware-accelerated
 *   - Triangle intersection: hardware Moller-Trumbore
 *   - Opacity micromap support (new in Ada)
 *   - RT cores operate independently from SM CUDA cores
 *   - Only the hit shaders execute on SMs (visible in SASS)
 *
 * RT Core Architecture on Ada:
 *   - Each SM has 1 RT core (3rd gen)
 *   - RT core processes ray-BVH traversal while SMs execute other work
 *   - optixTrace() issues a ray to the RT core and blocks the warp until
 *     traversal completes (or continues with other warps via scheduler)
 *   - The closest-hit/any-hit programs are regular CUDA code compiled to SASS
 *
 * Key SASS in hit shaders:
 *   FFMA chains      -- trilinear interpolation at hit point
 *   LDG.E            -- load density/velocity from distribution buffer
 *   MUFU.RCP         -- 1/distance for volume rendering attenuation
 *   FMNMX            -- min/max for AABB clamping
 *
 * OptiX-specific intrinsics (compile to special SASS):
 *   optixGetRayTmax()        -> S2R (special register read)
 *   optixGetPrimitiveIndex() -> S2R
 *   optixSetPayload_0()      -> MOV to payload register
 *   optixTrace()             -> CALL to RT core dispatch (not standard SASS)
 *
 * ======================================================================
 * PROBE CODE (requires OptiX SDK headers to compile)
 * ======================================================================
 */

#ifdef OPTIX_SDK_AVAILABLE
// This section only compiles with OptiX SDK headers

#include <optix/optix.h>
#include <optix/optix_device.h>

struct LbmSbtData {
    float *density;
    float *velocity;
    int nx, ny, nz;
};

// Raygen program: launch rays for particle tracing
extern "C" __global__ void __raygen__trace_particles() {
    uint3 idx = optixGetLaunchIndex();
    uint3 dim = optixGetLaunchDimensions();

    // Ray origin and direction from particle position
    float3 origin = make_float3((float)idx.x, (float)idx.y, (float)idx.z);
    float3 direction = make_float3(0.0f, 0.0f, 1.0f);

    unsigned int p0 = 0, p1 = 0;

    // optixTrace: dispatches ray to RT core for BVH traversal
    // This is where the RT core takes over (not visible in SASS)
    optixTrace(
        optixGetTraversableHandle(),
        origin, direction,
        0.0f,       // tmin
        1e16f,      // tmax
        0.0f,       // ray time
        0xFF,       // visibility mask
        OPTIX_RAY_FLAG_NONE,
        0, 1, 0,    // SBT offset, stride, miss index
        p0, p1      // payload
    );
}

// Closest-hit program: runs on SM when ray hits a brick
// This IS visible in SASS and contains standard FFMA/LDG instructions
extern "C" __global__ void __closesthit__cell() {
    // Get hit data from RT core
    float t = optixGetRayTmax();           // S2R: distance to hit
    int prim_idx = optixGetPrimitiveIndex(); // S2R: which brick was hit

    // Get SBT data
    const LbmSbtData *data = (const LbmSbtData*)optixGetSbtDataPointer();

    // Trilinear interpolation of density at hit point (standard FFMA)
    float3 hit_pos = optixGetWorldRayOrigin();
    hit_pos.x += optixGetWorldRayDirection().x * t;
    hit_pos.y += optixGetWorldRayDirection().y * t;
    hit_pos.z += optixGetWorldRayDirection().z * t;

    // Grid cell coordinates
    int ix = (int)hit_pos.x;
    int iy = (int)hit_pos.y;
    int iz = (int)hit_pos.z;
    float fx = hit_pos.x - (float)ix;
    float fy = hit_pos.y - (float)iy;
    float fz = hit_pos.z - (float)iz;

    int nx = data->nx, ny = data->ny;

    // Load 8 corner densities (LDG.E pattern)
    float d000 = data->density[ix + iy*nx + iz*nx*ny];
    float d100 = data->density[(ix+1) + iy*nx + iz*nx*ny];
    float d010 = data->density[ix + (iy+1)*nx + iz*nx*ny];
    float d110 = data->density[(ix+1) + (iy+1)*nx + iz*nx*ny];
    float d001 = data->density[ix + iy*nx + (iz+1)*nx*ny];
    float d101 = data->density[(ix+1) + iy*nx + (iz+1)*nx*ny];
    float d011 = data->density[ix + (iy+1)*nx + (iz+1)*nx*ny];
    float d111 = data->density[(ix+1) + (iy+1)*nx + (iz+1)*nx*ny];

    // Trilinear interpolation (7 FFMA operations)
    float i0 = d000 + fx * (d100 - d000);
    float i1 = d010 + fx * (d110 - d010);
    float i2 = d001 + fx * (d101 - d001);
    float i3 = d011 + fx * (d111 - d011);
    float j0 = i0 + fy * (i1 - i0);
    float j1 = i2 + fy * (i3 - i2);
    float density = j0 + fz * (j1 - j0);

    // Pack result into payload
    optixSetPayload_0(__float_as_uint(density));
    optixSetPayload_1(__float_as_uint(t));
}

// Miss program: ray didn't hit anything
extern "C" __global__ void __miss__background() {
    optixSetPayload_0(0);
    optixSetPayload_1(__float_as_uint(1e16f));
}

#endif // OPTIX_SDK_AVAILABLE

/*
 * ======================================================================
 * NON-OPTIX REFERENCE: Equivalent SASS patterns without OptiX
 * ======================================================================
 * The closest-hit shader above compiles to approximately:
 *
 * Trilinear interpolation SASS (8 LDG + 7 FFMA):
 *   LDG.E R0, [R_density + R_offset_000]    // d000
 *   LDG.E R1, [R_density + R_offset_100]    // d100
 *   LDG.E R2, [R_density + R_offset_010]    // d010
 *   LDG.E R3, [R_density + R_offset_110]    // d110
 *   LDG.E R4, [R_density + R_offset_001]    // d001
 *   LDG.E R5, [R_density + R_offset_101]    // d101
 *   LDG.E R6, [R_density + R_offset_011]    // d011
 *   LDG.E R7, [R_density + R_offset_111]    // d111
 *   FFMA R8, R_fx, (R1-R0), R0              // i0 = d000 + fx*(d100-d000)
 *   FFMA R9, R_fx, (R3-R2), R2              // i1
 *   FFMA R10, R_fx, (R5-R4), R4             // i2
 *   FFMA R11, R_fx, (R7-R6), R6             // i3
 *   FFMA R12, R_fy, (R9-R8), R8             // j0
 *   FFMA R13, R_fy, (R11-R10), R10          // j1
 *   FFMA R14, R_fz, (R13-R12), R12          // density
 *
 * Total: 8 LDG + 7 FFMA + index arithmetic (~10 IMAD)
 * At 92cy/LDG (L2) and 4.54cy/FFMA: ~770cy per hit (memory-bound)
 * With 8+ warps: LDG latency hidden, ~32cy per hit (compute-bound)
 *
 * The RT core traversal cost is NOT in SASS -- it runs on dedicated
 * hardware. Typical traversal: 20-100 BVH node tests at ~1-2 cy each.
 * ======================================================================
 */

// Standalone trilinear interpolation (compiles without OptiX SDK)
// This generates the same SASS as the closest-hit shader would
extern "C" __global__ void __launch_bounds__(128)
probe_trilinear_interpolation(float *out, const float *density,
                              const float *ray_origins,
                              const float *ray_dirs,
                              const float *hit_t,
                              int nx, int ny, int nz, int n_rays) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    if (i >= n_rays) return;

    float ox = ray_origins[i*3+0], oy = ray_origins[i*3+1], oz = ray_origins[i*3+2];
    float dx = ray_dirs[i*3+0], dy = ray_dirs[i*3+1], dz = ray_dirs[i*3+2];
    float t = hit_t[i];

    float hx = ox + dx * t;
    float hy = oy + dy * t;
    float hz = oz + dz * t;

    int ix = (int)hx, iy = (int)hy, iz = (int)hz;
    float fx = hx - (float)ix, fy = hy - (float)iy, fz = hz - (float)iz;

    // Clamp to grid
    ix = max(0, min(nx-2, ix));
    iy = max(0, min(ny-2, iy));
    iz = max(0, min(nz-2, iz));

    // 8 corner loads
    float d000 = density[ix + iy*nx + iz*nx*ny];
    float d100 = density[(ix+1) + iy*nx + iz*nx*ny];
    float d010 = density[ix + (iy+1)*nx + iz*nx*ny];
    float d110 = density[(ix+1) + (iy+1)*nx + iz*nx*ny];
    float d001 = density[ix + iy*nx + (iz+1)*nx*ny];
    float d101 = density[(ix+1) + iy*nx + (iz+1)*nx*ny];
    float d011 = density[ix + (iy+1)*nx + (iz+1)*nx*ny];
    float d111 = density[(ix+1) + (iy+1)*nx + (iz+1)*nx*ny];

    // Trilinear (7 lerps)
    float i0 = fmaf(fx, d100 - d000, d000);
    float i1 = fmaf(fx, d110 - d010, d010);
    float i2 = fmaf(fx, d101 - d001, d001);
    float i3 = fmaf(fx, d111 - d011, d011);
    float j0 = fmaf(fy, i1 - i0, i0);
    float j1 = fmaf(fy, i3 - i2, i2);
    out[i] = fmaf(fz, j1 - j0, j0);
}
