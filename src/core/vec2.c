#include <math.h>
#include <stdlib.h>
#include "vec2.h"

Vec2 vec2(float x, float y)
{
    Vec2 v;
    v.x = x;
    v.y = y;
    return v;
}

Vec2 vec2_add(Vec2 a, Vec2 b)
{
    return vec2(a.x + b.x, a.y + b.y);
}

Vec2 vec2_sub(Vec2 a, Vec2 b)
{
    return vec2(a.x - b.x, a.y - b.y);
}

Vec2 vec2_mul(Vec2 a, Vec2 b)
{
    return vec2(a.x * b.x, a.y * b.y);
}

Vec2 vec2_scale(Vec2 a, float s)
{
    return vec2(a.x * s, a.y * s);
}

Vec2 vec2_div(Vec2 a, Vec2 b)
{
    return vec2(a.x / b.x, a.y / b.y);
}

float vec2_dot(Vec2 a, Vec2 b)
{
    return a.x * b.x + a.y * b.y;
}

float vec2_length_squared(Vec2 a)
{
    return a.x * a.x + a.y * a.y;
}

float vec2_length(Vec2 a)
{
    return sqrtf(vec2_length_squared(a));
}

Vec2 vec2_normalize(Vec2 a)
{
    float len = vec2_length(a);
    if (len <= 0.0f) {
        return vec2(0.0f, 0.0f);
    }
    float inv = 1.0f / len;
    return vec2(a.x * inv, a.y * inv);
}

Vec2 vec2_reflect(Vec2 v, Vec2 n)
{
    // v - 2 * dot(v, n) * n
    float d = vec2_dot(v, n);
    return vec2_sub(v, vec2_scale(n, 2.0f * d));
}

Vec2 vec2_lerp(Vec2 a, Vec2 b, float t)
{
    return vec2(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t
    );
}

Vec2 vec2_perpendicular(Vec2 a)
{
    // Rotate 90° counterclockwise: (x, y) -> (-y, x)
    return vec2(-a.y, a.x);
}

float vec2_distance(Vec2 a, Vec2 b)
{
    return vec2_length(vec2_sub(a, b));
}

Vec2 vec2_clamp(Vec2 a, float min, float max)
{
    float cx = a.x < min ? min : (a.x > max ? max : a.x);
    float cy = a.y < min ? min : (a.y > max ? max : a.y);
    return vec2(cx, cy);
}

Vec2 vec2_abs(Vec2 a)
{
    return vec2(fabsf(a.x), fabsf(a.y));
}

float vec2_cross(Vec2 a, Vec2 b)
{
    // 2D cross product returns scalar (z-component): a.x * b.y - a.y * b.x
    return a.x * b.y - a.y * b.x;
}

static float rand_float01(void)
{
    return (float)rand() / (float)RAND_MAX;
}

Vec2 vec2_random(float min, float max)
{
    float range = max - min;
    float rx = min + range * rand_float01();
    float ry = min + range * rand_float01();
    return vec2(rx, ry);
}
