#ifndef RAY_H
#define RAY_H

#include "vec3.h"

typedef struct {
    Vec3 origin;
    Vec3 direction;
} Ray;

// Newer naming convention
Ray ray_create(Vec3 origin, Vec3 direction);

// Point along ray: origin + t * direction
Vec3 ray_at(Ray r, float t);

// Legacy alias (used by sphere.c, material.c, etc.)
Ray ray(Vec3 origin, Vec3 direction);

#endif
