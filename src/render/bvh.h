#ifndef BVH_H
#define BVH_H

#include <stdbool.h>
#include <stdint.h>

#include "vec3.h"
#include "ray.h"
#include "sphere.h"
#include "primitives.h"   // HitRecord

// -----------------------------
//   Axis-Aligned Bounding Box
// -----------------------------
typedef struct {
    Vec3 minimum;
    Vec3 maximum;
} aabb;

// -----------------------------
//        BVH Node Structure
// -----------------------------
typedef struct bvh_node {
    aabb box;
    int start;              // spheres[start ... start+count-1]
    int count;              // >0 if leaf, 0 if internal node
    struct bvh_node* left;
    struct bvh_node* right;

    // ===== TARGET-0 METRICS =====
    uint32_t visit_count;
    uint32_t useful_count;
    uint32_t depth;

    // ===== PASS-2 (policy) =====
    uint32_t id;            // preorder node id (for CSV policy)
    uint8_t  prune;         // 1 => this subtree will be pruned
} bvh_node;

// -----------------------------
//      Global metric counters
// -----------------------------
extern uint64_t g_bvh_node_visits;
extern uint64_t g_bvh_aabb_tests;

// -----------------------------
//      AABB Helper Functions
// -----------------------------
aabb aabb_surrounding(aabb b0, aabb b1);
aabb sphere_bounds(const Sphere* s);
bool aabb_hit(const aabb* box, const Ray* r, float t_min, float t_max);

// -----------------------------
//      BVH Build & Hit Test
// -----------------------------
bvh_node* bvh_build(Sphere* spheres, int start, int end);

bool bvh_hit(
    const bvh_node* node,
    const Sphere* spheres,
    const Ray* r,
    float t_min,
    float t_max,
    HitRecord* rec
);

// -----------------------------
//      CSV dump (TARGET-0)
//  (PASS-2 note: will add node_id to the dump)
// -----------------------------
void bvh_dump_stats(const char* path, const bvh_node* root);

// -----------------------------
//      PASS-2 Helpers
// -----------------------------
// Assigns preorder ids to root (node_id in policy file matches these)
void bvh_assign_ids(bvh_node* root);

// CSV format:
// node_id,prune
// 12,1
// 19,0
// ...
// Return: number of marked prune nodes
int bvh_load_policy_csv(const char* path, bvh_node* root);

// -----------------------------
//         Memory Cleanup
// -----------------------------
void bvh_free(bvh_node* node);

#endif // BVH_H
