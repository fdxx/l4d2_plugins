#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <dhooks>
#include <multicolors>

#define VERSION "0.2"

ConVar
	g_cvGameMode,
	g_cvSpawnTime,
	g_cvMaxSpecialLimit,
	g_cvSpecialLimit[9],
	g_cvBlockOtherRespawn,
	g_cvAdminImmunity,
	g_cvSurMaxIncapCount;

int
	g_iMaxSpecialLimit,
	g_iSpecialLimit[9],
	g_iSpawnCountDown[MAXPLAYERS+1],
	g_iSpawnTime,
	g_iGlowEntRef[MAXPLAYERS+1],
	g_iSurMaxIncapCount;

bool
	g_bBlockOtherRespawn,
	g_bLeftSafeArea,
	g_bAdminImmunity,
	g_bAllowSpawn;

Handle
	g_hSpawnSITimer[MAXPLAYERS+1],
	g_hSurGlowCheck;

ArrayList g_aJoinTankList;
char g_sGameMode[128];
DynamicDetour g_dSpawnPlayerZombieScan;
float g_fMapStartTime;

enum
{
	SMOKER	= 1,
	BOOMER	= 2,
	HUNTER	= 3,
	SPITTER	= 4,
	JOCKEY	= 5,
	CHARGER	= 6,
	TANK	= 8,
};

static const char g_sSpecialName[][] =
{
	"", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"
};

public Plugin myinfo = 
{
	name = "L4D2 Control Zombies",
	author = "sorallll, fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	LoadGameData();
	g_cvGameMode = FindConVar("mp_gamemode");
	g_cvSurMaxIncapCount = FindConVar("survivor_max_incapacitated_count");

	CreateConVar("l4d2_cz_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvSpawnTime = CreateConVar("l4d2_cz_spawn_time", "15", "重生时间", FCVAR_NONE);
	g_cvBlockOtherRespawn = CreateConVar("l4d2_cz_block_other_pz_respawn", "1", "阻止其他插件通过z_spawn等方式复活特感玩家", FCVAR_NONE);
	g_cvAdminImmunity = CreateConVar("l4d2_cz_admin_immunity", "1", "管理员加入特感团队不受最大人数限制", FCVAR_NONE);

	g_cvMaxSpecialLimit = CreateConVar("l4d2_cz_max_special_limit", "1", "感染玩家人数最大限制", FCVAR_NONE);
	g_cvSpecialLimit[SMOKER] = CreateConVar("l4d2_cz_smoker_limit", "0", "Smoker玩家限制", FCVAR_NONE);
	g_cvSpecialLimit[BOOMER] = CreateConVar("l4d2_cz_boomer_limit", "0", "Boomer玩家限制", FCVAR_NONE);
	g_cvSpecialLimit[HUNTER] = CreateConVar("l4d2_cz_hunter_limit", "5", "Hunter玩家限制", FCVAR_NONE);
	g_cvSpecialLimit[SPITTER] = CreateConVar("l4d2_cz_spitter_limit", "0", "Spitter玩家限制", FCVAR_NONE);
	g_cvSpecialLimit[JOCKEY] = CreateConVar("l4d2_cz_jockey_limit", "0", "Jockey玩家限制", FCVAR_NONE);
	g_cvSpecialLimit[CHARGER] = CreateConVar("l4d2_cz_charger_limit", "0", "Charger玩家限制", FCVAR_NONE);
	g_cvSpecialLimit[TANK] = CreateConVar("l4d2_cz_tank_limit", "1", "Tank玩家限制", FCVAR_NONE);

	GetCvars();

	g_cvSurMaxIncapCount.AddChangeHook(ConVarChanged);
	g_cvSpawnTime.AddChangeHook(ConVarChanged);
	g_cvBlockOtherRespawn.AddChangeHook(ConVarChanged);
	g_cvMaxSpecialLimit.AddChangeHook(ConVarChanged);
	g_cvAdminImmunity.AddChangeHook(ConVarChanged);
	
	for (int i = 1; i <= 8; i++)
	{
		if (g_cvSpecialLimit[i] != null)
			g_cvSpecialLimit[i].AddChangeHook(ConVarChanged);
	}

	RegConsoleCmd("sm_inf", Cmd_JoinTeam3);
	RegConsoleCmd("sm_team3", Cmd_JoinTeam3);
	RegConsoleCmd("sm_taketank", Cmd_JoinTank);
	RegConsoleCmd("sm_tk", Cmd_JoinTank);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	//HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	//HookEvent("player_bot_replace", Event_BotReplacePlayer);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("map_transition", Event_RoundEnd); //战役过关到下一关的时候 (没有触发round_end)
	HookEvent("mission_lost", Event_RoundEnd); //战役灭团重来该关卡的时候 (之后有触发round_end)
	HookEvent("finale_vehicle_leaving", Event_RoundEnd); //救援载具离开之时  (没有触发round_end)

	g_aJoinTankList = new ArrayList();
}

void LoadGameData()
{
	GameData hGameData = new GameData("l4d2_control_zombies");
	if (hGameData == null)
		SetFailState("加载 l4d2_control_zombies.txt 文件失败");
	
	g_dSpawnPlayerZombieScan = DynamicDetour.FromConf(hGameData, "ForEachTerrorPlayer<SpawnablePZScan>");
	if (g_dSpawnPlayerZombieScan == null)
		SetFailState("加载 ForEachTerrorPlayer<SpawnablePZScan> 签名失败");

	if (!g_dSpawnPlayerZombieScan.Enable(Hook_Pre, mreOnSpawnPlayerZombieScanPre))
		SetFailState("启用 mreOnSpawnPlayerZombieScan 失败");
}

public void OnConfigsExecuted()
{
	if (!L4D2_IsGenericCooperativeMode())
	{
		SetFailState("不支持的游戏模式");
	}

	g_cvGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));
	
	FindConVar("z_scrimmage_sphere").SetBounds(ConVarBound_Lower, true, 0.0);
	FindConVar("z_scrimmage_sphere").SetBounds(ConVarBound_Upper, true, 0.0);
	FindConVar("z_scrimmage_sphere").SetInt(0);
	
	FindConVar("z_max_player_zombies").SetBounds(ConVarBound_Lower, true, 32.0);
	FindConVar("z_max_player_zombies").SetBounds(ConVarBound_Upper, true, 32.0);
	FindConVar("z_max_player_zombies").SetInt(32);

	FindConVar("sb_all_bot_game").SetInt(1);
	FindConVar("allow_all_bot_survivor_team").SetInt(1);
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();	
}

void GetCvars()
{
	g_iSurMaxIncapCount = g_cvSurMaxIncapCount.IntValue;
	g_bBlockOtherRespawn = g_cvBlockOtherRespawn.BoolValue;
	g_iSpawnTime = g_cvSpawnTime.IntValue;
	g_iMaxSpecialLimit = g_cvMaxSpecialLimit.IntValue;
	g_bAdminImmunity = g_cvAdminImmunity.BoolValue;

	for (int i = 1; i <= 8; i++)
	{
		if (g_cvSpecialLimit[i] != null)
			g_iSpecialLimit[i] = g_cvSpecialLimit[i].IntValue;
	}
}

public void OnMapStart()
{
	g_fMapStartTime = GetGameTime();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
	CreateTimer(2.0, RemoveInfectedClips_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
	delete g_hSurGlowCheck;
	g_hSurGlowCheck = CreateTimer(0.2, SurGlowCheck_Timer, _, TIMER_REPEAT);
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

Action SurGlowCheck_Timer(Handle timer)
{
	if (HasZombiePlayer())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				SurGlowCheck(i);
			}
		}
	}
	return Plugin_Continue;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	g_bLeftSafeArea = false;
	g_aJoinTankList.Clear();

	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		delete g_hSpawnSITimer[i];
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	g_bLeftSafeArea = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && !IsPlayerAlive(i) && !IsFakeClient(i))
		{
			delete g_hSpawnSITimer[i];
			g_iSpawnCountDown[i] = 0;
			g_hSpawnSITimer[i] = CreateTimer(1.0, SpawnSI_Timer, GetClientUserId(i), TIMER_REPEAT);
		}
	}
	return Plugin_Continue;
}

Action SpawnSI_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsValidSI(client) && !IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if (g_iSpawnCountDown[client] <= 0)
		{
			int iClass = FindSpawnClass();
			if (1 <= iClass <= 6)
			{
				g_bAllowSpawn = true;
				
				FakeClientCommand(client, "spec_next");
				CheatCommand(client, "z_spawn_old", g_sSpecialName[iClass]);
				if (IsPlayerAlive(client)) L4D_State_Transition(client, STATE_GHOST);
				else LogError("设置灵魂状态失败, 客户端不是活着状态");

				g_bAllowSpawn = false;
			}

			g_hSpawnSITimer[client] = null;
			return Plugin_Stop;
		}

		PrintHintText(client, "%i 秒后重生", g_iSpawnCountDown[client]--);
		return Plugin_Continue;
	}
	g_hSpawnSITimer[client] = null;
	return Plugin_Stop;
}

Action Cmd_JoinTeam3(int client, int args)
{
	if (IsRealClient(client) && GetClientTeam(client) != 3)
	{
		if (g_bAdminImmunity && IsAdminClient(client))
		{
			ChangeClientTeam(client, 3);
		}
		else if (GetZombiePlayerTotal() < g_iMaxSpecialLimit)
		{
			ChangeClientTeam(client, 3);
		}
		else PrintHintText(client, "已达到感染玩家最大限制");
	}
	return Plugin_Handled;
}

Action Cmd_JoinTank(int client, int args)
{
	if (IsValidSI(client) && !IsFakeClient(client))
	{
		int userid = GetClientUserId(client);
		if (RemoveJoinTank(userid))
		{
			CPrintToChat(client, "{default}[{yellow}提示{default}] 你已退出接管Tank列表");
		}
		else
		{
			g_aJoinTankList.Push(userid);
			CPrintToChat(client, "{default}[{yellow}提示{default}] 你已加入接管Tank列表, 再次输入退出");
		}
	}
	return Plugin_Handled;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if (GetClientOfUserId(userid) > 0)
	{
		CreateTimer(0.1, CreateSurGlow_Timer, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action CreateSurGlow_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0)
	{
		//LogMessage("%N PlayerSpawn", client);
		RemoveSurGlow(client);
		CreateSurGlow(client);
	}
	return Plugin_Continue;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	int OldTeam = event.GetInt("oldteam");
	int NewTeam = event.GetInt("team");

	if (client > 0)
	{
		switch (OldTeam)
		{
			case 2:
			{
				//LogMessage("%N 离开team2", client);
				//CreateTimer(0.1, ResetSurGlow, _, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 3:
			{
				if (IsRealClient(client))
				{
					RemoveJoinTank(userid);
					CreateTimer(0.1, SetLadderGlow_Timer, userid, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}

		switch (NewTeam)
		{
			case 2:
			{
				//LogMessage("%N 加入team2", client);
				CreateTimer(0.1, ResetSurGlow, _, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 3:
			{
				if (IsRealClient(client))
				{
					CreateTimer(0.1, SetLadderGlow_Timer, userid, TIMER_FLAG_NO_MAPCHANGE);
					CPrintToChat(client, "{default}[{yellow}提示{default}] {olive}!taketank {default}或 {olive}!tk {default}可加入接管Tank列表(需在克出现之前提前输入)");

					if (g_bLeftSafeArea)
					{
						delete g_hSpawnSITimer[client];
						g_iSpawnCountDown[client] = g_iSpawnTime;
						g_hSpawnSITimer[client] = CreateTimer(1.0, SpawnSI_Timer, userid, TIMER_REPEAT);
					}
				}
			}
		}
	}
}

Action ResetSurGlow(Handle timer)
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
		RemoveSurGlow(i);
	for (i = 1; i <= MaxClients; i++)
		CreateSurGlow(i);
	return Plugin_Continue;
}

Action SetLadderGlow_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsRealClient(client))
	{
		if (GetClientTeam(client) == 3)
		{
			SendConVarValue(client, g_cvGameMode, "versus");
		}
		else SendConVarValue(client, g_cvGameMode, g_sGameMode);
	}
	return Plugin_Continue;
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		switch (GetClientTeam(client))
		{
			case 2: RemoveSurGlow(client);
			case 3:
			{
				if (g_bLeftSafeArea && !IsFakeClient(client))
				{
					delete g_hSpawnSITimer[client];
					g_iSpawnCountDown[client] = g_iSpawnTime;
					g_hSpawnSITimer[client] = CreateTimer(1.0, SpawnSI_Timer, userid, TIMER_REPEAT);
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	RemoveJoinTank(GetClientUserId(client));
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
	CreateTimer(0.1, JoinTankCheck_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

Action JoinTankCheck_Timer(Handle timer, int userid)
{
	int iTankbot = GetClientOfUserId(userid);
	if (IsTankBot(iTankbot) && GetTankPlayerTotal() < g_iSpecialLimit[TANK])
	{
		int client = GetJoinTankClient();
		if (client > 0)
		{
			if (IsPlayerAlive(client)) ForcePlayerSuicide(client);
			L4D_TakeOverZombieBot(client, iTankbot);

			if (IsPlayerAlive(client) && GetZombieClass(client) == 8)
			{
				CPrintToChatAll("{red}[{default}!{red}] {olive}AI Tank {default}已被 {red}%N {default}接管", client);
			}
		}
	}

	return Plugin_Continue;
}

MRESReturn mreOnSpawnPlayerZombieScanPre()
{
	if (!g_bAllowSpawn && g_bBlockOtherRespawn)
	{
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

public Action L4D_OnEnterGhostStatePre(int client)
{
	if (!g_bLeftSafeArea)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// 避免幽灵 Tank
public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	enterStasis = false;
	return Plugin_Changed;
}

void RemoveSurGlow(int client)
{
	if (IsValidEntRef(g_iGlowEntRef[client]))
	{
		RemoveEntity(g_iGlowEntRef[client]);
		g_iGlowEntRef[client] = 0;
	}	
}

void CreateSurGlow(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsValidEntRef(g_iGlowEntRef[client]))
	{
		int iEntity = CreateEntityByName("prop_dynamic_ornament");
		if (iEntity == -1) return;
		
		g_iGlowEntRef[client] = EntIndexToEntRef(iEntity);

		static char sModelName[128];
		GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
		DispatchKeyValue(iEntity, "model", sModelName);
		DispatchSpawn(iEntity);

		SetEntProp(iEntity, Prop_Send, "m_nSolidType", 0);
		SetEntProp(iEntity, Prop_Send, "m_usSolidFlags", 4);
		SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 0);

		AcceptEntityInput(iEntity, "DisableCollision");
		SetEntProp(iEntity, Prop_Data, "m_iEFlags", 0);
		SetEntProp(iEntity, Prop_Data, "m_fEffects", 0x020); //don't draw entity

		SetEntProp(iEntity, Prop_Send, "m_iGlowType", 3);
		SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 20000);
		SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", 1);
		SurGlowCheck(client);

		SetVariantString("!activator");
		AcceptEntityInput(iEntity, "SetAttached", client);

		SDKUnhook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
		SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
	}
}

Action Hook_SetTransmit(int entity, int client)
{
	if (!IsFakeClient(client) && GetClientTeam(client) == 3)
		return Plugin_Continue;

	return Plugin_Handled;
}

void SurGlowCheck(int client)
{
	if (IsValidEntRef(g_iGlowEntRef[client]))
	{
		static int iColor;
		iColor = GetSurGlowColor(client);
		if (GetEntProp(g_iGlowEntRef[client], Prop_Send, "m_glowColorOverride") != iColor)
			SetEntProp(g_iGlowEntRef[client], Prop_Send, "m_glowColorOverride", iColor);
	}
}

int GetSurGlowColor(int client)
{
	static float fFadeStartTime;

	if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurMaxIncapCount)
	{
		return 16777215; //白色
	}
	else if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		return 180; //红色
	}
	else if ((fFadeStartTime = GetEntPropFloat(client, Prop_Send, "m_vomitFadeStart")) > g_fMapStartTime && fFadeStartTime >= GetGameTime() - 15.0)
	{
		return 11796635; //紫色
	}
	else return 46080; //绿色
}

bool IsValidEntRef(int ref)
{
	if (ref && EntRefToEntIndex(ref) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

int FindSpawnClass()
{
	int iClass, iSpecialCount[7];
	ArrayList g_aClassArray = new ArrayList();
	SetRandomSeed(GetTime());

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsFakeClient(i))
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
			g_aClassArray.Push(i);
		}
	}

	iClass = -1;

	if (g_aClassArray.Length > 0)
	{
		iClass = g_aClassArray.Get(GetRandomInt(0, g_aClassArray.Length - 1));
	}
	
	delete g_aClassArray;
	return iClass;
}

int GetJoinTankClient()
{
	ArrayList aTemList = new ArrayList();
	int client;

	for (int i = 0; i < g_aJoinTankList.Length; i++)
	{
		client = GetClientOfUserId(g_aJoinTankList.Get(i));
		if (IsValidSI(client) && !IsFakeClient(client))
		{
			if (IsPlayerAlive(client) && GetZombieClass(client) == 8)
				continue;

			aTemList.Push(client);
		}
	}

	client = -1;

	if (aTemList.Length > 0)
	{
		client = aTemList.Get(GetRandomInt(0, aTemList.Length - 1));
	}
	
	delete aTemList;
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
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsFakeClient(i) && GetZombieClass(i) == 8)
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
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i))
		{
			iCount++;
		}
	}
	return iCount;
}

bool HasZombiePlayer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i))
		{
			return true;
		}
	}
	return false;
}

void CheatCommand(int client, const char[] sCommand, const char[] sArguments = "")
{
	static int iCmdFlags, iFlagBits;
	iFlagBits = GetUserFlagBits(client), iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags | FCVAR_CHEAT);
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

bool IsTankBot(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetZombieClass(client) == 8 && IsPlayerAlive(client) && IsFakeClient(client));
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool IsValidSI(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 3)
		{
			return true;
		}
	}
	return false;
}

bool IsAdminClient(int client)
{
	int iFlags = GetUserFlagBits(client);
	if (iFlags != 0 && (iFlags & ADMFLAG_ROOT)) 
	{
		return true;
	}
	return false;
}
