#ifndef YSU_OBJ_EXPORTER_H
#define YSU_OBJ_EXPORTER_H

#include "raylib.h"
#include <stdio.h>

// YSU mesh types (same as used in the editor)
typedef struct {
    Vector3 pos;
} EditVertex;

typedef struct {
    int v[3];
} EditTri;

// OBJ'e export
int ExportOBJ(const char *path,
              EditVertex *verts, int vertCount,
              EditTri *tris,   int triCount);

#endif
