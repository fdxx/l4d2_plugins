
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
	description = "特感Bot被推后的硬直时间内，阻止使用右键抓人",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_block_stumble_scratches_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
}

void Init()
{
	GameData hGameData = new GameData("l4d2_block_stumble_scratches");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_block_stumble_scratches.txt\" gamedata.");

	g_iOffset = hGameData.GetOffset("CGameTrace::m_pEnt");
	if (g_iOffset == -1)
		SetFailState("Failed to find offset: CGameTrace::m_pEnt");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::IsStaggering"))
		SetFailState("Failed to find signature: CTerrorPlayer::IsStaggering");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsStaggering = EndPrepSDKCall();
	if (g_hSDKIsStaggering == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::IsStaggering");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CClaw::OnHit");
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour: CClaw::OnHit");
	if (!dDetour.Enable(Hook_Pre, OnClawHitPre))
		SetFailState("Failed to enable DynamicDetour: CClaw::OnHit");

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
