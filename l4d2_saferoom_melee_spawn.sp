#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION	"0.6"

#define MAX_MELEENAME_LEN 128

#define TYPE_RANDOM	1
#define TYPE_FIXED	2

ConVar
	g_cvType,
	g_cvRandomCount,
	g_cvGoldenCrowbar;

ArrayList g_aMeleeList[3];
Handle g_hTimer;

public Plugin myinfo =
{
	name = "L4D2 Melee In The Saferoom",
	author = "fdxx",
	version = VERSION
}

public void OnPluginStart()
{
	CreateConVar("l4d2_saferoom_melee_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvType = CreateConVar("l4d2_saferoom_melee_type", "1", "0=disable, 1=random, 2=fixed, 3=both");
	g_cvRandomCount = CreateConVar("l4d2_saferoom_melee_random_count", "6", "If random, how many will be randomly spawn?");
	g_cvGoldenCrowbar = CreateConVar("l4d2_saferoom_melee_golden_crowbar", "1", "If a crowbar spawned, change the skin to a golden crowbar.");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_saferoom_melee_add_fixed", Cmd_AddList, ADMFLAG_ROOT, "Multiple, separated by spaces, Or use this command multiple times.");
	RegAdminCmd("sm_saferoom_melee_reset", Cmd_ResetList, ADMFLAG_ROOT);

	g_aMeleeList[TYPE_RANDOM] = new ArrayList(ByteCountToCells(MAX_MELEENAME_LEN));
	g_aMeleeList[TYPE_FIXED] = new ArrayList(ByteCountToCells(MAX_MELEENAME_LEN));
}

Action Cmd_AddList(int client, int args)
{
	if (!args)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <melee1> [melee2] ...", cmd);
		return Plugin_Handled;
	}
	
	char sMelee[MAX_MELEENAME_LEN];
	for (int i = 1; i <= args; i++)
	{
		GetCmdArg(i, sMelee, sizeof(sMelee));
		g_aMeleeList[TYPE_FIXED].PushString(sMelee);
	}

	return Plugin_Handled;
}

Action Cmd_ResetList(int client, int args)
{
	g_aMeleeList[TYPE_RANDOM].Clear();
	g_aMeleeList[TYPE_FIXED].Clear();
	return Plugin_Handled;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, SpawnMelee_Timer, _, TIMER_REPEAT);
}

Action SpawnMelee_Timer(Handle timer)
{
	int client = GetInGameClient();
	if (client > 0)
	{
		float fPos[3];
		GetClientEyePosition(client, fPos);

		if (g_cvType.IntValue & TYPE_RANDOM)
		{
			char sMelee[MAX_MELEENAME_LEN];
			g_aMeleeList[TYPE_RANDOM].Clear();

			int table = FindStringTable("meleeweapons");
			if (table == INVALID_STRING_TABLE)
			{
				LogError("INVALID_STRING_TABLE: meleeweapons");
				g_hTimer = null;
				return Plugin_Stop;
			}
			
			int num = GetStringTableNumStrings(table);
			for (int i = 0; i < num; i++ )
			{
				ReadStringTable(table, i, sMelee, sizeof(sMelee));
				g_aMeleeList[TYPE_RANDOM].PushString(sMelee);
			}

			g_aMeleeList[TYPE_RANDOM].Sort(Sort_Random, Sort_String);
			int len = g_cvRandomCount.IntValue > g_aMeleeList[TYPE_RANDOM].Length ? g_aMeleeList[TYPE_RANDOM].Length : g_cvRandomCount.IntValue;
			SpawnMeleesFromList(fPos, g_aMeleeList[TYPE_RANDOM], len);
		}


		if (g_cvType.IntValue & TYPE_FIXED)
		{
			SpawnMeleesFromList(fPos, g_aMeleeList[TYPE_FIXED], g_aMeleeList[TYPE_FIXED].Length);
		}

		g_hTimer = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void SpawnMeleesFromList(const float fPos[3], ArrayList aList, int len)
{
	char sMelee[MAX_MELEENAME_LEN];
	int entity;

	for (int i = 0; i < len; i++)
	{
		aList.GetString(i, sMelee, sizeof(sMelee));
		entity = SpawnMelee(sMelee, fPos);
		if (entity <= MaxClients || !IsValidEntity(entity))
			LogError("Failed to spawn melee weapon: %s", sMelee);

		if (g_cvGoldenCrowbar.BoolValue && !strcmp(sMelee, "crowbar"))
			SetEntProp(entity, Prop_Send, "m_nSkin", 1);
	}
}

int SpawnMelee(const char[] name, const float origin[3], const float angles[3] = {0.0, ...})
{
	int entity = CreateEntityByName("weapon_melee");
	if (entity == -1)
		return -1;

	DispatchKeyValue(entity, "melee_script_name", name);
	DispatchKeyValueVector(entity, "origin", origin);
	DispatchKeyValueVector(entity, "angles", angles);
	DispatchSpawn(entity);
	return entity;
}

int GetInGameClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			return i;
		}
	}
	return 0;
}
