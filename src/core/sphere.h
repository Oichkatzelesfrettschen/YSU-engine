#ifndef SPHERE_H
#define SPHERE_H

#include "vec3.h"
#include "ray.h"
#include "color.h"
#include "primitives.h"   // HitRecord comes from here

typedef struct {
    Vec3  center;
    float radius;
    int   material_index;
    Color albedo;
} Sphere;

Sphere    sphere_create(Vec3 center, float radius, int material_index);
HitRecord sphere_intersect(const Sphere *s, Ray r, float t_min, float t_max);

#endif
