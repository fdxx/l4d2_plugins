#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>
#include <sourcescramble>			// https://github.com/nosoop/SMExt-SourceScramble
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues

#define VERSION "0.1"

#define RMFLAG_NO_MODE_CHANGE			1
#define RMFLAG_NO_DIFFICULTY_CHANGE		2
#define RMFLAG_FORCE_ACCESS_PUBLIC		4	// private, friends -> public
#define RMFLAG_FORCE_OFFICIAL_MAP		8	// unofficial map -> official map

#define UNRESERVE_ALWAYS	1
#define UNRESERVE_DYNAMIC	2

ConVar
	mp_gamemode,
	z_difficulty,
	sv_allow_lobby_connect_only,
	g_cvUnreserveType,
	g_cvReserveModifyFlags;

char
	g_sGameMode[64],
	g_sDifficulty[64],
	g_sReservationCookie[20];

MemoryPatch
	g_mBlockReserve;

int
	g_iUnreserveType,
	g_iReserveModifyFlags;

Address
	g_pMatchExtL4D;

Handle
	g_hSDKGetGameModeInfo;

public Plugin myinfo = 
{
	name = "L4D2 Lobby match manager",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	Init();

	mp_gamemode = FindConVar("mp_gamemode");
	z_difficulty = FindConVar("z_difficulty");
	sv_allow_lobby_connect_only = FindConVar("sv_allow_lobby_connect_only");

	CreateConVar("l4d2_lobby_match_manager_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvUnreserveType =			CreateConVar("l4d2_lmm_unreserve_type",				"2",	"-1=Default, 1=Always unreserve, \n2=Dynamic unreserve (Allow reservation. Unreserve when the players is greater than the lobby slots, and recover when less than).");
	g_cvReserveModifyFlags =	CreateConVar("l4d2_lmm_reservation_modify_flags",	"15",	"Modify the lobby settings applied by the client to the server.\nSee RMFLAG_* (need cvar l4d2_lmm_unreserve_type != 1).");
	
	OnConVarChanged(null, "", "");
	
	mp_gamemode.AddChangeHook(OnConVarChanged);
	z_difficulty.AddChangeHook(OnConVarChanged);
	g_cvUnreserveType.AddChangeHook(OnConVarChanged);
	g_cvReserveModifyFlags.AddChangeHook(OnConVarChanged);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	RegAdminCmd("sm_lobby_status", Cmd_Status, ADMFLAG_ROOT);
	RegAdminCmd("sm_lobby_set", Cmd_Set, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d2_lobby_match_manager");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	mp_gamemode.GetString(g_sGameMode, sizeof(g_sGameMode));
	z_difficulty.GetString(g_sDifficulty, sizeof(g_sDifficulty));
	g_iUnreserveType = g_cvUnreserveType.IntValue;
	g_iReserveModifyFlags = g_cvReserveModifyFlags.IntValue;
	
	g_mBlockReserve.Disable();
	if (g_iUnreserveType == UNRESERVE_ALWAYS)
	{
		if (!g_mBlockReserve.Enable())
			SetFailState("Failed to verify patch.");
	}
}

public void OnConfigsExecuted()
{
	if (g_iUnreserveType == UNRESERVE_ALWAYS)
	{
		sv_allow_lobby_connect_only.IntValue = 0;
		L4D_LobbyUnreserve();
	}
}

MRESReturn OnApplyGameSettingsPre(Address pThis, DHookParam hParams)
{
	if (g_iUnreserveType == UNRESERVE_ALWAYS || !g_iReserveModifyFlags || hParams.IsNull(1))
		return MRES_Ignored;

	char sBuffer[128];
	SourceKeyValues kv = view_as<SourceKeyValues>(hParams.GetAddress(1));
	
	kv.GetName(sBuffer, sizeof(sBuffer));
	if (strcmp(sBuffer, "left4dead2", false)) // Exclude ExecGameTypeCfg
		return MRES_Ignored;

	if (g_iReserveModifyFlags & RMFLAG_NO_MODE_CHANGE)
		kv.SetString("Game/mode", g_sGameMode);

	if (g_iReserveModifyFlags & RMFLAG_NO_DIFFICULTY_CHANGE)
		kv.SetString("Game/difficulty", g_sDifficulty);

	if (g_iReserveModifyFlags & RMFLAG_FORCE_ACCESS_PUBLIC)
		kv.SetString("System/access", "public");

	if (g_iReserveModifyFlags & RMFLAG_FORCE_OFFICIAL_MAP)
	{
		kv.GetString("Game/campaign", sBuffer, sizeof(sBuffer));
		if (strncmp(sBuffer, "L4D2C", 5, false))
		{
			kv.SetString("Game/campaign", "L4D2C2");
			kv.SetInt("Game/chapter", 1);
		}
	}

	return MRES_Ignored;
}

public void OnClientConnected(int client)
{
	if (g_iUnreserveType != UNRESERVE_DYNAMIC || IsFakeClient(client))
		return;

	if (IsServerLobbyFull())
	{
		if (L4D_LobbyIsReserved())
			L4D_GetLobbyReservation(g_sReservationCookie, sizeof(g_sReservationCookie));
		sv_allow_lobby_connect_only.IntValue = 0;
		L4D_LobbyUnreserve();
	}
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iUnreserveType != UNRESERVE_DYNAMIC)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsFakeClient(client))
	{
		/*
		client == 0:
		reason: Server shutting down, networkid: BOT
		reason: No Steam logon,	networkid: STEAM_1:0:XXX
		*/
		char sNetworkid[4];
		event.GetString("networkid", sNetworkid, sizeof(sNetworkid));
		if (!strcmp(sNetworkid, "BOT", false)) 
			return;

		if (!L4D_LobbyIsReserved() && !IsServerLobbyFull(client) && g_sReservationCookie[0])
		{
			L4D_SetLobbyReservation(g_sReservationCookie);
			sv_allow_lobby_connect_only.IntValue = 1;
		}
	}
}

bool IsServerLobbyFull(int exclude = 0)
{
	int iPlayers;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != exclude && IsClientConnected(i) && !IsFakeClient(i))
			iPlayers++;
	}
	return iPlayers >= GetMaxLobbySlots(g_sGameMode);
}

int GetMaxLobbySlots(const char[] mode)
{
	SourceKeyValues kv = SDKCall(g_hSDKGetGameModeInfo, g_pMatchExtL4D, mode);
	if (kv)
		return kv.GetInt("maxplayers", 4);
	return 4;
}

Action Cmd_Status(int client, int args)
{
	int iPlayers, iMaxLobbySlots;
	bool bReserved;
	char sCookie[20];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			iPlayers++;
	}

	bReserved = L4D_LobbyIsReserved();
	if (bReserved) L4D_GetLobbyReservation(sCookie, sizeof(sCookie));
	iMaxLobbySlots = GetMaxLobbySlots(g_sGameMode);
	
	ReplyToCommand(client, "iPlayers = %i, iMaxLobbySlots = %i, sv_allow_lobby_connect_only = %i, sCookie = %s", iPlayers, iMaxLobbySlots, sv_allow_lobby_connect_only.IntValue, bReserved?sCookie:"Unreserve");

	return Plugin_Handled;
}

Action Cmd_Set(int client, int args)
{
	char sCookie[20];
	GetCmdArg(1, sCookie, sizeof(sCookie));
	
	if (StringToInt(sCookie) == 0)
		L4D_LobbyUnreserve();
	else
		L4D_SetLobbyReservation(sCookie);

	if (args == 2)
		sv_allow_lobby_connect_only.BoolValue = GetCmdArgInt(2) > 0;
	
	Cmd_Status(client, 0);
	return Plugin_Handled;
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_lobby_match_manager");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "CServerGameDLL::ApplyGameSettings");
	DynamicDetour detour = DynamicDetour.FromConf(hGameData, sBuffer);
	if (detour == null)
		SetFailState("Failed to create DynamicDetour: %s", sBuffer);
	if (!detour.Enable(Hook_Pre, OnApplyGameSettingsPre))
		SetFailState("Failed to detour pre: %s", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "CBaseServer::ReplyReservationRequest");
	g_mBlockReserve = MemoryPatch.CreateFromConf(hGameData, sBuffer);
	if (!g_mBlockReserve.Validate())
		SetFailState("Failed to verify patch: %s", sBuffer);
	
	strcopy(sBuffer, sizeof(sBuffer), "g_pMatchExtL4D");
	g_pMatchExtL4D = hGameData.GetAddress(sBuffer);
	if (g_pMatchExtL4D == Address_Null)
		SetFailState("Failed to get address: %s", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "CMatchExtL4D::GetGameModeInfo");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, sBuffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetGameModeInfo = EndPrepSDKCall();
	if (g_hSDKGetGameModeInfo == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	delete hGameData;
}
