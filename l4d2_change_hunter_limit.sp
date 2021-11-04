#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "1.1"

ConVar CvarMaxSpecialsLimit, CvarMaxHunterLimit, CvarSpawnTimeLimit;

public Plugin myinfo = 
{
	name = "L4D2 Change Hunter limit",
	author = "Dragokas, fdxx",
	description = "",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_change_hunter_limit_version", VERSION, "插件版本", FCVAR_NONE|FCVAR_DONTRECORD);
}

public void OnConfigsExecuted()
{
	CvarMaxSpecialsLimit = FindConVar("l4d2_si_spawn_control_max_specials");
	CvarMaxHunterLimit = FindConVar("l4d2_si_spawn_control_hunter_limit");
	CvarSpawnTimeLimit = FindConVar("l4d2_si_spawn_control_spawn_time");

	if (CvarMaxSpecialsLimit == null)
	{
		SetFailState("l4d2_si_spawn_control plugin not loaded?");
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (IsValidClient(client))
	{
		int iAmount, iTime;
		if (ParseCmd_Amount(sArgs, "ht", iAmount))
		{
			CvarMaxSpecialsLimit.SetInt(iAmount);
			CvarMaxHunterLimit.SetInt(iAmount);
		}
		else if (ParseCmd_Time(sArgs, "s", iTime))
		{
			CvarSpawnTimeLimit.SetFloat(float(iTime));
		}
	}

	return Plugin_Continue;	
}

bool ParseCmd_Amount(const char[] cmdSource, char[] cmdSample, int &iAmount)
{
	const int NUM_MIN = 1;
	const int NUM_MAX = 24;
	const int NUMLEN_MAX = 2;
	
	int lenSrc = strlen(cmdSource);
	int CMDLEN = strlen(cmdSample);
	
	if (CMDLEN + 1 <= lenSrc <= CMDLEN + NUMLEN_MAX)
	{
		if (strcmp(cmdSource[lenSrc-CMDLEN], cmdSample, true) == 0)
		{
			iAmount = StringToInt(cmdSource);
			if (NUM_MIN <= iAmount <= NUM_MAX)
			{
				return true;
			}
		}
	}
	return false;
}

bool ParseCmd_Time(const char[] cmdSource, char[] cmdSample, int &iTime)
{
	const int NUM_MIN = 1;
	const int NUM_MAX = 999;
	const int NUMLEN_MAX = 3;
	
	int lenSrc = strlen(cmdSource);
	int CMDLEN = strlen(cmdSample);
	
	if (CMDLEN + 1 <= lenSrc <= CMDLEN + NUMLEN_MAX)
	{
		if (strcmp(cmdSource[lenSrc-CMDLEN], cmdSample, true) == 0)
		{
			iTime = StringToInt(cmdSource);
			if (NUM_MIN <= iTime <= NUM_MAX)
			{
				return true;
			}
		}
	}
	return false;
}

bool IsValidClient(int client)
{ 
	if (0 < client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client))
		{
			return true;
		}
	}
	return false;
}
