#ifndef YSU_MESH_TOPOLOGY_H
#define YSU_MESH_TOPOLOGY_H

#include "raylib.h"
#include "raymath.h"

// Used by both topology and edit code
// Limits are generous for now; increase if needed.
#define MAX_VERTS  8000
#define MAX_TRIS   4000
#define YSU_MAX_EDGES   (MAX_TRIS * 3)

// Vertex / triangle types used on the edit side
typedef struct {
    Vector3 pos;
} EditVertex;

typedef struct {
    int v[3];
} EditTri;

// Edge = two vertices + up to two adjacent triangles (tri0 & tri1)
typedef struct {
    int v0, v1;
    int tri0;
    int tri1;
} MeshEdge;

typedef struct {
    MeshEdge edges[YSU_MAX_EDGES];
    int      edgeCount;
} MeshTopology;

// Build edge list from triangle list
void Topology_Build(MeshTopology *topo,
                    EditTri *tris, int triCount,
                    int vertCount);

// Find the index of edge (v0,v1) in topo, or -1 if not found
int Topology_FindEdge(const MeshTopology *topo,
                      int v0, int v1);

// Blender-style bevel (single-segment simple chamfer):
// - Adds new vertices (*pVertCount increases)
// - Adds new triangles (*pTriCount increases)
// - Creates a 4-triangle bevel band around the edge
int Mesh_BevelEdge(const MeshTopology *topo,
                   int edgeIndex,
                   int segments,
                   float amount,
                   EditVertex *verts,
                   int *pVertCount,
                   EditTri *tris,
                   int *pTriCount);

#endif // YSU_MESH_TOPOLOGY_H