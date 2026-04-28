#include <gb/gb.h>
#include <gb/cgb.h>
#include <string.h>

static void wait_frames(UINT8 frames) {
    while(frames--) {
        wait_vbl_done();
    }
}

void main(void) {
    static const unsigned char solid_tile[16] = {
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
    };
    unsigned char row[20];
    UINT8 y;

    DISPLAY_OFF;
    LCDC_REG = LCDCF_BGON | LCDCF_BG8000;

    memset(row, 0, sizeof(row));
    set_bkg_data(0u, 1u, solid_tile);
    for(y = 0u; y != 18u; ++y) {
        set_bkg_tiles(0u, y, 20u, 1u, row);
    }

#ifdef CGB
    if(_cpu == CGB_TYPE) {
        static UINT16 dark_pal[4] = {RGB(31, 31, 31), RGB(21, 21, 21), RGB(10, 10, 10), RGB(0, 0, 0)};
        static UINT16 light_pal[4] = {RGB(31, 31, 31), RGB(31, 31, 31), RGB(31, 31, 31), RGB(31, 31, 31)};
        for(UINT8 p = 0u; p != 8u; ++p) {
            set_bkg_palette(p, 1u, dark_pal);
        }
        DISPLAY_ON;
        while(1) {
            for(UINT8 p = 0u; p != 8u; ++p) {
                set_bkg_palette(p, 1u, dark_pal);
            }
            wait_frames(30u);
            for(UINT8 p = 0u; p != 8u; ++p) {
                set_bkg_palette(p, 1u, light_pal);
            }
            wait_frames(30u);
        }
    }
#endif

    DISPLAY_ON;
    while(1) {
        BGP_REG = 0xE4u;
        wait_frames(30u);
        BGP_REG = 0x1Bu;
        wait_frames(30u);
    }
}
