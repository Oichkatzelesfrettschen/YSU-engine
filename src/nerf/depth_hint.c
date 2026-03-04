/**
 * @file depth_hint.c
 * @brief CPU-GPU Heterogeneous Depth-Conditioned NeRF Sampling - Implementation
 * 
 * Research implementation for depth-aware sparse sampling.
 * 
 * Author: YSU Engine Research Team
 * Date: February 2026
 */

#include "depth_hint.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include <stdio.h>

// ============================================================================
// Math Helpers
// ============================================================================

static inline float vec3_dot(const float a[3], const float b[3]) {
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
}

static inline void vec3_sub(float out[3], const float a[3], const float b[3]) {
    out[0] = a[0] - b[0];
    out[1] = a[1] - b[1];
    out[2] = a[2] - b[2];
}

static inline void vec3_cross(float out[3], const float a[3], const float b[3]) {
    out[0] = a[1]*b[2] - a[2]*b[1];
    out[1] = a[2]*b[0] - a[0]*b[2];
    out[2] = a[0]*b[1] - a[1]*b[0];
}

static inline void vec3_normalize(float v[3]) {
    float len = sqrtf(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    if (len > 1e-8f) {
        float inv = 1.0f / len;
        v[0] *= inv;
        v[1] *= inv;
        v[2] *= inv;
    }
}

static inline float minf(float a, float b) { return a < b ? a : b; }
static inline float maxf(float a, float b) { return a > b ? a : b; }

// ============================================================================
// Buffer Management
// ============================================================================

int depth_hint_buffer_init(DepthHintBuffer* buf, uint32_t width, uint32_t height) {
    if (!buf || width == 0 || height == 0) return 0;
    
    memset(buf, 0, sizeof(*buf));
    buf->width = width;
    buf->height = height;
    buf->count = width * height;
    
    buf->hints = (DepthHint*)calloc(buf->count, sizeof(DepthHint));
    if (!buf->hints) return 0;
    
    // Initialize all hints to fallback state
    depth_hint_buffer_clear(buf);
    
    return 1;
}

void depth_hint_buffer_free(DepthHintBuffer* buf) {
    if (!buf) return;
    free(buf->hints);
    memset(buf, 0, sizeof(*buf));
}

void depth_hint_buffer_clear(DepthHintBuffer* buf) {
    if (!buf || !buf->hints) return;
    
    for (uint32_t i = 0; i < buf->count; i++) {
        buf->hints[i].depth = (DEPTH_HINT_FALLBACK_NEAR + DEPTH_HINT_FALLBACK_FAR) * 0.5f;
        buf->hints[i].delta = DEPTH_HINT_MAX_DELTA;
        buf->hints[i].confidence = 0.0f;
        buf->hints[i].flags = DEPTH_HINT_FLAG_FALLBACK;
    }
    
    buf->hits = 0;
    buf->misses = 0;
    buf->avg_depth = 0.0f;
    buf->depth_variance = 0.0f;
}

// ============================================================================
// AABB-Ray Intersection
// ============================================================================

static int aabb_ray_intersect(
    const float bbox_min[3],
    const float bbox_max[3],
    const float origin[3],
    const float inv_dir[3],
    float t_min,
    float t_max,
    float* out_t
) {
    float t0 = t_min;
    float t1 = t_max;
    
    for (int i = 0; i < 3; i++) {
        float tNear = (bbox_min[i] - origin[i]) * inv_dir[i];
        float tFar  = (bbox_max[i] - origin[i]) * inv_dir[i];
        
        if (tNear > tFar) {
            float tmp = tNear;
            tNear = tFar;
            tFar = tmp;
        }
        
        t0 = tNear > t0 ? tNear : t0;
        t1 = tFar  < t1 ? tFar  : t1;
        
        if (t0 > t1) return 0;
    }
    
    if (out_t) *out_t = t0;
    return 1;
}

// ============================================================================
// Triangle-Ray Intersection (Möller–Trumbore)
// ============================================================================

static int triangle_ray_intersect(
    const float v0[3],
    const float v1[3],
    const float v2[3],
    const float origin[3],
    const float dir[3],
    float t_min,
    float t_max,
    float* out_t
) {
    float e1[3], e2[3], h[3], s[3], q[3];
    
    vec3_sub(e1, v1, v0);
    vec3_sub(e2, v2, v0);
    vec3_cross(h, dir, e2);
    
    float a = vec3_dot(e1, h);
    if (fabsf(a) < 1e-8f) return 0;
    
    float f = 1.0f / a;
    vec3_sub(s, origin, v0);
    float u = f * vec3_dot(s, h);
    if (u < 0.0f || u > 1.0f) return 0;
    
    vec3_cross(q, s, e1);
    float v = f * vec3_dot(dir, q);
    if (v < 0.0f || u + v > 1.0f) return 0;
    
    float t = f * vec3_dot(e2, q);
    if (t < t_min || t > t_max) return 0;
    
    if (out_t) *out_t = t;
    return 1;
}

// ============================================================================
// BVH Building (Simple median split)
// ============================================================================

typedef struct BuildTriInfo {
    float centroid[3];
    float bbox_min[3];
    float bbox_max[3];
    uint32_t index;
} BuildTriInfo;

static int compare_x(const void* a, const void* b) {
    const BuildTriInfo* ta = (const BuildTriInfo*)a;
    const BuildTriInfo* tb = (const BuildTriInfo*)b;
    if (ta->centroid[0] < tb->centroid[0]) return -1;
    if (ta->centroid[0] > tb->centroid[0]) return 1;
    return 0;
}

static int compare_y(const void* a, const void* b) {
    const BuildTriInfo* ta = (const BuildTriInfo*)a;
    const BuildTriInfo* tb = (const BuildTriInfo*)b;
    if (ta->centroid[1] < tb->centroid[1]) return -1;
    if (ta->centroid[1] > tb->centroid[1]) return 1;
    return 0;
}

static int compare_z(const void* a, const void* b) {
    const BuildTriInfo* ta = (const BuildTriInfo*)a;
    const BuildTriInfo* tb = (const BuildTriInfo*)b;
    if (ta->centroid[2] < tb->centroid[2]) return -1;
    if (ta->centroid[2] > tb->centroid[2]) return 1;
    return 0;
}

static int build_bvh_recursive(
    DepthBVH* bvh,
    BuildTriInfo* tris,
    int start,
    int end,
    int* node_idx,
    int* idx_ptr
) {
    if (start >= end) return -1;
    
    int my_idx = (*node_idx)++;
    if (my_idx >= (int)bvh->node_count) return -1;
    
    DepthBVHNode* node = &bvh->nodes[my_idx];
    
    // Compute bounds
    for (int i = 0; i < 3; i++) {
        node->bbox_min[i] = FLT_MAX;
        node->bbox_max[i] = -FLT_MAX;
    }
    
    for (int i = start; i < end; i++) {
        for (int j = 0; j < 3; j++) {
            node->bbox_min[j] = minf(node->bbox_min[j], tris[i].bbox_min[j]);
            node->bbox_max[j] = maxf(node->bbox_max[j], tris[i].bbox_max[j]);
        }
    }
    
    int count = end - start;
    
    // Leaf threshold
    if (count <= 4) {
        node->left = -1;
        node->right = -1;
        node->tri_start = *idx_ptr;
        node->tri_count = count;
        
        for (int i = start; i < end; i++) {
            bvh->tri_indices[(*idx_ptr)++] = tris[i].index;
        }
        return my_idx;
    }
    
    // Find longest axis
    float extent[3];
    for (int i = 0; i < 3; i++) {
        extent[i] = node->bbox_max[i] - node->bbox_min[i];
    }
    
    int axis = 0;
    if (extent[1] > extent[axis]) axis = 1;
    if (extent[2] > extent[axis]) axis = 2;
    
    // Sort by axis
    switch (axis) {
        case 0: qsort(tris + start, count, sizeof(BuildTriInfo), compare_x); break;
        case 1: qsort(tris + start, count, sizeof(BuildTriInfo), compare_y); break;
        case 2: qsort(tris + start, count, sizeof(BuildTriInfo), compare_z); break;
    }
    
    int mid = start + count / 2;
    
    node->left = build_bvh_recursive(bvh, tris, start, mid, node_idx, idx_ptr);
    node->right = build_bvh_recursive(bvh, tris, mid, end, node_idx, idx_ptr);
    node->tri_start = -1;
    node->tri_count = 0;
    
    return my_idx;
}

int depth_bvh_build(DepthBVH* bvh, const ProxyMesh* mesh) {
    if (!bvh || !mesh || mesh->triangle_count == 0) return 0;
    
    memset(bvh, 0, sizeof(*bvh));
    bvh->mesh = mesh;
    
    // Allocate nodes (2*n - 1 max for binary tree)
    uint32_t max_nodes = mesh->triangle_count * 2;
    bvh->nodes = (DepthBVHNode*)calloc(max_nodes, sizeof(DepthBVHNode));
    bvh->tri_indices = (int32_t*)calloc(mesh->triangle_count, sizeof(int32_t));
    bvh->node_count = max_nodes;
    bvh->index_count = mesh->triangle_count;
    
    if (!bvh->nodes || !bvh->tri_indices) {
        depth_bvh_free(bvh);
        return 0;
    }
    
    // Build triangle info
    BuildTriInfo* tris = (BuildTriInfo*)malloc(mesh->triangle_count * sizeof(BuildTriInfo));
    if (!tris) {
        depth_bvh_free(bvh);
        return 0;
    }
    
    for (uint32_t i = 0; i < mesh->triangle_count; i++) {
        uint32_t i0 = mesh->indices[i * 3 + 0];
        uint32_t i1 = mesh->indices[i * 3 + 1];
        uint32_t i2 = mesh->indices[i * 3 + 2];
        
        const float* v0 = &mesh->vertices[i0 * 3];
        const float* v1 = &mesh->vertices[i1 * 3];
        const float* v2 = &mesh->vertices[i2 * 3];
        
        tris[i].index = i;
        
        for (int j = 0; j < 3; j++) {
            tris[i].centroid[j] = (v0[j] + v1[j] + v2[j]) / 3.0f;
            tris[i].bbox_min[j] = minf(minf(v0[j], v1[j]), v2[j]);
            tris[i].bbox_max[j] = maxf(maxf(v0[j], v1[j]), v2[j]);
        }
    }
    
    int node_idx = 0;
    int idx_ptr = 0;
    build_bvh_recursive(bvh, tris, 0, mesh->triangle_count, &node_idx, &idx_ptr);
    
    bvh->node_count = node_idx;
    bvh->index_count = idx_ptr;
    
    free(tris);
    return 1;
}

void depth_bvh_free(DepthBVH* bvh) {
    if (!bvh) return;
    free(bvh->nodes);
    free(bvh->tri_indices);
    memset(bvh, 0, sizeof(*bvh));
}

// ============================================================================
// BVH Ray Tracing
// ============================================================================

float depth_bvh_trace_ray(
    const DepthBVH* bvh,
    const float origin[3],
    const float direction[3],
    float t_min,
    float t_max
) {
    if (!bvh || !bvh->nodes || bvh->node_count == 0) return -1.0f;
    
    float inv_dir[3] = {
        1.0f / (fabsf(direction[0]) > 1e-8f ? direction[0] : 1e-8f),
        1.0f / (fabsf(direction[1]) > 1e-8f ? direction[1] : 1e-8f),
        1.0f / (fabsf(direction[2]) > 1e-8f ? direction[2] : 1e-8f)
    };
    
    float closest_t = t_max;
    int hit = 0;
    
    // Stack-based traversal
    int stack[64];
    int sp = 0;
    stack[sp++] = 0;  // Root node
    
    while (sp > 0) {
        int node_idx = stack[--sp];
        if (node_idx < 0 || node_idx >= (int)bvh->node_count) continue;
        
        const DepthBVHNode* node = &bvh->nodes[node_idx];
        
        // AABB test
        float box_t;
        if (!aabb_ray_intersect(node->bbox_min, node->bbox_max, origin, inv_dir, t_min, closest_t, &box_t)) {
            continue;
        }
        
        // Leaf node
        if (node->tri_count > 0) {
            for (int i = 0; i < node->tri_count; i++) {
                int tri_idx = bvh->tri_indices[node->tri_start + i];
                
                uint32_t i0 = bvh->mesh->indices[tri_idx * 3 + 0];
                uint32_t i1 = bvh->mesh->indices[tri_idx * 3 + 1];
                uint32_t i2 = bvh->mesh->indices[tri_idx * 3 + 2];
                
                const float* v0 = &bvh->mesh->vertices[i0 * 3];
                const float* v1 = &bvh->mesh->vertices[i1 * 3];
                const float* v2 = &bvh->mesh->vertices[i2 * 3];
                
                float t;
                if (triangle_ray_intersect(v0, v1, v2, origin, direction, t_min, closest_t, &t)) {
                    closest_t = t;
                    hit = 1;
                }
            }
        } else {
            // Internal node - push children
            if (node->right >= 0) stack[sp++] = node->right;
            if (node->left >= 0) stack[sp++] = node->left;
            
            if (sp > 60) sp = 60;  // Prevent overflow
        }
    }
    
    return hit ? closest_t : -1.0f;
}

// ============================================================================
// Depth Prepass
// ============================================================================

void depth_prepass_compute(
    const DepthBVH* bvh,
    const float cam_pos[3],
    const float cam_forward[3],
    const float cam_right[3],
    const float cam_up[3],
    float fov_y,
    uint32_t width,
    uint32_t height,
    DepthHintBuffer* out_hints,
    float default_delta
) {
    if (!out_hints || !out_hints->hints) return;
    
    float aspect = (float)width / (float)height;
    float viewport_h = 0.72f;  // Match shader FOV
    float viewport_w = aspect * viewport_h;
    
    out_hints->hits = 0;
    out_hints->misses = 0;
    double depth_sum = 0.0;
    double depth_sq_sum = 0.0;
    
    for (uint32_t y = 0; y < height; y++) {
        for (uint32_t x = 0; x < width; x++) {
            uint32_t idx = y * width + x;
            
            // Generate ray (match shader exactly)
            float u = ((float)x + 0.5f) / (float)width;
            float v = ((float)y + 0.5f) / (float)height;
            
            float local_x = viewport_w * (u - 0.5f);
            float local_y = viewport_h * (v - 0.5f);
            
            float dir[3] = {
                cam_right[0] * local_x + cam_up[0] * local_y + cam_forward[0],
                cam_right[1] * local_x + cam_up[1] * local_y + cam_forward[1],
                cam_right[2] * local_x + cam_up[2] * local_y + cam_forward[2]
            };
            vec3_normalize(dir);
            
            // Trace ray
            float t = -1.0f;
            if (bvh && bvh->nodes) {
                t = depth_bvh_trace_ray(bvh, cam_pos, dir, 0.01f, 100.0f);
            }
            
            DepthHint* hint = &out_hints->hints[idx];
            
            if (t > 0.0f) {
                // Hit: use narrow band around depth
                hint->depth = t;
                hint->delta = default_delta;
                hint->confidence = 1.0f;
                hint->flags = DEPTH_HINT_FLAG_VALID | DEPTH_HINT_FLAG_SURFACE;
                
                out_hints->hits++;
                depth_sum += t;
                depth_sq_sum += t * t;
            } else {
                // Miss: use full fallback range
                hint->depth = (DEPTH_HINT_FALLBACK_NEAR + DEPTH_HINT_FALLBACK_FAR) * 0.5f;
                hint->delta = DEPTH_HINT_MAX_DELTA;
                hint->confidence = 0.0f;
                hint->flags = DEPTH_HINT_FLAG_FALLBACK;
                
                out_hints->misses++;
            }
        }
    }
    
    // Compute statistics
    uint64_t total = out_hints->hits + out_hints->misses;
    if (out_hints->hits > 0) {
        out_hints->avg_depth = (float)(depth_sum / out_hints->hits);
        double variance = (depth_sq_sum / out_hints->hits) - (out_hints->avg_depth * out_hints->avg_depth);
        out_hints->depth_variance = (float)(variance > 0 ? sqrt(variance) : 0.0);
    }
}

// ============================================================================
// Multi-threaded Prepass (simple parallel rows)
// ============================================================================

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#endif

typedef struct DepthPrepassTask {
    const DepthBVH* bvh;
    const float* cam_pos;
    const float* cam_forward;
    const float* cam_right;
    const float* cam_up;
    float viewport_w;
    float viewport_h;
    uint32_t width;
    uint32_t height;
    uint32_t y_start;
    uint32_t y_end;
    DepthHintBuffer* out_hints;
    float default_delta;
    uint64_t local_hits;
    uint64_t local_misses;
} DepthPrepassTask;

static void prepass_task_run(DepthPrepassTask* task) {
    task->local_hits = 0;
    task->local_misses = 0;
    
    for (uint32_t y = task->y_start; y < task->y_end; y++) {
        for (uint32_t x = 0; x < task->width; x++) {
            uint32_t idx = y * task->width + x;
            
            float u = ((float)x + 0.5f) / (float)task->width;
            float v = ((float)y + 0.5f) / (float)task->height;
            
            float local_x = task->viewport_w * (u - 0.5f);
            float local_y = task->viewport_h * (v - 0.5f);
            
            float dir[3] = {
                task->cam_right[0] * local_x + task->cam_up[0] * local_y + task->cam_forward[0],
                task->cam_right[1] * local_x + task->cam_up[1] * local_y + task->cam_forward[1],
                task->cam_right[2] * local_x + task->cam_up[2] * local_y + task->cam_forward[2]
            };
            vec3_normalize(dir);
            
            float t = -1.0f;
            if (task->bvh && task->bvh->nodes) {
                t = depth_bvh_trace_ray(task->bvh, task->cam_pos, dir, 0.01f, 100.0f);
            }
            
            DepthHint* hint = &task->out_hints->hints[idx];
            
            if (t > 0.0f) {
                hint->depth = t;
                hint->delta = task->default_delta;
                hint->confidence = 1.0f;
                hint->flags = DEPTH_HINT_FLAG_VALID | DEPTH_HINT_FLAG_SURFACE;
                task->local_hits++;
            } else {
                hint->depth = (DEPTH_HINT_FALLBACK_NEAR + DEPTH_HINT_FALLBACK_FAR) * 0.5f;
                hint->delta = DEPTH_HINT_MAX_DELTA;
                hint->confidence = 0.0f;
                hint->flags = DEPTH_HINT_FLAG_FALLBACK;
                task->local_misses++;
            }
        }
    }
}

#ifdef _WIN32
static DWORD WINAPI prepass_thread_func(LPVOID arg) {
    prepass_task_run((DepthPrepassTask*)arg);
    return 0;
}
#else
static void* prepass_thread_func(void* arg) {
    prepass_task_run((DepthPrepassTask*)arg);
    return NULL;
}
#endif

void depth_prepass_compute_mt(
    const DepthBVH* bvh,
    const float cam_pos[3],
    const float cam_forward[3],
    const float cam_right[3],
    const float cam_up[3],
    float fov_y,
    uint32_t width,
    uint32_t height,
    DepthHintBuffer* out_hints,
    float default_delta,
    int num_threads
) {
    if (!out_hints || !out_hints->hints || num_threads <= 0) return;
    
    if (num_threads == 1) {
        depth_prepass_compute(bvh, cam_pos, cam_forward, cam_right, cam_up, 
                             fov_y, width, height, out_hints, default_delta);
        return;
    }
    
    float aspect = (float)width / (float)height;
    float viewport_h = 0.72f;
    float viewport_w = aspect * viewport_h;
    
    // Clamp threads
    if (num_threads > 32) num_threads = 32;
    if ((uint32_t)num_threads > height) num_threads = height;
    
    DepthPrepassTask* tasks = (DepthPrepassTask*)malloc(num_threads * sizeof(DepthPrepassTask));
    
    uint32_t rows_per_thread = height / num_threads;
    
    for (int i = 0; i < num_threads; i++) {
        tasks[i].bvh = bvh;
        tasks[i].cam_pos = cam_pos;
        tasks[i].cam_forward = cam_forward;
        tasks[i].cam_right = cam_right;
        tasks[i].cam_up = cam_up;
        tasks[i].viewport_w = viewport_w;
        tasks[i].viewport_h = viewport_h;
        tasks[i].width = width;
        tasks[i].height = height;
        tasks[i].y_start = i * rows_per_thread;
        tasks[i].y_end = (i == num_threads - 1) ? height : (i + 1) * rows_per_thread;
        tasks[i].out_hints = out_hints;
        tasks[i].default_delta = default_delta;
    }
    
#ifdef _WIN32
    HANDLE* threads = (HANDLE*)malloc(num_threads * sizeof(HANDLE));
    for (int i = 0; i < num_threads; i++) {
        threads[i] = CreateThread(NULL, 0, prepass_thread_func, &tasks[i], 0, NULL);
    }
    WaitForMultipleObjects(num_threads, threads, TRUE, INFINITE);
    for (int i = 0; i < num_threads; i++) {
        CloseHandle(threads[i]);
    }
    free(threads);
#else
    pthread_t* threads = (pthread_t*)malloc(num_threads * sizeof(pthread_t));
    for (int i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, prepass_thread_func, &tasks[i]);
    }
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    free(threads);
#endif
    
    // Aggregate stats
    out_hints->hits = 0;
    out_hints->misses = 0;
    for (int i = 0; i < num_threads; i++) {
        out_hints->hits += tasks[i].local_hits;
        out_hints->misses += tasks[i].local_misses;
    }
    
    free(tasks);
}

// ============================================================================
// Proxy Mesh from Occupancy Grid (Marching Cubes - Simplified)
// ============================================================================

// Marching cubes edge table (simplified)
static const int MC_EDGE_TABLE[256] = {
    0x0, 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
    0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
    // ... (full table would be 256 entries, simplified for brevity)
    // Using a simplified version that generates adequate proxy geometry
};

// Simplified marching cubes - generate box per occupied voxel
int proxy_mesh_from_occupancy(
    const uint8_t* occ_data,
    uint32_t occ_dim,
    float threshold,
    const float center[3],
    float scale,
    ProxyMesh* out_mesh
) {
    if (!occ_data || !out_mesh || occ_dim == 0) return 0;
    
    memset(out_mesh, 0, sizeof(*out_mesh));
    
    // Count occupied voxels
    uint32_t occupied = 0;
    for (uint32_t i = 0; i < occ_dim * occ_dim * occ_dim; i++) {
        if (occ_data[i] > (uint8_t)(threshold * 255.0f)) {
            occupied++;
        }
    }
    
    if (occupied == 0) return 0;
    
    // Each occupied voxel generates a cube (8 vertices, 12 triangles)
    // But we use a simplified approach: generate surface voxels only
    
    // Simplified: generate one triangle per surface voxel face
    // This gives a voxelized approximation of the surface
    
    // Allocate for worst case (6 faces per voxel, 2 tris per face)
    uint32_t max_tris = occupied * 12;
    uint32_t max_verts = max_tris * 3;
    
    out_mesh->vertices = (float*)malloc(max_verts * 3 * sizeof(float));
    out_mesh->indices = (uint32_t*)malloc(max_tris * 3 * sizeof(uint32_t));
    
    if (!out_mesh->vertices || !out_mesh->indices) {
        proxy_mesh_free(out_mesh);
        return 0;
    }
    
    float voxel_size = scale * 2.0f / (float)occ_dim;
    uint32_t vert_count = 0;
    uint32_t tri_count = 0;
    
    // Initialize bounds
    for (int i = 0; i < 3; i++) {
        out_mesh->bbox_min[i] = FLT_MAX;
        out_mesh->bbox_max[i] = -FLT_MAX;
    }
    
    // Generate mesh
    for (uint32_t z = 0; z < occ_dim; z++) {
        for (uint32_t y = 0; y < occ_dim; y++) {
            for (uint32_t x = 0; x < occ_dim; x++) {
                uint32_t idx = x + y * occ_dim + z * occ_dim * occ_dim;
                if (occ_data[idx] <= (uint8_t)(threshold * 255.0f)) continue;
                
                // Check if surface voxel (has empty neighbor)
                int is_surface = 0;
                if (x == 0 || x == occ_dim-1 || y == 0 || y == occ_dim-1 || z == 0 || z == occ_dim-1) {
                    is_surface = 1;
                } else {
                    // Check 6 neighbors
                    uint8_t thresh = (uint8_t)(threshold * 255.0f);
                    if (occ_data[idx - 1] <= thresh) is_surface = 1;
                    if (occ_data[idx + 1] <= thresh) is_surface = 1;
                    if (occ_data[idx - occ_dim] <= thresh) is_surface = 1;
                    if (occ_data[idx + occ_dim] <= thresh) is_surface = 1;
                    if (occ_data[idx - occ_dim*occ_dim] <= thresh) is_surface = 1;
                    if (occ_data[idx + occ_dim*occ_dim] <= thresh) is_surface = 1;
                }
                
                if (!is_surface) continue;
                
                // Generate cube vertices for this voxel
                float px = center[0] - scale + (x + 0.5f) * voxel_size;
                float py = center[1] - scale + (y + 0.5f) * voxel_size;
                float pz = center[2] - scale + (z + 0.5f) * voxel_size;
                float hs = voxel_size * 0.5f;
                
                // 8 cube vertices
                float cube[8][3] = {
                    {px - hs, py - hs, pz - hs},
                    {px + hs, py - hs, pz - hs},
                    {px + hs, py + hs, pz - hs},
                    {px - hs, py + hs, pz - hs},
                    {px - hs, py - hs, pz + hs},
                    {px + hs, py - hs, pz + hs},
                    {px + hs, py + hs, pz + hs},
                    {px - hs, py + hs, pz + hs}
                };
                
                // 12 triangles (2 per face)
                int faces[12][3] = {
                    {0,1,2}, {0,2,3},  // -Z face
                    {4,6,5}, {4,7,6},  // +Z face
                    {0,4,5}, {0,5,1},  // -Y face
                    {2,6,7}, {2,7,3},  // +Y face
                    {0,3,7}, {0,7,4},  // -X face
                    {1,5,6}, {1,6,2}   // +X face
                };
                
                uint32_t base_vert = vert_count;
                
                // Add vertices
                for (int v = 0; v < 8; v++) {
                    out_mesh->vertices[vert_count * 3 + 0] = cube[v][0];
                    out_mesh->vertices[vert_count * 3 + 1] = cube[v][1];
                    out_mesh->vertices[vert_count * 3 + 2] = cube[v][2];
                    
                    // Update bounds
                    for (int j = 0; j < 3; j++) {
                        out_mesh->bbox_min[j] = minf(out_mesh->bbox_min[j], cube[v][j]);
                        out_mesh->bbox_max[j] = maxf(out_mesh->bbox_max[j], cube[v][j]);
                    }
                    
                    vert_count++;
                }
                
                // Add triangles
                for (int t = 0; t < 12; t++) {
                    out_mesh->indices[tri_count * 3 + 0] = base_vert + faces[t][0];
                    out_mesh->indices[tri_count * 3 + 1] = base_vert + faces[t][1];
                    out_mesh->indices[tri_count * 3 + 2] = base_vert + faces[t][2];
                    tri_count++;
                }
            }
        }
    }
    
    out_mesh->vertex_count = vert_count;
    out_mesh->triangle_count = tri_count;
    
    printf("[DEPTH] Proxy mesh: %u vertices, %u triangles from %u surface voxels\n",
           vert_count, tri_count, tri_count / 12);
    
    return 1;
}

void proxy_mesh_free(ProxyMesh* mesh) {
    if (!mesh) return;
    free(mesh->vertices);
    free(mesh->indices);
    memset(mesh, 0, sizeof(*mesh));
}

// ============================================================================
// Statistics
// ============================================================================

float depth_hint_buffer_hit_rate(const DepthHintBuffer* buf) {
    if (!buf) return 0.0f;
    uint64_t total = buf->hits + buf->misses;
    if (total == 0) return 0.0f;
    return (float)buf->hits / (float)total;
}

void depth_hint_buffer_print_stats(const DepthHintBuffer* buf) {
    if (!buf) return;
    
    uint64_t total = buf->hits + buf->misses;
    float hit_rate = total > 0 ? (float)buf->hits / (float)total * 100.0f : 0.0f;
    
    printf("[DEPTH] Prepass stats:\n");
    printf("  Resolution: %u x %u (%u rays)\n", buf->width, buf->height, buf->count);
    printf("  Hits: %llu (%.1f%%)\n", (unsigned long long)buf->hits, hit_rate);
    printf("  Misses: %llu (%.1f%%)\n", (unsigned long long)buf->misses, 100.0f - hit_rate);
    printf("  Avg depth: %.3f\n", buf->avg_depth);
    printf("  Depth stddev: %.3f\n", buf->depth_variance);
}
