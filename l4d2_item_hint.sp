#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>   

#define VERSION		"0.3"

Handle g_hFindUseEntity;
StringMap g_smModelToName;
ConVar player_use_radius;

public Plugin myinfo =
{
	name = "L4D2 Item hint",
	author = "BHaType, fdxx",
	description = "When using 'Look' in vocalize menu, print corresponding item to chat area.",
	version = VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2753892"
};

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_item_hint_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	player_use_radius = FindConVar("player_use_radius");
	AddCommandListener(CmdListener_vocalize, "vocalize");
}

void Init()
{
	GameData hGameData = new GameData("l4d2_item_hint");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_item_hint.txt\" gamedata.");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "FindUseEntity");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);				// range
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);				// unknown
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);				// tolerance
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		// unknown bool pointer
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);				// player priority
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hFindUseEntity = EndPrepSDKCall();
	if (g_hFindUseEntity == null)
		SetFailState("Failed to create SDKCall: FindUseEntity");

	delete hGameData;

	g_smModelToName = new StringMap();

	// Case-sensitive
	g_smModelToName.SetString("models/w_models/weapons/w_eq_Medkit.mdl",				"First aid kit!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_defibrillator.mdl",			"Defibrillator!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_painpills.mdl",				"Pain pills!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_adrenaline.mdl",			"Adrenaline!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_bile_flask.mdl",			"Bile Bomb!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_molotov.mdl",				"Molotov!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_pipebomb.mdl",				"Pipe bomb!");
	g_smModelToName.SetString("models/w_models/Weapons/w_laser_sights.mdl",				"Laser Sight!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_incendiary_ammopack.mdl",	"Incendiary UpgradePack!");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_explosive_ammopack.mdl",	"Explosive UpgradePack!");
	g_smModelToName.SetString("models/props/terror/ammo_stack.mdl",						"Ammo stack!");
	g_smModelToName.SetString("models/props_unique/spawn_apartment/coffeeammo.mdl",		"Ammo stack!");
}

Action CmdListener_vocalize(int client, const char[] command, int argc)
{
	static char sArg[32], sModel[PLATFORM_MAX_PATH], sName[64];

	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if (GetCmdArgString(sArg, sizeof(sArg)) > 1 && !strncmp(sArg, "smartlook #", 11))
		{
			int entity = SDKCall(g_hFindUseEntity, client, player_use_radius.FloatValue, 0.0, 0.0, 0, false);
			if (entity > MaxClients && IsValidEntity(entity))
			{
				if (GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
				{
					if (g_smModelToName.GetString(sModel, sName, sizeof(sName)))
					{
						//PrintToChatAll("(Vocalize) %N: %s", client, sName);
						CPrintToChatAll("{blue}%N{default}: %s", client, sName);
					}
				}
			}
		}
	}

	return Plugin_Continue;
}
