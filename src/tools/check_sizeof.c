#include <stdio.h>
#include <stdint.h>

typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t levels;
    uint32_t features;
    uint32_t hashmap_size;
    uint32_t base_resolution;
    float    per_level_scale;
    uint32_t mlp_in;
    uint32_t mlp_hidden;
    uint32_t mlp_layers;
    uint32_t mlp_out;
    uint32_t flags;
    uint32_t reserved[3];
} NerfHashGridHeader;

int main(){
    printf("sizeof(NerfHashGridHeader) = %zu\n", sizeof(NerfHashGridHeader));
    printf("expected = 60\n");
    return 0;
}
