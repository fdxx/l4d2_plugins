#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define VERSION "0.1"

bool g_bTankInPlay;

public Plugin myinfo = 
{
	name = "L4D2 block hordes",
	author = "fdxx",
	description = "block hordes spawn while tank is alive",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bTankInPlay = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSI(client) && (GetZombieClass(client) == 8))
	{
		g_bTankInPlay = true;
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSI(client) && (GetZombieClass(client) == 8))
	{
		g_bTankInPlay = false;
	}
	return Plugin_Continue;
}


public Action L4D_OnSpawnMob(int &amount)
{
	if (g_bTankInPlay)
	{
		//PrintToChatAll("阻止尸潮产生");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool IsValidSI(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 3)
		{
			return true;
		}
	}
	return false;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}
