
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

Handle g_hStaggering;

public Plugin myinfo =
{
	name = "L4D2 Block stumble scratches",
	author = "Tabun, dcx2, fdxx",
	description = "特感Bot被推后的硬直时间内，阻止使用右键抓人",
	version = "0.1",
	url = "https://github.com/Tabbernaut/L4D2-Plugins/tree/master/ai_damagefix"
}

public void OnPluginStart()
{
	//https://github.com/Psykotikism/L4D1-2_Signatures/blob/main/l4d2/gamedata/l4d2_signatures.txt
	GameData hGameData = new GameData("l4d2_signatures");
	if (hGameData != null)
	{
		StartPrepSDKCall(SDKCall_Player);
		if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::IsStaggering"))
		{
			PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
			g_hStaggering = EndPrepSDKCall();
			if (g_hStaggering == null) SetFailState("Failed to load signature IsStaggering");
		}
		else SetFailState("Failed to load signature IsStaggering");
	}
	else SetFailState("Failed to load l4d2_signatures.txt file");
	delete hGameData;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsValidSI(client) && IsPlayerAlive(client) && IsFakeClient(client) && SDKCall(g_hStaggering, client))
	{
		buttons &= ~IN_ATTACK2;
	}
}

bool IsValidSI(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 3)
		{
			return true;
		}
	}
	return false;
}
