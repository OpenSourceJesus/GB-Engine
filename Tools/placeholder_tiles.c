#include "tiles.h"

/*
 * One empty 8x8 2bpp tile so the project still builds
 * before a real tileset PNG is configured.
 */
const unsigned char tiles_data[] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

const struct TilesInfo tiles = {
    1,
    (unsigned char*)tiles_data,
    0,
    0,
    0
};
