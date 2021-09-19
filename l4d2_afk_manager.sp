#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "0.4"

#define CHECK_TIME 3.0

ConVar CvarSpecTime, CvarKickTime, CvarExcludeTank, CvarExcludeAdmin, CvarExcludeDead, CvarKickPlayersLimit;
float g_fSpecTime, g_fKickTime;
bool g_bExcludeTank, g_bExcludeAdmin, g_bExcludeDead;
int g_iKickPlayersLimit;

float g_fLastActionTime[MAXPLAYERS+1];
Handle g_hAFKCheckTimer;
bool g_bForceSpec[MAXPLAYERS+1];

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

public Plugin myinfo =
{
	name = "L4D2 AFK Manager",
	author = "fdxx",
	description = "",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_afk_manager_version", VERSION, "插件版本", FCVAR_NONE|FCVAR_DONTRECORD);

	CvarSpecTime = CreateConVar("l4d2_afk_manager_spec_time", "90.0", "多少秒后闲置的玩家将会被强制移至旁观, 0.0=永不强制旁观", FCVAR_NONE);
	CvarKickTime = CreateConVar("l4d2_afk_manager_kick_time", "180.0", "多少秒后闲置的旁观玩家将会被踢出服务器(强制移至旁观后), 0.0=永不踢出", FCVAR_NONE);
	CvarExcludeTank = CreateConVar("l4d2_afk_manager_exclude_tank",	"1", "强制移至旁观排除Tank", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarExcludeAdmin = CreateConVar("l4d2_afk_manager_exclude_admin", "1", "强制移至旁观排除admin", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarExcludeDead = CreateConVar("l4d2_afk_manager_exclude_dead", "1", "强制移至旁观排除死人", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarKickPlayersLimit = CreateConVar("l4d2_afk_manager_kick_players_limit", "4", "服务器达到多少玩家后才会将闲置的旁观玩家踢出服务器", FCVAR_NONE, true, 0.0, true, 32.0);

	GetCvars();

	CvarSpecTime.AddChangeHook(ConVarChanged);
	CvarKickTime.AddChangeHook(ConVarChanged);
	CvarExcludeTank.AddChangeHook(ConVarChanged);
	CvarExcludeAdmin.AddChangeHook(ConVarChanged);
	CvarExcludeDead.AddChangeHook(ConVarChanged);
	CvarKickPlayersLimit.AddChangeHook(ConVarChanged);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeamChanged);
	HookEvent("player_say",	Event_PlayerSay);

	AutoExecConfig(true, "l4d2_afk_manager");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fSpecTime = CvarSpecTime.FloatValue;
	g_fKickTime = CvarKickTime.FloatValue;
	g_bExcludeTank = CvarExcludeTank.BoolValue;
	g_bExcludeAdmin = CvarExcludeAdmin.BoolValue;
	g_bExcludeDead = CvarExcludeDead.BoolValue;
	g_iKickPlayersLimit = CvarKickPlayersLimit.IntValue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (IsRealClient(client))
	{
		if (buttons)
		{
			g_fLastActionTime[client] = GetEngineTime();
		}

		if (mouse[0] || mouse[1])
		{
			if (!IsMouseExclude(client))
			{
				g_fLastActionTime[client] = GetEngineTime();
			}
		}
	}
}

//https://forums.alliedmods.net/showthread.php?p=2569852
bool IsMouseExclude(int iClient)
{
	//mode -1未定义 0自己 1刚死亡时 2未知 3未知 4第一视角 5第三视角 6自由视角
	if (GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 4)
	{
		static int iTarget;
		iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		if (0 < iTarget <= MaxClients)
		{
			if (IsClientInGame(iTarget) && IsPlayerAlive(iTarget))
			{
				if (GetEntProp(iTarget, Prop_Send, "m_isIncapacitated", 1)) //第一人称观战倒地的人会有鼠标数据
				{
					return true;
				}
			}
		}
	}
	return false;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && !IsFakeClient(client))
	{
		g_bForceSpec[client] = false;
		//LogMessage("%N 离开服务器，重置g_bForceSpec", client);
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	delete g_hAFKCheckTimer;
	g_hAFKCheckTimer = CreateTimer(CHECK_TIME, AFKCheck_Timer, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	delete g_hAFKCheckTimer;
}

public Action AFKCheck_Timer(Handle timer)
{
	static int iTeam;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (IsAdminClient(i) && g_bExcludeAdmin) continue;

			iTeam = GetClientTeam(i);
			switch (iTeam)
			{
				case TEAM_INFECTED, TEAM_SURVIVOR:
				{
					if (iTeam == TEAM_INFECTED)
					{
						if (GetZombieClass(i) == 8 && g_bExcludeTank) continue;
					}

					if ((g_fSpecTime >= 0.1) && (GetClientAFKTime(i) >= g_fSpecTime))
					{
						if (!IsPlayerAlive(i) && g_bExcludeDead) continue;

						g_bForceSpec[i] = true;
						g_fLastActionTime[i] = GetEngineTime();
						ChangeClientTeam(i, TEAM_SPECTATOR);
						continue;
					}
					continue;
				}

				case TEAM_SPECTATOR:
				{
					if (g_bForceSpec[i])
					{
						if ((g_fKickTime >= 0.1) && (GetClientAFKTime(i) >= g_fKickTime))
						{
							if (GetCurPlayerCount() >= g_iKickPlayersLimit)
							{
								kickAFK(i);
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

float GetClientAFKTime(int client)
{
	return (GetEngineTime() - g_fLastActionTime[client]);
}

public void Event_PlayerTeamChanged(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	bool bDisconnect = event.GetBool("disconnect");
	int iNewTeam = event.GetInt("team");

	if (!bDisconnect && !IsFakeClient(client))
	{
		if (iNewTeam == TEAM_INFECTED || iNewTeam == TEAM_SURVIVOR)
		{
			g_bForceSpec[client] = false;
			g_fLastActionTime[client] = GetEngineTime();
			//LogMessage("%N 团队切换，重置g_bForceSpec", client);
		}

		if (!g_bForceSpec[client] && iNewTeam == TEAM_SPECTATOR)
		{
			g_fLastActionTime[client] = GetEngineTime();
		}
	}
}

public void Event_PlayerSay(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	g_bForceSpec[client] = false;
	g_fLastActionTime[client] = GetEngineTime();
}

//sourcemod 1.11 6612 以上
public void OnClientSpeakingEnd(int client)
{
	g_bForceSpec[client] = false;
	g_fLastActionTime[client] = GetEngineTime();
}

void kickAFK(int client)
{
	if (IsClientInGame(client) && !IsClientInKickQueue(client))
	{
		if (!IsFakeClient(client))
		{
			KickClient(client, "You were kicked for being AFK too long");
		}
	}
}

int GetCurPlayerCount()
{
	int iCount;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			iCount++;
	}
	return iCount;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool IsAdminClient(int client)
{
	int iFlags = GetUserFlagBits(client);
	if ((iFlags != 0) && (iFlags & ADMFLAG_ROOT)) 
	{
		return true;
	}
	return false;
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}
