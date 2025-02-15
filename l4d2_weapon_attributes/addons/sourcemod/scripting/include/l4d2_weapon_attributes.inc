#if defined _l4d2_weapon_attributes_included
 #endinput
#endif
#define _l4d2_weapon_attributes_included

#define MAX_WEPID			56
#define MAX_WEPNAME_LEN		64
#define MAX_ATTRNAME_LEN	32

#define VALUETYPE_BOOL		0
#define VALUETYPE_INT		1
#define VALUETYPE_FLOAT		2

#define ATTR_NAME	0
#define ATTR_VALUETYPE	1	// See VALUETYPE_*

public const char g_L4D2WA_sWepAttributes[][2][MAX_ATTRNAME_LEN] =
{
	// ATTR_NAME		ATTR_VALUETYPE					
	{"damage",			"1"},
	{"bullets",			"1"},
	{"clipsize",		"1"},
	{"bucket",			"1"},
	{"tier",			"1"},

	{"speed",			"2"},
	{"spreadpershot",	"2"},
	{"maxspread",		"2"},
	{"spreaddecay",		"2"},
	{"minduckspread",	"2"},
	{"minstandspread",	"2"},
	{"minairspread",	"2"},
	{"maxmovespread",	"2"},
	{"penlayers",		"2"},
	{"penpower",		"2"},
	{"penmaxdist",		"2"},
	{"charpenmaxdist",	"2"},
	{"gainrange", 		"2"},
	{"range",			"2"},
	{"rangemod",		"2"},
	{"cycletime",		"2"},
	{"scatterpitch",	"2"},
	{"scatteryaw",		"2"},
	{"verticalpunch",	"2"},
	{"horizpunch",		"2"},
	{"reloadduration",	"2"},
};

public const char g_L4D2WA_sMeleeAttributes[][2][MAX_ATTRNAME_LEN] =
{
	{"decapitates",		"0"},

	{"damageflags",		"1"},
	{"rumbleeffect",	"1"},

	{"damage",			"2"},
	{"refiredelay",		"2"},
	{"weaponidletime",	"2"},
};


public const char g_L4D2WA_sMeleeNames[][MAX_WEPNAME_LEN] =
{
	"fireaxe",			// 0
	"frying_pan",		// 1
	"machete",			// 2
	"baseball_bat",		// 3
	"crowbar",			// 4
	"cricket_bat",		// 5
	"tonfa",			// 6
	"katana",			// 7
	"electric_guitar",	// 8
	"knife",			// 9
	"golfclub",			// 10
	"pitchfork",		// 11
	"shovel",			// 12
};

public const char g_L4D2WA_sWeaponNames[MAX_WEPID][MAX_WEPNAME_LEN] =
{
	"weapon_none",					// 0
	"weapon_pistol",				// 1
	"weapon_smg",					// 2
	"weapon_pumpshotgun",			// 3
	"weapon_autoshotgun",			// 4
	"weapon_rifle",					// 5
	"weapon_hunting_rifle",			// 6
	"weapon_smg_silenced",			// 7
	"weapon_shotgun_chrome",		// 8
	"weapon_rifle_desert",			// 9
	"weapon_sniper_military",		// 10
	"weapon_shotgun_spas",			// 11
	"weapon_first_aid_kit",			// 12
	"weapon_molotov",				// 13
	"weapon_pipe_bomb",				// 14
	"weapon_pain_pills",			// 15
	"weapon_gascan",				// 16
	"weapon_propanetank",			// 17
	"weapon_oxygentank",			// 18
	"weapon_melee",					// 19
	"weapon_chainsaw",				// 20
	"weapon_grenade_launcher",		// 21
	"weapon_ammo_pack",				// 22
	"weapon_adrenaline",			// 23
	"weapon_defibrillator",			// 24
	"weapon_vomitjar",				// 25
	"weapon_rifle_ak47",			// 26
	"weapon_gnome",					// 27
	"weapon_cola_bottles",			// 28
	"weapon_fireworkcrate",			// 29
	"weapon_upgradepack_incendiary",	// 30
	"weapon_upgradepack_explosive",		// 31
	"weapon_pistol_magnum",			// 32
	"weapon_smg_mp5",				// 33
	"weapon_rifle_sg552",			// 34
	"weapon_sniper_awp",			// 35
	"weapon_sniper_scout",			// 36
	"weapon_rifle_m60",				// 37
	"weapon_tank_claw",				// 38
	"weapon_hunter_claw",			// 39
	"weapon_charger_claw",			// 40
	"weapon_boomer_claw",			// 41
	"weapon_smoker_claw",			// 42
	"weapon_spitter_claw",			// 43
	"weapon_jockey_claw",			// 44
	"weapon_machinegun",			// 45
	"weapon_vomit",					// 46
	"weapon_splat",					// 47
	"weapon_pounce",				// 48
	"weapon_lounge",				// 49
	"weapon_pull",					// 50
	"weapon_choke",					// 51
	"weapon_rock",					// 52
	"weapon_physics",				// 53
	"weapon_ammo",					// 54
	"weapon_upgrade_item",			// 55
};


/**
 * Set the weapon attribute.
 *
 * @note The attribute value of melee is auto reset after map changed.
 * Please note the type of value, this plugin just passes it as is, no additional checks are done internally.
 * 
 * @param weapon		Weapon name.
 * @param attribute		Attribute name.
 * @param setValue		The value to be set.
 * @param oldValue		Optional parameter to store the oldValue.
 * @return				True on success.
 */
native bool L4D2_SetWepAttrValue(const char[] weapon, const char[] attribute, any setValue, any &oldValue = 0);

/**
 * Get the weapon attribute.
 *
 * @param weapon		Weapon name.
 * @param attribute		Attribute name.
 * @param curValue		Variable to store value.
 * @return				True on success.
 */
native bool L4D2_GetWepAttrValue(const char[] weapon, const char[] attribute, any &curValue);


/**
 * Reset the weapon attribute.
 *
 * @param weapon		Weapon name.
 * @return				True on success.
 */
native bool L4D2_ResetWepAttrValue(const char[] weapon);


public SharedPlugin __pl_l4d2_weapon_attributes = 
{
	name = "l4d2_weapon_attributes",
	file = "l4d2_weapon_attributes.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_weapon_attributes_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2_SetWepAttrValue");
	MarkNativeAsOptional("L4D2_GetWepAttrValue");
	MarkNativeAsOptional("L4D2_ResetWepAttrValue");
}
#endif
