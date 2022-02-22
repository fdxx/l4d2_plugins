#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "View player network status",
	author = "X@IDER, fdxx",
	description = "View player network status",
	version = "1.2",
	url = ""
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_netstat", Cmd_Netstat);
	RegConsoleCmd("sm_rates", Cmd_Netstat);
}

Action Cmd_Netstat(int client, int args)
{
	float fLoss, fChoke;
	char sRate[32], sCmdRate[32], sUpdateRate[32], sLerp[32];
	float fLerp;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			fLoss = GetClientAvgLoss(i, NetFlow_Both)*100;
			fChoke = GetClientAvgChoke(i, NetFlow_Both)*100;
			GetClientInfo(i, "rate", sRate, sizeof(sRate));
			GetClientInfo(i, "cl_cmdrate", sCmdRate, sizeof(sCmdRate));
			GetClientInfo(i, "cl_updaterate", sUpdateRate, sizeof(sUpdateRate));
			GetClientInfo(i, "cl_interp", sLerp, sizeof(sLerp));
			fLerp = StringToFloat(sLerp)*1000;
			ReplyToCommand(client, "loss: %.1f%% | choke: %.1f%% | rate: %-6s | cmdrate: %-3s | updrate: %-3s | lerp: %.1f | %N", fLoss, fChoke, sRate, sCmdRate, sUpdateRate, fLerp, i);
		}
	}
	return Plugin_Handled;
}
