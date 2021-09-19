#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "0.2"

#define LAUGHTER "player/survivor/voice/producer/laughter13.wav"
Handle g_hMusicStop;

public Plugin myinfo =
{
	name = "L4D2 Mission lost sound",
	author = "DeathChaos25, Shadowysn, fdxx",
	description = "Replace the sound of mission lost",
	version = VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2706516"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_mission_lost_sound_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	GetGamedata();
	HookEvent("mission_lost", Event_MissionLost);
}

void GetGamedata()
{
	//https://github.com/Psykotikism/L4D1-2_Signatures/blob/main/l4d2/gamedata/l4d2_signatures.txt
	GameData hGameData = new GameData("l4d2_signatures");
	if (hGameData != null)
	{
		StartPrepSDKCall(SDKCall_Raw);
		if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Music::StopPlaying"))
		{
			PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			g_hMusicStop = EndPrepSDKCall();
			if (g_hMusicStop == null) SetFailState("Failed to load signature Music::StopPlaying");
		}
		else SetFailState("Failed to load signature Music::StopPlaying");
	}
	else SetFailState("Failed to load l4d2_signatures.txt file");

	delete hGameData;
}

public void OnMapStart()
{
	PrecacheSound(LAUGHTER, true);
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) 
{
	RequestFrame(StopMusic_FrameCallback);
	EmitSoundToAll(LAUGHTER, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

void StopMusic_FrameCallback()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SDK_StopMusic(i, "Event.ScenarioLose");
			SDK_StopMusic(i, "Event.ScenarioLose_L4D1");
		}
	}
}

void SDK_StopMusic(int client, const char[] music_str, float one_float = 0.0, bool one_bool = false)
{	
	Address music_address = GetEntityAddress(client)+(view_as<Address>(GetEntSendPropOffs(client, "m_music")));
	SDKCall(g_hMusicStop, music_address, music_str, one_float, one_bool);
}
