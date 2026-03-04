// gpu_bvh_lbvh_builder.c - LBVH integration for GPU BVH building
// Uses Linear BVH with Morton codes for better spatial locality and cache performance

#include "gpu_bvh_build.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

// ===== Bit expansion for Morton codes =====
static inline uint32_t expand_bits(uint32_t v) {
    v = (v | (v << 16)) & 0x030000FF;
    v = (v | (v << 8))  & 0x0300F00F;
    v = (v | (v << 4))  & 0x030C30C3;
    v = (v | (v << 2))  & 0x09249249;
    return v;
}

// Compute 3D Morton code from normalized [0,1] position
static inline uint32_t morton_code_3d(float x, float y, float z) {
    uint32_t xi = (uint32_t)(fmax(0.0f, fmin(1.0f, x)) * 1023.0f);
    uint32_t yi = (uint32_t)(fmax(0.0f, fmin(1.0f, y)) * 1023.0f);
    uint32_t zi = (uint32_t)(fmax(0.0f, fmin(1.0f, z)) * 1023.0f);
    
    return expand_bits(xi) | (expand_bits(yi) << 1) | (expand_bits(zi) << 2);
}

// ===== Triangle info structure =====
typedef struct {
    float x, y, z;
} v3;

typedef struct {
    v3 bmin;
    v3 bmax;
    v3 centroid;
    uint32_t morton;
    int32_t tri_id;
} TriInfoLBVH;

// ===== GPU BVH node vector =====
typedef struct {
    GPUBVHNode* nodes;
    uint32_t count;
    uint32_t cap;
} NodeVec;

static void nv_reserve(NodeVec* nv, uint32_t want) {
    if (nv->cap >= want) return;
    uint32_t nc = nv->cap ? nv->cap : 1024;
    while (nc < want) nc *= 2;
    nv->nodes = (GPUBVHNode*)realloc(nv->nodes, (size_t)nc * sizeof(GPUBVHNode));
    nv->cap = nc;
}

static uint32_t nv_push(NodeVec* nv, const GPUBVHNode* n) {
    nv_reserve(nv, nv->count + 1);
    nv->nodes[nv->count] = *n;
    return nv->count++;
}

// ===== Vector math =====
static v3 v3_min(v3 a, v3 b) {
    v3 r = { fminf(a.x, b.x), fminf(a.y, b.y), fminf(a.z, b.z) };
    return r;
}

static v3 v3_max(v3 a, v3 b) {
    v3 r = { fmaxf(a.x, b.x), fmaxf(a.y, b.y), fmaxf(a.z, b.z) };
    return r;
}

static v3 v3_add(v3 a, v3 b) {
    v3 r = { a.x + b.x, a.y + b.y, a.z + b.z };
    return r;
}

static v3 v3_mul(v3 a, float s) {
    v3 r = { a.x * s, a.y * s, a.z * s };
    return r;
}

// ===== Morton code comparator for qsort =====
static int cmp_morton(const void* a, const void* b) {
    uint32_t ma = ((const TriInfoLBVH*)a)->morton;
    uint32_t mb = ((const TriInfoLBVH*)b)->morton;
    if (ma < mb) return -1;
    if (ma > mb) return 1;
    return 0;
}

// ===== Binary search for split point in Morton-sorted array =====
static uint32_t find_split_point(TriInfoLBVH* prims, uint32_t first, uint32_t last) {
    if (first >= last) return first;
    
    uint32_t first_code = prims[first].morton;
    uint32_t last_code = prims[last].morton;
    
    if (first_code == last_code) {
        return (first + last) / 2;  // Fallback to middle
    }
    
    // Find most significant bit where codes differ
    uint32_t xor_code = first_code ^ last_code;
    int msb = 0;
    while (xor_code) {
        xor_code >>= 1;
        msb++;
    }
    
    // Binary search for split
    uint32_t split = first;
    uint32_t count = last - first + 1;
    uint32_t step = count / 2;
    
    while (step > 0) {
        uint32_t mid = split + step;
        if (mid <= last && (prims[mid].morton >> (msb - 1)) == (first_code >> (msb - 1))) {
            split = mid + 1;
            count -= step + 1;
        } else {
            count = step;
        }
        step = count / 2;
    }
    
    return split;
}

// ===== Compute bounds for primitive range =====
static void compute_bounds(TriInfoLBVH* prims, uint32_t start, uint32_t end,
                          v3* out_min, v3* out_max) {
    v3 mn = { 1e30f, 1e30f, 1e30f };
    v3 mx = { -1e30f, -1e30f, -1e30f };
    
    for (uint32_t i = start; i < end; i++) {
        mn = v3_min(mn, prims[i].bmin);
        mx = v3_max(mx, prims[i].bmax);
    }
    
    *out_min = mn;
    *out_max = mx;
}

// ===== Recursive LBVH builder (converts to GPU BVH format) =====
static uint32_t build_lbvh_node(NodeVec* nv, TriInfoLBVH* prims, int32_t* tri_idx,
                               uint32_t start, uint32_t end) {
    const uint32_t LEAF_MAX = 8;
    uint32_t ntris = end - start;
    
    v3 mn, mx;
    compute_bounds(prims, start, end, &mn, &mx);
    
    // Create node
    GPUBVHNode node;
    memset(&node, 0, sizeof(node));
    node.bmin[0] = mn.x; node.bmin[1] = mn.y; node.bmin[2] = mn.z; node.bmin[3] = 0.0f;
    node.bmax[0] = mx.x; node.bmax[1] = mx.y; node.bmax[2] = mx.z; node.bmax[3] = 0.0f;
    node.left = -1;
    node.right = -1;
    node.triOffset = (int32_t)start;
    node.triCount = (int32_t)ntris;
    
    uint32_t my_index = nv_push(nv, &node);
    
    // Leaf node
    if (ntris <= LEAF_MAX) {
        return my_index;
    }
    
    // Find split point using Morton codes (better spatial locality)
    uint32_t split = find_split_point(prims, start, end - 1);
    
    // Sanity check
    if (split == start) split = start + 1;
    if (split >= end) split = end - 1;
    
    // Build children
    uint32_t L = build_lbvh_node(nv, prims, tri_idx, start, split);
    uint32_t R = build_lbvh_node(nv, prims, tri_idx, split, end);
    
    // Update internal node
    nv->nodes[my_index].left = (int32_t)L;
    nv->nodes[my_index].right = (int32_t)R;
    nv->nodes[my_index].triOffset = -1;
    nv->nodes[my_index].triCount = 0;
    
    return my_index;
}

// ===== Main public function: Build GPU BVH using LBVH =====
int gpu_build_bvh_lbvh(
    const float* tri_data,
    uint32_t tri_count,
    GPUBVHNode** out_nodes,
    uint32_t* out_node_count,
    int32_t** out_indices,
    uint32_t* out_index_count
) {
    if (!tri_data || tri_count == 0 || !out_nodes || !out_node_count || !out_indices || !out_index_count)
        return 0;
    
    // Allocate triangle info with Morton codes
    TriInfoLBVH* tri = (TriInfoLBVH*)malloc((size_t)tri_count * sizeof(TriInfoLBVH));
    if (!tri) return 0;
    
    // Compute bounds and centroids, calculate AABB
    v3 scene_min = { 1e30f, 1e30f, 1e30f };
    v3 scene_max = { -1e30f, -1e30f, -1e30f };
    
    for (uint32_t i = 0; i < tri_count; i++) {
        const float* t = tri_data + (size_t)i * 12u;
        
        v3 p0 = { t[0], t[1], t[2] };
        v3 p1 = { t[4], t[5], t[6] };
        v3 p2 = { t[8], t[9], t[10] };
        
        v3 mn = v3_min(p0, v3_min(p1, p2));
        v3 mx = v3_max(p0, v3_max(p1, p2));
        v3 c = v3_mul(v3_add(v3_add(p0, p1), p2), 1.0f / 3.0f);
        
        tri[i].bmin = mn;
        tri[i].bmax = mx;
        tri[i].centroid = c;
        tri[i].tri_id = (int32_t)i;
        
        scene_min = v3_min(scene_min, mn);
        scene_max = v3_max(scene_max, mx);
    }
    
    // Compute scene extent
    v3 extent = { scene_max.x - scene_min.x, scene_max.y - scene_min.y, scene_max.z - scene_min.z };
    float max_extent = fmaxf(fmaxf(extent.x, extent.y), extent.z);
    if (max_extent < 1e-6f) max_extent = 1.0f;
    
    // Compute Morton codes for all triangles
    for (uint32_t i = 0; i < tri_count; i++) {
        float nx = (tri[i].centroid.x - scene_min.x) / max_extent;
        float ny = (tri[i].centroid.y - scene_min.y) / max_extent;
        float nz = (tri[i].centroid.z - scene_min.z) / max_extent;
        
        tri[i].morton = morton_code_3d(nx, ny, nz);
    }
    
    // Sort triangles by Morton code (spatial locality!)
    qsort(tri, (size_t)tri_count, sizeof(TriInfoLBVH), cmp_morton);
    
    // Create index mapping (Morton-sorted order)
    int32_t* idx = (int32_t*)malloc((size_t)tri_count * sizeof(int32_t));
    if (!idx) {
        free(tri);
        return 0;
    }
    
    for (uint32_t i = 0; i < tri_count; i++) {
        idx[i] = tri[i].tri_id;
    }
    
    // Build BVH using LBVH algorithm
    NodeVec nv;
    memset(&nv, 0, sizeof(nv));
    
    (void)build_lbvh_node(&nv, tri, idx, 0, tri_count);
    
    free(tri);
    
    *out_nodes = nv.nodes;
    *out_node_count = nv.count;
    *out_indices = idx;
    *out_index_count = tri_count;
    
    return 1;
}
