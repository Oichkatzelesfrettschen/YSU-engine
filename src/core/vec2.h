/* vec2.h — 2D vector math for YSU engine
 *
 * Basic 2D vector type and operations (similar pattern to vec3.h).
 * Used for 2D graphics, texture coordinates, screen space, etc.
 */

#ifndef VEC2_H
#define VEC2_H

typedef struct {
    float x;
    float y;
} Vec2;

/* Constructors */
Vec2 vec2(float x, float y);

/* Basic arithmetic */
Vec2 vec2_add(Vec2 a, Vec2 b);
Vec2 vec2_sub(Vec2 a, Vec2 b);
Vec2 vec2_mul(Vec2 a, Vec2 b);        /* component-wise multiplication */
Vec2 vec2_scale(Vec2 a, float s);     /* scalar multiplication */
Vec2 vec2_div(Vec2 a, float s);       /* scalar division */

/* Dot product and length */
float vec2_dot(Vec2 a, Vec2 b);
float vec2_length(Vec2 a);
float vec2_length_squared(Vec2 a);

/* Normalization and reflection */
Vec2 vec2_normalize(Vec2 a);
Vec2 vec2_reflect(Vec2 v, Vec2 n);    /* reflect v across normal n */

/* Utilities */
Vec2 vec2_lerp(Vec2 a, Vec2 b, float t);        /* linear interpolation [0, 1] */
Vec2 vec2_perpendicular(Vec2 v);                /* rotate 90° counterclockwise */
float vec2_distance(Vec2 a, Vec2 b);
float vec2_distance_squared(Vec2 a, Vec2 b);
Vec2 vec2_clamp(Vec2 v, float min_val, float max_val);
Vec2 vec2_abs(Vec2 v);
float vec2_cross(Vec2 a, Vec2 b);               /* 2D "cross" → scalar (z component) */

/* Random */
Vec2 vec2_random(float min, float max);

#endif /* VEC2_H */
