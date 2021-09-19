#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define VERSION "0.1"

#define SOUND "ui/pickup_secret01.wav"

public Plugin myinfo = 
{
	name = "L4D2 Tank spawn announce",
	author = "fdxx",
	description = "",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_tank_spawn_announce_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	HookEvent("tank_spawn", Event_TankSpawn);
}

public void OnMapStart()
{
	PrecacheSound(SOUND, true);
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		EmitSoundToAll(SOUND, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
		CPrintToChatAll("{red}[{default}!{red}] {olive}Tank {default}has spawned!");
	}
}
