#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2_weapons_spawn> // https://github.com/fdxx/l4d2_plugins/blob/main/include/l4d2_weapons_spawn.inc

#define VERSION "1.4"
#define MAX_ITEMNAME_LEN 128

StringMap
	g_smModelToName,
	g_smItemReplace,
	g_smItemLimit;

ConVar
	g_cvFinalPills,
	g_cvRemoveBox;

bool
	g_bFinalPills,
	g_bRemoveBox;
	
ArrayList
	g_aLimitEnt,
	g_aStartItem,
	g_aItemSpawn;

enum struct EntityData
{
	int entity;
	char sName[MAX_ITEMNAME_LEN];
}

enum struct SpawnData
{
	int entRef;
	char map[256];
	char item[MAX_ITEMNAME_LEN];
	float origin[3];
	float angles[3];
	int count;
	MoveType movetype;
}

public Plugin myinfo = 
{
	name = "L4D2 Item rule",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_item_rule_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvFinalPills = CreateConVar("l4d2_item_rule_finalmap_pills", "0", "Replace final map medkit with pills.");
	g_cvRemoveBox = CreateConVar("l4d2_item_rule_remove_box", "0", "remove item box");

	OnConVarChanged(null, "", "");

	g_cvFinalPills.AddChangeHook(OnConVarChanged);
	g_cvRemoveBox.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_start_item", Cmd_AddStartItem, ADMFLAG_ROOT);
	RegAdminCmd("sm_item_replace", Cmd_AddItemReplace, ADMFLAG_ROOT);
	RegAdminCmd("sm_item_limit", Cmd_AddItemLimit, ADMFLAG_ROOT);
	RegAdminCmd("sm_item_spawn", Cmd_AddItemSpawn, ADMFLAG_ROOT);
	RegAdminCmd("sm_item_rule_reset", Cmd_Reset, ADMFLAG_ROOT);

	RegAdminCmd("sm_item_rule_test", Cmd_Test, ADMFLAG_ROOT);
}

Action Cmd_AddStartItem(int client, int args)
{
	if (!args)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <item1> [item2] ...", cmd);
		return Plugin_Handled;
	}
	
	char item[MAX_ITEMNAME_LEN];
	for (int i = 1; i <= args; i++)
	{
		GetCmdArg(i, item, sizeof(item));
		g_aStartItem.PushString(item);
	}

	return Plugin_Handled;
}

Action Cmd_AddItemReplace(int client, int args)
{
	if (args != 2)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <oldItem> <newItem>", cmd);
		return Plugin_Handled;
	}
	
	char oldItem[MAX_ITEMNAME_LEN], newItem[MAX_ITEMNAME_LEN];
	GetCmdArg(1, oldItem, sizeof(oldItem));
	GetCmdArg(2, newItem, sizeof(newItem));
	g_smItemReplace.SetString(oldItem, newItem);

	return Plugin_Handled;
}

Action Cmd_AddItemLimit(int client, int args)
{
	if (args != 2)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <item> <limitValue>", cmd);
		return Plugin_Handled;
	}
	
	char item[MAX_ITEMNAME_LEN];
	GetCmdArg(1, item, sizeof(item));
	g_smItemLimit.SetValue(item, GetCmdArgInt(2));
	
	return Plugin_Handled;
}

Action Cmd_AddItemSpawn(int client, int args)
{
	if (args < 4)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <map> <item> <origin> <angles> [count] [movetype]", cmd);
		ReplyToCommand(client, "Syntax: %s c2m1_highway weapon_shotgun_chrome 1,1,1 2,2,2 1 0", cmd);
		return Plugin_Handled;
	}

	SpawnData data;
	char buffer[128];

	GetCmdArg(1, data.map, sizeof(data.map));
	GetCmdArg(2, data.item, sizeof(data.item));
	GetCmdArg(3, buffer, sizeof(buffer));
	GetVecFromString(data.origin, buffer, ",");
	GetCmdArg(4, buffer, sizeof(buffer));
	GetVecFromString(data.angles, buffer, ",");

	data.count = args > 4 ? GetCmdArgInt(5) : 1;
	data.movetype = args > 5 ? view_as<MoveType>(GetCmdArgInt(6)) : MOVETYPE_NONE;

	g_aItemSpawn.PushArray(data);
	return Plugin_Handled;
}

Action Cmd_Reset(int client, int args)
{
	if (args != 1)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <start_item|item_replace|item_limit|item_spawn>", cmd);
		return Plugin_Handled;
	}
	
	char type[16];
	GetCmdArg(1, type, sizeof(type));
	if (!strcmp(type, "start_item", false))
		g_aStartItem.Clear();

	else if (!strcmp(type, "item_replace", false))
		g_smItemReplace.Clear();

	else if (!strcmp(type, "item_limit", false))
		g_smItemLimit.Clear();

	else if (!strcmp(type, "item_spawn", false))
		g_aItemSpawn.Clear();
	
	return Plugin_Handled;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bFinalPills = g_cvFinalPills.BoolValue;
	g_bRemoveBox = g_cvRemoveBox.BoolValue;
}

public void OnMapStart()
{
	L4D2Wep_PrecacheModel();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.3, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action RoundStart_Timer(Handle timer)
{
	SpawnItem();
	RemoveItemBox();
	EntityHandling();
	EntityLimit();
	return Plugin_Continue;
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	RemoveItemBox();
	EntityHandling();
	EntityLimit();
	GiveStartItem();
}

void SpawnItem()
{
	SpawnData data;
	char curMap[PLATFORM_MAX_PATH];
	GetCurrentMap(curMap, sizeof(curMap));
	int entity;

	for (int i = 0, len = g_aItemSpawn.Length; i < len; i++)
	{
		g_aItemSpawn.GetArray(i, data);
		data.entRef = -1;
		g_aItemSpawn.SetArray(i, data);

		if (strcmp(curMap, data.map, false))
			continue;
		
		entity = L4D2Wep_Spawn(data.item, data.origin, data.angles, data.count, data.movetype);
		if (!IsValidEntity(entity))
		{
			LogError("Failed to spawn item: %s, map: %s", data.item, data.map);
			continue;
		}

		data.entRef = EntIndexToEntRef(entity);
		g_aItemSpawn.SetArray(i, data);
	}
}

// C6地图上大量物品的箱子
void RemoveItemBox()
{
	if (!g_bRemoveBox)
		return;

	int button, box;
	char sBoxModel[PLATFORM_MAX_PATH];

	button = -1;
	while ((button = FindEntityByClassname(button, "func_button")) != -1)
	{
		box = GetEntPropEnt(button, Prop_Send, "m_glowEntity");
		if (!IsValidEntity(box))
			continue;
		
		if (GetEntPropString(box, Prop_Data, "m_ModelName", sBoxModel, sizeof(sBoxModel)) < 2)
			continue;

		if (!strcmp(sBoxModel, "models/props_waterfront/footlocker01.mdl", false))
		{
			RemoveEntity(button);
			RemoveEntity(box);
		}
	}
}

void EntityHandling()
{
	int limit;
	EntityData data;
	char clsname[MAX_ITEMNAME_LEN], item[MAX_ITEMNAME_LEN], newItem[MAX_ITEMNAME_LEN], model[PLATFORM_MAX_PATH];

	bool bFinalMap = L4D_IsMissionFinalMap();
	g_aLimitEnt.Clear();

	for (int i = MaxClients+1; i < 2049; i++)
	{
		if (!IsValidEntity(i) || !GetEdictClassname(i, clsname, sizeof(clsname)))
			continue;

		if (clsname[0] != 'w' && clsname[0] != 'p' && clsname[0] != 'u')
			continue;

		if (IsCarriedByClient(i))
			continue;
			
		if (GetEntPropString(i, Prop_Data, "m_ModelName", model, sizeof(model)) < 2)
			continue;
			
		CharToLowerCase(model, strlen(model));
		if (g_smModelToName.GetString(model, item, sizeof(item)))
		{
			if (!strcmp(clsname, "predicted_viewmodel")) // 部分物品的模型和视图模型一样
				continue;

			if (!strcmp(item, "weapon_gascan") && IsEventGascan(i))
				continue;
			
			if (g_aItemSpawn.FindValue(EntIndexToEntRef(i)) != -1)
			{
				//PrintToServer("绕过 %s (%i)", item, EntIndexToEntRef(i));
				continue;
			}
				
			if (bFinalMap && g_bFinalPills)
			{
				if (!strcmp(item, "weapon_pain_pills")) // 结局地图不处理药
					continue;
					
				if (!strcmp(item, "weapon_first_aid_kit")) // 替换包为药
				{
					ReplaceEntity(i, clsname, "weapon_pain_pills", 1, MOVETYPE_NONE);
					continue;
				}
			}

			if (g_smItemReplace.GetString(item, newItem, sizeof(newItem)))
			{
				ReplaceEntity(i, clsname, newItem, 3, MOVETYPE_NONE);
				continue;
			}

			if (g_smItemLimit.GetValue(item, limit))
			{
				if (limit == 0)
					RemoveEntity(i);
					
				else if (limit > 0)
				{
					data.entity = i;
					data.sName = item;
					g_aLimitEnt.PushArray(data);
				}
			}
		}
	}
}

void ReplaceEntity(int entity, const char[] clsname, const char[] newItem, int count = 1, MoveType movetype = MOVETYPE_CUSTOM)
{
	static float fPos[3], fAng[3];

	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fPos);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", fAng);

	RemoveEntity(entity);

	if (!IsValidEntity(L4D2Wep_Spawn(newItem, fPos, fAng, count, movetype)))
		LogError("Failed to replace %s to %s", clsname, newItem);
}

void EntityLimit()
{
	char item[MAX_ITEMNAME_LEN];
	int i, limit, remove, index;
	int len = g_aLimitEnt.Length;

	EntityData data;
	ArrayList aTemp = new ArrayList(sizeof(EntityData));
	StringMapSnapshot snap = g_smItemLimit.Snapshot();

	for (int j = 0, snapLen = snap.Length; j < snapLen; j++)
	{
		snap.GetKey(j, item, sizeof(item));
		g_smItemLimit.GetValue(item, limit);
		if (limit < 1)
			continue;

		aTemp.Clear();
		for (i = 0; i < len; i++)
		{
			g_aLimitEnt.GetArray(i, data);
			if (!strcmp(data.sName, item))
				aTemp.PushArray(data);
		}

		remove = aTemp.Length - limit;
		for (i = 0; i < remove; i++)
		{
			index = GetRandomIntEx(0, aTemp.Length-1);
			aTemp.GetArray(index, data);
			RemoveEntity(data.entity);
			aTemp.Erase(index);
		}
	}

	delete aTemp;
	delete snap;
}

void GiveStartItem()
{
	char name[128];

	for (int i = 0, len = g_aStartItem.Length; i < len; i++)
	{
		g_aStartItem.GetString(i, name, sizeof(name));
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
				continue;

			if (!strcmp(name, "health"))
				RestoreHealth(client, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
			else
				CheatCommand(client, "give", name);
		}
	}
}

bool IsCarriedByClient(int entity)
{
	if (HasEntProp(entity, Prop_Data, "m_iState"))
		return GetEntProp(entity, Prop_Data, "m_iState") > 0;
	return false;
}

void CharToLowerCase(char[] chr, int len)
{
	static int i;
	for (i = 0; i < len; i++)
		chr[i] = CharToLower(chr[i]);
}

bool IsEventGascan(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_nSkin") > 0 || GetEntProp(entity, Prop_Send, "m_iGlowType") == 3;
}

int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

void RestoreHealth(int client, int iHealth)
{
	Event event = CreateEvent("heal_success", true);
	event.SetInt("userid", GetClientUserId(client));
	event.SetInt("subject", GetClientUserId(client));
	event.SetInt("health_restored", iHealth - GetEntProp(client, Prop_Send, "m_iHealth"));

	CheatCommand(client, "give", "health");

	SetEntProp(client, Prop_Send, "m_iHealth", iHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());

	event.Fire();
}

void CheatCommand(int client, const char[] command, const char[] args = "")
{
	int iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, args);
	SetCommandFlags(command, iFlags);
}

void GetVecFromString(float vec[3], const char[] str, const char[] split)
{
	char buffer[3][32];
	ExplodeString(str, split, buffer, sizeof(buffer), sizeof(buffer[]));
	vec[0] = StringToFloat(buffer[0]);
	vec[1] = StringToFloat(buffer[1]);
	vec[2] = StringToFloat(buffer[2]);
}

void Init()
{
	delete g_smModelToName;
	delete g_smItemReplace;
	delete g_smItemLimit;
	delete g_aLimitEnt;
	delete g_aStartItem;
	delete g_aItemSpawn;

	g_smModelToName = new StringMap();
	g_smItemReplace = new StringMap();
	g_smItemLimit = new StringMap();
	g_aLimitEnt = new ArrayList(sizeof(EntityData));
	g_aStartItem = new ArrayList(ByteCountToCells(MAX_ITEMNAME_LEN));
	g_aItemSpawn = new ArrayList(sizeof(SpawnData));
	
	char sBuffer[PLATFORM_MAX_PATH];
	for (int i; i < sizeof(g_sWeapons); i++)
	{
		strcopy(sBuffer, sizeof(sBuffer), g_sWeapons[i][WEAPON_MODEL]);
		CharToLowerCase(sBuffer, strlen(sBuffer));
		g_smModelToName.SetString(sBuffer, g_sWeapons[i][WEAPON_NAME]);
	}
}

Action Cmd_Test(int client, int args)
{
	char clsname[MAX_ITEMNAME_LEN], item[MAX_ITEMNAME_LEN], model[PLATFORM_MAX_PATH];
	ArrayList list = new ArrayList(128);
	
	for (int i = MaxClients+1; i < 2049; i++)
	{
		if (!IsValidEntity(i) || !GetEdictClassname(i, clsname, sizeof(clsname)))
			continue;

		if (clsname[0] != 'w' && clsname[0] != 'p' && clsname[0] != 'u')
			continue;

		if (IsCarriedByClient(i))
			continue;
			
		if (GetEntPropString(i, Prop_Data, "m_ModelName", model, sizeof(model)) < 2)
			continue;
			
		CharToLowerCase(model, strlen(model));
		if (g_smModelToName.GetString(model, item, sizeof(item)))
		{
			if (!strcmp(clsname, "predicted_viewmodel")) // 部分物品的模型和视图模型一样
				continue;

			if (!strcmp(item, "weapon_gascan") && IsEventGascan(i))
				continue;
			
			list.PushString(item);
		}
	}

	list.Sort(Sort_Ascending, Sort_String);

	for (int i = 0, len = list.Length; i < len; i++)
	{
		list.GetString(i, item, sizeof(item));
		PrintToServer("%s", item);
	}

	return Plugin_Handled;
}
