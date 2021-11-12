#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

#define VERSION "0.3"

float g_fLastLerp[MAXPLAYERS+1];
bool bRoundInProgress;

public Plugin myinfo = 
{
	name = "Lerp Monitor",
	author = "ProdigySim, Die Teetasse, vintik, fdxx",
	description = "",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("lerp_monitor_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	HookEvent("player_team", Event_PlayerTeamChanged);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	RegConsoleCmd("sm_lerps", Lerps_Cmd, "List the Lerps of all players in game");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.5, RoundStart_Timer);
}

public Action RoundStart_Timer(Handle timer)
{
	bRoundInProgress = true;
	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	bRoundInProgress = false;
}

public void OnMapEnd()
{
	bRoundInProgress = false;
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		g_fLastLerp[client] = GetClientLerp(client);
	}
}

public void OnClientSettingsChanged(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			float fNewLerp = GetClientLerp(client);
			if (fNewLerp != g_fLastLerp[client])
			{
				if (GetClientTeam(client) > 1)
				{
					CPrintToChatAllEx(client, "{default}<{olive}Lerp{default}> {teamcolor}%N {default}@ {teamcolor}%.1f {default}<== {green}%.1f", client, fNewLerp*1000, g_fLastLerp[client]*1000);
				}
				g_fLastLerp[client] = fNewLerp;
			}
		}
	}
}

public void Event_PlayerTeamChanged(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	bool bDisconnect = event.GetBool("disconnect");
	int iNewTeam = event.GetInt("team");

	if (!bDisconnect && IsClientInGame(client) && !IsFakeClient(client) && iNewTeam > 1)
	{
		CreateTimer(0.2, PlayerTeamChanged_Timer, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action PlayerTeamChanged_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			PrintLerp(client);
		}
	}
	return Plugin_Continue;
}

public Action Lerps_Cmd(int client, int args)
{
	float fLerp;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) > 1)
		{
			fLerp = GetClientLerp(i);
			ReplyToCommand(client, "%N: %.1f", i, fLerp*1000);
		}
	}
	return Plugin_Handled;
}

float GetClientLerp(int client)
{
	static char sLerp[64];
	GetClientInfo(client, "cl_interp", sLerp, sizeof(sLerp));
	return StringToFloat(sLerp);
}

void PrintLerp(int client)
{
	if (bRoundInProgress)
	{
		CPrintToChatAllEx(client, "{default}<{olive}Lerp{default}> {teamcolor}%N {default}@ {teamcolor}%.01f", client, g_fLastLerp[client]*1000);
	}
}
