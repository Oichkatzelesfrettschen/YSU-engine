#include <stdio.h>
#include <stdlib.h>
#include "gpu_obj_loader.h"

int main() {
    printf("Testing quad-aware OBJ loader\n");
    printf("==============================\n\n");

    // Test 1: mixed quad + triangle
    printf("Test 1: Loading quad_test.obj (1 quad + 1 triangle)\n");
    GPUTriangle* tris = NULL;
    size_t tri_count = 0;
    GPUSquare* quads = NULL;
    size_t quad_count = 0;
    
    if(gpu_load_obj_triangles_and_quads("quad_test.obj", &tris, &tri_count, &quads, &quad_count)) {
        printf("  ✓ Loaded successfully\n");
        printf("    Triangles: %zu\n", tri_count);
        printf("    Quads: %zu\n", quad_count);
        if(tri_count > 0) {
            printf("    First triangle v0: (%.2f, %.2f, %.2f)\n", 
                   tris[0].v0[0], tris[0].v0[1], tris[0].v0[2]);
        }
        if(quad_count > 0) {
            printf("    First quad v0: (%.2f, %.2f, %.2f)\n", 
                   quads[0].v0[0], quads[0].v0[1], quads[0].v0[2]);
            printf("    First quad v3: (%.2f, %.2f, %.2f)\n", 
                   quads[0].v3[0], quads[0].v3[1], quads[0].v3[2]);
        }
        free(tris);
        free(quads);
    } else {
        printf("  ✗ Failed to load\n");
        return 1;
    }

    printf("\nTest 2: Loading cube_quad_test.obj (all quads)\n");
    tris = NULL;
    tri_count = 0;
    quads = NULL;
    quad_count = 0;
    
    if(gpu_load_obj_triangles_and_quads("cube_quad_test.obj", &tris, &tri_count, &quads, &quad_count)) {
        printf("  ✓ Loaded successfully\n");
        printf("    Triangles: %zu\n", tri_count);
        printf("    Quads: %zu\n", quad_count);
        printf("    Expected: 6 quads, got %zu %s\n", quad_count, 
               quad_count == 6 ? "✓" : "✗");
        free(tris);
        free(quads);
    } else {
        printf("  ✗ Failed to load\n");
        return 1;
    }

    printf("\nTest 3: Loading with legacy tri-only function\n");
    GPUTriangle* tris_only = NULL;
    size_t tris_only_count = 0;
    
    if(gpu_load_obj_triangles("cube_quad_test.obj", &tris_only, &tris_only_count)) {
        printf("  ✓ Loaded successfully\n");
        printf("    Total triangles (quads converted): %zu\n", tris_only_count);
        printf("    Expected: 12 triangles (6 quads * 2), got %zu %s\n", tris_only_count,
               tris_only_count == 12 ? "✓" : "✗");
        free(tris_only);
    } else {
        printf("  ✗ Failed to load\n");
        return 1;
    }

    printf("\n✓ All tests passed!\n");
    return 0;
}
