#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define VERSION "0.3"

#define LAUGHTER "player/survivor/voice/producer/laughter13.wav"

public Plugin myinfo =
{
	name = "L4D2 Mission lost sound",
	author = "fdxx",
	description = "Replace the sound of mission lost",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_mission_lost_sound_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	PrecacheSound(LAUGHTER, true);
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) 
{
	RequestFrame(StopMusic_OnNextFrame);
}

void StopMusic_OnNextFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			// left4dhooks 1.62 以上版本
			L4D_StopMusic(i, "Event.ScenarioLose");
			L4D_StopMusic(i, "Event.ScenarioLose_L4D1");
		}
	}
	EmitSoundToAll(LAUGHTER);
}
