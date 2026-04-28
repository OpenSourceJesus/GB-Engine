#pragma bank 255

#include "StateGame.h"
#include "ZGBMain.h"
#include "Scroll.h"

#ifdef USE_LDTK_MAP
#include "ldtk_map.h"
#endif

const void __at(255) __bank_StateGame;

void Start_StateGame (void)
{
#ifdef USE_LDTK_MAP
	InitScroll(0, &ldtk_map, 0, 0);
#endif
}

void Update_StateGame (void)
{
}