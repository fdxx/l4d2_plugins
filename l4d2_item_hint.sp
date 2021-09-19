#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>

Handle g_hUseEntity;
ConVar CvarFindRadius;
StringMap g_smModelToName;

public Plugin myinfo =
{
	name = "L4D2 Item hint",
	author = "BHaType, fdxx",
	description = "When using 'Look' in vocalize menu, print corresponding item to chat area.",
	version = "0.2",
	url = ""
};

public void OnPluginStart()
{
	GameData hGameData = new GameData("l4d2_item_hint");
	if (hGameData != null)
	{
		int iOffset = hGameData.GetOffset("FindUseEntity");
		if (iOffset != -1)
		{
			//https://forums.alliedmods.net/showpost.php?p=2753773&postcount=2
			StartPrepSDKCall(SDKCall_Player);
			PrepSDKCall_SetVirtual(iOffset);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
			g_hUseEntity = EndPrepSDKCall();
		}
		else SetFailState("Failed to load offset");
	}
	else SetFailState("Failed to load l4d2_item_hint.txt file");
	delete hGameData;

	CvarFindRadius = FindConVar("player_use_radius");
	AddCommandListener(Vocalize_Listener, "vocalize");

	CreateStringMap();
}

void CreateStringMap()
{
	g_smModelToName = new StringMap();

	//Case-sensitive
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
}

public Action Vocalize_Listener(int client, const char[] command, int argc)
{
	if (IsRealSur(client))
	{
		static char sCmdString[64];
		if (GetCmdArgString(sCmdString, sizeof(sCmdString)) > 1)
		{
			if (strncmp(sCmdString, "smartlook #", 11) == 0)
			{
				static int iEntity;
				iEntity = GetUseEntity(client, CvarFindRadius.FloatValue);
				if (MaxClients < iEntity <= GetMaxEntities())
				{
					if (HasEntProp(iEntity, Prop_Data, "m_ModelName"))
					{
						static char sEntModelName[PLATFORM_MAX_PATH];
						if (GetEntPropString(iEntity, Prop_Data, "m_ModelName", sEntModelName, sizeof(sEntModelName)) > 1)
						{
							static char sItemName[64];
							if (g_smModelToName.GetString(sEntModelName, sItemName, sizeof(sItemName)))
							{
								//PrintToChatAll("\x01(Vocalize) \x05%N\x01: %s", client, sItemName);
								CPrintToChatAll("({yellow}Vocalize{default}) {blue}%N{default}：%s", client, sItemName);
							}
						}
					}
				}
			}
		}
	}
}

int GetUseEntity(int client, float fRadius)
{
	return SDKCall(g_hUseEntity, client, fRadius, 0.0, 0.0, 0, 0);
}

bool IsRealSur(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsFakeClient(client));
}
