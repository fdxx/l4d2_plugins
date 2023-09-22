#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues
#include <sourcescramble>			// https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "1.6.1"
#define MAX_MELEE_LIST	511
#define DEFAULT_MELEES	"fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork"

DynamicDetour g_Detour;
MemoryPatch g_MemPatch;
Handle g_hSDK_GetMissionInfo;
Handle g_hSDK_MeleeDump;
char g_sMeleeList[MAX_MELEE_LIST];

public Plugin myinfo =
{
	name = "l4d2 melee spawn control",
	author = "IA/NanaNana, sorallll, fdxx",
	description = "Unlock melee weapons",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_melee_spawn_control_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ConVar cvar = CreateConVar("l4d2_melee_spawn_unlock_all", "1");
	OnConVarChanged(cvar, "", "");
	cvar.AddChangeHook(OnConVarChanged);
	
	RegAdminCmd("sm_spawnmelee_test", Cmd_Spawn, ADMFLAG_ROOT);
	RegAdminCmd("sm_meleedump", Cmd_Dump, ADMFLAG_ROOT);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_Detour)
		g_Detour.Disable(Hook_Pre, OnMeleeWeaponInfoStore_LoadScripts_Pre);
	delete g_Detour;
	delete g_MemPatch;

	if (convar.BoolValue)
		Init();
}

// void CMeleeWeaponInfoStore::LoadScripts(bool unknown)
MRESReturn OnMeleeWeaponInfoStore_LoadScripts_Pre(Address pThis, DHookParam hParams)
{
	static char sMissionMelees[MAX_MELEE_LIST], buffer[PLATFORM_MAX_PATH];
	strcopy(g_sMeleeList, sizeof(g_sMeleeList), DEFAULT_MELEES);

	SourceKeyValues kvMission = SDKCall(g_hSDK_GetMissionInfo);
	kvMission.GetString("meleeweapons", sMissionMelees, sizeof(sMissionMelees));
	if (sMissionMelees[0])
	{
		int relocIndex, index;

		while ((index = SplitString(sMissionMelees[relocIndex], ";", buffer, sizeof(buffer))) != -1)
		{
			if (StrContains(g_sMeleeList, buffer) == -1)
				Format(g_sMeleeList, sizeof(g_sMeleeList), "%s;%s", buffer, g_sMeleeList);
			relocIndex += index;
		}

		if (StrContains(g_sMeleeList, sMissionMelees[relocIndex]) == -1)
			Format(g_sMeleeList, sizeof(g_sMeleeList), "%s;%s", sMissionMelees[relocIndex], g_sMeleeList);
		
		kvMission.SetString("meleeweapons", g_sMeleeList);
		return MRES_Ignored;
	}


	// g_pStringTableMeleeWeapons = networkstringtable.CreateStringTable("MeleeWeapons", 16, 0, 0, 0);
	// Only 16 melee weapons allowed? Exceeding that will issue a warning.
	SourceKeyValues kvManifest = SourceKeyValues("");
	kvManifest.UsesEscapeSequences(true);
	if (kvManifest.LoadFromFile("scripts/melee/melee_manifest.txt", "GAME"))
	{
		for (SourceKeyValues sub = kvManifest.GetFirstValue(); sub; sub = sub.GetNextValue())
		{
			sub.GetName(buffer, sizeof(buffer));
			if (strcmp(buffer, "file"))
				continue;
			
			sub.GetString(NULL_STRING, buffer, sizeof(buffer));
			if (!buffer[0] || !FileExists(buffer, true, "GAME"))
				continue;

			TrimSuffix(buffer, ".txt");
			TrimPrefix(buffer, "scripts/melee/");
			if (StrContains(g_sMeleeList, buffer) == -1)
				Format(g_sMeleeList, sizeof(g_sMeleeList), "%s;%s", buffer, g_sMeleeList);
		}
	}

	kvMission.SetString("meleeweapons", g_sMeleeList);
	kvManifest.deleteThis();
	return MRES_Ignored;
}

bool TrimSuffix(char[] str, const char[] suffix)
{
	int strLen = strlen(str);
	int suffixLen = strlen(suffix);

	if (suffixLen >= strLen) // What if there is only a suffix?
		return false;

	if (!strcmp(str[strLen-suffixLen], suffix))
	{
		str[strLen-suffixLen] = 0;
		return true;
	}
	return false;
}


bool TrimPrefix(char[] str, const char[] prefix)
{
	int strLen = strlen(str);
	int prefixLen = strlen(prefix);

	if (prefixLen >= strLen)
		return false;
	
	if (!strncmp(str, prefix, prefixLen))
	{
		strcopy(str, strLen, str[prefixLen]);
		return true;
	}
	return false;
}


Action Cmd_Spawn(int client, int args)
{
	if (!args)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <meleeName>", cmd);
		return Plugin_Handled;
	}

	if (client > 0 && IsClientInGame(client))
	{
		char sMelee[128];
		float fPos[3];
		GetCmdArg(1, sMelee, sizeof(sMelee));
		GetClientEyePosition(client, fPos);
		SpawnMelee(sMelee, fPos);
	}

	return Plugin_Handled;
}

Action Cmd_Dump(int client, int args)
{
	PrintToServer("--- g_sMeleeList ---");
	PrintToServer("%s", g_sMeleeList);

	// StringTable shall prevail.
	PrintToServer("--- StringTable ---");
	int table = FindStringTable("meleeweapons");
	if (table != INVALID_STRING_TABLE)
	{
		char sMelee[128];
		int num = GetStringTableNumStrings(table);
		for (int i = 0; i < num; i++ )
		{
			ReadStringTable(table, i, sMelee, sizeof(sMelee));
			PrintToServer("%s", sMelee);
		}
	}
	
	PrintToServer("--- MeleeDumpWeapons_f ---");
	SDKCall(g_hSDK_MeleeDump);

	return Plugin_Handled;
}

int SpawnMelee(const char[] name, const float origin[3], const float angles[3] = {0.0, ...})
{
	int entity = CreateEntityByName("weapon_melee");
	if (entity == -1)
		return -1;

	DispatchKeyValue(entity, "melee_script_name", name);
	DispatchKeyValueVector(entity, "origin", origin);
	DispatchKeyValueVector(entity, "angles", angles);
	DispatchSpawn(entity);
	return entity;
}

void Init()
{
	GameData hGameData = new GameData("l4d2_melee_spawn_control");
	char buffer[128];
	
	strcopy(buffer, sizeof(buffer), "CMeleeWeaponInfoStore::LoadScripts");
	g_Detour = DynamicDetour.FromConf(hGameData, buffer);
	if (g_Detour == null)
		SetFailState("Failed to create DynamicDetour: %s", buffer);
	if (!g_Detour.Enable(Hook_Pre, OnMeleeWeaponInfoStore_LoadScripts_Pre))
		SetFailState("Failed to enable DynamicDetour: %s", buffer);
	
	strcopy(buffer, sizeof(buffer), "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	g_MemPatch = MemoryPatch.CreateFromConf(hGameData, buffer);
	if (!g_MemPatch.Validate())
		SetFailState("Failed to validate patch: %s", buffer);
	if (!g_MemPatch.Enable())
		SetFailState("Failed to enable patch: %s", buffer);

	strcopy(buffer, sizeof(buffer), "CTerrorGameRules::GetMissionInfo");
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_GetMissionInfo = EndPrepSDKCall();
	if (g_hSDK_GetMissionInfo == null)
		SetFailState("Failed to create SDKCall: %s", buffer);
	
	// void MeleeDumpWeapons_f()
	strcopy(buffer, sizeof(buffer), "MeleeDumpWeapons_f");
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	g_hSDK_MeleeDump = EndPrepSDKCall();
	if (g_hSDK_MeleeDump == null)
		LogError("Failed to create SDKCall: %s", buffer);

	delete hGameData;
}

