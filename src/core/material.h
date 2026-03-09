// material.h
#ifndef MATERIAL_H
#define MATERIAL_H

#include <stdbool.h>
#include "vec3.h"
#include "ray.h"

// --------------------------------------
// Material Types
// --------------------------------------
typedef enum {
    MAT_LAMBERTIAN = 0,
    MAT_METAL,
    MAT_DIELECTRIC,  // Glass/transparent
    MAT_EMISSIVE     // Light-emitting
} MaterialType;

// --------------------------------------
// Material Struct
// --------------------------------------
typedef struct Material {
    MaterialType type;
    Vec3 albedo;    // Base color
    float fuzz;     // Metal roughness (0 = perfectly smooth)
    float ref_idx;  // Refractive index for dielectrics
    Vec3 emission;  // Emitted color for emissive surfaces
} Material;

// --------------------------------------
// Scatter
// --------------------------------------
// in          : incoming ray
// hit_point   : surface intersection point
// normal      : surface normal
// scattered   : outgoing scattered ray
// attenuation : color multiplier
bool material_scatter(const Material *mat,
                      Ray in,
                      Vec3 hit_point,
                      Vec3 normal,
                      Ray *scattered,
                      Vec3 *attenuation);

#endif // MATERIAL_H
