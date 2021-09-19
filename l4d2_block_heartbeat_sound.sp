#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "L4D2 block Heartbeat sound",
	author = "fdxx",
	description = "",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	AddNormalSoundHook(SoundHook);
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (strcmp(sample, "player/heartbeatloop.wav", false) == 0)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
