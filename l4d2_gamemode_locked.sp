#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

ConVar
	mp_gamemode,
	z_difficulty;

char
	g_sLogPath[PLATFORM_MAX_PATH],
	g_sDefGameMode[64],
	g_sDefDifficulty[64];

public Plugin myinfo =
{
	name = "L4D2 Game mode locked",
	author = "fdxx",
	version = "0.1",
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_gamemode_locked.log");

	mp_gamemode = FindConVar("mp_gamemode");
	z_difficulty = FindConVar("z_difficulty");

	mp_gamemode.GetString(g_sDefGameMode, sizeof(g_sDefGameMode));
	z_difficulty.GetString(g_sDefDifficulty, sizeof(g_sDefDifficulty));

	mp_gamemode.AddChangeHook(OnConVarChanged);
	z_difficulty.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sName[128];
	convar.GetName(sName, sizeof(sName));
	LogToFileEx(g_sLogPath, "%s: %s -> %s", sName, oldValue, newValue);

	mp_gamemode.SetString(g_sDefGameMode);
	z_difficulty.SetString(g_sDefDifficulty);
}

