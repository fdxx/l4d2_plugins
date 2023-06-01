#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sourcescramble>			// https://github.com/nosoop/SMExt-SourceScramble
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues

#define VERSION "0.1"
#define CFG_PATH "data/server_info.cfg"

enum struct ServerInfo
{
	char sHostName[128];
	char sGameDescription[128];
	char sModeDisplaytitle[128];

	void Reset()
	{
		this.sHostName[0] = 0;
		this.sGameDescription[0] = 0;
		this.sModeDisplaytitle[0] = 0;
	}
}

ServerInfo
	g_ServerInfo;

MemoryPatch
	g_mGameDescription;

SourceKeyValues
	g_kvGameMode;

ConVar
	hostname,
	mp_gamemode,
	g_cvSetHostName,
	g_cvDynamicName,
	g_cvGameDescription,
	g_cvModeDisplaytitle,
	g_cvMaxSpecial,
	g_cvSpawnTime;

public Plugin myinfo = 
{
	name = "L4D2 Server info",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_server_info_version", VERSION, "Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	hostname = FindConVar("hostname");
	mp_gamemode = FindConVar("mp_gamemode");
	g_cvSetHostName = CreateConVar("l4d2_server_info_hostname", "1", "Set host name.");
	g_cvDynamicName = CreateConVar("l4d2_server_info_dynamic_hostname", "1", "Add special infected configure to host name.");
	g_cvGameDescription = CreateConVar("l4d2_server_info_gamedescription", "1", "Set a custom game description.");
	g_cvModeDisplaytitle = CreateConVar("l4d2_server_info_modedisplaytitle", "1", "Set a custom mode displaytitle.");
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	if (g_cvSetHostName.BoolValue && g_cvDynamicName.BoolValue)
	{
		g_cvMaxSpecial = FindConVar("l4d2_si_spawn_control_max_specials");
		g_cvSpawnTime = FindConVar("l4d2_si_spawn_control_spawn_time");

		if (!g_cvMaxSpecial || !g_cvSpawnTime)
			SetFailState("l4d2_si_spawn_control plugin not loaded?");
	}

	SetServerInfo();

	mp_gamemode.AddChangeHook(OnConVarChanged);
	g_cvSetHostName.AddChangeHook(OnConVarChanged);
	g_cvDynamicName.AddChangeHook(OnConVarChanged);
	g_cvGameDescription.AddChangeHook(OnConVarChanged);
	g_cvModeDisplaytitle.AddChangeHook(OnConVarChanged);

	if (g_cvSetHostName.BoolValue && g_cvDynamicName.BoolValue)
	{
		g_cvMaxSpecial.AddChangeHook(OnSpecialsChanged);
		g_cvSpawnTime.AddChangeHook(OnSpecialsChanged);
	}
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetServerInfo();
}

void OnSpecialsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetHostName();
}

void SetServerInfo()
{
	// ------- Load config -------
	char sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), CFG_PATH);

	KeyValues kv = new KeyValues("");
	if (!kv.ImportFromFile(sBuffer))
		SetFailState("Failed to load %s", sBuffer);

	g_ServerInfo.Reset();
	FindConVar("hostport").GetString(sBuffer, sizeof(sBuffer)); // Get config by port

	if (kv.JumpToKey(sBuffer))
	{
		kv.GetString("hostname", g_ServerInfo.sHostName, sizeof(g_ServerInfo.sHostName));
		kv.GetString("game_description", g_ServerInfo.sGameDescription, sizeof(g_ServerInfo.sGameDescription));
		kv.GetString("mode_displaytitle", g_ServerInfo.sModeDisplaytitle, sizeof(g_ServerInfo.sModeDisplaytitle));
	}


	// ------- Set host name -------
	if (g_cvSetHostName.BoolValue && g_ServerInfo.sHostName[0])
		SetHostName();


	// ------- Set game description -------
	strcopy(sBuffer, sizeof(sBuffer), "l4d2_server_info");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", sBuffer);

	delete g_mGameDescription;
	if (g_cvGameDescription.BoolValue && g_ServerInfo.sGameDescription[0])
	{
		strcopy(sBuffer, sizeof(sBuffer), "GetGameDescription::OpcodeBytes");
		int iOffset = hGameData.GetOffset(sBuffer);
		if (iOffset == -1)
			SetFailState("Failed to get offset: %s", sBuffer);

		strcopy(sBuffer, sizeof(sBuffer), "GetGameDescription");
		g_mGameDescription = MemoryPatch.CreateFromConf(hGameData, sBuffer);
		if (!g_mGameDescription.Validate())
			SetFailState("Failed to validate patch: %s", sBuffer);
		if (!g_mGameDescription.Enable())
			SetFailState("Failed to enable patch: %s", sBuffer);

		StoreToAddress(g_mGameDescription.Address + view_as<Address>(iOffset), GetAddressOfString(g_ServerInfo.sGameDescription), NumberType_Int32);
	}


	// ------- Set mode displaytitle -------
	if (g_kvGameMode)
		g_kvGameMode.SetInt("addon", 0);
	
	if (g_cvModeDisplaytitle.BoolValue && g_ServerInfo.sModeDisplaytitle[0])
	{
		strcopy(sBuffer, sizeof(sBuffer), "g_pMatchExtL4D");
		Address pMatchExtL4D = hGameData.GetAddress(sBuffer);
		if (pMatchExtL4D == Address_Null)
			SetFailState("Failed to get GetAddress: %s", sBuffer);

		strcopy(sBuffer, sizeof(sBuffer), "CMatchExtL4D::GetGameModeInfo");
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, sBuffer);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		Handle hSDK_GetGameModeInfo = EndPrepSDKCall();
		if (hSDK_GetGameModeInfo == null)
			SetFailState("Failed to create SDKCall: %s", sBuffer);

		mp_gamemode.GetString(sBuffer, sizeof(sBuffer));
		g_kvGameMode = SDKCall(hSDK_GetGameModeInfo, pMatchExtL4D, sBuffer);
		if (!g_kvGameMode)
			ThrowError("Failed to GetGameModeInfo: %s", sBuffer);

		g_kvGameMode.SetInt("addon", 1);
		g_kvGameMode.SetString("DisplayTitle", g_ServerInfo.sModeDisplaytitle);

		delete hSDK_GetGameModeInfo;
	}

	delete kv;
	delete hGameData;
}

void SetHostName()
{
	char sName[128];

	if (g_cvDynamicName.BoolValue)
		FormatEx(sName, sizeof(sName), "%s[%i特%.0f秒]", g_ServerInfo.sHostName, g_cvMaxSpecial.IntValue, g_cvSpawnTime.FloatValue);
	else
		FormatEx(sName, sizeof(sName), "%s", g_ServerInfo.sHostName);

	hostname.SetString(sName);
}
