#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <adminmenu>
#include <left4dhooks>

#define VERSION "1.0"

#define ZC_SMOKER	1
#define ZC_BOOMER	2
#define ZC_HUNTER	3
#define ZC_SPITTER	4
#define ZC_JOCKEY	5
#define ZC_CHARGER	6
#define ZC_WITCH	7
#define ZC_TANK		8

#define TARGET_UNK	-1
#define TARGET_SI	0
#define TARGET_CI	1
#define TARGET_SELF	2
#define TARGET_SUR	3
#define TARGET_ALL	4
#define TARGET_SAFEROOM	5


static const char g_sClassName[][] = {
	"", "Smoker", "Boomer", "Hunter", "Spitter", "Jockey", "Charger", "Witch", "Tank"
};

static const char g_sTargetName[][] = {
	"si", "ci", "me", "sur", "all", "saferoom"
};

static const char g_sWeapons[][][] = 
{
	{"weapon_shotgun_chrome",		"铁喷",			"models/w_models/weapons/w_pumpshotgun_A.mdl"},
	{"weapon_pumpshotgun",			"木喷",			"models/w_models/weapons/w_shotgun.mdl"},
	{"weapon_smg",					"乌兹",			"models/w_models/weapons/w_smg_uzi.mdl"},
	{"weapon_smg_silenced",			"消音冲锋",		"models/w_models/weapons/w_smg_a.mdl"},
	{"weapon_autoshotgun",			"连喷",			"models/w_models/weapons/w_autoshot_m4super.mdl"},
	{"weapon_shotgun_spas",			"钢喷",			"models/w_models/weapons/w_shotgun_spas.mdl"},
	{"weapon_rifle",				"M16A2",		"models/w_models/weapons/w_rifle_m16a2.mdl"},
	{"weapon_rifle_desert",			"三连发",		"models/w_models/weapons/w_desert_rifle.mdl"},
	{"weapon_rifle_ak47",			"AK47",			"models/w_models/weapons/w_rifle_ak47.mdl"},
	{"weapon_sniper_military",		"连狙",			"models/w_models/weapons/w_sniper_military.mdl"},
	{"weapon_hunting_rifle",		"木狙",			"models/w_models/weapons/w_sniper_mini14.mdl"},
	{"weapon_sniper_awp",			"AWP",			"models/w_models/weapons/w_sniper_awp.mdl"},
	{"weapon_sniper_scout",			"鸟狙",			"models/w_models/weapons/w_sniper_scout.mdl"},
	{"weapon_smg_mp5",				"MP5",			"models/w_models/weapons/w_smg_mp5.mdl"},
	{"weapon_rifle_sg552",			"SG552",		"models/w_models/weapons/w_rifle_sg552.mdl"},
	{"weapon_grenade_launcher",		"榴弹发射器",	"models/w_models/weapons/w_grenade_launcher.mdl"},
	{"weapon_rifle_m60",			"M60",			"models/w_models/weapons/w_m60.mdl"},
	{"weapon_pistol_magnum",		"马格南",		"models/w_models/weapons/w_desert_eagle.mdl"},
	{"weapon_chainsaw",				"电锯",			"models/weapons/melee/w_chainsaw.mdl"},
};

static const char g_sMelees[][][] = 
{
	// 需要使用近战解锁插件
	{"fireaxe",				"斧头",			"models/weapons/melee/w_fireaxe.mdl"},
	{"baseball_bat",		"棒球棒",		"models/weapons/melee/w_bat.mdl"},
	{"cricket_bat",			"球拍",			"models/weapons/melee/w_cricket_bat.mdl"},
	{"crowbar",				"撬棍",			"models/weapons/melee/w_crowbar.mdl"},
	{"frying_pan",			"平底锅",		"models/weapons/melee/w_frying_pan.mdl"},
	{"golfclub",			"高尔夫球棍",	"models/weapons/melee/w_golfclub.mdl"},
	{"electric_guitar",		"吉他",			"models/weapons/melee/w_electric_guitar.mdl"},
	{"katana",				"武士刀",		"models/weapons/melee/w_katana.mdl"},
	{"machete",				"砍刀",			"models/weapons/melee/w_machete.mdl"},
	{"tonfa",				"警棍",			"models/weapons/melee/w_tonfa.mdl"},
	{"knife",				"小刀",			"models/w_models/weapons/w_knife_t.mdl"},
	{"pitchfork",			"草叉",			"models/weapons/melee/w_pitchfork.mdl"},
	{"shovel",				"铁铲",			"models/weapons/melee/w_shovel.mdl"},
	{"weapon_pistol_magnum","马格南",		"models/w_models/weapons/w_desert_eagle.mdl"},
	{"weapon_chainsaw",		"电锯",			"models/weapons/melee/w_chainsaw.mdl"},
};

static const char g_sMedicalAndThrowItem[][][] = 
{
	{"weapon_first_aid_kit",	"急救包",		"models/w_models/weapons/w_eq_medkit.mdl"},
	{"weapon_pain_pills",		"止痛药",		"models/w_models/weapons/w_eq_painpills.mdl"},
	{"weapon_adrenaline",		"肾上腺素",		"models/w_models/weapons/w_eq_adrenaline.mdl"},
	{"weapon_defibrillator",	"电击除颤器",	"models/w_models/weapons/w_eq_defibrillator.mdl"},
	{"weapon_molotov",			"燃烧瓶",		"models/w_models/weapons/w_eq_molotov.mdl"},
	{"weapon_pipe_bomb",		"土制炸弹",		"models/w_models/weapons/w_eq_pipebomb.mdl"},
	{"weapon_vomitjar",			"胆汁瓶",		"models/w_models/weapons/w_eq_bile_flask.mdl"},
};

static const char g_sOtherItem[][][] = 
{
	// 如果客户端已经持有相同的物品，再次产生时会变得无法破坏/点燃/爆炸，需要重新捡起来一次才行
	// https://forums.alliedmods.net/showthread.php?p=2739179
	{"weapon_gascan",					"汽油箱",		"models/props_junk/gascan001a.mdl"},
	{"weapon_propanetank",				"丙烷罐",		"models/props_junk/propanecanister001a.mdl"},
	{"weapon_oxygentank",				"氧气罐",		"models/props_equipment/oxygentank01.mdl"},
	{"weapon_fireworkcrate",			"烟花盒",		"models/props_junk/explosive_box001.mdl"},
	{"weapon_upgradepack_incendiary",	"燃烧弹升级包",	"models/w_models/weapons/w_eq_incendiary_ammopack.mdl"},
	{"weapon_upgradepack_explosive",	"高爆弹升级包",	"models/w_models/weapons/w_eq_explosive_ammopack.mdl"},
};


enum
{
	ITEM_NAME,
	ITEM_DISPLAY,
	ITEM_MODEL
};

TopMenu g_TopMenu;

TopMenuObject 
	g_TopObj_Kill,
	g_TopObj_SpawnSpecial,
	g_TopObj_GodMode,
	g_TopObj_NoClip,
	g_TopObj_Teleport,
	g_TopObj_GiveItem,
	g_TopObj_GiveHp,
	g_TopObj_Falldown,
	g_TopObj_Respawn,
	g_TopObj_Deprive,
	g_TopObj_Freeze;

int
	g_iGiveItemMenuPos[MAXPLAYERS+1][4],
	g_iSpecialClassMenuPos[MAXPLAYERS+1],
	g_iNoClipMenuPos[MAXPLAYERS+1],
	g_iGodModeMenuPos[MAXPLAYERS+1],
	g_iKillMenuPos[MAXPLAYERS+1],
	g_iGiveItemType[MAXPLAYERS+1],
	g_iReHealthMenuPos[MAXPLAYERS+1],
	g_iFalldownMenuPos[MAXPLAYERS+1],
	g_iRespawnMenuPos[MAXPLAYERS+1],
	g_iDepriveMenuPos[MAXPLAYERS+1],
	g_iFreezeMenuPos[MAXPLAYERS+1];

bool
	g_bAutoSpawn[MAXPLAYERS+1],
	g_bSpawnType[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "L4D2 Dev Menu",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_dev_menu_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);

	RegAdminCmd("sm_kl", Cmd_Kill, ADMFLAG_ROOT);
	RegAdminCmd("sm_god", Cmd_GodMode, ADMFLAG_ROOT);
	RegAdminCmd("sm_fly", Cmd_Noclip, ADMFLAG_ROOT);
	RegAdminCmd("sm_tele", Cmd_Teleport, ADMFLAG_ROOT);
	RegAdminCmd("sm_givehp", Cmd_GiveHealth, ADMFLAG_ROOT);
	RegAdminCmd("sm_rehp", Cmd_GiveHealth, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	if (LibraryExists("adminmenu") && ((g_TopMenu = GetAdminTopMenu()) != null))
	{
		TopMenuObject TopObj_DevMenu = g_TopMenu.AddCategory("l4d2_dev_menu", Category_TopMenuHandler, "l4d2_dev_menu", ADMFLAG_ROOT);

		// 可以在 configs/adminmenu_sorting.txt 中设置菜单显示的顺序
		g_TopObj_Kill = g_TopMenu.AddItem("l4d2_dev_menu_kill", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_kill", ADMFLAG_ROOT, "处死玩家");
		g_TopObj_SpawnSpecial = g_TopMenu.AddItem("l4d2_dev_menu_spawnspecial", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_spawnspecial", ADMFLAG_ROOT, "产生特感");
		g_TopObj_GodMode = g_TopMenu.AddItem("l4d2_dev_menu_godmode", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_godmode", ADMFLAG_ROOT, "无敌模式");
		g_TopObj_NoClip = g_TopMenu.AddItem("l4d2_dev_menu_noclip", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_noclip", ADMFLAG_ROOT, "穿墙模式");
		g_TopObj_Teleport = g_TopMenu.AddItem("l4d2_dev_menu_teleport", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_teleport", ADMFLAG_ROOT, "传送");
		g_TopObj_GiveItem = g_TopMenu.AddItem("l4d2_dev_menu_giveitem", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_giveitem", ADMFLAG_ROOT, "产生物品");
		g_TopObj_GiveHp = g_TopMenu.AddItem("l4d2_dev_menu_givehp", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_givehp", ADMFLAG_ROOT, "回血");
		g_TopObj_Falldown = g_TopMenu.AddItem("l4d2_dev_menu_falldown", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_falldown", ADMFLAG_ROOT, "强制倒地");
		g_TopObj_Respawn = g_TopMenu.AddItem("l4d2_dev_menu_respawn", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_respawn", ADMFLAG_ROOT, "复活");
		g_TopObj_Deprive = g_TopMenu.AddItem("l4d2_dev_menu_deprive", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_deprive", ADMFLAG_ROOT, "装备剥夺");
		g_TopObj_Freeze = g_TopMenu.AddItem("l4d2_dev_menu_freeze", Item_TopMenuHandler, TopObj_DevMenu, "l4d2_dev_menu_freeze", ADMFLAG_ROOT, "冻结");
	}
}

void Category_TopMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "开发工具");
		case TopMenuAction_DisplayTitle: FormatEx(buffer, maxlength, "开发工具:");
	}
}

void Item_TopMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			topmenu.GetInfoString(topobj_id, buffer, maxlength);
		}
		case TopMenuAction_SelectOption:
		{
			ResetSubMenuPos(client); // 重置子菜单位置

			if (topobj_id == g_TopObj_Kill)
				Kill_TargetSelect(client);
			else if (topobj_id == g_TopObj_SpawnSpecial)
				SpawnSpecial_ClassSelect(client);
			else if (topobj_id == g_TopObj_GodMode)
				GodMode_TargetSelect(client);
			else if (topobj_id == g_TopObj_NoClip)
				NoClip_TargetSelect(client);
			else if (topobj_id == g_TopObj_Teleport)
				Teleport_TypeSelect(client);
			else if (topobj_id == g_TopObj_GiveItem)
				GiveItem_TypeSelect(client);
			else if (topobj_id == g_TopObj_GiveHp)
				GiveHp_TargetSelect(client);
			else if (topobj_id == g_TopObj_Falldown)
				FallDown_TargetSelect(client);
			else if (topobj_id == g_TopObj_Respawn)
				Respawn_TargetSelect(client);
			else if (topobj_id == g_TopObj_Deprive)
				Deprive_TargetSelect(client);
			else if (topobj_id == g_TopObj_Freeze)
				Freeze_TargetSelect(client);
		}
	}
}

void ResetSubMenuPos(int client)
{
	for (int i = 0; i < sizeof(g_iGiveItemMenuPos[]); i++)
		g_iGiveItemMenuPos[client][i] = 0;

	g_iSpecialClassMenuPos[client] = 0;
	g_iNoClipMenuPos[client] = 0;
	g_iGodModeMenuPos[client] = 0;
	g_iKillMenuPos[client] = 0;
	g_iReHealthMenuPos[client] = 0;
	g_iFalldownMenuPos[client] = 0;
	g_iRespawnMenuPos[client] = 0;
	g_iDepriveMenuPos[client] = 0;
	g_iFreezeMenuPos[client] = 0;
}

void Kill_TargetSelect(int client)
{
	Menu menu = new Menu(Kill_TargetSelect_MenuHandler);
	menu.SetTitle("选择处死目标:");
	menu.AddItem(g_sTargetName[TARGET_SI], "所有特感");
	menu.AddItem(g_sTargetName[TARGET_CI], "所有普通感染者");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		int team = GetClientTeam(i);
		if (team == 2 || team == 3)
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}
	
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iKillMenuPos[client], MENU_TIME_FOREVER);
}

int Kill_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoKill(client, targetName);

			g_iKillMenuPos[client] = menu.Selection;
			Kill_TargetSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

Action Cmd_Kill(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_kl <si|ci|me|sur|all|userid>");
		return Plugin_Handled;
	}

	char targetName[32];
	GetCmdArg(1, targetName, sizeof(targetName));
	DoKill(client, targetName);
	return Plugin_Handled;
}

void DoKill(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SI:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
				{
					Print(client, "[DevMenu] 处死: %N", i);
					ForcePlayerSuicide(i);
				}
			}

			int witch = -1;
			while ((witch = FindEntityByClassname(witch, "witch")) != INVALID_ENT_REFERENCE)
			{
				Print(client, "[DevMenu] 处死: Witch");
				AcceptEntityInput(witch, "Kill");
			}
		}

		case TARGET_CI:
		{
			int inf = -1;
			int count;
			while ((inf = FindEntityByClassname(inf, "infected")) != INVALID_ENT_REFERENCE)
			{
				count++;
				AcceptEntityInput(inf, "Kill");
			}
			Print(client, "[DevMenu] 处死普通感染者: %i 个", count);
		}

		case TARGET_SELF:
		{
			if (IsPlayerAlive(client))
			{
				Print(client, "[DevMenu] 处死: %N", client);
				ForcePlayerSuicide(client);
			}
		}

		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					Print(client, "[DevMenu] 处死: %N", i);
					ForcePlayerSuicide(i);
				}
			}
		}

		case TARGET_ALL:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == 2 || GetClientTeam(i) == 3))
				{
					Print(client, "[DevMenu] 处死: %N", i);
					ForcePlayerSuicide(i);
				}
			}
		}

		case TARGET_UNK:
		{
			int userid = 0;
			if (StringToIntEx(targetName, userid) != strlen(targetName))
				return;

			int target = GetClientOfUserId(userid);
			if (!target || !IsClientInGame(target) || !IsPlayerAlive(target))
				return;

			int team = GetClientTeam(target);
			if (team == 2 || team == 3)
			{
				Print(client, "[DevMenu] 处死: %N", target);
				ForcePlayerSuicide(target);
			}
		}
	}
}

void SpawnSpecial_ClassSelect(int client)
{
	static char sSpawnType[128], sAutoSpawn[128];
	FormatEx(sSpawnType, sizeof(sSpawnType), "%s", g_bSpawnType[client] ? "设置产生方式 [当前: left4dhooks]" : "设置产生方式 [当前: z_spawn_old]");
	FormatEx(sAutoSpawn, sizeof(sAutoSpawn), "%s", g_bAutoSpawn[client] ? "设置产生位置 [当前: 自动找位]" : "设置产生位置 [当前: 十字准星处]");

	Menu menu = new Menu(SpawnSpecial_ClassSelect_MenuHandler);
	menu.SetTitle("产生特感:");
	menu.AddItem("", sSpawnType);
	menu.AddItem("", sAutoSpawn);
	menu.AddItem(g_sClassName[ZC_TANK], g_sClassName[ZC_TANK]);
	menu.AddItem(g_sClassName[ZC_WITCH], g_sClassName[ZC_WITCH]);
	menu.AddItem(g_sClassName[ZC_SMOKER], g_sClassName[ZC_SMOKER]);
	menu.AddItem(g_sClassName[ZC_BOOMER], g_sClassName[ZC_BOOMER]);
	menu.AddItem(g_sClassName[ZC_HUNTER], g_sClassName[ZC_HUNTER]);
	menu.AddItem(g_sClassName[ZC_SPITTER], g_sClassName[ZC_SPITTER]);
	menu.AddItem(g_sClassName[ZC_JOCKEY], g_sClassName[ZC_JOCKEY]);
	menu.AddItem(g_sClassName[ZC_CHARGER], g_sClassName[ZC_CHARGER]);

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iSpecialClassMenuPos[client], MENU_TIME_FOREVER);
}

int SpawnSpecial_ClassSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (itemNum == 0)
				g_bSpawnType[client] = !g_bSpawnType[client];

			else if (itemNum == 1)
				g_bAutoSpawn[client] = !g_bAutoSpawn[client];

			else
			{
				char sName[16];
				menu.GetItem(itemNum, sName, sizeof(sName));
				DoSpawnSpecial(client, sName);
			}

			g_iSpecialClassMenuPos[client] = menu.Selection;
			SpawnSpecial_ClassSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void DoSpawnSpecial(int client, const char[] name)
{
	int class = NameToClass(name);

	if (!g_bSpawnType[client])
	{
		char sCmdArgs[128];
		FormatEx(sCmdArgs, sizeof(sCmdArgs), "%s%s", name, (g_bAutoSpawn[client] ? " auto" : ""));

		int oldValue = SpawnProtect(class, 0);
		CheatCommand(client, "z_spawn_old", sCmdArgs);
		SpawnProtect(class, oldValue);

		Print(client, "[DevMenu] 产生特感 (z_spawn_old): %s", name);
		return;
	}

	float fPos[3];
	if (!GetSpawnPos(client, class, fPos))
		return;
	
	bool bSpawnSuccess = false;
	int oldValue = SpawnProtect(class, 0);

	switch (class)
	{
		case ZC_SMOKER, ZC_BOOMER, ZC_HUNTER, ZC_SPITTER, ZC_JOCKEY, ZC_CHARGER:
			bSpawnSuccess = L4D2_SpawnSpecial(class, fPos, NULL_VECTOR) > 0;

		case ZC_WITCH:
			bSpawnSuccess = L4D2_SpawnWitch(fPos, NULL_VECTOR) > MaxClients;
		
		case ZC_TANK:
			bSpawnSuccess = L4D2_SpawnTank(fPos, NULL_VECTOR) > 0;
	}

	SpawnProtect(class, oldValue);
	if (bSpawnSuccess)
		Print(client, "[DevMenu] 产生特感 (left4dhooks): %s", name);
}


bool GetSpawnPos(int client, int iClass, float fPos[3])
{
	if (g_bAutoSpawn[client])
		return L4D_GetRandomPZSpawnPosition(client, iClass, 30, fPos);
	
	float fClientAng[3], fClientPos[3];
	GetClientEyeAngles(client, fClientAng);
	GetClientEyePosition(client, fClientPos);

	Handle hTrace = TR_TraceRayFilterEx(fClientPos, fClientAng, MASK_SHOT, RayType_Infinite, TraceFilter);
	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(fPos, hTrace); //获得碰撞点
		fPos[2] += 20.0; // 避免产生在地下
		delete hTrace;
		return true;
	}
	delete hTrace;
	return false;
}

bool TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients;
}

void GodMode_TargetSelect(int client)
{
	Menu menu = new Menu(GodMode_TargetSelect_MenuHandler);
	menu.SetTitle("选择无敌模式目标:");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");
	menu.AddItem(g_sTargetName[TARGET_SI], "所有特感");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		int team = GetClientTeam(i);
		if (team == 2 || (team == 3 && !GetEntProp(i, Prop_Send, "m_isGhost")))
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iGodModeMenuPos[client], MENU_TIME_FOREVER);
}

int GodMode_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoGodMode(client, targetName);

			g_iGodModeMenuPos[client] = menu.Selection;
			GodMode_TargetSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

Action Cmd_GodMode(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_god <me|sur|si|userid>");
		return Plugin_Handled;
	}

	char targetName[32];
	GetCmdArg(1, targetName, sizeof(targetName));
	DoGodMode(client, targetName);
	return Plugin_Handled;
}

void DoGodMode(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SI:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3 && !GetEntProp(i, Prop_Send, "m_isGhost"))
					SetClientGodMode(client, i);
			}
		}

		case TARGET_SELF:
		{
			if (!IsPlayerAlive(client))
				return;

			int team = GetClientTeam(client);
			if (team == 2 || (team == 3 && !GetEntProp(client, Prop_Send, "m_isGhost")))
				SetClientGodMode(client, client);
		}

		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
					SetClientGodMode(client, i);
			}
		}

		case TARGET_UNK:
		{
			int userid = 0;
			if (StringToIntEx(targetName, userid) != strlen(targetName))
				return;

			int target = GetClientOfUserId(userid);
			if (!target || !IsClientInGame(target) || !IsPlayerAlive(target))
				return;

			int team = GetClientTeam(target);
			if (team == 2 || (team == 3 && !GetEntProp(target, Prop_Send, "m_isGhost")))
				SetClientGodMode(client, target);
		}
	}
}

void SetClientGodMode(int client, int target)
{
	int flags = GetEntityFlags(target);

	if (flags & FL_GODMODE)
	{
		SetEntityFlags(target, flags & ~FL_GODMODE);
		Print(client, "[DevMenu] 关闭无敌模式: %N", target);
	}
	else
	{
		SetEntityFlags(target, flags | FL_GODMODE);
		Print(client, "[DevMenu] 开启无敌模式: %N", target);
	}
}

void NoClip_TargetSelect(int client)
{
	Menu menu = new Menu(NoClip_TargetSelect_MenuHandler);
	menu.SetTitle("选择穿墙模式目标:");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");
	menu.AddItem(g_sTargetName[TARGET_SI], "所有特感");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		int team = GetClientTeam(i);
		if (team == 2 || team == 3)
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iNoClipMenuPos[client], MENU_TIME_FOREVER);
}

int NoClip_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoNoclip(client, targetName);

			g_iNoClipMenuPos[client] = menu.Selection;
			NoClip_TargetSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

Action Cmd_Noclip(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_fly <me|sur|si|userid>");
		return Plugin_Handled;
	}

	char targetName[32];
	GetCmdArg(1, targetName, sizeof(targetName));
	DoNoclip(client, targetName);
	return Plugin_Handled;
}

void DoNoclip(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SI:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
					SetClientNoClip(client, i);
			}
		}

		case TARGET_SELF:
		{
			if (IsPlayerAlive(client))
				SetClientNoClip(client, client);
		}

		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
					SetClientNoClip(client, i);
			}
		}

		case TARGET_UNK:
		{
			int userid = 0;
			if (StringToIntEx(targetName, userid) != strlen(targetName))
				return;

			int target = GetClientOfUserId(userid);
			if (!target || !IsClientInGame(target) || !IsPlayerAlive(target))
				return;

			int team = GetClientTeam(target);
			if (team == 2 || team == 3)
				SetClientNoClip(client, target);
		}
	}
}

void SetClientNoClip(int client, int target)
{
	MoveType movetype = GetEntityMoveType(target);

	if (movetype != MOVETYPE_NOCLIP)
	{
		SetEntityMoveType(target, MOVETYPE_NOCLIP);
		Print(client, "[DevMenu] 开启穿墙模式: %N", target);
	}
	else
	{
		SetEntityMoveType(target, MOVETYPE_WALK);
		Print(client, "[DevMenu] 关闭穿墙模式: %N", target);
	}
}

void Teleport_TypeSelect(int client)
{
	Menu menu = new Menu(Teleport_TypeSelect_MenuHandler);
	menu.SetTitle("选择传送类型:");
	menu.AddItem(g_sTargetName[TARGET_SUR], "传送幸存者到自己");
	menu.AddItem(g_sTargetName[TARGET_SI], "传送特感到自己");
	menu.AddItem(g_sTargetName[TARGET_SAFEROOM], "所有幸存者到安全屋");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Teleport_TypeSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoTeleport(client, targetName);

			Teleport_TypeSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}


Action Cmd_Teleport(int client, int args)
{
	if (args != 1 && args != 3)
	{
		ReplyToCommand(client, "sm_tele <sur|si|saferoom> | sm_tele <pos0 pos1 pos2>");
		return Plugin_Handled;
	}

	if (args == 1)
	{
		char targetName[32];
		GetCmdArg(1, targetName, sizeof(targetName));
		DoTeleport(client, targetName);
	}

	else if (args == 3)
	{
		float fPos[3];

		fPos[0] = GetCmdArgFloat(1);
		fPos[1] = GetCmdArgFloat(2);
		fPos[2] = GetCmdArgFloat(3);

		TeleportEntity(client, fPos, NULL_VECTOR, NULL_VECTOR);
		Print(client, "[DevMenu] 传送自己到: %f %f %f", fPos[0], fPos[1], fPos[2]);
	}

	return Plugin_Handled;
}

void DoTeleport(int client, const char[] targetName)
{
	float fPos[3];
	GetClientAbsOrigin(client, fPos);

	switch (TargetToType(targetName))
	{
		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
				{
					TeleportEntity(i, fPos, NULL_VECTOR, NULL_VECTOR);
					Print(client, "[DevMenu] 传送幸存者到自己");
				}
			}
		}

		case TARGET_SI:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
				{
					TeleportEntity(i, fPos, NULL_VECTOR, NULL_VECTOR);
					Print(client, "[DevMenu] 传送特感到自己");
				}
			}
		}

		case TARGET_SAFEROOM:
		{
			CheatCommand(client, "warp_all_survivors_to_checkpoint");
			Print(client, "[DevMenu] 传送所有幸存者到安全屋");
		}
	}
}


void GiveItem_TypeSelect(int client)
{	
	Menu menu = new Menu(GiveItem_TypeSelect_MenuHandler);
	menu.SetTitle("选择物品类型:");
	menu.AddItem("", "武器");
	menu.AddItem("", "近战"); // 需要近战解锁插件
	menu.AddItem("", "医疗和投掷");
	menu.AddItem("", "其他");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int GiveItem_TypeSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iGiveItemType[client] = itemNum;
			GiveItem_Select(client);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void GiveItem_Select(int client)
{
	Menu menu = new Menu(GiveItem_Select_MenuHandler);

	switch (g_iGiveItemType[client])
	{
		case 0:
		{
			menu.SetTitle("产生武器:");
			for (int i = 0; i < sizeof(g_sWeapons); i++)
			{
				menu.AddItem(g_sWeapons[i][ITEM_NAME], g_sWeapons[i][ITEM_DISPLAY]);
			}
		}
		case 1:
		{
			menu.SetTitle("产生近战:");
			for (int i = 0; i < sizeof(g_sMelees); i++)
			{
				menu.AddItem(g_sMelees[i][ITEM_NAME], g_sMelees[i][ITEM_DISPLAY]);
			}
		}
		case 2:
		{
			menu.SetTitle("产生医疗和投掷:");
			for (int i = 0; i < sizeof(g_sMedicalAndThrowItem); i++)
			{
				menu.AddItem(g_sMedicalAndThrowItem[i][ITEM_NAME], g_sMedicalAndThrowItem[i][ITEM_DISPLAY]);
			}
		}
		case 3:
		{
			menu.SetTitle("产生其他物品:");
			for (int i = 0; i < sizeof(g_sOtherItem); i++)
			{
				menu.AddItem(g_sOtherItem[i][ITEM_NAME], g_sOtherItem[i][ITEM_DISPLAY]);
			}
		}
	}
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iGiveItemMenuPos[client][g_iGiveItemType[client]], MENU_TIME_FOREVER);

}

int GiveItem_Select_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sName[128], sDisplay[128];
			menu.GetItem(itemNum, sName, sizeof(sName), _, sDisplay, sizeof(sDisplay));

			CheatCommand(client, "give", sName);
			Print(client, "[DevMenu] 产生物品: %s", sDisplay);

			g_iGiveItemMenuPos[client][g_iGiveItemType[client]] = menu.Selection;
			GiveItem_Select(client);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				GiveItem_TypeSelect(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void GiveHp_TargetSelect(int client)
{	
	Menu menu = new Menu(GiveHp_TargetSelect_MenuHandler);
	menu.SetTitle("选择回血目标:");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");
	menu.AddItem(g_sTargetName[TARGET_SI], "所有特感");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		int team = GetClientTeam(i);
		if (team == 2 || team == 3)
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iReHealthMenuPos[client], MENU_TIME_FOREVER);
}

int GiveHp_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoRestoreHealth(client, targetName);
			
			g_iReHealthMenuPos[client] = menu.Selection;
			GiveHp_TargetSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

Action Cmd_GiveHealth(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_rehp <me|sur|si|userid>");
		return Plugin_Handled;
	}

	char targetName[32];
	GetCmdArg(1, targetName, sizeof(targetName));
	DoRestoreHealth(client, targetName);
	return Plugin_Handled;
}

void DoRestoreHealth(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SELF:
		{
			RestoreHealth(client, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
			Print(client, "[DevMenu] 回血: %N", client);
		}

		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
				{
					RestoreHealth(i, GetEntProp(i, Prop_Send, "m_iMaxHealth"));
					Print(client, "[DevMenu] 回血: %N", i);
				}
			}
		}

		case TARGET_SI:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
				{
					RestoreHealth(i, GetEntProp(i, Prop_Send, "m_iMaxHealth"));
					Print(client, "[DevMenu] 回血: %N", i);
				}
			}
		}

		case TARGET_UNK:
		{
			int userid = 0;
			if (StringToIntEx(targetName, userid) != strlen(targetName))
				return;

			int target = GetClientOfUserId(userid);
			if (!target || !IsClientInGame(target) || !IsPlayerAlive(target))
				return;

			int team = GetClientTeam(target);
			if (team == 2 || team == 3)
			{
				RestoreHealth(target, GetEntProp(target, Prop_Send, "m_iMaxHealth"));
				Print(client, "[DevMenu] 回血: %N", target);
			}
		}
	}
}


void RestoreHealth(int client, int iHealth)
{
	if (GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_isIncapacitated")) // Mainly for TANK.
		return;

	Event event = CreateEvent("heal_success", true);
	event.SetInt("userid", GetClientUserId(client));
	event.SetInt("subject", GetClientUserId(client));
	event.SetInt("health_restored", iHealth - GetEntProp(client, Prop_Send, "m_iHealth"));

	int iflags = GetCommandFlags("give");
	SetCommandFlags("give", iflags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give health");
	SetCommandFlags("give", iflags);

	SetEntProp(client, Prop_Send, "m_iHealth", iHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());

	event.Fire();
}

void FallDown_TargetSelect(int client)
{	
	Menu menu = new Menu(FallDown_TargetSelect_MenuHandler);
	menu.SetTitle("选择倒地目标:");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2 && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iFalldownMenuPos[client], MENU_TIME_FOREVER);
}
 
  

int FallDown_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoFallDown(client, targetName);

			g_iFalldownMenuPos[client] = menu.Selection;
			FallDown_TargetSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void DoFallDown(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SELF:
		{
			if (IsPlayerAlive(client) && GetClientTeam(client) == 2 && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			{
				SDKHooks_TakeDamage(client, client, client, GetHealth(client)+1.0, DMG_GENERIC);
				Print(client, "[DevMenu] 强制倒地: %N", client);
			}
		}
		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2 && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
				{
					SDKHooks_TakeDamage(i, i, i, GetHealth(i)+1.0, DMG_GENERIC);
					Print(client, "[DevMenu] 强制倒地: %N", i);
				}
			}
		}
		case TARGET_UNK:
		{
			int target = GetClientOfUserId(StringToInt(targetName));
			if (target > 0 && IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) == 2 && !GetEntProp(target, Prop_Send, "m_isIncapacitated"))
			{
				SDKHooks_TakeDamage(target, target, target, GetHealth(target)+1.0, DMG_GENERIC);
				Print(client, "[DevMenu] 强制倒地: %N", target);
			}
		}
	}
}

void Respawn_TargetSelect(int client)
{	
	Menu menu = new Menu(Respawn_TargetSelect_MenuHandler);
	menu.SetTitle("选择复活目标:");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && !IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iRespawnMenuPos[client], MENU_TIME_FOREVER);
}


int Respawn_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoRespawn(client, targetName);

			g_iRespawnMenuPos[client] = menu.Selection;
			Respawn_TargetSelect(client);
		}

		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void DoRespawn(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SELF:
		{
			if (!IsPlayerAlive(client) && GetClientTeam(client) == 2)
			{
				if (L4D2_VScriptWrapper_ReviveByDefib(client))
					Print(client, "[DevMenu] 复活: %N", client);
			}
		}
		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					if (L4D2_VScriptWrapper_ReviveByDefib(i))
						Print(client, "[DevMenu]: 复活 %N", i);
				}
			}
		}
		case TARGET_UNK:
		{
			int target = GetClientOfUserId(StringToInt(targetName));
			if (target > 0 && IsClientInGame(target) && !IsPlayerAlive(target) && GetClientTeam(target) == 2)
			{
				L4D2_VScriptWrapper_ReviveByDefib(target);
				Print(client, "[DevMenu]: 复活 %N", target);
			}
		}
	}
}


void Deprive_TargetSelect(int client)
{	
	Menu menu = new Menu(Deprive_TargetSelect_MenuHandler);
	menu.SetTitle("选择装备剥夺目标:");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iDepriveMenuPos[client], MENU_TIME_FOREVER);
}


int Deprive_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoDeprive(client, targetName);

			g_iDepriveMenuPos[client] = menu.Selection;
			Deprive_TargetSelect(client);
		}
		
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void DoDeprive(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SELF:
		{
			if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
			{
				DepriveClientItem(client);
				Print(client, "[DevMenu] 剥夺 %N 的装备", client);
			}
		}
		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					DepriveClientItem(i);
					Print(client, "[DevMenu] 剥夺 %N 的装备", i);
				}
			}
		}
		case TARGET_UNK:
		{
			int target = GetClientOfUserId(StringToInt(targetName));
			if (target > 0 && IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) == 2)
			{
				DepriveClientItem(target);
				Print(client, "[DevMenu] 剥夺 %N 的装备", target);
			}
		}
	}
}


void DepriveClientItem(int client)
{
	for (int slot = 0; slot <= 4; slot++)
	{
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon != -1)
		{
			RemovePlayerItem(client, weapon);
			RemoveEntity(weapon);
		}
	}
}

void Freeze_TargetSelect(int client)
{
	Menu menu = new Menu(Freeze_TargetSelect_MenuHandler);
	menu.SetTitle("选择冻结目标:");
	menu.AddItem(g_sTargetName[TARGET_SELF], "自己");
	menu.AddItem(g_sTargetName[TARGET_SUR], "所有幸存者");
	menu.AddItem(g_sTargetName[TARGET_SI], "所有特感");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		int team = GetClientTeam(i);
		if (team == 2 || team == 3)
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iFreezeMenuPos[client], MENU_TIME_FOREVER);
}

int Freeze_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char targetName[32];
			menu.GetItem(itemNum, targetName, sizeof(targetName));
			DoFreeze(client, targetName);

			g_iFreezeMenuPos[client] = menu.Selection;
			Freeze_TargetSelect(client);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}


void DoFreeze(int client, const char[] targetName)
{
	switch (TargetToType(targetName))
	{
		case TARGET_SELF:
		{
			if (IsPlayerAlive(client) && (GetClientTeam(client) == 2 || GetClientTeam(client) == 3))
				FreezeClient(client, client);
		}
		case TARGET_SUR:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
					FreezeClient(client, i);
			}
		}
		case TARGET_SI:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
					FreezeClient(client, i);
			}
		}
		case TARGET_UNK:
		{
			int target = GetClientOfUserId(StringToInt(targetName));
			if (!target || !IsClientInGame(target) || !IsPlayerAlive(target))
				return;

			int team = GetClientTeam(target);
			if (team == 2 || team == 3)
				FreezeClient(client, target);
		}
	}
}

void FreezeClient(int client, int target)
{
	MoveType movetype = GetEntityMoveType(target);

	if (movetype != MOVETYPE_NONE)
	{
		SetEntityMoveType(target, MOVETYPE_NONE);
		Print(client, "[DevMenu] 设置冻结模式: %N", target);
	}
	else
	{
		SetEntityMoveType(target, MOVETYPE_WALK);
		Print(client, "[DevMenu] 解除冻结模式: %N", target);
	}
}
/*
void FreezeClient(int client, int target)
{
	int Flags = GetEntityFlags(target);

	if (Flags & FL_FROZEN)
	{
		SetEntityFlags(target, Flags & ~FL_FROZEN);
		Print(client, "[DevMenu] 解除冻结模式: %N", target);
	}
	else
	{
		SetEntityFlags(target, Flags | FL_FROZEN);
		Print(client, "[DevMenu] 设置冻结模式: %N", target);
	}
}
*/
void CheatCommand(int client, const char[] command, const char[] args = "")
{
	int iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, args);
	SetCommandFlags(command, iFlags);
}

public void OnMapStart()
{
	CreateTimer(4.0, PrecacheModel_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action PrecacheModel_Timer(Handle timer)
{
	for (int i = 0; i < sizeof(g_sWeapons); i++)
	{
		if (IsModelPrecached(g_sWeapons[i][ITEM_MODEL]))
			continue;

		if (PrecacheModel(g_sWeapons[i][ITEM_MODEL], true) <= 0)
			LogError("[DevMenu] %s 模型缓存错误", g_sWeapons[i][ITEM_MODEL]);
	}

	for (int i = 0; i < sizeof(g_sMelees); i++)
	{
		if (IsModelPrecached(g_sMelees[i][ITEM_MODEL]))
			continue;

		if (PrecacheModel(g_sMelees[i][ITEM_MODEL], true) <= 0)
			LogError("[DevMenu] %s 模型缓存错误", g_sMelees[i][ITEM_MODEL]);
	}

	for (int i = 0; i < sizeof(g_sMedicalAndThrowItem); i++)
	{
		if (IsModelPrecached(g_sMedicalAndThrowItem[i][ITEM_MODEL]))
			continue;

		if (PrecacheModel(g_sMedicalAndThrowItem[i][ITEM_MODEL], true) <= 0)
			LogError("[DevMenu] %s 模型缓存错误", g_sMedicalAndThrowItem[i][ITEM_MODEL]);
	}

	for (int i = 0; i < sizeof(g_sOtherItem); i++)
	{
		if (IsModelPrecached(g_sOtherItem[i][ITEM_MODEL]))
			continue;

		if (PrecacheModel(g_sOtherItem[i][ITEM_MODEL], true) <= 0)
			LogError("[DevMenu] %s 模型缓存错误", g_sOtherItem[i][ITEM_MODEL]);
	}

	return Plugin_Continue;
}



int NameToClass(const char[] name)
{
	for (int i = 1; i < sizeof(g_sClassName); i++)
	{
		if (!strcmp(g_sClassName[i], name, false))
			return i;
	}
	return -1;
}

int TargetToType(const char[] name)
{
	for (int i = 0; i < sizeof(g_sTargetName); i++)
	{
		if (!strcmp(g_sTargetName[i], name, false))
			return i;
	}
	return TARGET_UNK;
}

int SpawnProtect(int class, int value)
{
	ConVar cvar = null;

	switch (class)
	{
		case ZC_SMOKER, ZC_BOOMER, ZC_HUNTER, ZC_SPITTER, ZC_JOCKEY, ZC_CHARGER:
			cvar = FindConVar("l4d2_si_spawn_control_block_other_si_spawn");
		case ZC_WITCH:
			cvar = FindConVar("l4d2_boss_spawn_control_block_other_witch_spawn");
		case ZC_TANK:
			cvar = FindConVar("l4d2_boss_spawn_control_block_other_tank_spawn");
	}

	if (!cvar)
		return -1;

	int oldValue = cvar.IntValue;
	cvar.IntValue = value;
	return oldValue;
}

float GetHealth(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_healthBuffer") + GetEntProp(client, Prop_Send, "m_iHealth");
}

void Print(int client, const char[] msg, any ...)
{
	if (!client || !IsClientInGame(client))
		return;

	char buffer[253];
	VFormat(buffer, sizeof(buffer), msg, 3);
	PrintToChat(client, "%s", buffer);
}

