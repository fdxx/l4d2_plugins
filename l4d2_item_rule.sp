#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>

#if DEBUG
#include <profiler>
#endif

#define VERSION "1.1"

char g_sLogPath[PLATFORM_MAX_PATH], g_sConfigPath[PLATFORM_MAX_PATH];
bool g_bFinalMap, g_bOfficialMap;
ArrayList g_aItemsArray, g_aTemItemsArray, g_aKitPosArray;
ConVar CvarFinalMapPills, CvarDelFootLocker, CvarStartItems;
bool g_bFinalMapPills, g_bDelFootLocker;
char g_sStartItems[256];

StringMap g_smNameToNumber, g_smModelToName, g_smOldItemToNewItem, g_smItemToLimitNum;
KeyValues g_kv;

enum struct g_eItemInfo
{
	char sName[64];
	float fPos[3];
	float fAng[3];
}

enum
{
	SPAWN_TYPE,
	HAS_SPAWN_CLASS,
	HAS_COUNT,
	ITEM_NAME,
	ITEM_MODEL
}

//https://github.com/raziEiL/l4d2_weapons/blob/master/scripting/include/l4d2_weapons.inc
static const char g_sItems[][][] = 
{
	{"1",	"true",		"true",		"weapon_first_aid_kit",				"models/w_models/weapons/w_eq_medkit.mdl"},					//0 急救包
	{"1",	"true",		"true",		"weapon_pain_pills",				"models/w_models/weapons/w_eq_painpills.mdl"},				//1 止痛药
	{"1",	"true",		"true",		"weapon_adrenaline",				"models/w_models/weapons/w_eq_adrenaline.mdl"},				//2 肾上腺素
	{"1",	"true",		"true",		"weapon_defibrillator",				"models/w_models/weapons/w_eq_defibrillator.mdl"},			//3 电击除颤器
	{"1",	"true",		"true",		"weapon_molotov",					"models/w_models/weapons/w_eq_molotov.mdl"},				//4 燃烧瓶
	{"1",	"true",		"true",		"weapon_pipe_bomb",					"models/w_models/weapons/w_eq_pipebomb.mdl"},				//5 土制炸弹
	{"1",	"true",		"true",		"weapon_vomitjar",					"models/w_models/weapons/w_eq_bile_flask.mdl"},				//6 胆汁瓶
	{"1",	"true",		"false",	"weapon_upgradepack_incendiary",	"models/w_models/weapons/w_eq_incendiary_ammopack.mdl"},	//7 燃烧弹升级包
	{"1",	"true",		"false",	"weapon_upgradepack_explosive",		"models/w_models/weapons/w_eq_explosive_ammopack.mdl"},		//8 高爆弹升级包
	{"1",	"true",		"true",		"weapon_shotgun_chrome",			"models/w_models/weapons/w_pumpshotgun_A.mdl"},				//9 铁喷
	{"1",	"true",		"true",		"weapon_pumpshotgun",				"models/w_models/weapons/w_shotgun.mdl"},					//10 木喷
	{"1",	"true",		"true",		"weapon_smg",						"models/w_models/weapons/w_smg_uzi.mdl"},					//11 乌兹
	{"1",	"true",		"true",		"weapon_smg_silenced",				"models/w_models/weapons/w_smg_a.mdl"},						//12 消音冲锋
	{"1",	"true",		"true",		"weapon_autoshotgun",				"models/w_models/weapons/w_autoshot_m4super.mdl"},			//13 连喷
	{"1",	"true",		"true",		"weapon_shotgun_spas",				"models/w_models/weapons/w_shotgun_spas.mdl"},				//14 钢喷
	{"1",	"true",		"true",		"weapon_rifle",						"models/w_models/weapons/w_rifle_m16a2.mdl"},				//15 M4
	{"1",	"true",		"true",		"weapon_rifle_desert",				"models/w_models/weapons/w_desert_rifle.mdl"},				//16 三连发
	{"1",	"true",		"true",		"weapon_rifle_ak47",				"models/w_models/weapons/w_rifle_ak47.mdl"},				//17 AK47
	{"1",	"true",		"true",		"weapon_sniper_military",			"models/w_models/weapons/w_sniper_military.mdl"},			//18 连狙
	{"1",	"true",		"true",		"weapon_hunting_rifle",				"models/w_models/weapons/w_sniper_mini14.mdl"},				//19 木狙
	{"1",	"false",	"false",	"weapon_sniper_awp",				"models/w_models/weapons/w_sniper_awp.mdl"},				//20 AWP
	{"1",	"false",	"false",	"weapon_sniper_scout",				"models/w_models/weapons/w_sniper_scout.mdl"},				//21 鸟狙
	{"1",	"false",	"false",	"weapon_smg_mp5",					"models/w_models/weapons/w_smg_mp5.mdl"},					//22 MP5
	{"1",	"false",	"false",	"weapon_rifle_sg552",				"models/w_models/weapons/w_rifle_sg552.mdl"},				//23 SG552
	{"1",	"true",		"false",	"weapon_grenade_launcher",			"models/w_models/weapons/w_grenade_launcher.mdl"},			//24 榴弹发射器	
	{"1",	"true",		"false",	"weapon_rifle_m60",					"models/w_models/weapons/w_m60.mdl"},						//25 M60
	{"1",	"true",		"false",	"weapon_chainsaw",					"models/weapons/melee/w_chainsaw.mdl"},						//26 电锯

	{"2",	"false",	"false",	"weapon_gascan",					"models/props_junk/gascan001a.mdl"},						//27 汽油箱
	{"2",	"false",	"false",	"weapon_propanetank",				"models/props_junk/propanecanister001a.mdl"},				//28 丙烷罐
	{"2",	"false",	"false",	"weapon_oxygentank",				"models/props_equipment/oxygentank01.mdl"},					//29 氧气罐
	{"2",	"false",	"false",	"weapon_fireworkcrate",				"models/props_junk/explosive_box001.mdl"},					//30 烟花盒

	{"3",	"false",	"false",	"upgrade_laser_sight",				"models/w_models/Weapons/w_laser_sights.mdl"},				//31 激光瞄准器
};

public Plugin myinfo = 
{
	name = "L4D2 Item rule",
	author = "fdxx",
	description = "物品规则",
	version = VERSION,
	url = ""
};

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_item_rule.log");
	BuildPath(Path_SM, g_sConfigPath, sizeof(g_sConfigPath), "data/l4d2_item_rule.cfg");

	CreateConVar("l4d2_item_rule_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	CvarFinalMapPills = CreateConVar("l4d2_item_rule_finalmap_pills", "1", "将结局地图的包替换成药", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarDelFootLocker = CreateConVar("l4d2_item_rule_del_footlocker", "1", "删除物品箱(c6m1大量物品的箱子)", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarStartItems = CreateConVar("l4d2_item_rule_start_give_items", "weapon_pain_pills;health", "出门给的物品, 多个物品用;分割", FCVAR_NONE);
	
	GetCvars();

	CvarFinalMapPills.AddChangeHook(ConVarChanged);
	CvarDelFootLocker.AddChangeHook(ConVarChanged);
	CvarStartItems.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart_C4, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_limit_item", Cmd_LimitItems, ADMFLAG_ROOT);
	RegAdminCmd("sm_spawn_item", Cmd_SpawnItem, ADMFLAG_ROOT);
	RegAdminCmd("sm_spawn_all_item", Cmd_SpawnAllItem, ADMFLAG_ROOT);

	Initialization();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();	
}

void GetCvars()
{
	g_bFinalMapPills = CvarFinalMapPills.BoolValue;
	g_bDelFootLocker = CvarDelFootLocker.BoolValue;
	CvarStartItems.GetString(g_sStartItems, sizeof(g_sStartItems));
}

void Initialization()
{
	g_aItemsArray = new ArrayList(sizeof(g_eItemInfo));
	g_aTemItemsArray = new ArrayList(sizeof(g_eItemInfo));
	g_aKitPosArray = new ArrayList(3);

	g_smModelToName = new StringMap();
	g_smNameToNumber = new StringMap();
	
	char sModel[PLATFORM_MAX_PATH];
	for (int i = 0; i < sizeof(g_sItems); i++)
	{
		strcopy(sModel, sizeof(sModel), g_sItems[i][ITEM_MODEL]);
		StrToLowerCase(sModel);
		g_smModelToName.SetString(sModel, g_sItems[i][ITEM_NAME]);
		g_smNameToNumber.SetValue(g_sItems[i][ITEM_NAME], i);
	}

	g_smOldItemToNewItem = new StringMap();
	g_smItemToLimitNum = new StringMap();

	g_kv = new KeyValues("l4d2_item_rule");
	if (g_kv.ImportFromFile(g_sConfigPath))
	{
		char sItem[64], sNewItem[64];
		int iLimit;

		// 保存物品替换数据
		if (g_kv.JumpToKey("item_replace"))
		{
			if (g_kv.GotoFirstSubKey(false))
			{
				do
				{
					if (g_kv.GetSectionName(sItem, sizeof(sItem)))
					{
						g_kv.GetString(NULL_STRING, sNewItem, sizeof(sNewItem));
						
						if (sNewItem[0] != '\0')
						{
							g_smOldItemToNewItem.SetString(sItem, sNewItem);
						}
						else LogError("[错误] g_kv.GetString 失败");
					}
					else LogError("[错误] g_kv.GetSectionName 失败");
				}
				while (g_kv.GotoNextKey(false));
			}
			else LogError("[错误] g_kv.GotoFirstSubKey 失败");
		}
		else LogError("[错误] g_kv.JumpToKey item_replace 失败");

		g_kv.Rewind();

		// 保存物品限制数据
		if (g_kv.JumpToKey("item_limit"))
		{
			if (g_kv.GotoFirstSubKey(false))
			{
				do
				{
					if (g_kv.GetSectionName(sItem, sizeof(sItem)))
					{
						iLimit = g_kv.GetNum(NULL_STRING, -1);
						
						if (iLimit != -1)
						{
							g_smItemToLimitNum.SetValue(sItem, iLimit);
						}
						else LogError("[错误] g_kv.GetNum 失败");
					}
					else LogError("[错误] g_kv.GetSectionName 失败");
				}
				while (g_kv.GotoNextKey(false));
			}
			else LogError("[错误] g_kv.GotoFirstSubKey 失败");
		}
		else LogError("[错误] g_kv.JumpToKey item_limit 失败");
	}
	else SetFailState("无法加载 l4d2_item_rule.cfg!");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.5, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStart_Timer(Handle timer)
{
	//LogToFileEx_Debug("====================   Map: %s   ====================", CurrentMap());

	#if DEBUG
	Profiler hProfiler = new Profiler();
	hProfiler.Start();
	#endif
	
	g_bOfficialMap = IsOfficialMap();
	g_bFinalMap = L4D_IsMissionFinalMap();

	PrecacheItemModels();
	ProcessEntity();
	LimitItem();

	#if DEBUG
	hProfiler.Stop();
	LogToFileEx_Debug("执行时间: %f", hProfiler.Time);
	delete hProfiler;
	#endif
}

void PrecacheItemModels()
{
	for (int i = 0; i < sizeof(g_sItems); i++)
	{
		if (!IsModelPrecached(g_sItems[i][ITEM_MODEL]))
		{
			if (PrecacheModel(g_sItems[i][ITEM_MODEL], true) <= 0)
			{
				LogError("[错误] %s 模型缓存错误", g_sItems[i][ITEM_NAME]);
			}
		}
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	//再次检查。有些物品会延迟产生
	ProcessEntity();
	LimitItem();
	CreateTimer(0.2, GiveItems_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
	if (g_bFinalMap && g_bFinalMapPills) SpawnPill();
}

//开局给物品
public Action GiveItems_Timer(Handle timer)
{
	static char sPieces[16][64];

	if (g_sStartItems[0] != '\0')
	{
		int iNumPieces = ExplodeString(g_sStartItems, ";", sPieces, sizeof(sPieces), sizeof(sPieces[]));

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				for (int p = 0; p < iNumPieces; p++)
				{
					GiveItemByName(i, sPieces[p]);
				}
			}
		}
	}
}

//过图的时候删除健康物品和投掷物品
public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) 
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			for (int Slot = 2; Slot <= 4; Slot++)
			{
				int weapon = GetPlayerWeaponSlot(i, Slot);
				if (weapon != -1)
				{
					RemovePlayerItem(i, weapon);
					RemoveEntity(weapon);
				}
			}
		}
	}
}

//替换物品、保存物品点位、删除物品
void ProcessEntity()
{
	static char sClassName[64], sItemName[64], sNewItem[64];
	static int iItemLimit;
	static char sModel[PLATFORM_MAX_PATH];

	g_aItemsArray.Clear();

	for (int i = MaxClients+1; i <= GetMaxEntities(); i++)
	{
		if (IsValidEntity(i))
		{
			if (GetEdictClassname(i, sClassName, sizeof(sClassName)))
			{
				if (HasEntProp(i, Prop_Data, "m_iState"))
				{
					//https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/weapons.inc
					if (GetEntProp(i, Prop_Data, "m_iState"))
					{
						//LogToFileEx_Debug("在玩家身上, 跳过处理 %s", sClassName);
						continue;
					}
				}

				//删除物品箱(c6m1大量物品的箱子)
				if (strcmp(sClassName, "prop_dynamic") == 0 && g_bDelFootLocker)
				{
					DelFootLocker(i);
					continue;
				}

				if (strncmp(sClassName, "weapon_", 7) == 0 || strcmp(sClassName, "prop_physics") == 0 || strcmp(sClassName, "upgrade_laser_sight") == 0)
				{
					if (GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
					{
						StrToLowerCase(sModel);
						if (g_smModelToName.GetString(sModel, sItemName, sizeof(sItemName)))
						{
							if (!g_bOfficialMap || g_bFinalMap)
							{
								//结局地图和三方图不处理汽油箱
								if (strcmp(sItemName, "weapon_gascan") == 0)
								{
									//LogToFileEx_Debug("跳过处理 %s (%s)", sItemName, sClassName);
									continue;
								}

								//结局地图保存包的位置，以便后续产生药
								if (g_bFinalMap && g_bFinalMapPills)
								{
									if (strcmp(sItemName, "weapon_first_aid_kit") == 0)
									{
										SaveKitPos(i);
										continue;
									}
								}
							}

							//替换武器
							if (g_smOldItemToNewItem.GetString(sItemName, sNewItem, sizeof(sNewItem)))
							{
								ReplaceWeapon(i, sClassName, sNewItem);
								continue;
							}
							
							
							//保存物品点位
							if (g_smItemToLimitNum.GetValue(sItemName, iItemLimit))
							{
								if (iItemLimit >= 0)
								{
									if (iItemLimit >= 1)
									{
										SaveItemData(i, sItemName);
										//LogToFileEx_Debug("保存 %s (%s) 信息", sItemName, sClassName);
									}
									RemoveEntity(i);
									//LogToFileEx_Debug("删除 %s (%s)", sItemName, sClassName);
								}
							}
						}
					}
				}
			}
		}
	}
}

void DelFootLocker(int iEntity)
{
	static char sModel[PLATFORM_MAX_PATH], sButtonClassName[16];

	if (GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
	{
		if (strcmp(sModel, "models/props_waterfront/footlocker01.mdl", false) == 0)
		{
			static float fBoxPos[3];
			GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fBoxPos);
			
			for (int i = MaxClients+1; i <= GetMaxEntities(); i++)
			{
				if (IsValidEntity(i))
				{
					if (GetEdictClassname(i, sButtonClassName, sizeof(sButtonClassName)))
					{
						if (strcmp(sButtonClassName, "func_button") == 0) //打开按钮
						{
							static float fButtonPos[3];
							GetEntPropVector(i, Prop_Data, "m_vecOrigin", fButtonPos);
							if (GetVectorDistance(fBoxPos, fButtonPos) <= 1.0) //是箱子的打开按钮
							{
								//LogToFileEx_Debug("和footlocker距离: %f, 删除footlocker button", GetVectorDistance(fBoxPos, fButtonPos));
								RemoveEntity(i);
								break;
							}
						}
					}
				}
			}

			RemoveEntity(iEntity);
			//LogToFileEx_Debug("删除 footlocker");
		}
	}
}

void ReplaceWeapon(int iEntity, const char[] sClassName, const char[] sNewItem)
{
	static float fPos[3], fAng[3];

	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fPos);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fAng);

	RemoveEntity(iEntity);

	if (IsValidEntity(SpawnItem(sNewItem, fPos, fAng, 3)))
	{
		//LogToFileEx_Debug("将 %s 替换成 %s 成功", sClassName, sNewItem);
	}
	else LogError("[错误] 将 %s 替换成 %s 失败, 新物品索引无效", sClassName, sNewItem);
}

void SaveItemData(int iEntity, const char sItemName[64])
{
	static float fItemPos[3], fItemAng[3];
	static g_eItemInfo eItemInfo;

	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fItemPos);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fItemAng);

	eItemInfo.sName = sItemName;
	eItemInfo.fPos = fItemPos;
	eItemInfo.fAng = fItemAng;

	g_aItemsArray.PushArray(eItemInfo);
	//LogToFileEx_Debug("SaveItemData %s (%.1f %.1f %.1f)", sItemName, fItemPos[0], fItemPos[1], fItemPos[2]);
}

//产生物品到限制
void LimitItem()
{
	static int iLimit;
	static char sItemName[64];

	g_kv.Rewind();

	if (g_kv.JumpToKey("item_limit"))
	{
		if (g_kv.GotoFirstSubKey(false))
		{
			do
			{
				if (g_kv.GetSectionName(sItemName, sizeof(sItemName)))
				{
					iLimit = g_kv.GetNum(NULL_STRING, -1);

					if (iLimit != -1)
					{
						if (iLimit >= 1) SpawnItemToLimit(sItemName, iLimit);
					}
					else LogError("[错误] g_kv.GetNum 失败");
				}
				else LogError("[错误] g_kv.GetSectionName 失败");
			}
			while (g_kv.GotoNextKey(false));
		}
		else LogError("[错误] g_kv.GotoFirstSubKey 失败");
	}
	else LogError("[错误] g_kv.JumpToKey item_limit 失败");
}

void SpawnItemToLimit(const char[] sItemName, int iLimit)
{
	static int iSpawnCount, index;
	static g_eItemInfo eItemInfo;

	g_aTemItemsArray.Clear();
	iSpawnCount = 0;
	
	//提取物品到新的数组
	for (int i = 0; i < g_aItemsArray.Length; i++)
	{
		g_aItemsArray.GetArray(i, eItemInfo);
		
		if (strcmp(sItemName, eItemInfo.sName) == 0)
		{
			g_aTemItemsArray.PushArray(eItemInfo);
		}
	}

	//从新的数组随机产生物品
	if (iLimit > g_aTemItemsArray.Length) iLimit = g_aTemItemsArray.Length;
	for (int i = 0; i < iLimit; i++)
	{
		index = GetRandomInt(0, g_aTemItemsArray.Length - 1);

		//获取随机索引的物品信息
		g_aTemItemsArray.GetArray(index, eItemInfo);

		if (IsValidEntity(SpawnItem(eItemInfo.sName, eItemInfo.fPos, eItemInfo.fAng, 1)))
		{
			iSpawnCount++;
			//LogToFileEx_Debug("(%i/%i) 产生 %s (%.0f %.0f %.0f)", iSpawnCount, iLimit, sItemName, eItemInfo.fPos[0], eItemInfo.fPos[1], eItemInfo.fPos[2]);
		}
		else LogError("[错误] 产生 %s 失败, 新物品索引无效", sItemName);

		g_aTemItemsArray.Erase(index);
	}
}

void SaveKitPos(int iEntity)
{
	static float fPos[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fPos);

	if (!IsRepeatPos(fPos))
	{
		g_aKitPosArray.PushArray(fPos);
		//LogToFileEx_Debug("SaveKitPos -> KitPosCheck 推送包位置");
	}
	//else LogToFileEx_Debug("SaveKitPos -> KitPosCheck 跳过重复点位的包");

	RemoveEntity(iEntity);
}

//如果sv_allow_lobby_connect_only = 1，玩家第一次进入服务器有二次加载地图的问题，因此需要检查是否重复点位
bool IsRepeatPos(const float[] x)
{
	static float y[3];
	for (int i = 0; i < g_aKitPosArray.Length; i++)
	{
		g_aKitPosArray.GetArray(i, y);
		if (x[0] == y[0] && x[1] == y[1] && x[2] == y[2])
		{
			return true;
		}
	}
	return false;
}

void SpawnPill()
{
	static float fPos[3];
	static int iSpawnCount;

	iSpawnCount = 0;

	for (int i = 0; i < g_aKitPosArray.Length; i++)
	{
		g_aKitPosArray.GetArray(i, fPos);

		if (IsValidEntity(SpawnItem("weapon_pain_pills", fPos, _, 1)))
		{
			iSpawnCount++;
			//LogToFileEx_Debug("(%i/%i) 将包替换成药 (%.1f %.1f %.1f)", iSpawnCount, g_aKitPosArray.Length, fPos[0], fPos[1], fPos[2]);
		}
		else LogError("[错误] 产生药失败, 实体索引无效");
	}

	g_aKitPosArray.Clear();
}

bool IsOfficialMap()
{
	static const char sMapList[][] =
	{
		"c1m1_hotel","c1m2_streets","c1m3_mall","c1m4_atrium",
		"c2m1_highway","c2m2_fairgrounds","c2m3_coaster","c2m4_barns","c2m5_concert",
		"c3m1_plankcountry","c3m2_swamp","c3m3_shantytown","c3m4_plantation",
		"c4m1_milltown_a","c4m2_sugarmill_a","c4m3_sugarmill_b","c4m4_milltown_b","c4m5_milltown_escape",
		"c5m1_waterfront","c5m1_waterfront_sndscape","c5m2_park","c5m3_cemetery","c5m4_quarter","c5m5_bridge",
		"c6m1_riverbank","c6m2_bedlam","c6m3_port",
		"c7m1_docks","c7m2_barge","c7m3_port",
		"c8m1_apartment","c8m2_subway","c8m3_sewers","c8m4_interior","c8m5_rooftop",
		"c9m1_alleys","c9m2_lots",
		"c10m1_caves","c10m2_drainage","c10m3_ranchhouse","c10m4_mainstreet","c10m5_houseboat",
		"c11m1_greenhouse","c11m2_offices","c11m3_garage","c11m4_terminal","c11m5_runway",
		"c12m1_hilltop","c12m2_traintunnel","c12m3_bridge","c12m4_barn","c12m5_cornfield",
		"c13m1_alpinecreek","c13m2_southpinestream","c13m3_memorialbridge","c13m4_cutthroatcreek",
		"c14m1_junkyard","c14m2_lighthouse"
	};
	
	static char sCurMap[64];
	GetCurrentMap(sCurMap, sizeof(sCurMap));

	for (int i = 0; i < sizeof(sMapList); i++)
	{
		if (strcmp(sCurMap, sMapList[i], false) == 0)
		{
			return true;
		}
	}
	return false;
}

//为什么c4m4安全屋没有枪? HardCode that shit
public void Event_RoundStart_C4(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(5.0, SpawnGun_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action SpawnGun_Timer(Handle timer)
{
	if (strcmp(CurrentMap(), "c4m3_sugarmill_b") == 0)
	{
		//起点安全屋
		SpawnItem("weapon_shotgun_chrome", view_as<float>({3552.0, -1767.0, 263.0}), view_as<float>({0.0, 180.0, 90.0}), 3);
		SpawnItem("weapon_smg_silenced", view_as<float>({3549.0, -1738.0, 263.0}), view_as<float>({0.0, 180.0, 90.0}), 3);
	}

	if (strcmp(CurrentMap(), "c4m4_milltown_b") == 0)
	{
		//终点安全屋
		SpawnItem("weapon_shotgun_chrome", view_as<float>({-3320.0, 7788.0, 156.0}), view_as<float>({0.0, 268.0, 270.0}), 3);
		SpawnItem("weapon_smg_silenced", view_as<float>({-3336.0, 7788.0, 156.0}), view_as<float>({0.0, 285.0, 270.0}), 3);
	}
}


char CurrentMap()
{
	static char sMapName[64];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return sMapName;
}

int SpawnItem(const char[] sItemName, const float fPos[3], float fAng[3] = {0.0, ...}, int iCount = 1)
{
	int iItemNum;
	int iEntIndex = -1;

	if (g_smNameToNumber.GetValue(sItemName, iItemNum))
	{
		bool bHasSpawnclass = strcmp(g_sItems[iItemNum][HAS_SPAWN_CLASS], "true") == 0;
		bool bHasCount = strcmp(g_sItems[iItemNum][HAS_COUNT], "true") == 0;

		switch (StringToInt(g_sItems[iItemNum][SPAWN_TYPE]))
		{
			//https://forums.alliedmods.net/showthread.php?t=222934
			case 1:
			{
				char sClassName[64];
				strcopy(sClassName, sizeof(sClassName), sItemName);
				if (bHasSpawnclass) StrCat(sClassName, sizeof(sClassName), "_spawn");

				iEntIndex = CreateEntityByName(sClassName);
				if (iEntIndex == -1) ThrowError("Failed to create '%s'", sClassName);

				DispatchKeyValue(iEntIndex, "solid", "6");
				DispatchKeyValue(iEntIndex, "model", g_sItems[iItemNum][ITEM_MODEL]);
				DispatchKeyValue(iEntIndex, "rendermode", "3");
				DispatchKeyValue(iEntIndex, "disableshadows", "1");

				if (iItemNum == 24 || iItemNum == 25)
				{
					DispatchKeyValue(iEntIndex, "count", "1");
				}

				if (bHasCount)
				{
					switch (iItemNum)
					{
						case 0, 1, 2, 3:
						{
							DataPack hPack = new DataPack();
							hPack.WriteCell(iEntIndex);
							hPack.WriteCell(iCount);
							RequestFrame(SetCount_OnNextFrame, hPack);
						}
						default:
						{
							char sCount[5];
							IntToString(iCount, sCount, sizeof(sCount));
							DispatchKeyValue(iEntIndex, "count", sCount);
						}
					}
				}

				TeleportEntity(iEntIndex, fPos, fAng, NULL_VECTOR);
				DispatchSpawn(iEntIndex);
				
				if (!bHasSpawnclass)
				{
					int iAmmo;
					switch (iItemNum)
					{
						case 20, 21:	iAmmo = FindConVar("ammo_sniperrifle_max").IntValue;
						case 22:		iAmmo = FindConVar("ammo_smg_max").IntValue;
						case 23:		iAmmo = FindConVar("ammo_assaultrifle_max").IntValue;
					}
					if (iAmmo > 0) SetEntProp(iEntIndex, Prop_Send, "m_iExtraPrimaryAmmo", iAmmo);
				}

				SetEntityMoveType(iEntIndex, MOVETYPE_NONE);
			}

			//https://forums.alliedmods.net/showthread.php?t=331053
			case 2:
			{
				iEntIndex = CreateEntityByName("prop_physics");
				if (iEntIndex == -1) ThrowError("Failed to create '%s'", sItemName);

				DispatchKeyValue(iEntIndex, "model", g_sItems[iItemNum][ITEM_MODEL]);
				TeleportEntity(iEntIndex, fPos, fAng, NULL_VECTOR);
				DispatchSpawn(iEntIndex);
				ActivateEntity(iEntIndex);
			}
			
			//https://forums.alliedmods.net/showthread.php?t=223012
			case 3:
			{
				iEntIndex = CreateEntityByName("upgrade_laser_sight");
				if (iEntIndex == -1) ThrowError("Failed to create '%s'", sItemName);

				DispatchKeyValue(iEntIndex, "model", g_sItems[iItemNum][ITEM_MODEL]);
				TeleportEntity(iEntIndex, fPos, fAng, NULL_VECTOR);
				DispatchSpawn(iEntIndex);
			}
		}
	}
	else LogError("[错误] 物品名字 %s 无效", sItemName);

	return iEntIndex;
}

// 为什么医疗物品 DispatchKeyValue count 无效??
public void SetCount_OnNextFrame(DataPack hPack)
{
	hPack.Reset();
	int iEntIndex = hPack.ReadCell();
	int iCount = hPack.ReadCell();
	delete hPack;
	SetEntProp(iEntIndex, Prop_Data, "m_itemCount", iCount);
}

void GiveItemByName(int client, const char[] sName)
{
	CheatCommand(client, "give", sName);
}

void CheatCommand(int client, const char[] command, const char[] args = "")
{
	int iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, args);
	SetCommandFlags(command, iFlags);
}

//https://forums.alliedmods.net/showthread.php?t=331053
void StrToLowerCase(char[] str)
{
	for (int i = 0; i < strlen(str); i++)
	{
		str[i] = CharToLower(str[i]);
	}
}

public Action Cmd_LimitItems(int client, int args)
{
	ProcessEntity();
	LimitItem();
}

public Action Cmd_SpawnItem(int client, int args)
{
	if (args == 2)
	{
		char sItemName[64];
		GetCmdArg(1, sItemName, sizeof(sItemName));

		float fPos[3];
		GetClientEyePosition(client, fPos);

		char sCount[4];
		GetCmdArg(2, sCount, sizeof(sCount));
		int iCount = StringToInt(sCount);

		SpawnItem(sItemName, fPos, _, iCount);
	}
	else PrintToChat(client, "使用 sm_spawn_item <物品名字> <数量>");
}

public Action Cmd_SpawnAllItem(int client, int args)
{
	if (args == 1)
	{
		float fPos[3];
		GetClientEyePosition(client, fPos);

		char sCount[4];
		GetCmdArg(1, sCount, sizeof(sCount));
		int iCount = StringToInt(sCount);

		for (int i = 0; i < sizeof(g_sItems); i++)
		{
			SpawnItem(g_sItems[i][ITEM_NAME], fPos, _, iCount);
			fPos[0] += 50.0;
		}
	}
	else PrintToChat(client, "使用 sm_spawn_all_item <数量>");
}

stock void LogToFileEx_Debug(const char[] format, any ...)
{
	static char buffer[254];
	VFormat(buffer, sizeof(buffer), format, 2);

	#if DEBUG
	LogToFileEx(g_sLogPath, "%s", buffer);
	#endif
}

