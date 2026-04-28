#pragma bank 0

#include "StateGame.h"
#include "ZGBMain.h"
#include "Scroll.h"
#include "BankManager.h"
#include <gb/gb.h>
#ifdef CGB
#include <gb/cgb.h>
#endif

#ifdef USE_LDTK_MAP
#include "ldtk_map.h"
#endif

const void __at(255) __bank_StateGame;

void Start_StateGame (void)
{
#ifdef USE_LDTK_MAP
	InitScroll(BANK(ldtk_map), &ldtk_map, 0, 0);
#endif
}

void Update_StateGame (void)
{
}