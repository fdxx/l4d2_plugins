#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <adminmenu>
#include <left4dhooks>

#define VERSION "0.6"

#define	BOSS_TYPE_TANK	0
#define	BOSS_TYPE_WITCH	1


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
	g_iGiveItemType[MAXPLAYERS+1];

bool
	g_bGodMode[MAXPLAYERS+1],
	g_bAutoSpawn[MAXPLAYERS+1],
	g_bSpawnType[MAXPLAYERS+1],
	g_bSpecialSpawnControl,
	g_bBossSpawnControl;
	
StringMap
	g_smNameToClass;

public Plugin myinfo = 
{
	name = "L4D2 Dev Menu",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_dev_menu_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	CreateStringMap();

	RegAdminCmd("sm_kl", Cmd_Kill, ADMFLAG_ROOT);
	RegAdminCmd("sm_god", Cmd_GodMode, ADMFLAG_ROOT);
	RegAdminCmd("sm_fly", Cmd_Noclip, ADMFLAG_ROOT);
	RegAdminCmd("sm_tele", Cmd_Teleport, ADMFLAG_ROOT);
	RegAdminCmd("sm_givehp", Cmd_GiveHealth, ADMFLAG_ROOT);
	RegAdminCmd("sm_rehp", Cmd_GiveHealth, ADMFLAG_ROOT);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_bGodMode[i] = false;
	}
}

public void OnClientDisconnect(int client)
{
	g_bGodMode[client] = false;
}

public void OnClientPutInServer(int client)
{
	g_bGodMode[client] = false;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_bGodMode[victim]) return Plugin_Continue;

	char sName[6];
	if (attacker > MaxClients && GetEdictClassname(attacker, sName, sizeof(sName)) && strcmp(sName, "witch") == 0)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

void CreateStringMap()
{
	g_smNameToClass = new StringMap();
	g_smNameToClass.SetValue("smoker", 1, true);
	g_smNameToClass.SetValue("boomer", 2, true);
	g_smNameToClass.SetValue("hunter", 3, true);
	g_smNameToClass.SetValue("spitter", 4, true);
	g_smNameToClass.SetValue("jockey", 5, true);
	g_smNameToClass.SetValue("charger", 6, true);
	g_smNameToClass.SetValue("witch", 7, true);
	g_smNameToClass.SetValue("tank", 8, true);
}

public void OnConfigsExecuted()
{
	g_bSpecialSpawnControl = GetFeatureStatus(FeatureType_Native, "L4D2_CanSpawnSpecial") == FeatureStatus_Available;
	g_bBossSpawnControl = GetFeatureStatus(FeatureType_Native, "L4D2_CanSpawnBoss") == FeatureStatus_Available;

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
	{
		g_iGiveItemMenuPos[client][i] = 0;
	}
	g_iSpecialClassMenuPos[client] = 0;
	g_iNoClipMenuPos[client] = 0;
	g_iGodModeMenuPos[client] = 0;
	g_iKillMenuPos[client] = 0;
}

void Kill_TargetSelect(int client)
{
	Menu menu = new Menu(Kill_TargetSelect_MenuHandler);
	menu.SetTitle("选择处死目标:");
	menu.AddItem("", "所有特感");
	menu.AddItem("", "所有普通感染者");
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i))
		{
			switch (GetClientTeam(i))
			{
				case 2, 3:
				{
					FormatEx(sName, sizeof(sName), "%N", i);
					FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
					menu.AddItem(sUserid, sName);
				}
			}
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
			switch (itemNum)
			{
				case 0, 1, 2, 3: DoKill(client, itemNum);
				default:
				{
					char sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget))
					{
						switch (GetClientTeam(iTarget))
						{
							case 2, 3:
							{
								ForcePlayerSuicide(iTarget);
								PrintToChat(client, "[DevMenu] 处死: %N", iTarget);
							}
						}
					}
				}
			}

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
		ReplyToCommand(client, "sm_kl <si|ci|me|sur|all>");
		return Plugin_Handled;
	}

	int iType = -1;
	char sTarget[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));
	if (strcmp(sTarget, "si", false) == 0)
		iType = 0;
	else if (strcmp(sTarget, "ci", false) == 0)
		iType = 1;
	else if (strcmp(sTarget, "me", false) == 0)
		iType = 2;
	else if (strcmp(sTarget, "sur", false) == 0)
		iType = 3;
	else if (strcmp(sTarget, "all", false) == 0)
		iType = 4;
	
	DoKill(client, iType);
	return Plugin_Handled;
}

void DoKill(int client, int iType)
{
	switch (iType)
	{
		case 0:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
				{
					ForcePlayerSuicide(i);
					PrintToChat(client, "[DevMenu] 处死: %N", i);
				}
			}

			int witch = -1;
			while ((witch = FindEntityByClassname(witch, "witch")) != INVALID_ENT_REFERENCE)
			{
				AcceptEntityInput(witch, "Kill");
				PrintToChat(client, "[DevMenu] 处死: Witch");
			}
		}
		case 1:
		{
			int inf = -1;
			int count;
			while ((inf = FindEntityByClassname(inf, "infected")) != INVALID_ENT_REFERENCE)
			{
				count++;
				AcceptEntityInput(inf, "Kill");
			}
			PrintToChat(client, "[DevMenu] 处死普通感染者: %i 个", count);
		}
		case 2:
		{
			if (IsPlayerAlive(client))
			{
				ForcePlayerSuicide(client);
				PrintToChat(client, "[DevMenu] 处死: %N", client);
			}
		}
		case 3:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					ForcePlayerSuicide(i);
					PrintToChat(client, "[DevMenu] 处死: %N", i);
				}
			}
		}
		case 4:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == 2 || GetClientTeam(i) == 3))
				{
					ForcePlayerSuicide(i);
					PrintToChat(client, "[DevMenu] 处死: %N", i);
				}
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
	menu.AddItem("tank", "Tank");
	menu.AddItem("witch", "Witch");
	menu.AddItem("smoker", "Smoker");
	menu.AddItem("boomer", "Boomer");
	menu.AddItem("hunter", "Hunter");
	menu.AddItem("spitter", "Spitter");
	menu.AddItem("jockey", "Jockey");
	menu.AddItem("charger", "Charger");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iSpecialClassMenuPos[client], MENU_TIME_FOREVER);
}

int SpawnSpecial_ClassSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0: g_bSpawnType[client] = !g_bSpawnType[client];
				case 1: g_bAutoSpawn[client] = !g_bAutoSpawn[client];
				default:
				{
					AllowSpawn(true);

					char sName[16], sDisplay[128];
					menu.GetItem(itemNum, sName, sizeof(sName), _, sDisplay, sizeof(sDisplay));

					if (!g_bSpawnType[client])
					{
						char sCmdArgs[128];
						FormatEx(sCmdArgs, sizeof(sCmdArgs), "%s%s", sName, (g_bAutoSpawn[client] ? " auto" : ""));
						CheatCommand(client, "z_spawn_old", sCmdArgs);
						PrintToChat(client, "[DevMenu] 产生特感 (z_spawn_old): %s", sDisplay);
					}
					else
					{
						int iClass;
						if (g_smNameToClass.GetValue(sName, iClass))
						{
							float fPos[3];
							if (GetSpawnPos(client, iClass, fPos))
							{
								bool bSpawnSuccess;
								switch (iClass)
								{
									case 1,2,3,4,5,6:
										bSpawnSuccess = L4D2_SpawnSpecial(iClass, fPos, NULL_VECTOR) > 0;

									case 7:
										bSpawnSuccess = L4D2_SpawnWitch(fPos, NULL_VECTOR) > MaxClients;
									
									case 8:
										bSpawnSuccess = L4D2_SpawnTank(fPos, NULL_VECTOR) > 0;
								}
								if (bSpawnSuccess)
								{
									PrintToChat(client, "[DevMenu] 产生特感 (left4dhooks): %s", sDisplay);
								}
							}
						}
					}

					AllowSpawn(false);
				}
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

bool GetSpawnPos(int client, int iClass, float fPos[3])
{
	if (g_bAutoSpawn[client])
	{
		return L4D_GetRandomPZSpawnPosition(client, iClass, 30, fPos);
	}
	else
	{
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
}

bool TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients;
}

void GodMode_TargetSelect(int client)
{
	Menu menu = new Menu(GodMode_TargetSelect_MenuHandler);
	menu.SetTitle("选择无敌模式目标:");
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");
	menu.AddItem("", "所有特感");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i))
		{
			switch (GetClientTeam(i))
			{
				case 2:
				{
					FormatEx(sName, sizeof(sName), "%N", i);
					FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
					menu.AddItem(sUserid, sName);
				}
				case 3:
				{
					if (!GetEntProp(i, Prop_Send, "m_isGhost"))
					{
						FormatEx(sName, sizeof(sName), "%N", i);
						FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
						menu.AddItem(sUserid, sName);
					}
				}
			}
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
			switch (itemNum)
			{
				case 0, 1, 2: DoGodMode(client, itemNum);
				default:
				{
					char sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget))
					{
						switch (GetClientTeam(iTarget))
						{
							case 2: SetClientGodMode(client, iTarget);
							case 3:
							{
								if (!GetEntProp(iTarget, Prop_Send, "m_isGhost"))
									SetClientGodMode(client, iTarget);
							}
						}
					}
				}
			}

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
		ReplyToCommand(client, "sm_god <me|sur|si>");
		return Plugin_Handled;
	}

	int iType = -1;
	char sTarget[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));
	if (strcmp(sTarget, "me", false) == 0)
		iType = 0;
	else if (strcmp(sTarget, "sur", false) == 0)
		iType = 1;
	else if (strcmp(sTarget, "si", false) == 0)
		iType = 2;
	
	DoGodMode(client, iType);
	return Plugin_Handled;
}

void DoGodMode(int client, int iType)
{
	switch (iType)
	{
		case 0:
		{
			if (IsPlayerAlive(client))
			{
				switch (GetClientTeam(client))
				{
					case 2: SetClientGodMode(client, client);
					case 3:
					{
						if (!GetEntProp(client, Prop_Send, "m_isGhost"))
							SetClientGodMode(client, client);
					}
				}
			}
		}
		case 1:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					SetClientGodMode(client, i);
				}
			}
		}
		case 2:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3 && !GetEntProp(i, Prop_Send, "m_isGhost"))
				{
					SetClientGodMode(client, i);
				}
			}
		}
	}
}

void SetClientGodMode(int client, int iTarget)
{
	bool bGodMode = GetEntProp(iTarget, Prop_Data, "m_takedamage") == 0;

	if (bGodMode)
	{
		g_bGodMode[iTarget] = false;
		SetEntProp(iTarget, Prop_Data, "m_takedamage", 2);
		PrintToChat(client, "[DevMenu] 关闭无敌模式: %N", iTarget);
	}
	else
	{
		g_bGodMode[iTarget] = true;
		SetEntProp(iTarget, Prop_Data, "m_takedamage", 0);
		PrintToChat(client, "[DevMenu] 开启无敌模式: %N", iTarget);
	}
}

void NoClip_TargetSelect(int client)
{
	Menu menu = new Menu(NoClip_TargetSelect_MenuHandler);
	menu.SetTitle("选择穿墙模式目标:");
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");
	menu.AddItem("", "所有特感");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
			{
				FormatEx(sName, sizeof(sName), "%N", i);
				FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
				menu.AddItem(sUserid, sName);
			}
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
			switch (itemNum)
			{
				case 0, 1, 2: DoNoclip(client, itemNum);
				default:
				{
					char sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget))
					{
						if (GetClientTeam(iTarget) == 2 || GetClientTeam(iTarget) == 3)
						{
							SetClientNoClip(client, iTarget);
						}
					}
				}
			}

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
		ReplyToCommand(client, "sm_fly <me|sur|si>");
		return Plugin_Handled;
	}

	int iType = -1;
	char sTarget[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));
	if (strcmp(sTarget, "me", false) == 0)
		iType = 0;
	else if (strcmp(sTarget, "sur", false) == 0)
		iType = 1;
	else if (strcmp(sTarget, "si", false) == 0)
		iType = 2;
	
	DoNoclip(client, iType);
	return Plugin_Handled;
}

void DoNoclip(int client, int iType)
{
	switch (iType)
	{
		case 0:
		{
			if (IsPlayerAlive(client))
			{
				SetClientNoClip(client, client);
			}
		}
		case 1:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					SetClientNoClip(client, i);
				}
			}
		}
		case 2:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
				{
					SetClientNoClip(client, i);
				}
			}
		}
	}
}

void SetClientNoClip(int client, int iTarget)
{
	MoveType movetype = GetEntityMoveType(iTarget);

	if (movetype != MOVETYPE_NOCLIP)
	{
		SetEntityMoveType(iTarget, MOVETYPE_NOCLIP);
		PrintToChat(client, "[DevMenu] 开启穿墙模式: %N", iTarget);
	}
	else
	{
		SetEntityMoveType(iTarget, MOVETYPE_WALK);
		PrintToChat(client, "[DevMenu] 关闭穿墙模式: %N", iTarget);
	}
}

void Teleport_TypeSelect(int client)
{
	Menu menu = new Menu(Teleport_TypeSelect_MenuHandler);
	menu.SetTitle("选择传送类型:");
	menu.AddItem("", "传送幸存者到自己");
	menu.AddItem("", "传送特感到自己");
	menu.AddItem("", "所有幸存者到安全屋");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Teleport_TypeSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0, 1, 2: DoTeleport(client, itemNum);
			}

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
		int iType = -1;
		char sTarget[32];

		GetCmdArg(1, sTarget, sizeof(sTarget));
		if (strcmp(sTarget, "sur", false) == 0)
			iType = 0;
		else if (strcmp(sTarget, "si", false) == 0)
			iType = 1;
		else if (strcmp(sTarget, "saferoom", false) == 0)
			iType = 2;
		
		DoTeleport(client, iType);
	}

	else if (args == 3)
	{
		float fPos[3];

		fPos[0] = GetCmdArgFloat(1);
		fPos[1] = GetCmdArgFloat(2);
		fPos[2] = GetCmdArgFloat(3);

		TeleportEntity(client, fPos, NULL_VECTOR, NULL_VECTOR);
		PrintToChat(client, "[DevMenu] 传送自己到: %f %f %f", fPos[0], fPos[1], fPos[2]);
	}

	return Plugin_Handled;
}

void DoTeleport(int client, int iType)
{
	float fPos[3];
	GetClientAbsOrigin(client, fPos);

	switch (iType)
	{
		case 0:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
				{
					TeleportEntity(i, fPos, NULL_VECTOR, NULL_VECTOR);
					PrintToChat(client, "[DevMenu] 传送幸存者到自己");
				}
			}
		}
		case 1:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
				{
					TeleportEntity(i, fPos, NULL_VECTOR, NULL_VECTOR);
					PrintToChat(client, "[DevMenu] 传送特感到自己");
				}
			}
		}
		case 2:
		{
			CheatCommand(client, "warp_all_survivors_to_checkpoint");
			PrintToChat(client, "[DevMenu] 传送所有幸存者到安全屋");
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
			PrintToChat(client, "[DevMenu] 产生物品: %s", sDisplay);

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
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");
	menu.AddItem("", "所有特感");

	char sName[128], sUserid[16];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i))
		{
			switch (GetClientTeam(i))
			{
				case 2, 3:
				{
					FormatEx(sName, sizeof(sName), "%N", i);
					FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
					menu.AddItem(sUserid, sName);
				}
			}
		}
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int GiveHp_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0:
				{
					RestoreHealth(client, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
					PrintToChat(client, "[DevMenu] 回血: %N", client);
				}
				case 1:
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
						{
							RestoreHealth(i, GetEntProp(i, Prop_Send, "m_iMaxHealth"));
							PrintToChat(client, "[DevMenu] 回血: %N", i);
						}
					}
				}
				case 2:
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
						{
							RestoreHealth(i, GetEntProp(i, Prop_Send, "m_iMaxHealth"));
							PrintToChat(client, "[DevMenu] 回血: %N", i);
						}
					}
				}
				default:
				{
					char sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget))
					{
						RestoreHealth(iTarget, GetEntProp(iTarget, Prop_Send, "m_iMaxHealth"));
						PrintToChat(client, "[DevMenu] 回血: %N", iTarget);
					}
				}
			}

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
		ReplyToCommand(client, "sm_rehp <me|sur|si>");
		return Plugin_Handled;
	}

	int iType = -1;
	char sTarget[32];

	GetCmdArg(1, sTarget, sizeof(sTarget));
	if (strcmp(sTarget, "me", false) == 0)
		iType = 0;
	else if (strcmp(sTarget, "sur", false) == 0)
		iType = 1;
	else if (strcmp(sTarget, "si", false) == 0)
		iType = 2;
	
	switch (iType)
	{
		case 0:
		{
			RestoreHealth(client, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
			PrintToChat(client, "[DevMenu] 回血: %N", client);
		}
		case 1:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
				{
					RestoreHealth(i, GetEntProp(i, Prop_Send, "m_iMaxHealth"));
					PrintToChat(client, "[DevMenu] 回血: %N", i);
				}
			}
		}
		case 2:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
				{
					RestoreHealth(i, GetEntProp(i, Prop_Send, "m_iMaxHealth"));
					PrintToChat(client, "[DevMenu] 回血: %N", i);
				}
			}
		}

	}
	return Plugin_Handled;
}

void RestoreHealth(int client, int iHealth)
{
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
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");

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
	menu.Display(client, MENU_TIME_FOREVER);
}

int FallDown_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0:
				{
					if (IsPlayerAlive(client) && GetClientTeam(client) == 2 && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
					{
						SDKHooks_TakeDamage(client, client, client, 99999.0, DMG_GENERIC);
						PrintToChat(client, "[DevMenu] 强制倒地: %N", client);
					}
				}
				case 1:
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2 && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
						{
							SDKHooks_TakeDamage(i, i, i, 99999.0, DMG_GENERIC);
							PrintToChat(client, "[DevMenu] 强制倒地: %N", i);
						}
					}
				}
				default:
				{
					char sName[128], sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid), _, sName, sizeof(sName));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && GetClientTeam(iTarget) == 2 && !GetEntProp(iTarget, Prop_Send, "m_isIncapacitated"))
					{
						SDKHooks_TakeDamage(iTarget, iTarget, iTarget, 99999.0, DMG_GENERIC);
						PrintToChat(client, "[DevMenu] 强制倒地: %N", iTarget);
					}
				}
			}

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

void Respawn_TargetSelect(int client)
{	
	Menu menu = new Menu(Respawn_TargetSelect_MenuHandler);
	menu.SetTitle("选择复活目标:");
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");

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
	menu.Display(client, MENU_TIME_FOREVER);
}

int Respawn_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0:
				{
					if (!IsPlayerAlive(client) && GetClientTeam(client) == 2)
					{
						if (L4D2_VScriptWrapper_ReviveByDefib(client))
							PrintToChat(client, "[DevMenu] 复活: %N", client);
					}
				}
				case 1:
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && !IsPlayerAlive(i) && GetClientTeam(i) == 2)
						{
							if (L4D2_VScriptWrapper_ReviveByDefib(i))
								PrintToChat(client, "[DevMenu]: 复活 %N", i);
						}
					}
				}
				default:
				{
					char sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && !IsPlayerAlive(iTarget) && GetClientTeam(iTarget) == 2)
					{
						if (L4D2_VScriptWrapper_ReviveByDefib(iTarget))
							PrintToChat(client, "[DevMenu]: 复活 %N", iTarget);
					}
				}
			}

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

void Deprive_TargetSelect(int client)
{	
	Menu menu = new Menu(Deprive_TargetSelect_MenuHandler);
	menu.SetTitle("选择装备剥夺目标:");
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");

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
	menu.Display(client, MENU_TIME_FOREVER);
}

int Deprive_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0:
				{
					if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
					{
						DepriveClientItem(client);
						PrintToChat(client, "[DevMenu] 剥夺 %N 的装备", client);
					}
				}
				case 1:
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
						{
							DepriveClientItem(i);
							PrintToChat(client, "[DevMenu] 剥夺 %N 的装备", i);
						}
					}
				}
				default:
				{
					char sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget) && GetClientTeam(iTarget) == 2)
					{
						DepriveClientItem(iTarget);
						PrintToChat(client, "[DevMenu] 剥夺 %N 的装备", iTarget);
					}
				}
			}

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
	menu.AddItem("", "自己");
	menu.AddItem("", "所有幸存者");
	menu.AddItem("", "所有特感");

	char sName[128], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i))
		{
			switch (GetClientTeam(i))
			{
				case 2, 3:
				{
					FormatEx(sName, sizeof(sName), "%N", i);
					FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
					menu.AddItem(sUserid, sName);
				}
			}
		}
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Freeze_TargetSelect_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0:
				{
					if (IsPlayerAlive(client))
					{
						switch (GetClientTeam(client))
						{
							case 2, 3: FreezeClient(client, client);
						}
					}
				}
				case 1:
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
						{
							FreezeClient(client, i);
						}
					}
				}
				case 2:
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
						{
							FreezeClient(client, i);
						}
					}
				}
				default:
				{
					char sUserid[16];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientInGame(iTarget) && IsPlayerAlive(iTarget))
					{
						switch (GetClientTeam(iTarget))
						{
							case 2, 3: FreezeClient(client, iTarget);
						}
					}
				}
			}

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

void FreezeClient(int client, int iTarget)
{
	MoveType movetype = GetEntityMoveType(iTarget);

	if (movetype != MOVETYPE_NONE)
	{
		SetEntityMoveType(iTarget, MOVETYPE_NONE);
		PrintToChat(client, "[DevMenu] 设置冻结模式: %N", iTarget);
	}
	else
	{
		SetEntityMoveType(iTarget, MOVETYPE_WALK);
		PrintToChat(client, "[DevMenu] 解除冻结模式: %N", iTarget);
	}
}
/*
void FreezeClient(int client, int iTarget)
{
	int Flags = GetEntityFlags(iTarget);

	if (Flags & FL_FROZEN)
	{
		SetEntityFlags(iTarget, Flags &= ~FL_FROZEN);
		PrintToChat(client, "[DevMenu] 解除冻结模式: %N", iTarget);
	}
	else
	{
		SetEntityFlags(iTarget, Flags |= FL_FROZEN);
		PrintToChat(client, "[DevMenu] 设置冻结模式: %N", iTarget);
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
	static int i;
	for (i = 0; i < sizeof(g_sWeapons); i++)
	{
		if (!IsModelPrecached(g_sWeapons[i][ITEM_MODEL]))
		{
			if (PrecacheModel(g_sWeapons[i][ITEM_MODEL], true) <= 0)
			{
				LogError("[DevMenu] %s 模型缓存错误", g_sWeapons[i][ITEM_MODEL]);
			}
		}
	}

	for (i = 0; i < sizeof(g_sMelees); i++)
	{
		if (!IsModelPrecached(g_sMelees[i][ITEM_MODEL]))
		{
			if (PrecacheModel(g_sMelees[i][ITEM_MODEL], true) <= 0)
			{
				LogError("[DevMenu] %s 模型缓存错误", g_sMelees[i][ITEM_MODEL]);
			}
		}
	}

	for (i = 0; i < sizeof(g_sMedicalAndThrowItem); i++)
	{
		if (!IsModelPrecached(g_sMedicalAndThrowItem[i][ITEM_MODEL]))
		{
			if (PrecacheModel(g_sMedicalAndThrowItem[i][ITEM_MODEL], true) <= 0)
			{
				LogError("[DevMenu] %s 模型缓存错误", g_sMedicalAndThrowItem[i][ITEM_MODEL]);
			}
		}
	}

	for (i = 0; i < sizeof(g_sOtherItem); i++)
	{
		if (!IsModelPrecached(g_sOtherItem[i][ITEM_MODEL]))
		{
			if (PrecacheModel(g_sOtherItem[i][ITEM_MODEL], true) <= 0)
			{
				LogError("[DevMenu] %s 模型缓存错误", g_sOtherItem[i][ITEM_MODEL]);
			}
		}
	}

	return Plugin_Continue;
}

native void L4D2_CanSpawnSpecial(bool bCanSpawn);
native void L4D2_CanSpawnBoss(int iBossType, bool bCanSpawn);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("L4D2_CanSpawnSpecial");
	MarkNativeAsOptional("L4D2_CanSpawnBoss");
	return APLRes_Success;
}

void AllowSpawn(bool bAllow)
{
	if (g_bSpecialSpawnControl)
	{
		L4D2_CanSpawnSpecial(bAllow);
	}

	if (g_bBossSpawnControl)
	{
		L4D2_CanSpawnBoss(BOSS_TYPE_TANK, bAllow);
		L4D2_CanSpawnBoss(BOSS_TYPE_WITCH, bAllow);
	}
}
