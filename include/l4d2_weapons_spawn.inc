#if defined _l4d2_weapons_spawn_included
 #endinput
#endif
#define _l4d2_weapons_spawn_included

// From: https://github.com/raziEiL/l4d2_weapons/blob/master/scripting/include/l4d2_weapons.inc
// Modify by: fdxx

#include <sourcemod>
#include <sdktools>

#define WEAPON_TYPE 0
#define WEAPON_NAME 1
#define WEAPON_MODEL 2

public const char g_sWeapons[][][] = 
{
	{"1",	"weapon_first_aid_kit",				"models/w_models/weapons/w_eq_medkit.mdl"},					// 0 急救包
	{"1",	"weapon_pain_pills",				"models/w_models/weapons/w_eq_painpills.mdl"},				// 1 止痛药
	{"1",	"weapon_adrenaline",				"models/w_models/weapons/w_eq_adrenaline.mdl"},				// 2 肾上腺素
	{"1",	"weapon_defibrillator",				"models/w_models/weapons/w_eq_defibrillator.mdl"},			// 3 电击除颤器
	{"1",	"weapon_molotov",					"models/w_models/weapons/w_eq_molotov.mdl"},				// 4 燃烧瓶
	{"1",	"weapon_pipe_bomb",					"models/w_models/weapons/w_eq_pipebomb.mdl"},				// 5 土制炸弹
	{"1",	"weapon_vomitjar",					"models/w_models/weapons/w_eq_bile_flask.mdl"},				// 6 胆汁瓶
	{"1",	"weapon_upgradepack_incendiary",	"models/w_models/weapons/w_eq_incendiary_ammopack.mdl"},	// 7 燃烧弹升级包
	{"1",	"weapon_upgradepack_explosive",		"models/w_models/weapons/w_eq_explosive_ammopack.mdl"},		// 8 高爆弹升级包
	{"1",	"weapon_shotgun_chrome",			"models/w_models/weapons/w_pumpshotgun_A.mdl"},				// 9 铁喷
	{"1",	"weapon_pumpshotgun",				"models/w_models/weapons/w_shotgun.mdl"},					// 10 木喷
	{"1",	"weapon_smg",						"models/w_models/weapons/w_smg_uzi.mdl"},					// 11 乌兹
	{"1",	"weapon_smg_silenced",				"models/w_models/weapons/w_smg_a.mdl"},						// 12 消音冲锋
	{"1",	"weapon_autoshotgun",				"models/w_models/weapons/w_autoshot_m4super.mdl"},			// 13 连喷
	{"1",	"weapon_shotgun_spas",				"models/w_models/weapons/w_shotgun_spas.mdl"},				// 14 钢喷
	{"1",	"weapon_rifle",						"models/w_models/weapons/w_rifle_m16a2.mdl"},				// 15 M4
	{"1",	"weapon_rifle_desert",				"models/w_models/weapons/w_desert_rifle.mdl"},				// 16 三连发
	{"1",	"weapon_rifle_ak47",				"models/w_models/weapons/w_rifle_ak47.mdl"},				// 17 AK47
	{"1",	"weapon_sniper_military",			"models/w_models/weapons/w_sniper_military.mdl"},			// 18 连狙
	{"1",	"weapon_hunting_rifle",				"models/w_models/weapons/w_sniper_mini14.mdl"},				// 19 木狙
	{"1",	"weapon_sniper_awp",				"models/w_models/weapons/w_sniper_awp.mdl"},				// 20 AWP
	{"1",	"weapon_sniper_scout",				"models/w_models/weapons/w_sniper_scout.mdl"},				// 21 鸟狙
	{"1",	"weapon_smg_mp5",					"models/w_models/weapons/w_smg_mp5.mdl"},					// 22 MP5
	{"1",	"weapon_rifle_sg552",				"models/w_models/weapons/w_rifle_sg552.mdl"},				// 23 SG552
	{"1",	"weapon_grenade_launcher",			"models/w_models/weapons/w_grenade_launcher.mdl"},			// 24 榴弹发射器	
	{"1",	"weapon_rifle_m60",					"models/w_models/weapons/w_m60.mdl"},						// 25 M60
	{"1",	"weapon_chainsaw",					"models/weapons/melee/w_chainsaw.mdl"},						// 26 电锯

	{"2",	"weapon_gascan",					"models/props_junk/gascan001a.mdl"},						// 27 汽油箱
	{"2",	"weapon_propanetank",				"models/props_junk/propanecanister001a.mdl"},				// 28 丙烷罐
	{"2",	"weapon_oxygentank",				"models/props_equipment/oxygentank01.mdl"},					// 29 氧气罐
	{"2",	"weapon_fireworkcrate",				"models/props_junk/explosive_box001.mdl"},					// 30 烟花盒

	{"3",	"upgrade_laser_sight",				"models/w_models/Weapons/w_laser_sights.mdl"},				// 31 激光瞄准器
	{"3",	"weapon_ammo_spawn",				"models/props/terror/ammo_stack.mdl"},						// 32 子弹堆

	{"4",	"fireaxe",							"models/weapons/melee/w_fireaxe.mdl"},						// 33 斧头
	{"4",	"baseball_bat",						"models/weapons/melee/w_bat.mdl"},							// 34 棒球棒
	{"4",	"cricket_bat",						"models/weapons/melee/w_cricket_bat.mdl"},					// 35 球拍
	{"4",	"crowbar",							"models/weapons/melee/w_crowbar.mdl"},						// 36 撬棍
	{"4",	"frying_pan",						"models/weapons/melee/w_frying_pan.mdl"},					// 37 平底锅
	{"4",	"golfclub",							"models/weapons/melee/w_golfclub.mdl"},						// 38 高尔夫球棍
	{"4",	"electric_guitar",					"models/weapons/melee/w_electric_guitar.mdl"},				// 39 吉他
	{"4",	"katana",							"models/weapons/melee/w_katana.mdl"},						// 40 武士刀
	{"4",	"machete",							"models/weapons/melee/w_machete.mdl"},						// 41 砍刀
	{"4",	"tonfa",							"models/weapons/melee/w_tonfa.mdl"},						// 42 警棍
	{"4",	"knife",							"models/w_models/weapons/w_knife_t.mdl"},					// 43 小刀
	{"4",	"pitchfork",						"models/weapons/melee/w_pitchfork.mdl"},					// 44 草叉
	{"4",	"shovel",							"models/weapons/melee/w_shovel.mdl"}						// 45 铁铲
};

stock void L4D2Wep_PrecacheModel()
{
	for (int i; i < sizeof(g_sWeapons); i++)
	{
		if (!IsModelPrecached(g_sWeapons[i][WEAPON_MODEL]))
		{
			if (!PrecacheModel(g_sWeapons[i][WEAPON_MODEL], true))
				LogError("PrecacheModel error: %s", g_sWeapons[i][WEAPON_MODEL]);
		}
	}
}

stock int L4D2Wep_GetNumByModel(const char[] model)
{
	for (int i; i < sizeof(g_sWeapons); i++)
	{
		if (!strcmp(model, g_sWeapons[i][WEAPON_MODEL], false))
			return i;
	}
	return -1;
}

stock int L4D2Wep_GetNumByName(const char[] name)
{
	for (int i; i < sizeof(g_sWeapons); i++)
	{
		if (!strcmp(name, g_sWeapons[i][WEAPON_NAME], false))
			return i;
	}
	return -1;
}

stock int L4D2Wep_Spawn(const char[] name, const float origin[3], const float angles[3] = {0.0, ...}, int count = 1, MoveType movetype = MOVETYPE_CUSTOM)
{
	int num = L4D2Wep_GetNumByName(name);
	if (num == -1)
	{
		LogError("Invalid item name: %s", name);
		return -1;
	}

	int entity;
	switch (StringToInt(g_sWeapons[num][WEAPON_TYPE]))
	{
		case 1:
		{
			char sClassName[64];
			FormatEx(sClassName, sizeof(sClassName), "%s_spawn", name);

			entity = CreateEntityByName(sClassName);
			if (entity == -1) LogError("Failed to create \"%s\"", name);

			DispatchKeyValue(entity, "model", g_sWeapons[num][WEAPON_MODEL]);
			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValueVector(entity, "angles", angles);
			DispatchKeyValueInt(entity, "count", count);
			DispatchSpawn(entity);

			DataPack hPack = new DataPack();
			hPack.WriteCell(EntIndexToEntRef(entity));
			hPack.WriteCell(count);
			RequestFrame(NextFrame_SetCount, hPack);
		}

		case 2:
		{
			entity = CreateEntityByName("prop_physics");
			if (entity == -1) LogError("Failed to create \"%s\"", name);

			DispatchKeyValue(entity, "model", g_sWeapons[num][WEAPON_MODEL]);
			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValueVector(entity, "angles", angles);
			DispatchSpawn(entity);
			ActivateEntity(entity);
		}

		case 3:
		{
			entity = CreateEntityByName(name);
			if (entity == -1) LogError("Failed to create \"%s\"", name);

			DispatchKeyValue(entity, "model", g_sWeapons[num][WEAPON_MODEL]);
			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValueVector(entity, "angles", angles);
			DispatchSpawn(entity);
		}

		case 4:
		{
			entity = CreateEntityByName("weapon_melee");
			if (entity == -1) LogError("Failed to create \"%s\"", name);

			DispatchKeyValue(entity, "melee_script_name", name);
			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValueVector(entity, "angles", angles);
			DispatchSpawn(entity);
		}
	}

	// No set by default.
	if (movetype != MOVETYPE_CUSTOM)
		SetEntityMoveType(entity, movetype);

	return entity;
}

static void NextFrame_SetCount(DataPack hPack)
{
	hPack.Reset();
	int entity = EntRefToEntIndex(hPack.ReadCell());
	int count = hPack.ReadCell();
	delete hPack;

	if (entity > MaxClients && IsValidEntity(entity))
		SetEntProp(entity, Prop_Data, "m_itemCount", count);
}

