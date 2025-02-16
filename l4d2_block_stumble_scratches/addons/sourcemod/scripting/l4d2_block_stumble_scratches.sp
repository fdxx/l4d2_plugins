
#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.3"

#include <sourcemod>
#include <dhooks>

Handle g_hSDKIsStaggering;
int g_iOffset;

public Plugin myinfo =
{
	name = "L4D2 Block stumble scratches",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_block_stumble_scratches_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
}

void Init()
{
	char buffer[128];

	strcopy(buffer, sizeof(buffer), "l4d2_block_stumble_scratches");
	GameData hGameData = new GameData(buffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", buffer);

	strcopy(buffer, sizeof(buffer), "CGameTrace::m_pEnt");
	g_iOffset = hGameData.GetOffset(buffer);
	if (g_iOffset == -1)
		SetFailState("Failed to GetOffset: %s", buffer);

	strcopy(buffer, sizeof(buffer), "CTerrorPlayer::IsStaggering");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsStaggering = EndPrepSDKCall();
	if (g_hSDKIsStaggering == null)
		SetFailState("Failed to create SDKCall: %s", buffer);

	strcopy(buffer, sizeof(buffer), "CClaw::OnHit");
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, buffer);
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour: %s", buffer);
	if (!dDetour.Enable(Hook_Pre, OnClawHitPre))
		SetFailState("Failed to enable DynamicDetour: %s", buffer);

	delete hGameData;
}

MRESReturn OnClawHitPre(int claw, DHookReturn hReturn, DHookParam hParams)
{
	int attacker = GetEntPropEnt(claw, Prop_Send, "m_hOwnerEntity");
	int victim = hParams.GetObjectVar(1, g_iOffset, ObjectValueType_CBaseEntityPtr);

	if (IsValidClient(attacker, 3) && IsPlayerAlive(attacker) && SDKCall(g_hSDKIsStaggering, attacker) && IsFakeClient(attacker))
	{
		if (IsValidClient(victim, 2) && IsPlayerAlive(victim))
		{
			//PrintToServer("阻止 %N ClawHit %N", attacker, victim);
			hReturn.Value = 0;
			return MRES_Supercede;
		}
	}
	return MRES_Ignored;
}

bool IsValidClient(int client, int team)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			return true;
		}
	}
	return false;
}
