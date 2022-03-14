#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.2"

#include <sourcemod>
#include <dhooks>

Handle g_hSDKKVGetInt, g_hSDKKVSetInt;

public Plugin myinfo =
{
	name = "L4D2 Transition idle fix",
	author = "fdxx",
	description = "Player's idle state will not be saved to the next level",
	version = VERSION,
}

public void OnPluginStart()
{
	LoadGameData();
	CreateConVar("l4d2_transition_idle_fix_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
}

void LoadGameData()
{
	GameData hGameData = new GameData("l4d2_transition_idle_fix");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_transition_idle_fix.txt\" gamedata.");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "PlayerSaveData::Restore");
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour: PlayerSaveData::Restore");
	if (!dDetour.Enable(Hook_Pre, mreRestorePlayerDataPre))
		SetFailState("Failed to detour pre: PlayerSaveData::Restore");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetInt"))
		SetFailState("Failed to find signature: KeyValues::GetInt");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKKVGetInt = EndPrepSDKCall();
	if (g_hSDKKVGetInt == null)
		SetFailState("Failed to create SDKCall: KeyValues::GetInt");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetInt"))
		SetFailState("Failed to find signature: KeyValues::SetInt");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKKVSetInt = EndPrepSDKCall();
	if (g_hSDKKVSetInt == null)
		SetFailState("Failed to create SDKCall: KeyValues::SetInt");

	delete hGameData;
}

MRESReturn mreRestorePlayerDataPre(Address pThis, DHookParam hParams)
{
	int client = hParams.Get(1);

	if (client > 0 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client))
	{
		Address kv = view_as<Address>(LoadFromAddress(pThis, NumberType_Int32));

		if (kv != Address_Null && SDKCall(g_hSDKKVGetInt, kv, "idle", 0) == 1)
		{
			SDKCall(g_hSDKKVSetInt, kv, "idle", 0);
			LogMessage("Set %N idle to 0", client);
		}
	}

	return MRES_Ignored;
}
