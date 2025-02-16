#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2_weapon_attributes>

#define VERSION "0.2"

#define MAX_ATTRVALUE_LEN	15
#define MELEE	0
#define GUN		1

enum struct AttrInfo
{
	int type;
	Address offset;
	NumberType size;
	char name[MAX_ATTRNAME_LEN];
}

enum struct WepInfo
{
	int type;
	int id;
	Address ptr;
	char name[MAX_WEPNAME_LEN];
}

StringMap
	g_smWepNameToId[2],
	g_smAttrInfo[2];

Handle g_hSDKGetWeaponInfo[2];
Address g_pMeleeWeaponInfoStore;
KeyValues g_kvDefValue;

public Plugin myinfo =
{
	name = "L4D2 Weapon Attributes",
	author = "Jahze, A1m`, fork by fdxx",
	version = VERSION,
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2) 
		SetFailState("Plugin only supports L4D2");

	CreateNative("L4D2_SetWepAttrValue", Native_SetWepAttrValue);
	CreateNative("L4D2_GetWepAttrValue", Native_GetWepAttrValue);
	CreateNative("L4D2_ResetWepAttrValue", Native_ResetWepAttrValue);
	RegPluginLibrary("l4d2_weapon_attributes");
	return APLRes_Success;
}

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_weapon_attributes_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	RegAdminCmd("sm_weapon", Cmd_SetWepAttrValue, ADMFLAG_ROOT);
	RegConsoleCmd("sm_weapon_attributes", Cmd_GetWepAttrValue);
	RegAdminCmd("sm_weapon_attributes_reset", Cmd_ResetWepAttrValue, ADMFLAG_ROOT);
}

public void OnPluginEnd()
{
	ResetAllWepAttrValue(0, GUN);
	ResetAllWepAttrValue(0, MELEE);
}

public void OnMapStart()
{
	delete g_smWepNameToId[MELEE];
	g_smWepNameToId[MELEE] = new StringMap();

	char name[MAX_WEPNAME_LEN];
	int table = FindStringTable("meleeweapons");

	if (table == INVALID_STRING_TABLE)
	{
		for (int i = 0; i < sizeof(g_L4D2WA_sMeleeNames); i++)
		{
			CopyAndToLower(g_L4D2WA_sMeleeNames[i], name, sizeof(name));
			g_smWepNameToId[MELEE].SetValue(name, i);
		}
	}
	else
	{
		int num = GetStringTableNumStrings(table);
		for (int i = 0; i < num; i++ )
		{
			ReadStringTable(table, i, name, sizeof(name));
			CharToLowerCase(name, strlen(name));
			g_smWepNameToId[MELEE].SetValue(name, i);
		}
	}
}

Action Cmd_SetWepAttrValue(int client, int args)
{
	if (args != 3)
	{
		char sCmd[32];
		GetCmdArg(0, sCmd, sizeof(sCmd));
		ReplyToCommand(client, "[WEPATTR] Syntax: %s <name> <attr> <value>.", sCmd);
		return Plugin_Handled;
	}

	WepInfo wepInfo;
	GetCmdArg(1, wepInfo.name, sizeof(wepInfo.name));
	if (!GetWeaponInfo(wepInfo))
	{
		ReplyToCommand(client, "[WEPATTR] Failed to GetWeaponInfo: %s", wepInfo.name);
		return Plugin_Handled;
	}

	AttrInfo attrInfo;
	GetCmdArg(2, attrInfo.name, sizeof(attrInfo.name));
	CharToLowerCase(attrInfo.name, strlen(attrInfo.name));

	if (!g_smAttrInfo[wepInfo.type].GetArray(attrInfo.name, attrInfo, sizeof(attrInfo)))
	{
		ReplyToCommand(client, "[WEPATTR] Failed to GetAttrInfo: %s", attrInfo.name);
		return Plugin_Handled;
	}

	any setValue;
	if (attrInfo.type == VALUETYPE_FLOAT)
		setValue = GetCmdArgFloat(3);
	else
		setValue = GetCmdArgInt(3);

	any oldValue = SetWepAttrValue(wepInfo, attrInfo, setValue);
	PrintValueChanged(client, wepInfo, attrInfo, oldValue, setValue);
	return Plugin_Handled;
}

// native bool L4D2_SetWepAttrValue(const char[] weapon, const char[] attribute, any setValue, any &oldValue = 0);
any Native_SetWepAttrValue(Handle plugin, int numParams)
{	
	WepInfo wepInfo;
	GetNativeString(1, wepInfo.name, sizeof(wepInfo.name));
	if (!GetWeaponInfo(wepInfo))
	{	
		ThrowNativeError(SP_ERROR_PARAM, "[WEPATTR] Failed to GetWeaponInfo: %s", wepInfo.name);
		return false;
	}

	AttrInfo attrInfo;
	GetNativeString(2, attrInfo.name, sizeof(attrInfo.name));
	CharToLowerCase(attrInfo.name, strlen(attrInfo.name));
	if (!g_smAttrInfo[wepInfo.type].GetArray(attrInfo.name, attrInfo, sizeof(attrInfo)))
	{
		ThrowNativeError(SP_ERROR_PARAM, "[WEPATTR] Failed to GetAttrInfo: %s", attrInfo.name);
		return false;
	}

	any newValue = GetNativeCell(3);
	any oldValue = SetWepAttrValue(wepInfo, attrInfo, newValue);
	PrintValueChanged(0, wepInfo, attrInfo, oldValue, newValue);
	SetNativeCellRef(4, oldValue);
	return true;
}

bool SetWepAttrValue(const WepInfo wepInfo, const AttrInfo attrInfo, any setValue)
{
	any oldValue = LoadFromAddress(wepInfo.ptr + attrInfo.offset, attrInfo.size);
	SaveDefValue(wepInfo, attrInfo, oldValue);
	StoreToAddress(wepInfo.ptr + attrInfo.offset, setValue, attrInfo.size);
	return oldValue;
}

bool SaveDefValue(const WepInfo wepInfo, const AttrInfo attrInfo, any defValue)
{
	g_kvDefValue.Rewind();

	char buffer[256];
	FormatEx(buffer, sizeof(buffer), "%s/%s/%s/defvalue", (wepInfo.type == MELEE ? "melee":"gun"), wepInfo.name, attrInfo.name);
	if (g_kvDefValue.JumpToKey(buffer, false))
		return false;
	
	g_kvDefValue.JumpToKey(buffer, true);
	g_kvDefValue.SetNum(NULL_STRING, defValue);
	return true;
}

Action Cmd_GetWepAttrValue(int client, int args)
{
	if (args != 1 && args != 2)
	{
		char sCmd[32];
		GetCmdArg(0, sCmd, sizeof(sCmd));
		ReplyToCommand(client, "[WEPATTR] Syntax: %s <weapon> [attribute]", sCmd);
		return Plugin_Handled;
	}

	WepInfo wepInfo;
	AttrInfo attrInfo;

	GetCmdArg(1, wepInfo.name, sizeof(wepInfo.name));
	if (!GetWeaponInfo(wepInfo))
	{
		ReplyToCommand(client, "[WEPATTR] Failed to GetWeaponInfo: %s", wepInfo.name);
		return Plugin_Handled;
	}

	if (args == 2)
	{
		GetCmdArg(2, attrInfo.name, sizeof(attrInfo.name));
		CharToLowerCase(attrInfo.name, strlen(attrInfo.name));
		if (!g_smAttrInfo[wepInfo.type].GetArray(attrInfo.name, attrInfo, sizeof(attrInfo)))
		{
			ReplyToCommand(client, "[WEPATTR] Failed to GetAttrInfo: %s", attrInfo.name);
			return Plugin_Handled;
		}

		any curValue = LoadFromAddress(wepInfo.ptr + attrInfo.offset, attrInfo.size);
		PrintAttrValue(client, wepInfo, attrInfo, curValue);
		return Plugin_Handled;
	}

	StringMapSnapshot snapshot = g_smAttrInfo[wepInfo.type].Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, attrInfo.name, sizeof(attrInfo.name));
		g_smAttrInfo[wepInfo.type].GetArray(attrInfo.name, attrInfo, sizeof(attrInfo));
		any curValue = LoadFromAddress(wepInfo.ptr + attrInfo.offset, attrInfo.size);
		PrintAttrValue(client, wepInfo, attrInfo, curValue);
	}

	delete snapshot;
	return Plugin_Handled;
}

// native bool L4D2_GetWepAttrValue(const char[] weapon, const char[] attribute, any &curValue);
any Native_GetWepAttrValue(Handle plugin, int numParams)
{
	WepInfo wepInfo;
	GetNativeString(1, wepInfo.name, sizeof(wepInfo.name));
	if (!GetWeaponInfo(wepInfo))
	{	
		ThrowNativeError(SP_ERROR_PARAM, "[WEPATTR] Failed to GetWeaponInfo: %s", wepInfo.name);
		return false;
	}

	AttrInfo attrInfo;
	GetNativeString(2, attrInfo.name, sizeof(attrInfo.name));
	CharToLowerCase(attrInfo.name, strlen(attrInfo.name));
	if (!g_smAttrInfo[wepInfo.type].GetArray(attrInfo.name, attrInfo, sizeof(attrInfo)))
	{
		ThrowNativeError(SP_ERROR_PARAM, "[WEPATTR] Failed to GetAttrInfo: %s", attrInfo.name);
		return false;
	}

	any curValue = LoadFromAddress(wepInfo.ptr + attrInfo.offset, attrInfo.size);
	SetNativeCellRef(3, curValue);
	return true;
}


Action Cmd_ResetWepAttrValue(int client, int args)
{
	if (args != 1)
	{
		char sCmd[32];
		GetCmdArg(0, sCmd, sizeof(sCmd));
		ReplyToCommand(client, "Syntax: %s <weapon|@all>", sCmd);
		return Plugin_Handled;
	}

	char weapon[MAX_WEPNAME_LEN];
	GetCmdArg(1, weapon, sizeof(weapon));

	if (!strcmp(weapon, "@all"))
	{
		ResetAllWepAttrValue(client, GUN);
		ResetAllWepAttrValue(client, MELEE);
		return Plugin_Handled;
	}

	ResetWepAttrValue(client, weapon);
	return Plugin_Handled;
}

any Native_ResetWepAttrValue(Handle plugin, int numParams)
{
	char weapon[MAX_WEPNAME_LEN];
	GetNativeString(1, weapon, sizeof(weapon));
	return ResetWepAttrValue(0, weapon);
}


void ResetAllWepAttrValue(int client, int type)
{
	char weapon[MAX_WEPNAME_LEN];
	StringMapSnapshot snapshot = g_smWepNameToId[type].Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, weapon, sizeof(weapon));
		ResetWepAttrValue(client, weapon);
	}
	delete snapshot;
}

bool ResetWepAttrValue(int client, const char[] weapon)
{
	WepInfo wepInfo;
	strcopy(wepInfo.name, sizeof(wepInfo.name), weapon);
	if (!GetWeaponInfo(wepInfo))
		return false;

	g_kvDefValue.Rewind();

	char buffer[256];
	FormatEx(buffer, sizeof(buffer), "%s/%s", (wepInfo.type == MELEE ? "melee":"gun"), wepInfo.name);

	if (!g_kvDefValue.JumpToKey(buffer))
		return false;
	
	AttrInfo attrInfo;
	for (bool iter = g_kvDefValue.GotoFirstSubKey(); iter; iter = g_kvDefValue.GotoNextKey())
	{
		g_kvDefValue.GetSectionName(attrInfo.name, sizeof(attrInfo.name));
		CharToLowerCase(attrInfo.name, strlen(attrInfo.name));
		g_smAttrInfo[wepInfo.type].GetArray(attrInfo.name, attrInfo, sizeof(attrInfo));

		any defValue = g_kvDefValue.GetNum("defvalue");
		any curValue = LoadFromAddress(wepInfo.ptr + attrInfo.offset, attrInfo.size);

		if (curValue == defValue)
			continue;

		StoreToAddress(wepInfo.ptr + attrInfo.offset, defValue, attrInfo.size);
		PrintValueChanged(client, wepInfo, attrInfo, curValue, defValue);
	}

	return true;
}

void PrintValueChanged(int client, const WepInfo wepInfo, const AttrInfo attrInfo, any oldValue, any newValue)
{
	switch (attrInfo.type)
	{
		case VALUETYPE_BOOL:
			ReplyToCommand(client, "[WEPATTR] %s: %s %b -> %b", wepInfo.name, attrInfo.name, oldValue, newValue);
		case VALUETYPE_INT:
			ReplyToCommand(client, "[WEPATTR] %s: %s %i -> %i", wepInfo.name, attrInfo.name, oldValue, newValue);
		case VALUETYPE_FLOAT:
			ReplyToCommand(client, "[WEPATTR] %s: %s %.3f -> %.3f", wepInfo.name, attrInfo.name, oldValue, newValue);
	}
}

void PrintAttrValue(int client,  const WepInfo wepInfo, const AttrInfo attrInfo, any curValue)
{
	switch (attrInfo.type)
	{
		case VALUETYPE_BOOL:
			ReplyToCommand(client, "[WEPATTR] %s: %s %b", wepInfo.name, attrInfo.name, curValue);
		case VALUETYPE_INT:
			ReplyToCommand(client, "[WEPATTR] %s: %s %i", wepInfo.name, attrInfo.name, curValue);
		case VALUETYPE_FLOAT:
			ReplyToCommand(client, "[WEPATTR] %s: %s %.3f", wepInfo.name, attrInfo.name, curValue);
	}
}

bool GetWeaponInfo(WepInfo wepInfo)
{
	CharToLowerCase(wepInfo.name, strlen(wepInfo.name));
	if (g_smWepNameToId[MELEE].GetValue(wepInfo.name, wepInfo.id))
	{
		wepInfo.type = MELEE;
		wepInfo.ptr = SDKCall(g_hSDKGetWeaponInfo[MELEE], g_pMeleeWeaponInfoStore, wepInfo.id);
		return wepInfo.ptr != Address_Null;
	}

	if (strncmp(wepInfo.name, "weapon_", 7))
		Format(wepInfo.name, sizeof(wepInfo.name), "weapon_%s", wepInfo.name);

	if (g_smWepNameToId[GUN].GetValue(wepInfo.name, wepInfo.id))
	{
		wepInfo.type = GUN;
		wepInfo.ptr = SDKCall(g_hSDKGetWeaponInfo[GUN], wepInfo.id);
		return wepInfo.ptr != Address_Null;
	}

	return false;
}

void CharToLowerCase(char[] chr, int len)
{
	for (int i = 0; i < len; i++)
		chr[i] = CharToLower(chr[i]);
}

void CopyAndToLower(const char[] input, char[] output, int maxlen)
{
	strcopy(output, maxlen, input);
	for (int i = 0, len = strlen(output); i < len; i++)
		output[i] = CharToLower(output[i]);
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_weapon_attributes");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load %s.txt gamedata.", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "GetWeaponInfo");
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetWeaponInfo[GUN] = EndPrepSDKCall();
	if (g_hSDKGetWeaponInfo[GUN] == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "CMeleeWeaponInfoStore::GetMeleeWeaponInfo");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetWeaponInfo[MELEE] = EndPrepSDKCall();
	if (g_hSDKGetWeaponInfo[MELEE] == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "MeleeWeaponInfoStore");
	g_pMeleeWeaponInfoStore = hGameData.GetAddress(sBuffer);
	if (g_pMeleeWeaponInfoStore == Address_Null)
		SetFailState("Failed to get address: %s", sBuffer);

	for (int i = 0; i < 2; i++)
	{
		delete g_smWepNameToId[i];
		delete g_smAttrInfo[i];

		g_smWepNameToId[i] = new StringMap();
		g_smAttrInfo[i] = new StringMap();
	}

	for (int i = 0; i < MAX_WEPID; i++)
	{
		char name[MAX_WEPNAME_LEN];
		CopyAndToLower(g_L4D2WA_sWeaponNames[i], name, sizeof(name));
		g_smWepNameToId[GUN].SetValue(name, i);
	}

	AttrInfo attrInfo;
	int offset;

	for (int i = 0; i < sizeof(g_L4D2WA_sMeleeAttributes); i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "CMeleeWeaponInfo::%s", g_L4D2WA_sMeleeAttributes[i][ATTR_NAME]);
		offset = hGameData.GetOffset(sBuffer);
		if (offset == -1)
			SetFailState("Failed to GetOffset: %s", sBuffer);

		attrInfo.offset = view_as<Address>(offset);
		attrInfo.type = StringToInt(g_L4D2WA_sMeleeAttributes[i][ATTR_VALUETYPE]);
		attrInfo.size = attrInfo.type == VALUETYPE_BOOL ? NumberType_Int8 : NumberType_Int32;
		CopyAndToLower(g_L4D2WA_sMeleeAttributes[i][ATTR_NAME], attrInfo.name, sizeof(attrInfo.name));
		g_smAttrInfo[MELEE].SetArray(attrInfo.name, attrInfo, sizeof(attrInfo));
	}

	for (int i = 0; i < sizeof(g_L4D2WA_sWepAttributes); i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "CCSWeaponInfo::%s", g_L4D2WA_sWepAttributes[i][ATTR_NAME]);
		offset = hGameData.GetOffset(sBuffer);
		if (offset == -1)
			SetFailState("Failed to GetOffset: %s", sBuffer);

		attrInfo.offset = view_as<Address>(offset);
		attrInfo.type = StringToInt(g_L4D2WA_sWepAttributes[i][ATTR_VALUETYPE]);
		attrInfo.size = attrInfo.type == VALUETYPE_BOOL ? NumberType_Int8 : NumberType_Int32;
		CopyAndToLower(g_L4D2WA_sWepAttributes[i][ATTR_NAME], attrInfo.name, sizeof(attrInfo.name));
		g_smAttrInfo[GUN].SetArray(attrInfo.name, attrInfo, sizeof(attrInfo));
	}

	delete hGameData;

	delete g_kvDefValue;
	g_kvDefValue = new KeyValues("");
}

