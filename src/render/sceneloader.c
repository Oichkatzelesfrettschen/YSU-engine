#include <stdio.h>
#include <string.h>
#include "sceneloader.h"

// scene.txt format:
// sphere cx cy cz radius r g b
// r,g,b = 0–1 color range

int load_scene(const char *path, SceneSphere *out, int max_spheres) {
    FILE *f = fopen(path, "r");
    if (!f) {
        printf("Could not open scene file '%s'\n", path);
        return 0;
    }

    int count = 0;
    char tag[16];
    double cx, cy, cz, r, cr, cg, cb;

    while (count < max_spheres) {
        int n = fscanf(f, "%15s %lf %lf %lf %lf %lf %lf %lf",
                       tag, &cx, &cy, &cz, &r, &cr, &cg, &cb);
        if (n == EOF) break;
        if (n != 8) {
            // Malformed line: skip
            char buf[256];
            if (!fgets(buf, sizeof(buf), f)) break;
            continue;
        }

        if (strcmp(tag, "sphere") == 0) {
            out[count].center = vec3((float)cx, (float)cy, (float)cz);
            out[count].radius = (float)r;
            out[count].albedo = vec3((float)cr, (float)cg, (float)cb);
            count++;
        }
    }

    fclose(f);
    return count;
}
