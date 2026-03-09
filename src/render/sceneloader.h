#ifndef SCENELOADER_H
#define SCENELOADER_H

#include "vec3.h"

// Simple data type for scene spheres from editor
typedef struct {
    Vec3 center;
    float radius;
    Vec3 albedo; // 0–1 color range
} SceneSphere;

// Reads scene.txt, fills up to max_spheres.
// Returns number of spheres successfully read.
int load_scene(const char *path, SceneSphere *out, int max_spheres);

#endif
