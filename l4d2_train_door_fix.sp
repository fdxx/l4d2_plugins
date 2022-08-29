#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

DynamicHook g_hHook;

public Plugin myinfo = 
{
	name = "L4D2 Train door fix",
	author = "fdxx",
	description = "Auto unlock the second train door on c7m1 map",
	version = "0.3",
}

public void OnPluginStart()
{
	Init();
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.1, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action RoundStart_Timer(Handle timer)
{
	static char sCurMap[11];
	GetCurrentMap(sCurMap, sizeof(sCurMap));

	if (!strcmp(sCurMap, "c7m1_docks"))
	{
		int entity = FindTankDoorOut();
		if (entity > MaxClients && IsValidEntity(entity))
		{
			if (g_hHook.HookEntity(Hook_Post, entity, OnAcceptInputPost) == INVALID_HOOK_ID)
				LogError("Failed to HookEntity %i", entity);
		}
	}
	return Plugin_Continue;
}

int FindTankDoorOut()
{
	int entity = -1;
	char sName[32];

	while ((entity = FindEntityByClassname(entity, "func_button_timed")) != -1)
	{
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
		if (!strcmp(sName, "tankdoorout_button"))
			return entity;
	}

	return -1;
}

// bool CBaseEntity::AcceptInput( const char *szInputName, CBaseEntity *pActivator, CBaseEntity *pCaller, variant_t Value, int outputID )
// sClass = func_button_timed, sName = tankdoorout_button, sInputName = Lock, sActivator(6) = Tank, sCaller(933) = trigger_multiple
// sClass = func_button_timed, sName = tankdoorout_button, sInputName = Unlock, sActivator(6) = Tank, sCaller(933) = trigger_multiple
MRESReturn OnAcceptInputPost(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	char sInput[5];
	hParams.GetString(1, sInput, sizeof(sInput));

	if (!strcmp(sInput, "Lock", false))
		RequestFrame(NextFrame, EntIndexToEntRef(pThis));

	return MRES_Ignored;
}

void NextFrame(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if (entity > MaxClients && IsValidEntity(entity))
		AcceptEntityInput(entity, "Unlock");
}

void Init()
{
	GameData hGameData = new GameData("l4d2_train_door_fix");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_train_door_fix.txt\" gamedata.");

	g_hHook = DynamicHook.FromConf(hGameData, "CBaseEntity::AcceptInput");
	if (g_hHook == null)
		SetFailState("Failed to create DynamicHook \"CBaseEntity::AcceptInput\"");

	delete hGameData;
}

