#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "1.3"

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
}

public void OnPluginStart()
{
	CreateConVar("l4d2_change_hunter_limit_version", VERSION, "插件版本", FCVAR_NONE|FCVAR_DONTRECORD);
}

public void OnConfigsExecuted()
{
	g_cvMaxSpecialsLimit = FindConVar("l4d2_si_spawn_control_max_specials");
	g_cvHunterLimit = FindConVar("l4d2_si_spawn_control_hunter_limit");
	g_cvSpawnTime = FindConVar("l4d2_si_spawn_control_spawn_time");

	if (g_cvMaxSpecialsLimit == null)
	{
		SetFailState("l4d2_si_spawn_control plugin not loaded?");
	}
}

// 1s 1ht - 999s 24ht
public Action OnClientSayCommand(int client, const char[] command, const char[] sSay)
{
	if (IsValidClient(client))
	{
		static int iSayLen, iNumLen, iNum;

		iSayLen = strlen(sSay);
		if (2 <= iSayLen <= 4)
		{
			switch (sSay[iSayLen-1])
			{
				case 't':
				{
					iNumLen = iSayLen - 2;
					if (strcmp(sSay[iNumLen], "ht") == 0)
					{
						if (IsInteger(sSay, iNumLen))
						{
							iNum = StringToInt(sSay);
							if (MIN_HUNTER <= iNum <= MAX_HUNTER)
							{
								g_cvMaxSpecialsLimit.IntValue = iNum;
								g_cvHunterLimit.IntValue = iNum;
								//PrintToChatAll("iNum = %i", iNum);
							}
						}
					}
				}
				case 's':
				{
					iNumLen = iSayLen - 1;
					if (strcmp(sSay[iNumLen], "s") == 0)
					{
						if (IsInteger(sSay, iNumLen))
						{
							iNum = StringToInt(sSay);
							if (MIN_TIME <= iNum <= MAX_TIME)
							{
								g_cvSpawnTime.FloatValue = float(iNum);
								//PrintToChatAll("iNum = %i", iNum);
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;	
}

bool IsInteger(const char[] sBuffer, int iCompareLen)
{
	static int i;

	for (i = 0; i < iCompareLen; i++)
	{
		if (!IsCharNumeric(sBuffer[i]) )
			return false;
	}

	return true;
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
