#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

public Plugin myinfo =
{
	name = "Simble Player Joined/Left Notifier",
	author = "def (user00111)",
	description = "Notifies when a new player has joined or left the game (with disconnect reason).",
	version = "1.1",
	url = "https://forums.alliedmods.net/showthread.php?t=213471"
}

public void OnPluginStart()
{
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnClientConnected(int client)
{
	if (!IsFakeClient(client))
	{
		CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}正在加入游戏..", client);
	}
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && !IsFakeClient(client))
	{
		CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}离开了游戏.", client);
		if (!dontBroadcast)
		{
			SetEventBroadcast(event, true);
		}
	}
	return Plugin_Continue;
}
