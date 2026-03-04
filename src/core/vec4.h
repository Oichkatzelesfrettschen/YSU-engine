#ifndef VEC4_H
#define VEC4_H

#include "vec3.h"

typedef struct {
    float x;
    float y;
    float z;
    float w;
} Vec4;

// Vector operations
Vec4 vec4(float x, float y, float z, float w);
Vec4 vec4_add(Vec4 a, Vec4 b);
Vec4 vec4_sub(Vec4 a, Vec4 b);
Vec4 vec4_mul(Vec4 a, Vec4 b);       // component-wise multiplication
Vec4 vec4_scale(Vec4 a, float s);    // scalar multiplication
float vec4_dot(Vec4 a, Vec4 b);
float vec4_length(Vec4 a);
Vec4 vec4_normalize(Vec4 a);

// Conversions
Vec4 vec4_from_vec3(Vec3 v, float w);

#endif // VEC4_H
