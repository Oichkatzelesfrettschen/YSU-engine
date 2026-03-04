#include "vec4.h"
#include <math.h>

Vec4 vec4(float x, float y, float z, float w) {
    return (Vec4){x, y, z, w};
}

Vec4 vec4_add(Vec4 a, Vec4 b) {
    return vec4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w);
}

Vec4 vec4_sub(Vec4 a, Vec4 b) {
    return vec4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w);
}

Vec4 vec4_mul(Vec4 a, Vec4 b) {
    return vec4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);
}

Vec4 vec4_scale(Vec4 a, float s) {
    return vec4(a.x * s, a.y * s, a.z * s, a.w * s);
}

float vec4_dot(Vec4 a, Vec4 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
}

float vec4_length(Vec4 a) {
    return sqrtf(vec4_dot(a, a));
}

Vec4 vec4_normalize(Vec4 a) {
    float len = vec4_length(a);
    if(len < 1e-6f) return vec4(0, 0, 0, 0);
    return vec4_scale(a, 1.0f / len);
}

Vec4 vec4_from_vec3(Vec3 v, float w) {
    return vec4(v.x, v.y, v.z, w);
}
