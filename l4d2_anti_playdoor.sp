#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define VERSION "0.1"

#define DEBUG 1
char g_logPath[PLATFORM_MAX_PATH];

ConVar CvarPlayDoorNumber, CvarPlayDoorTime;
int g_iPlayDoorNumber;
float g_fPlayDoorTime;

float g_fLastCloseDoorTime[MAXPLAYERS+1];
int g_iPlayDoorCount[MAXPLAYERS+1];

#define KILL_SOUND "weapons/awp/gunfire/awp1.wav"

public Plugin myinfo =
{
	name = "L4D2 Anti play door",
	author = "fdxx",
	description = "",
	version = VERSION,
	url = ""
};

public void OnPluginStart()
{
	BuildPath(Path_SM, g_logPath, sizeof(g_logPath), "logs/l4d2_anti_playdoor.log");

	HookEvent("door_close", Event_DoorClose, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	CreateConVar("l4d2_anti_playdoor_version", VERSION, "Plugin version", FCVAR_NONE|FCVAR_DONTRECORD);
	CvarPlayDoorNumber = CreateConVar("l4d2_anti_playdoor_number", "4", "PlayDoor reaches the number, the player will be Kill", FCVAR_NONE);
	CvarPlayDoorTime = CreateConVar("l4d2_anti_playdoor_time", "7.0", "After this time, the number of PlayDoor will be reset", FCVAR_NONE);

	GetCvars();

	CvarPlayDoorNumber.AddChangeHook(ConVarChange);
	CvarPlayDoorTime.AddChangeHook(ConVarChange);

	AutoExecConfig(true, "l4d2_anti_playdoor");
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iPlayDoorNumber = CvarPlayDoorNumber.IntValue;
	g_fPlayDoorTime = CvarPlayDoorTime.FloatValue;
}

public void Event_DoorClose(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetBool("checkpoint"))
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		
		if (IsRealSur(client))
		{
			if ((GetEngineTime() - g_fLastCloseDoorTime[client]) < g_fPlayDoorTime)
			{
				if (++g_iPlayDoorCount[client] >= g_iPlayDoorNumber) KillClient(client);
				//else PrintToChatAll("%N play door %i times.", client, g_iPlayDoorCount[client]);
			}
			else g_iPlayDoorCount[client] = 0;

			g_fLastCloseDoorTime[client] = GetEngineTime();
		}
	}
}

void KillClient(int client)
{
	if (IsRealSur(client))
	{
		ForcePlayerSuicide(client);
		EmitSoundToAll(KILL_SOUND, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
		CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}因为玩门被系统自动处死", client);
		LogToFileEx_Debug("%N 因为玩门被系统自动处死", client);
		g_iPlayDoorCount[client] = 0;
	}
}

public void OnMapStart()
{
	PrecacheSound(KILL_SOUND, true);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		g_iPlayDoorCount[i] = 0;
	}
}

public void OnClientPutInServer(int client)
{
	g_iPlayDoorCount[client] = 0;
}

bool IsRealSur(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client));
}

void LogToFileEx_Debug(const char[] format, any ...)
{
	char buffer[254];
	VFormat(buffer, sizeof(buffer), format, 2);

	#if DEBUG
	LogToFileEx(g_logPath, buffer);
	#endif
}
