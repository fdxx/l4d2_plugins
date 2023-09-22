
// If the server does not enable lobby matching, When entering the game for the first time, Mutation mode scripts do not execute correctly.
// So we reloaded the current map.

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues

#define VERSION "0.1"

ConVar
	mp_gamemode,
	l4d2_mutation_fix_time;

public Plugin myinfo = 
{
	name = "L4D2 mutation fix",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_mutation_fix_version", VERSION, "Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	l4d2_mutation_fix_time = CreateConVar("l4d2_mutation_fix_time", "0.2");
	mp_gamemode = FindConVar("mp_gamemode");
}

public void OnConfigsExecuted()
{
	static bool shit = false;
	if (shit) return;
	shit = true;

	if (l4d2_mutation_fix_time.FloatValue > 0.0)
		CreateTimer(l4d2_mutation_fix_time.FloatValue, ChangeMap_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action ChangeMap_Timer(Handle timer)
{
	GameData hGameData = new GameData("l4d2_mutation_fix");
	char buffer[256];

	strcopy(buffer, sizeof(buffer), "g_pMatchExtL4D");
	Address pMatchExtL4D = hGameData.GetAddress(buffer);
	if (pMatchExtL4D == Address_Null)
		SetFailState("Failed to get GetAddress: %s", buffer);

	strcopy(buffer, sizeof(buffer), "CMatchExtL4D::GetGameModeInfo");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, buffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	Handle hSDK_GetGameModeInfo = EndPrepSDKCall();
	if (hSDK_GetGameModeInfo == null)
		SetFailState("Failed to create SDKCall: %s", buffer);

	mp_gamemode.GetString(buffer, sizeof(buffer));
	SourceKeyValues kv = SDKCall(hSDK_GetGameModeInfo, pMatchExtL4D, buffer);
	if (!kv)
		ThrowError("Failed to GetGameModeInfo: %s", buffer);

	// If mutation mode..
	if (kv.GetInt("mutation", 0))
	{
		GetCurrentMap(buffer, sizeof(buffer));
		ServerCommand("changelevel %s", buffer);
		LogMessage("Reloaded current map: %s", buffer);
	}

	delete hSDK_GetGameModeInfo;
	delete hGameData;
	return Plugin_Continue;
}
