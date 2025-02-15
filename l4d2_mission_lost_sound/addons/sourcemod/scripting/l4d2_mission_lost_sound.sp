#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define VERSION "0.4"
#define LAUGHTER "player/survivor/voice/producer/laughter13.wav"

ConVar g_cvSoundFile;
char g_sSoundFile[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "L4D2 Mission lost sound",
	author = "fdxx",
	description = "Replace the sound of mission lost",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_mission_lost_sound_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvSoundFile = CreateConVar("l4d2_mission_lost_sound_file", LAUGHTER);
	OnConVarChanged(null, "", "");
	g_cvSoundFile.AddChangeHook(OnConVarChanged);

	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvSoundFile.GetString(g_sSoundFile, sizeof(g_sSoundFile));
}

public void OnMapStart()
{
	PrecacheSound(g_sSoundFile, true);
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
	EmitSoundToAll(g_sSoundFile);
}
