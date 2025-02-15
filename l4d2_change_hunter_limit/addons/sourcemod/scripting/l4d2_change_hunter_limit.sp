#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "1.4"

#define MIN_HUNTER 1
#define MAX_HUNTER 24

#define MIN_TIME 1
#define MAX_TIME 999

ConVar
	g_cvMaxSpecialsLimit,
	g_cvHunterLimit,
	g_cvSpawnTime;

public Plugin myinfo = 
{
	name = "L4D2 Change Hunter limit",
	author = "Dragokas, fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_change_hunter_limit_version", VERSION, "version", FCVAR_NONE|FCVAR_DONTRECORD);
}

public void OnConfigsExecuted()
{
	g_cvMaxSpecialsLimit = FindConVar("l4d2_si_spawn_control_max_specials");
	g_cvHunterLimit = FindConVar("l4d2_si_spawn_control_hunter_limit");
	g_cvSpawnTime = FindConVar("l4d2_si_spawn_control_spawn_time");

	if (g_cvMaxSpecialsLimit == null)
		SetFailState("l4d2_si_spawn_control plugin not loaded?");
}

// 1s 1ht - 999s 24ht
public Action OnClientSayCommand(int client, const char[] command, const char[] sSay)
{
	if (!IsValidSur(client) || !IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Continue;	

	int sayLen = strlen(sSay);
	if (sayLen < 2 || sayLen > 4)
		return Plugin_Continue;	

	if (!strcmp(sSay[sayLen-2], "ht"))
	{
		if (!IsInteger(sSay, sayLen-2))
			return Plugin_Continue;

		int num = StringToInt(sSay);
		if (num < MIN_HUNTER || num > MAX_HUNTER)
			return Plugin_Continue;	
		
		g_cvMaxSpecialsLimit.IntValue = num;
		g_cvHunterLimit.IntValue = num;
	}

	else if (sSay[sayLen-1] == 's')
	{
		if (!IsInteger(sSay, sayLen-1))
			return Plugin_Continue;

		int num = StringToInt(sSay);
		if (num < MIN_TIME || num > MAX_TIME)
			return Plugin_Continue;	

		g_cvSpawnTime.FloatValue = float(num);
	}

	return Plugin_Continue;	
}

bool IsInteger(const char[] str, int len)
{
	for (int i = 0; i < len; i++)
	{
		if (!IsCharNumeric(str[i]) )
			return false;
	}

	return true;
}

bool IsValidSur(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}
