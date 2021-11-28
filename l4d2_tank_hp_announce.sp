#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define VERSION "0.1"

public Plugin myinfo =
{
	name = "L4D2 Tank HP Announce",
	author = "fdxx",
	description = "团灭时公布Tank剩余血量",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_tank_hp_announce_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
}

void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) 
{
	RequestFrame(OnNextFrame);
}

void OnNextFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i))
		{
			if (!IsFakeClient(i))
			{
				CPrintToChatAll("{default}[{yellow}提示{default}] {olive}Tank {default}({red}%N{default}) 还剩余 {yellow}%i {default}血量.", i, GetEntProp(i, Prop_Data, "m_iHealth"));
			}
			else CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}还剩余 {yellow}%i {default}血量.", i, GetEntProp(i, Prop_Data, "m_iHealth"));
		}
	}
}
