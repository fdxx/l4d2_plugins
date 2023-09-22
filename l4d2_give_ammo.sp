#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>  

#define VERSION		"0.3"

ConVar g_cvInterval;
float g_fLastTime[MAXPLAYERS];

public Plugin myinfo = 
{
	name = "L4D2 give ammo",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_give_ammo_version", VERSION, "version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvInterval = CreateConVar("l4d2_give_ammo_time", "90.0", "Interval time between using commands, -1.0=Disable");

	RegConsoleCmd("sm_ammo", Cmd_GiveAmmo);
	//AutoExecConfig(true, "l4d2_give_ammo");
}

public void OnClientPutInServer(int client)
{
	g_fLastTime[client] = 0.0;
}

Action Cmd_GiveAmmo(int client, int args)
{
	if (g_cvInterval.FloatValue < 0.0)
		return Plugin_Handled;

	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client))
	{
		float fTime = GetEngineTime() - g_fLastTime[client] - g_cvInterval.FloatValue;
		if (fTime < 0.0)
		{
			CPrintToChat(client, "{lightgreen}请等待%.1f秒后在使用本命令", FloatAbs(fTime));
			return Plugin_Handled;
		}

		CheatCommand(client, "give", "ammo");
		g_fLastTime[client] = GetEngineTime();
	}
	return Plugin_Handled;
}

void CheatCommand(int client, char[] command, char[] args = "")
{
	int iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, args);
	SetCommandFlags(command, iFlags);
}
