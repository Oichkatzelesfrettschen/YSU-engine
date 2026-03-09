// primitives.c
#include "primitives.h"
#include <math.h>

// This file provides "other primitive" hit functions.
// triangle_make() and hit_triangle() are defined in triangle.c.
// We do NOT redefine them here (would cause multiple-definition errors).

static HitRecord no_hit_record(void) {
    HitRecord rec;
    rec.hit = 0;
    rec.t = 0.0f;
    rec.point  = vec3(0.0f, 0.0f, 0.0f);
    rec.normal = vec3(0.0f, 0.0f, 0.0f);
    rec.material_index = -1;

    // primitives.h fields:
    rec.u = 0.0f;
    rec.v = 0.0f;
    rec.b0 = 0.0f;
    rec.b1 = 0.0f;
    rec.b2 = 0.0f;

    return rec;
}

// primitives.h prototypes use void*, so these are stubs for now.
// Later we can define Plane/Cylinder/Box structs and implement real hit functions.

HitRecord hit_plane(void* pl, Ray r, float t_min, float t_max) {
    (void)pl; (void)r; (void)t_min; (void)t_max;
    return no_hit_record();
}

HitRecord hit_cylinder(void* cy, Ray r, float t_min, float t_max) {
    (void)cy; (void)r; (void)t_min; (void)t_max;
    return no_hit_record();
}

HitRecord hit_box(void* b, Ray r, float t_min, float t_max) {
    (void)b; (void)r; (void)t_min; (void)t_max;
    return no_hit_record();
}

// --- Square/Quad Support ---

Square square_make(Vec3 p0, Vec3 p1, Vec3 p2, Vec3 p3,
                   float u0, float v0,
                   float u1, float v1,
                   float u2, float v2,
                   float u3, float v3,
                   int material_index) {
    Square sq;
    sq.p0 = p0; sq.p1 = p1; sq.p2 = p2; sq.p3 = p3;
    sq.n0 = vec3(0,0,0); sq.n1 = vec3(0,0,0); sq.n2 = vec3(0,0,0); sq.n3 = vec3(0,0,0);
    sq.u0 = u0; sq.v0 = v0;
    sq.u1 = u1; sq.v1 = v1;
    sq.u2 = u2; sq.v2 = v2;
    sq.u3 = u3; sq.v3 = v3;
    sq.material_index = material_index;
    return sq;
}

HitRecord hit_square(Square sq, Ray r, float t_min, float t_max) {
    // Split quad into two triangles: (p0, p1, p2) and (p0, p2, p3)
    Triangle tri1 = triangle_make(sq.p0, sq.p1, sq.p2,
                                   sq.u0, sq.v0,
                                   sq.u1, sq.v1,
                                   sq.u2, sq.v2,
                                   sq.material_index);
    
    Triangle tri2 = triangle_make(sq.p0, sq.p2, sq.p3,
                                   sq.u0, sq.v0,
                                   sq.u2, sq.v2,
                                   sq.u3, sq.v3,
                                   sq.material_index);
    
    // Check first triangle
    HitRecord hit1 = hit_triangle(tri1, r, t_min, t_max);
    if(hit1.hit) {
        return hit1;
    }
    
    // Check second triangle with updated t_max
    HitRecord hit2 = hit_triangle(tri2, r, t_min, t_max);
    return hit2;
}

