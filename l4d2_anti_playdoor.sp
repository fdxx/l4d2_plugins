#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>  

#define VERSION		"0.2"
#define KILL_SOUND	"weapons/awp/gunfire/awp1.wav"

ConVar
	g_cvMaxPlayNum,
	g_cvResetTime;

int
	g_iMaxPlayNum,
	g_iPlayCount[MAXPLAYERS+1];

float
	g_fResetTime,
	g_fLastCloseDoorTime[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "L4D2 Anti play door",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_anti_playdoor_version", VERSION, "version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvMaxPlayNum = CreateConVar("l4d2_anti_playdoor_number", "4", "PlayDoor reaches the number, the player will be Kill");
	g_cvResetTime = CreateConVar("l4d2_anti_playdoor_time", "7.0", "After this time, the number of PlayDoor will be reset");

	OnConVarChange(null, "", "");

	g_cvMaxPlayNum.AddChangeHook(OnConVarChange);
	g_cvResetTime.AddChangeHook(OnConVarChange);

	HookEvent("door_close", Event_DoorClose);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "l4d2_anti_playdoor");
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iMaxPlayNum = g_cvMaxPlayNum.IntValue;
	g_fResetTime = g_cvResetTime.FloatValue;
}

public void OnMapStart()
{
	PrecacheSound(KILL_SOUND, true);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		g_iPlayCount[i] = 0;
}

public void OnClientPutInServer(int client)
{
	g_iPlayCount[client] = 0;
}

void Event_DoorClose(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("checkpoint"))
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if ((GetEngineTime() - g_fLastCloseDoorTime[client]) < g_fResetTime)
		{
			if (++g_iPlayCount[client] >= g_iMaxPlayNum)
			{
				ForcePlayerSuicide(client);
				EmitSoundToAll(KILL_SOUND);
				CPrintToChatAll("{blue}[提示] {olive}%N {default}因为玩门被系统自动处死.", client);
			}
		}
		else
			g_iPlayCount[client] = 0;

		g_fLastCloseDoorTime[client] = GetEngineTime();
	}
}
