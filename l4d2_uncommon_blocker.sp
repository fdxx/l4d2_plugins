/*
	-----------------------------------------------------------------------------------------------------------------------------------------------------

	Changelog
	---------
		0.2 (by fdxx)
			- Newdecls
			- Add more Uncommon Infected

		0.1b
			- spawns common after killing uncommon entity
			
		0.1a
			- first version (not really optimized)

	-----------------------------------------------------------------------------------------------------------------------------------------------------
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define DEBUG 0

#define UNC_CEDA		1	//防化服
#define UNC_CLOWN		2	//小丑
#define UNC_FALLEN		4	//堕落幸存者
#define UNC_JIMMY		8	//赛车手
#define UNC_MUDMEN		16	//泥人
#define UNC_RIOT		32	//防爆警察
#define UNC_ROADCREW	64	//道路工人
#define UNC_PARACHUTIST	128	//伞兵(c3m2)

ConVar CvarPluginEnabled, CvarBlockFlags;
bool g_bPluginEnabled;
int g_iBlockFlags;

char logPath[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "Uncommon Infected Blocker",
	author = "Tabun",
	description = "Blocks uncommon infected from ruining your day.",
	version = "0.2.3",
	url = "nope"
}

public void OnPluginStart()
{
	BuildPath(Path_SM, logPath, sizeof(logPath), "logs/l4d2_uncommon_blocker.log");

	CvarPluginEnabled = CreateConVar("sm_uncinfblock_enabled", "1", "Enable Plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarBlockFlags = CreateConVar("sm_uncinfblock_types", "165", "Which uncommon infected to block. Number addition.(1:ceda, 2:clown, 4:fallen survivor, 8:jimmy, 16:mud men, 32:riot, 64:roadcrew, 128:parachutist).", FCVAR_NONE);

	GetCvars();

	CvarPluginEnabled.AddChangeHook(ConVarChange);
	CvarBlockFlags.AddChangeHook(ConVarChange);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();	
}

void GetCvars()
{
	g_bPluginEnabled = CvarPluginEnabled.BoolValue;
	g_iBlockFlags = CvarBlockFlags.IntValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_bPluginEnabled)
	{
		if (strcmp(classname, "infected") == 0)
		{
			SDKHook(entity, SDKHook_SpawnPost, EntitySpawned);
		}
	}
}

public void EntitySpawned(int entity)
{
	RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
}

public void OnNextFrame(any entity)
{
	if (EntRefToEntIndex(entity) == INVALID_ENT_REFERENCE || !IsValidEntity(entity)) return;

	static char sModelName[PLATFORM_MAX_PATH];
	if (GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName)) > 1)
	{
		if (IsUncommonInf(sModelName))
		{
			float fPos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fPos);
			RemoveEntity(entity);
			LogToFileEx_Debug("删除 %s (%.1f %.1f %.1f)", sModelName, fPos[0], fPos[1], fPos[2]);
			SpawnCommonInfected(fPos);
		}
	}
}

bool IsUncommonInf(const char[] sModelName)
{
	if (StrContains(sModelName, "_ceda") != -1			&& (UNC_CEDA & g_iBlockFlags))			{ return true; }
	if (StrContains(sModelName, "_clown") != -1			&& (UNC_CLOWN & g_iBlockFlags))			{ return true; }
	if (StrContains(sModelName, "_fallen") != -1		&& (UNC_FALLEN & g_iBlockFlags))		{ return true; }
	if (StrContains(sModelName, "_jimmy") != -1			&& (UNC_JIMMY & g_iBlockFlags))			{ return true; }
	if (StrContains(sModelName, "_mud") != -1			&& (UNC_MUDMEN & g_iBlockFlags))		{ return true; }
	if (StrContains(sModelName, "_riot") != -1			&& (UNC_RIOT & g_iBlockFlags))			{ return true; }
	if (StrContains(sModelName, "_roadcrew") != -1		&& (UNC_ROADCREW & g_iBlockFlags))		{ return true; }
	if (StrContains(sModelName, "_parachutist") != -1	&& (UNC_PARACHUTIST & g_iBlockFlags))	{ return true; }

	return false;
}

void SpawnCommonInfected(const float fPos[3])
{
	int iZombie = CreateEntityByName("infected");
	int ticktime = RoundToNearest(GetGameTime() / GetTickInterval()) + 5;
	SetEntProp(iZombie, Prop_Data, "m_nNextThinkTick", ticktime);
	DispatchSpawn(iZombie);
	ActivateEntity(iZombie);
	TeleportEntity(iZombie, fPos, NULL_VECTOR, NULL_VECTOR);

	LogToFileEx_Debug("产生普通僵尸 (%.1f %.1f %.1f)", fPos[0], fPos[1], fPos[2]);
}

void LogToFileEx_Debug(const char[] format, any ...)
{
	char buffer[254];
	VFormat(buffer, sizeof(buffer), format, 2);

	#if DEBUG
	LogToFileEx(logPath, "%s", buffer);
	#endif
}

