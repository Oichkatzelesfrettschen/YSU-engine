// lbvh.c - Linear BVH (LBVH) with Morton codes for GPU ray tracing
// Provides better cache coherence and faster traversal than traditional BVH
#include "bvh.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

// ==================================================
// MORTON CODE FUNCTIONS (Spatial Locality)
// ==================================================

// Expand bits: 000 -> 000000000 (for 3D interleaving)
static inline uint32_t expand_bits(uint32_t v) {
    v = (v | (v << 16)) & 0x030000FF;
    v = (v | (v << 8))  & 0x0300F00F;
    v = (v | (v << 4))  & 0x030C30C3;
    v = (v | (v << 2))  & 0x09249249;
    return v;
}

// Compute 3D Morton code (Z-order curve) from normalized [0,1] position
static inline uint32_t morton_code_3d(float x, float y, float z) {
    // Clamp and convert to 10-bit integer
    uint32_t xi = (uint32_t)(fmax(0.0f, fmin(1.0f, x)) * 1023.0f);
    uint32_t yi = (uint32_t)(fmax(0.0f, fmin(1.0f, y)) * 1023.0f);
    uint32_t zi = (uint32_t)(fmax(0.0f, fmin(1.0f, z)) * 1023.0f);
    
    return expand_bits(xi) | (expand_bits(yi) << 1) | (expand_bits(zi) << 2);
}

// ==================================================
// LBVH BUILD
// ==================================================

typedef struct {
    uint32_t morton;  // Morton code for sorting
    int triangle_id;  // Original triangle index
    aabb bounds;      // Triangle AABB
    Vec3 centroid;    // For later refinement
} lbvh_primitive;

typedef struct lbvh_node_internal {
    aabb bounds;
    int left_idx;   // Index into nodes array (or ~triangle_id if leaf)
    int right_idx;
    int depth;
} lbvh_node_internal;

// Comparison for qsort
static int compare_morton(const void* a, const void* b) {
    uint32_t ma = ((const lbvh_primitive*)a)->morton;
    uint32_t mb = ((const lbvh_primitive*)b)->morton;
    if (ma < mb) return -1;
    if (ma > mb) return 1;
    return 0;
}

// Find split point in sorted Morton codes (finds highest differing bit)
static int find_split(lbvh_primitive* prims, int first, int last) {
    if (first == last) return first;
    
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
    
    // Binary search for split point
    int split = first;
    int count = last - first + 1;
    int step = count / 2;
    
    while (step > 0) {
        int mid = split + step;
        if (mid < last && (prims[mid].morton >> (msb - 1)) == (first_code >> (msb - 1))) {
            split = mid + 1;
            count -= step + 1;
        } else {
            count = step;
        }
        step = count / 2;
    }
    
    return split;
}

// Recursively build LBVH
static void lbvh_build_recursive(lbvh_primitive* prims, int first, int last,
                                 lbvh_node_internal* nodes, int* node_count,
                                 bvh_node* result_nodes, int* result_count,
                                 int depth) {
    int num_prims = last - first + 1;
    
    // Leaf node
    if (num_prims <= 8) {
        bvh_node* leaf = &result_nodes[(*result_count)++];
        leaf->box = prims[first].bounds;
        leaf->left = NULL;
        leaf->right = NULL;
        leaf->start = first;
        leaf->count = num_prims;
        leaf->depth = depth;
        leaf->visit_count = 0;
        leaf->useful_count = 0;
        leaf->id = 0;
        leaf->prune = 0;
        
        // Expand bounds to include all primitives
        for (int i = first + 1; i <= last; i++) {
            leaf->box = aabb_surrounding(leaf->box, prims[i].bounds);
        }
        return;
    }
    
    // Find split point
    int split = find_split(prims, first, last);
    
    if (split == first || split == last + 1) {
        split = (first + last) / 2;  // Fallback if split fails
    }
    
    bvh_node* internal = &result_nodes[(*result_count)++];
    internal->count = 0;  // Mark as internal (non-leaf)
    internal->depth = depth;
    internal->visit_count = 0;
    internal->useful_count = 0;
    internal->id = 0;
    internal->prune = 0;
    
    // Recursively build subtrees
    int left_idx = *result_count;
    lbvh_build_recursive(prims, first, split - 1, nodes, node_count, result_nodes, result_count, depth + 1);
    
    int right_idx = *result_count;
    lbvh_build_recursive(prims, split, last, nodes, node_count, result_nodes, result_count, depth + 1);
    
    // Set child pointers (indices into result_nodes)
    internal->left = &result_nodes[left_idx];
    internal->right = &result_nodes[right_idx];
    
    // Compute bounds
    internal->box = aabb_surrounding(result_nodes[left_idx].box, result_nodes[right_idx].box);
}

// Public LBVH builder
bvh_node* lbvh_build(void* triangles, int tri_count, int tri_size) {
    if (tri_count <= 0) return NULL;
    
    // Create primitive array with Morton codes
    lbvh_primitive* prims = (lbvh_primitive*)malloc(tri_count * sizeof(lbvh_primitive));
    
    // Find scene bounds
    aabb scene_bounds = {
        .minimum = {-1e10f, -1e10f, -1e10f},
        .maximum = {1e10f, 1e10f, 1e10f}
    };
    
    // Initialize primitives
    for (int i = 0; i < tri_count; i++) {
        prims[i].triangle_id = i;
        
        // Compute centroid (simplified - uses first 3 verts as positions)
        float* tri_data = (float*)((uint8_t*)triangles + i * tri_size);
        Vec3 p0 = {tri_data[0], tri_data[1], tri_data[2]};
        Vec3 p1 = {tri_data[3], tri_data[4], tri_data[5]};
        Vec3 p2 = {tri_data[6], tri_data[7], tri_data[8]};
        
        prims[i].centroid = vec3_scale(
            vec3_add(vec3_add(p0, p1), p2), 
            1.0f / 3.0f
        );
        
        // Compute bounds
        Vec3 bmin = p0, bmax = p0;
        if (p1.x < bmin.x) bmin.x = p1.x; if (p1.x > bmax.x) bmax.x = p1.x;
        if (p1.y < bmin.y) bmin.y = p1.y; if (p1.y > bmax.y) bmax.y = p1.y;
        if (p1.z < bmin.z) bmin.z = p1.z; if (p1.z > bmax.z) bmax.z = p1.z;
        if (p2.x < bmin.x) bmin.x = p2.x; if (p2.x > bmax.x) bmax.x = p2.x;
        if (p2.y < bmin.y) bmin.y = p2.y; if (p2.y > bmax.y) bmax.y = p2.y;
        if (p2.z < bmin.z) bmin.z = p2.z; if (p2.z > bmax.z) bmax.z = p2.z;
        
        prims[i].bounds.minimum = bmin;
        prims[i].bounds.maximum = bmax;
        
        // Update scene bounds
        scene_bounds = aabb_surrounding(scene_bounds, prims[i].bounds);
    }
    
    // Normalize centroids to [0,1] and compute Morton codes
    Vec3 extent = {
        scene_bounds.maximum.x - scene_bounds.minimum.x,
        scene_bounds.maximum.y - scene_bounds.minimum.y,
        scene_bounds.maximum.z - scene_bounds.minimum.z
    };
    float max_extent = extent.x > extent.y ? extent.x : extent.y;
    if (extent.z > max_extent) max_extent = extent.z;
    if (max_extent < 1e-6f) max_extent = 1.0f;
    
    for (int i = 0; i < tri_count; i++) {
        Vec3 norm = {
            (prims[i].centroid.x - scene_bounds.minimum.x) / max_extent,
            (prims[i].centroid.y - scene_bounds.minimum.y) / max_extent,
            (prims[i].centroid.z - scene_bounds.minimum.z) / max_extent
        };
        prims[i].morton = morton_code_3d(norm.x, norm.y, norm.z);
    }
    
    // Sort by Morton code
    qsort(prims, tri_count, sizeof(lbvh_primitive), compare_morton);
    
    // Build tree
    bvh_node* result = (bvh_node*)malloc(2 * tri_count * sizeof(bvh_node));
    int result_count = 0;
    
    lbvh_node_internal* nodes = NULL;
    int node_count = 0;
    
    lbvh_build_recursive(prims, 0, tri_count - 1, nodes, &node_count, result, &result_count, 0);
    
    free(prims);
    
    return result;
}
