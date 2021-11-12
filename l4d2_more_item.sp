#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>

StringMap g_smModelToName, g_smNameToCount;

public Plugin myinfo =
{
	name = "L4D2 More item",
	author = "fdxx",
	version = "0.1",
};

public void OnPluginStart()   
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	g_smNameToCount = new StringMap();
	g_smModelToName = new StringMap();

	ModelToName();
	NameToCount();

	RegAdminCmd("sm_more_item_reload_cfg", Cmd_ReloadCfg, ADMFLAG_ROOT);
}

void ModelToName()
{
	// lower case
	g_smModelToName.SetString("models/w_models/weapons/w_eq_medkit.mdl",		"weapon_first_aid_kit");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_painpills.mdl",		"weapon_pain_pills");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_adrenaline.mdl",	"weapon_adrenaline");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_defibrillator.mdl",	"weapon_defibrillator");

	g_smModelToName.SetString("models/w_models/weapons/w_eq_molotov.mdl",		"weapon_molotov");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_pipebomb.mdl",		"weapon_pipe_bomb");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_bile_flask.mdl",	"weapon_vomitjar");

	g_smModelToName.SetString("models/w_models/weapons/w_pumpshotgun_a.mdl",	"weapon_shotgun_chrome");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun.mdl",			"weapon_pumpshotgun");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_uzi.mdl",			"weapon_smg");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_a.mdl",			"weapon_smg_silenced");
	g_smModelToName.SetString("models/w_models/weapons/w_autoshot_m4super.mdl",	"weapon_autoshotgun");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun_spas.mdl",		"weapon_shotgun_spas");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_m16a2.mdl",		"weapon_rifle");
	g_smModelToName.SetString("models/w_models/weapons/w_desert_rifle.mdl",		"weapon_rifle_desert");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_ak47.mdl",		"weapon_rifle_ak47");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_military.mdl",	"weapon_sniper_military");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_mini14.mdl",	"weapon_hunting_rifle");
}

void NameToCount()
{
	int iCount;
	char sPath[PLATFORM_MAX_PATH], sName[64];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/l4d2_more_item.cfg");
	KeyValues kv = new KeyValues("l4d2_more_item");
	
	g_smNameToCount.Clear();

	if (kv.ImportFromFile(sPath))
	{
		if (kv.JumpToKey("item_count"))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					if (kv.GetSectionName(sName, sizeof(sName)))
					{
						iCount = kv.GetNum(NULL_STRING, -1);
						
						if (iCount != -1)
						{
							g_smNameToCount.SetValue(sName, iCount);
							//LogMessage("%s 的 count 为 %i", sName, iCount);
						}
						else LogError("[错误] kv.GetNum 失败");
					}
					else LogError("[错误] kv.GetSectionName 失败");
				}
				while (kv.GotoNextKey(false));
			}
			else LogError("[错误] kv.GotoFirstSubKey 失败");
		}
		else LogError("[错误] kv.JumpToKey item_limit 失败");
	}
	else SetFailState("无法加载 l4d2_more_item.cfg!");

	delete kv;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.5, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStart_Timer(Handle timer)
{
	SetItemCount();
	return Plugin_Continue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	//再次检查。有些物品可能会延迟产生
	SetItemCount();
	return Plugin_Continue;
}

void SetItemCount()
{
	static char sModel[PLATFORM_MAX_PATH], sItemName[64];
	static int iCount, iCurCount;

	for (int i = MaxClients+1; i <= GetMaxEntities(); i++)
	{
		if (IsValidEntity(i))
		{
			if (HasEntProp(i, Prop_Data, "m_iState"))
			{
				if (GetEntProp(i, Prop_Data, "m_iState"))
				{
					//LogMessage("在玩家身上, 跳过");
					//在玩家身上的物品模型不一样 models/v_models/v_medkit.mdl
					continue;
				}
			}

			if (HasEntProp(i, Prop_Data, "m_ModelName"))
			{
				if (GetEntPropString(i, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
				{
					StrToLowerCase(sModel);
					if (g_smModelToName.GetString(sModel, sItemName, sizeof(sItemName)))
					{
						if (g_smNameToCount.GetValue(sItemName, iCount))
						{
							if (iCount > 1)
							{
								if (HasEntProp(i, Prop_Data, "m_itemCount"))
								{
									iCurCount = GetEntProp(i, Prop_Data, "m_itemCount");
									if (iCurCount < iCount)
									{
										SetEntProp(i, Prop_Data, "m_itemCount", iCount);
										//LogMessage("将 %s 的 Count 由 %i 更改为 %i", sItemName, iCurCount, iCount);
									}
									//else LogMessage("%s iCurCount = %i, iCount = %i, 跳过", sItemName, iCurCount, iCount);
								}
							}
						}
					}
				}
			}
		}
	}
}

void StrToLowerCase(char[] str)
{
	for (int i = 0; i < strlen(str); i++)
	{
		str[i] = CharToLower(str[i]);
	}
}

public Action Cmd_ReloadCfg(int client, int args)
{
	NameToCount();
	return Plugin_Handled;
}
