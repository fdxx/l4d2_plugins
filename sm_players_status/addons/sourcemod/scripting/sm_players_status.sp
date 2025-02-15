#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.1"

enum struct PlayerInfo
{
	int client;
	int userid;
	int team;
	bool bAlive;
	bool bFakeClient;
	char name[MAX_NAME_LENGTH];
	char steamid[MAX_AUTHID_LENGTH];

	float fPing;
	float fLoss;
	float fChoke;

	char sRate[32];
	char sCmdRate[32];
	char sUpdateRate[32];
}


public Plugin myinfo = 
{
	name = "sm_players_status",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("sm_players_status_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	RegConsoleCmd("sm_netstat", Cmd_NetStatus);
	RegConsoleCmd("sm_rates", Cmd_NetStatus);

	RegConsoleCmd("sm_player", Cmd_PlayerStatus);
	RegConsoleCmd("sm_players", Cmd_PlayerStatus);
}

Action Cmd_NetStatus(int client, int args)
{
	PlayerInfo info;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		info.fPing = GetClientAvgLatency(client, NetFlow_Outgoing) * 1000;
		info.fLoss = GetClientAvgLoss(i, NetFlow_Incoming) * 100;
		info.fChoke = GetClientAvgChoke(i, NetFlow_Incoming) * 100;
		GetClientInfo(i, "rate", info.sRate, sizeof(info.sRate));
		GetClientInfo(i, "cl_cmdrate", info.sCmdRate, sizeof(info.sCmdRate));
		GetClientInfo(i, "cl_updaterate", info.sUpdateRate, sizeof(info.sUpdateRate));

		ReplyToCommand(client, "ping: %3.0f | loss: %3.0f | choke: %3.0f | rate: %6s | cmdrate: %4s | updrate: %4s | %N", info.fPing, info.fLoss, info.fChoke, info.sRate, info.sCmdRate, info.sUpdateRate, i);
	}

	return Plugin_Handled;
}

Action Cmd_PlayerStatus(int client, int args)
{
	PlayerInfo info;
	ArrayList array = new ArrayList(sizeof(info));

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		info.client = i;
		info.userid = GetClientUserId(i);
		info.team = GetClientTeam(i);
		info.bAlive = IsPlayerAlive(i);
		info.bFakeClient = IsFakeClient(i);
		FormatEx(info.name, sizeof(info.name), "%N", i);

		if (!info.bFakeClient)
			GetClientAuthId(i, AuthId_Steam2, info.steamid, sizeof(info.steamid));
		else 
			strcopy(info.steamid, sizeof(info.steamid), "BOT");
		
		array.PushArray(info);
	}

	// Players last print.
	array.SortCustom(SortCB);

	for (int i = 0; i < array.Length; i++)
	{
		array.GetArray(i, info);
		ReplyToCommand(client, "team: %i | alive: %b | client: %2i | userid: %i | %s | %s", info.team, info.bAlive, info.client, info.userid, info.steamid, info.name);
	}

	delete array;
	return Plugin_Handled;
}

int SortCB(int index1, int index2, ArrayList array, Handle hndl)
{
	PlayerInfo info1, info2;
	array.GetArray(index1, info1);
	array.GetArray(index2, info2);

	if (info1.bFakeClient > info2.bFakeClient)
		return -1;
	if (info1.bFakeClient < info2.bFakeClient)
		return 1;
	return 0;
}

