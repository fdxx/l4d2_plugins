#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <multicolors>		
#include <sourcescramble>	// https://github.com/nosoop/SMExt-SourceScramble
#include <left4dhooks>

#define VERSION "1.5"

#define STATE_GHOST 8
#define EF_NODRAW	32
#define FSOLID_NOT_SOLID 4

#define TEAM_NONE	0
#define TEAM_SPEC	1
#define TEAM_SUR	2
#define TEAM_INF	3

#define COLOR_RED		{255, 0, 0}
#define COLOR_GREEN		{0, 255, 0}
#define COLOR_WHITE		{255, 255, 255}
#define COLOR_PURPLE	{255, 0, 255}

#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6
#define	TANK	8
#define	MAX_CLASS	9

ConVar
	g_cvMaxSpecialLimit,
	g_cvSpecialLimit[MAX_CLASS],
	g_cvSpawnTime,
	g_cvAdminImmunity,
	g_cvBlockOtherRespawn,
	mp_gamemode,
	z_scrimmage_sphere,
	z_max_player_zombies,
	sb_all_bot_game,
	allow_all_bot_survivor_team,
	survivor_max_incapacitated_count;

int
	g_iMaxSpecialLimit,
	g_iSpecialLimit[MAX_CLASS],
	g_iSpawnCountDown[MAXPLAYERS+1],
	g_iSpawnTime,
	g_iGlowEntRef[MAXPLAYERS+1] = {-1, ...},
	g_iSurMaxIncapCount;

bool
	g_bLeftSafeArea,
	g_bAdminImmunity,
	g_bBlockOtherRespawn;

Handle
	g_hSpawnTimer[MAXPLAYERS+1],
	g_hSDK_SetPreSpawnClass,
	g_hSDK_IsGenericCoopMode,
	g_hSDK_StateTransition,
	g_hSDK_ReplaceWithBot,
	g_hSDK_TakeOverZombieBot;

float
	g_fBugExploitTime[MAXPLAYERS+1][2];

ArrayList
	g_aJoinTankList;

char
	g_sMode[128];

public Plugin myinfo = 
{
	name = "L4D2 Control Zombies",
	author = "sorallll, fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_control_zombies_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_cvMaxSpecialLimit =		CreateConVar("l4d2_cz_max_special_limit",	"1", "Max SI limit");
	g_cvSpecialLimit[SMOKER] =	CreateConVar("l4d2_cz_smoker_limit",		"0", "Smoker limit.");
	g_cvSpecialLimit[BOOMER] =	CreateConVar("l4d2_cz_boomer_limit",		"0", "Boomer limit.");
	g_cvSpecialLimit[HUNTER] =	CreateConVar("l4d2_cz_hunter_limit",		"1", "Hunter limit.");
	g_cvSpecialLimit[SPITTER] =	CreateConVar("l4d2_cz_spitter_limit",		"0", "Spitter limit.");
	g_cvSpecialLimit[JOCKEY] =	CreateConVar("l4d2_cz_jockey_limit",		"0", "Jockey limit.");
	g_cvSpecialLimit[CHARGER] =	CreateConVar("l4d2_cz_charger_limit",		"0", "Charger limit.");
	g_cvSpecialLimit[TANK] =	CreateConVar("l4d2_cz_tank_limit",			"1", "Tank limit.");

	g_cvSpawnTime = CreateConVar("l4d2_cz_spawn_time", "15", "Spawn time");
	g_cvAdminImmunity = CreateConVar("l4d2_cz_admin_immunity", "1", "Admin join infected team without limit.");
	g_cvBlockOtherRespawn = CreateConVar("l4d2_cz_block_other_pz_respawn", "1", "Block infected player spawned by z_spawn_old command.");

	mp_gamemode = FindConVar("mp_gamemode");
	z_scrimmage_sphere = FindConVar("z_scrimmage_sphere");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	sb_all_bot_game = FindConVar("sb_all_bot_game");
	allow_all_bot_survivor_team = FindConVar("allow_all_bot_survivor_team");
	survivor_max_incapacitated_count = FindConVar("survivor_max_incapacitated_count");

	OnConVarChanged(null, "", "");

	for (int i = 1; i < MAX_CLASS; i++)
	{
		if (g_cvSpecialLimit[i] != null)
			g_cvSpecialLimit[i].AddChangeHook(OnConVarChanged);
	}

	g_cvMaxSpecialLimit.AddChangeHook(OnConVarChanged);
	g_cvSpawnTime.AddChangeHook(OnConVarChanged);
	g_cvAdminImmunity.AddChangeHook(OnConVarChanged);
	g_cvBlockOtherRespawn.AddChangeHook(OnConVarChanged);
	survivor_max_incapacitated_count.AddChangeHook(OnConVarChanged);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("bot_player_replace", Event_PlayerReplacedBot);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_inf", Cmd_JoinTeam3);
	RegConsoleCmd("sm_team3", Cmd_JoinTeam3);
	
	RegConsoleCmd("sm_taketank", Cmd_JoinTank);
	RegConsoleCmd("sm_tk", Cmd_JoinTank);

	CreateTimer(0.2, SurGlowCheck_Timer, _, TIMER_REPEAT);

	for (int i = 0; i <= MaxClients; i++)
		RemoveSurGlow(i);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 1; i < MAX_CLASS; i++)
	{
		if (g_cvSpecialLimit[i] != null)
			g_iSpecialLimit[i] = g_cvSpecialLimit[i].IntValue;
	}

	g_iMaxSpecialLimit = g_cvMaxSpecialLimit.IntValue;
	g_iSpawnTime = g_cvSpawnTime.IntValue;
	g_bAdminImmunity = g_cvAdminImmunity.BoolValue;
	g_bBlockOtherRespawn = g_cvBlockOtherRespawn.BoolValue;
	g_iSurMaxIncapCount = survivor_max_incapacitated_count.IntValue;
}

public void OnConfigsExecuted()
{
	if (!SDKCall(g_hSDK_IsGenericCoopMode))
		SetFailState("Unsupported game mode.");

	mp_gamemode.GetString(g_sMode, sizeof(g_sMode));
	
	z_scrimmage_sphere.SetBounds(ConVarBound_Lower, true, 0.0);
	z_scrimmage_sphere.SetBounds(ConVarBound_Upper, true, 0.0);
	z_scrimmage_sphere.IntValue = 0;
	
	z_max_player_zombies.SetBounds(ConVarBound_Lower, true, 32.0);
	z_max_player_zombies.SetBounds(ConVarBound_Upper, true, 32.0);
	z_max_player_zombies.IntValue = 32;

	sb_all_bot_game.IntValue = 1;
	allow_all_bot_survivor_team.IntValue = 1;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
	CreateTimer(2.0, RemoveInfectedClips_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

public void OnClientDisconnect(int client)
{
	if (!IsFakeClient(client))
	{
		delete g_hSpawnTimer[client];
		RemoveJoinTank(GetClientUserId(client));
	}
	RemoveSurGlow(client);
}

void Reset()
{
	g_bLeftSafeArea = false;
	g_aJoinTankList.Clear();

	for (int i = 1; i <= MaxClients; i++)
	{
		delete g_hSpawnTimer[i];
	}
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	g_bLeftSafeArea = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INF && !IsPlayerAlive(i) && !IsFakeClient(i))
		{
			delete g_hSpawnTimer[i];
			g_iSpawnCountDown[i] = 0;
			g_hSpawnTimer[i] = CreateTimer(1.0, SpawnSI_Timer, GetClientUserId(i), TIMER_REPEAT);
		}
	}
}

Action SpawnSI_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (g_bLeftSafeArea && client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_INF && !IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if (g_iSpawnCountDown[client] <= 0)
		{
			if (g_iSpawnCountDown[client] <= -7)
			{
				CPrintToChat(client, "{lightgreen}重生失败, 请尝试重新切换团队后再试试.");
				g_hSpawnTimer[client] = null;
				return Plugin_Stop;
			}

			int iClass = GetSpawnClass();
			if (1 <= iClass <= 6)
			{
				SDKCall(g_hSDK_SetPreSpawnClass, client, iClass);
				SDKCall(g_hSDK_StateTransition, client, STATE_GHOST);

				g_hSpawnTimer[client] = null;
				return Plugin_Stop;
			}
		}

		PrintHintText(client, "%i 秒后重生", g_iSpawnCountDown[client]--);
		return Plugin_Continue;
	}

	g_hSpawnTimer[client] = null;
	return Plugin_Stop;
}

Action Cmd_JoinTeam3(int client, int args)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) == TEAM_INF)
		return Plugin_Handled;

	if (g_bAdminImmunity && CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
	{
		ChangeClientTeam(client, TEAM_INF);
		return Plugin_Handled;
	}

	if (GetZombiePlayerTotal() < g_iMaxSpecialLimit)
		ChangeClientTeam(client, TEAM_INF);
	else
		PrintHintText(client, "已达到感染玩家最大限制");

	return Plugin_Handled;
}

Action Cmd_JoinTank(int client, int args)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INF)
		return Plugin_Handled;

	int userid = GetClientUserId(client);
	
	if (RemoveJoinTank(userid))
		CPrintToChat(client, "{lightgreen}你已退出接管Tank列表.");
	else
	{
		g_aJoinTankList.Push(userid);
		CPrintToChat(client, "{lightgreen}你已加入接管Tank列表, 再次输入退出.");
	}

	return Plugin_Handled;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_INF)
		mp_gamemode.ReplicateToClient(client, "versus");
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	int oldTeam = event.GetInt("oldteam");
	int newTeam = event.GetInt("team");

	if (client <= 0)
		return;

	switch (oldTeam)
	{
		case TEAM_INF:
		{
			if (!IsFakeClient(client))
			{
				delete g_hSpawnTimer[client];
				RemoveJoinTank(userid);
				mp_gamemode.ReplicateToClient(client, g_sMode);

				// Prevent Residual Survivor glow
				for (int i = 0; i <= MaxClients; i++)
					RemoveSurGlow(i);
				SurGlowCheck_Timer(null);
			}
		}
	}

	switch (newTeam)
	{
		case TEAM_INF:
		{
			if (!IsFakeClient(client))
			{
				mp_gamemode.ReplicateToClient(client, "versus");
				CPrintToChat(client, "{blue}[提示] {olive}特感玩家输入 !taketank 或 !tk 可加入接管Tank列表(需在克出现之前提前输入).");

				if (!g_bLeftSafeArea)
					return;

				delete g_hSpawnTimer[client];
				g_iSpawnCountDown[client] = g_iSpawnTime;
				g_hSpawnTimer[client] = CreateTimer(1.0, SpawnSI_Timer, userid, TIMER_REPEAT);
			}
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client > 0 && IsClientInGame(client))
	{
		switch (GetClientTeam(client))
		{
			case TEAM_SUR:
				RemoveSurGlow(client);

			case TEAM_INF:
			{
				if (IsFakeClient(client) || !g_bLeftSafeArea)
					return;

				delete g_hSpawnTimer[client];
				g_iSpawnCountDown[client] = g_iSpawnTime;
				g_hSpawnTimer[client] = CreateTimer(1.0, SpawnSI_Timer, userid, TIMER_REPEAT);
			}
		}
	}
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
	if (client > 0)
		CreateTimer(0.1, JoinTankCheck_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

Action JoinTankCheck_Timer(Handle timer, int userid)
{
	if (GetTankPlayerTotal() >= g_iSpecialLimit[TANK])
		return Plugin_Continue;

	int tank = GetClientOfUserId(userid);
	if (tank > 0 && IsClientInGame(tank) && IsFakeClient(tank) && GetClientTeam(tank) == TEAM_INF && GetZombieClass(tank) == TANK && IsPlayerAlive(tank))
	{
		int client = GetJoinTankClient();
		if (client <= 0)
			return Plugin_Continue;
		
		if (IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isGhost"))
			SDKCall(g_hSDK_ReplaceWithBot, client, false);

		SDKCall(g_hSDK_TakeOverZombieBot, client, tank);
	}

	return Plugin_Continue;
}

void Event_PlayerReplacedBot(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));

	if (player > 0 && IsClientInGame(player) && GetClientTeam(player) == TEAM_INF && GetZombieClass(player) == TANK && IsPlayerAlive(player))
		CPrintToChatAll("{blue}[提示] {olive}Tank {default}已被 {olive}%N {default}接管.", player);
}

Action SurGlowCheck_Timer(Handle timer)
{
	int iGlowEntity;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SUR && IsPlayerAlive(i))
		{
			iGlowEntity = EntRefToEntIndex(g_iGlowEntRef[i]);
			if (iGlowEntity <= MaxClients || !IsValidEntity(iGlowEntity))
				iGlowEntity = CreateSurGlow(i);

			SetSurGlowColor(i, iGlowEntity);
			continue;
		}
		RemoveSurGlow(i);
	}

	return Plugin_Continue;
}

int CreateSurGlow(int client)
{
	int entity = CreateEntityByName("prop_dynamic_ornament");
	if (entity <= MaxClients)
	{
		LogError("Failed to create glow entity.");
		return -1;
	}
	
	g_iGlowEntRef[client] = EntIndexToEntRef(entity);

	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	DispatchKeyValue(entity, "model", sModel);
	DispatchSpawn(entity);

	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID);
	SetEntProp(entity, Prop_Data, "m_iEFlags", 0);
	SetEntProp(entity, Prop_Data, "m_fEffects", EF_NODRAW);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	AcceptEntityInput(entity, "DisableCollision");

	// Prevents the face looking distorted.
	SetEntityRenderMode(entity, RENDER_WORLDGLOW);
	SetEntityRenderColor(entity, .a=0);

	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 20000);
	SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 1);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetAttached", client);

	SDKUnhook(entity, SDKHook_SetTransmit, OnSetTransmit);
	SDKHook(entity, SDKHook_SetTransmit, OnSetTransmit);

	return entity;
}

Action OnSetTransmit(int entity, int client)
{
	if (!IsFakeClient(client) && GetClientTeam(client) == TEAM_INF)
		return Plugin_Continue;
	return Plugin_Handled;
}

void RemoveSurGlow(int client)
{
	int entity = EntRefToEntIndex(g_iGlowEntRef[client]);
	if (entity > MaxClients && IsValidEntity(entity))
	{
		SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
		RemoveEntity(entity);
	}
	g_iGlowEntRef[client] = -1;
}

void SetSurGlowColor(int client, int entity)
{
	int color[3];
	GetSurGlowColor(client, color);
	int hexColor = color[0] | (color[1] << 8) | (color[2] << 16);
	
	if (GetEntProp(entity, Prop_Send, "m_glowColorOverride") != hexColor)
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", hexColor);
}

void GetSurGlowColor(int client, int color[3])
{
	if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurMaxIncapCount)
	{
		color = COLOR_WHITE;
		return;
	}

	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		color = COLOR_RED;
		return;
	}

	if (GetEntPropFloat(client, Prop_Send, "m_itTimer", 1) > GetGameTime())
	{
		color = COLOR_PURPLE;
		return;
	}

	color = COLOR_GREEN;
}

Action RemoveInfectedClips_Timer(Handle timer)
{
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "func_playerinfected_clip")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
		
	entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "func_playerghostinfected_clip")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);

	return Plugin_Continue;
}

int GetSpawnClass()
{
	int iClass, iSpecialCount[7];
	ArrayList array = new ArrayList();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INF && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			iClass = GetZombieClass(i);
			if (1 <= iClass <= 6)
			{
				iSpecialCount[iClass]++;
			}
		}
	}

	for (int i = 1; i <= 6; i++)
	{
		if (iSpecialCount[i] < g_iSpecialLimit[i])
		{
			array.Push(i);
		}
	}

	iClass = -1;

	if (array.Length > 0)
	{
		iClass = array.Get(GetRandomIntEx(0, array.Length - 1));
	}
	
	delete array;
	return iClass;
}

int GetJoinTankClient()
{
	ArrayList array = new ArrayList();
	int client;

	for (int i = 0; i < g_aJoinTankList.Length; i++)
	{
		client = GetClientOfUserId(g_aJoinTankList.Get(i));
		if (IsValidSI(client) && !IsFakeClient(client))
		{
			if (IsPlayerAlive(client) && GetZombieClass(client) == TANK)
				continue;

			array.Push(client);
		}
	}

	client = -1;

	if (array.Length > 0)
	{
		client = array.Get(GetRandomIntEx(0, array.Length - 1));
	}
	
	delete array;
	return client;
}

bool RemoveJoinTank(int userid)
{
	int index = g_aJoinTankList.FindValue(userid);
	if (index != -1)
	{
		g_aJoinTankList.Erase(index);
		return true;
	}
	return false;
}

int GetTankPlayerTotal()
{
	int iCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INF && IsPlayerAlive(i) && !IsFakeClient(i) && GetZombieClass(i) == TANK)
		{
			iCount++;
		}
	}

	return iCount;
}

int GetZombiePlayerTotal()
{
	int iCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INF && !IsFakeClient(i))
		{
			iCount++;
		}
	}
	
	return iCount;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool IsValidSI(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_INF)
		{
			return true;
		}
	}
	return false;
}

int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

// void CTerrorPlayer::MaterializeFromGhost(void)
MRESReturn OnMaterializeFromGhostPost(int client)
{
	if (!IsFakeClient(client))
		g_fBugExploitTime[client][0] = GetEngineTime() + 1.5;
	return MRES_Ignored;
}

// void CTerrorPlayer::PlayerZombieAbortControl(void)
MRESReturn OnPlayerZombieAbortControlPre(int client)
{
	if (!IsFakeClient(client) && g_fBugExploitTime[client][0] > GetEngineTime())
		return MRES_Supercede;
	return MRES_Ignored;
}

MRESReturn OnPlayerZombieAbortControlPost(int client)
{
	if (!IsFakeClient(client))
		g_fBugExploitTime[client][1] = GetEngineTime() + 1.5;
	return MRES_Ignored;
}

MRESReturn OnMaterializeFromGhostPre(int client)
{
	if (!IsFakeClient(client) && g_fBugExploitTime[client][1] > GetEngineTime())
		return MRES_Supercede;
	return MRES_Ignored;
}

// bool ForEachTerrorPlayer<SpawnablePZScan>(SpawnablePZScan &)
MRESReturn OnSpawnPlayerZombieScanPre(DHookReturn hReturn, DHookParam hParams)
{
	if (g_bBlockOtherRespawn)
	{
		hReturn.Value = true; // true == not find
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

// void CTerrorPlayer::OnEnterGhostState(void)
MRESReturn OnEnterGhostStatePre(int client)
{
	if (!g_bLeftSafeArea)
		return MRES_Supercede;
	return MRES_Ignored;
}

void SetupDetour(GameData hGameData, DHookCallback CallbackPre, DHookCallback CallbackPost, const char[] name, DynamicDetour &detour = null)
{
	detour = DynamicDetour.FromConf(hGameData, name);
	if (detour == null)
		SetFailState("Failed to create DynamicDetour: %s", name);

	if (CallbackPre != INVALID_FUNCTION && !detour.Enable(Hook_Pre, CallbackPre)) 
		SetFailState("Failed to detour pre: %s", name);

	if (CallbackPost != INVALID_FUNCTION && !detour.Enable(Hook_Post, CallbackPost)) 
		SetFailState("Failed to detour post: %s", name);
}

void SetupPatch(GameData hGameData, const char[] name, MemoryPatch &patch = null)
{
	patch = MemoryPatch.CreateFromConf(hGameData, name);
	if (!patch.Validate())
		SetFailState("Failed to validate patch: %s", name);
	if (!patch.Enable())
		SetFailState("Failed to enable patch: %s", name);
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_control_zombies");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", sBuffer);

	SetupDetour(hGameData, OnPlayerZombieAbortControlPre, OnPlayerZombieAbortControlPost, "CTerrorPlayer::PlayerZombieAbortControl");
	SetupDetour(hGameData, OnMaterializeFromGhostPre, OnMaterializeFromGhostPost, "CTerrorPlayer::MaterializeFromGhost");
	SetupDetour(hGameData, OnEnterGhostStatePre, INVALID_FUNCTION, "CTerrorPlayer::OnEnterGhostState");

	if (hGameData.GetOffset("os") == 1) // windows
	{
		strcopy(sBuffer, sizeof(sBuffer), "ForEachTerrorPlayer<SpawnablePZScan>");
		Address addr = hGameData.GetAddress(sBuffer);
		if (addr == Address_Null)
			SetFailState("Failed to GetAddress: %s", sBuffer);
		Address pRelativeOffset = LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32);
		Address pFunc = addr + view_as<Address>(5) + pRelativeOffset;

		DynamicDetour detour = new DynamicDetour(pFunc, CallConv_CDECL, ReturnType_Bool, ThisPointer_Ignore);
		detour.AddParam(HookParamType_ObjectPtr);
		if (!detour.Enable(Hook_Pre, OnSpawnPlayerZombieScanPre))
			SetFailState("Failed to detour: %s", sBuffer);
	}
	else
		SetupDetour(hGameData, OnSpawnPlayerZombieScanPre, INVALID_FUNCTION, "ForEachTerrorPlayer<SpawnablePZScan>");

	SetupPatch(hGameData, "CTerrorPlayer::UpdateZombieFrustration::AllowCheckPointFrustration");
	SetupPatch(hGameData, "CTerrorPlayer::UpdateZombieFrustration::SkipUselessCode"); // jump to CreateEvent("tank_frustrated")
	SetupPatch(hGameData, "CTerrorPlayer::UpdateZombieFrustration::NeverTryOfferingTankBot");
	SetupPatch(hGameData, "CDirector::SetLotteryTank::NeverEnterStasis");

	// void CTerrorPlayer::SetPreSpawnClass(ZombieClassType)
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorPlayer::SetPreSpawnClass");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_SetPreSpawnClass = EndPrepSDKCall();
	if (g_hSDK_SetPreSpawnClass == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// void CCSPlayer::State_Transition(CSPlayerState)
	strcopy(sBuffer, sizeof(sBuffer), "CCSPlayer::State_Transition");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_StateTransition = EndPrepSDKCall();
	if (g_hSDK_StateTransition == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// CTerrorPlayer* CTerrorPlayer::ReplaceWithBot(bool)
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorPlayer::ReplaceWithBot");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_ReplaceWithBot = EndPrepSDKCall();
	if (g_hSDK_ReplaceWithBot == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// void CTerrorPlayer::TakeOverZombieBot(CTerrorPlayer*)
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorPlayer::TakeOverZombieBot");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_TakeOverZombieBot = EndPrepSDKCall();
	if (g_hSDK_TakeOverZombieBot == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// bool CTerrorGameRules::IsGenericCooperativeMode()
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorGameRules::IsGenericCooperativeMode");
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_IsGenericCoopMode = EndPrepSDKCall();
	if (g_hSDK_IsGenericCoopMode == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	delete hGameData;

	g_aJoinTankList = new ArrayList();
}

