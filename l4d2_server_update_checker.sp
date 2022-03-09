#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.3"

#include <sourcemod>
#include <dhooks>
#include <multicolors>	// https://github.com/Bara/Multi-Colors

ConVar g_cvRestartTime;
char g_sLogPath[PLATFORM_MAX_PATH];
int g_iHookid;

public Plugin myinfo =
{
	name = "L4D2 Server update checker",
	author = "fdxx",
	description = "Restart the server when the server has an update.",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_server_update_checker_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvRestartTime = CreateConVar("l4d2_server_update_restart_time", "60.0", "How many time later the server will restart if there is an update (sec).", FCVAR_NONE);
	AutoExecConfig(true, "l4d2_server_update_checker");
}

public void OnConfigsExecuted()
{
	FindConVar("sv_hibernate_when_empty").IntValue = 0;

	static bool shit;
	if (shit) return;
	shit = true;

	// https://github.com/nosoop/SM-SteamPawn
	GameData hGameData = new GameData("l4d2_server_update_checker");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_server_update_checker.txt\" gamedata.");

	Address pSteamGameServer = hGameData.GetAddress("SteamGameServer");
	if (pSteamGameServer == Address_Null)
		SetFailState("Failed to get SteamGameServer address");

	DynamicHook dHook = DynamicHook.FromConf(hGameData, "WasRestartRequested");
	if (dHook == null)
		SetFailState("Failed to create DynamicHook: WasRestartRequested");

	g_iHookid = dHook.HookRaw(Hook_Post, pSteamGameServer, OnRestartRequested);
	if (g_iHookid == INVALID_HOOK_ID)
		SetFailState("Failed to Hook: OnRestartRequested");

	delete hGameData;

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_server_update_checker.log");
}

MRESReturn OnRestartRequested(DHookReturn hReturn)
{
	if (hReturn.Value == true)
	{
		RequestFrame(RemoveHook_NextFrame);

		float fRestartTime = g_cvRestartTime.FloatValue;
		CPrintToChatAll("{default}[{red}Warn{default}] Server update detected, Will auto restart in %.1f seconds.", fRestartTime);
		LogToFileEx(g_sLogPath, "Server update detected, Will auto restart in %.1f seconds.", fRestartTime);

		CreateTimer(fRestartTime, Restart_Timer);
	}
	return MRES_Ignored;
}

void RemoveHook_NextFrame()
{
	DynamicHook.RemoveHook(g_iHookid);
}

Action Restart_Timer(Handle timer)
{
	UnloadAccelerator();
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
	return Plugin_Continue;
}

void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();
	}
}

// by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if (index == -1)
		return -1;

	for (int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}

