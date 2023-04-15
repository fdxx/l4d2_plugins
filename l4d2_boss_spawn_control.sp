#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>  
#include <dhooks>

#define VERSION "2.7"

#define SPAWN_SOUND "ui/pickup_secret01.wav"

#define BOSS_SURVIVOR_SAFE_DISTANCE 2200.0	// Safe distance between boss and survivors (considering Flow transitions)
#define TANK_WITCH_SAFE_FLOW 0.20			// Safe distance between witch and tank (Flow percentage)

#define BOSS_MIN_SPAWN_FLOW 0.20
#define BOSS_MAX_SPAWN_FLOW 0.85

#define FLOW_MIN 0
#define FLOW_MAX 1

#define FLOW_DISABLED	-3.0
#define FLOW_DEFAULT	-2.0
#define FLOW_STATIC		-1.0
#define FLOW_NONE		0.0

#define TANK 0
#define WITCH 1

ConVar
	director_no_bosses,
	g_cvEnable[2],
	g_cvBlockSpawn[2];

bool
	g_bEnable[2],
	g_bBlockSpawn[2],
	g_bCanSpawn[2],
	g_bSetBossFlow,
	g_bDisableDirectorBoss,
	g_bLeftSafeArea;

float
	g_fSpawnFlow[2],
	g_fSpawnPos[2][3],

	g_fMapMaxFlowDist;

Handle
	g_hSDKFindRandomSpot,
	g_hRoundStartTimer,
	g_hSpawnCheckTimer[2];

int
	g_iSpawnAttributesOffset,
	g_iFlowDistanceOffset,
	g_iNavCountOffset;

Address
	g_pReFlowTime;
	
ArrayList
	g_aSpawnData,
	g_aBanFlow;

StringMap
	g_smSpawnMap[2],
	g_smStaticMap[2];

enum struct SpawnData
{
	float fFlow;
	float fPos[3];
}

// https://developer.valvesoftware.com/wiki/List_of_L4D_Series_Nav_Mesh_Attributes:zh-cn
#define	TERROR_NAV_NO_NAME1				(1 << 0)
#define	TERROR_NAV_EMPTY				(1 << 1)
#define	TERROR_NAV_STOP_SCAN			(1 << 2)
#define	TERROR_NAV_NO_NAME2				(1 << 3)
#define	TERROR_NAV_NO_NAME3				(1 << 4)
#define	TERROR_NAV_BATTLESTATION		(1 << 5)
#define	TERROR_NAV_FINALE				(1 << 6)
#define	TERROR_NAV_PLAYER_START			(1 << 7)
#define	TERROR_NAV_BATTLEFIELD			(1 << 8)
#define	TERROR_NAV_IGNORE_VISIBILITY	(1 << 9)
#define	TERROR_NAV_NOT_CLEARABLE		(1 << 10)
#define	TERROR_NAV_CHECKPOINT			(1 << 11)
#define	TERROR_NAV_OBSCURED				(1 << 12)
#define	TERROR_NAV_NO_MOBS				(1 << 13)
#define	TERROR_NAV_THREAT				(1 << 14)
#define	TERROR_NAV_RESCUE_VEHICLE		(1 << 15)
#define	TERROR_NAV_RESCUE_CLOSET		(1 << 16)
#define	TERROR_NAV_ESCAPE_ROUTE			(1 << 17)
#define	TERROR_NAV_DOOR					(1 << 18)
#define	TERROR_NAV_NOTHREAT				(1 << 19)
#define	TERROR_NAV_LYINGDOWN			(1 << 20)
#define	TERROR_NAV_COMPASS_NORTH		(1 << 24)
#define	TERROR_NAV_COMPASS_NORTHEAST	(1 << 25)
#define	TERROR_NAV_COMPASS_EAST			(1 << 26)
#define	TERROR_NAV_COMPASS_EASTSOUTH	(1 << 27)
#define	TERROR_NAV_COMPASS_SOUTH		(1 << 28)
#define	TERROR_NAV_COMPASS_SOUTHWEST	(1 << 29)
#define	TERROR_NAV_COMPASS_WEST			(1 << 30)
#define	TERROR_NAV_COMPASS_WESTNORTH	(1 << 31)

methodmap TheNavAreas
{
	public int Count()
	{
		return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iNavCountOffset), NumberType_Int32);
	}

	public Address Dereference()
	{
		return LoadFromAddress(view_as<Address>(this), NumberType_Int32);
	}

	public NavArea GetArea(int i, bool bDereference = true)
	{
		if (!bDereference)
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(i*4), NumberType_Int32);
		return LoadFromAddress(this.Dereference() + view_as<Address>(i*4), NumberType_Int32);
	}
}

methodmap NavArea
{
	public bool IsNull()
	{
		return view_as<Address>(this) == Address_Null;
	}
	
	public void GetSpawnPos(float fPos[3])
	{
		SDKCall(g_hSDKFindRandomSpot, this, fPos, sizeof(fPos));
	}

	property int SpawnAttributes
	{
		public get()
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iSpawnAttributesOffset), NumberType_Int32);

		public set(int value)
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iSpawnAttributesOffset), value, NumberType_Int32);
	}
	
	public float GetFlow()
	{
		return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iFlowDistanceOffset), NumberType_Int32);
	}
}

TheNavAreas g_pTheNavAreas;

public Plugin myinfo = 
{
	name = "L4D2 Boss spawn control",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);

	director_no_bosses = FindConVar("director_no_bosses");

	CreateConVar("l4d2_boss_spawn_control_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnable[TANK] = CreateConVar("l4d2_boss_spawn_control_tank_enable", "1", "Enables tank spawn on a given map.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvEnable[WITCH] = CreateConVar("l4d2_boss_spawn_control_witch_enable", "1", "Enables witch spawn on a given map.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBlockSpawn[TANK] = CreateConVar("l4d2_boss_spawn_control_block_other_tank_spawn", "1", "Block other tank spawn (by L4D_OnSpawnTank).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBlockSpawn[WITCH] = CreateConVar("l4d2_boss_spawn_control_block_other_witch_spawn", "1", "Block other witch spawn (by L4D_OnSpawnWitch).", FCVAR_NONE, true, 0.0, true, 1.0);
	
	OnConVarChange(null, "", "");

	g_cvEnable[TANK].AddChangeHook(OnConVarChange);
	g_cvEnable[WITCH].AddChangeHook(OnConVarChange);
	g_cvBlockSpawn[TANK].AddChangeHook(OnConVarChange);
	g_cvBlockSpawn[WITCH].AddChangeHook(OnConVarChange);

	RegConsoleCmd("sm_boss", Cmd_PrintFlow);
	RegConsoleCmd("sm_tank", Cmd_PrintFlow);
	RegConsoleCmd("sm_witch", Cmd_PrintFlow);
	RegConsoleCmd("sm_cur", Cmd_PrintFlow);
	RegConsoleCmd("sm_current", Cmd_PrintFlow);
	
	RegAdminCmd("sm_tank_spawn_map", Cmd_BossSpawnMap, ADMFLAG_ROOT);
	RegAdminCmd("sm_witch_spawn_map", Cmd_BossSpawnMap, ADMFLAG_ROOT);

	RegAdminCmd("sm_tank_static_map", Cmd_BossStaticMap, ADMFLAG_ROOT);
	RegAdminCmd("sm_witch_static_map", Cmd_BossStaticMap, ADMFLAG_ROOT);

	//DEBUG
	RegAdminCmd("sm_reflow", Cmd_ReFlow, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d2_boss_spawn_control");
}

Action Cmd_BossSpawnMap(int client, int args)
{
	char sCmd[32];
	GetCmdArg(0, sCmd, sizeof(sCmd));
	
	if (args != 2)
	{
		LogError("%s <add|remove> <MapName>", sCmd);
		return Plugin_Handled;
	}

	char sType[8], sMap[256];
	GetCmdArg(1, sType, sizeof(sType));
	GetCmdArg(2, sMap, sizeof(sMap));

	int iBoss = !strcmp(sCmd, "sm_tank_spawn_map", false) ? TANK : WITCH;

	if (!strcmp(sType, "add", false))
		g_smSpawnMap[iBoss].SetValue(sMap, 1);
	else if (!strcmp(sType, "remove", false))
		g_smSpawnMap[iBoss].Remove(sMap);
	else
	{
		LogError("%s <add|remove> <MapName>", sCmd);
		return Plugin_Handled;
	}
		
	if (client > 0)
		ReplyToCommand(client, "%s %s spawn map: %s", sType, !iBoss ? "tank":"witch", sMap);

	return Plugin_Handled;
}

Action Cmd_BossStaticMap(int client, int args)
{
	char sCmd[32];
	GetCmdArg(0, sCmd, sizeof(sCmd));

	if (args != 2)
	{
		LogError("%s <add|remove> <MapName>", sCmd);
		return Plugin_Handled;
	}

	char sType[8], sMap[256];
	GetCmdArg(1, sType, sizeof(sType));
	GetCmdArg(2, sMap, sizeof(sMap));

	int iBoss = !strcmp(sCmd, "sm_tank_static_map", false) ? TANK : WITCH;

	if (!strcmp(sType, "add", false))
		g_smStaticMap[iBoss].SetValue(sMap, 1);
	else if (!strcmp(sType, "remove", false))
		g_smStaticMap[iBoss].Remove(sMap);
	else
	{
		LogError("%s <add|remove> <MapName>", sCmd);
		return Plugin_Handled;
	}
	
	if (client > 0)
		ReplyToCommand(client, "%s %s static map: %s", sType, !iBoss ? "tank":"witch", sMap);

	return Plugin_Handled;
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bEnable[TANK] = g_cvEnable[TANK].BoolValue;
	g_bEnable[WITCH] = g_cvEnable[WITCH].BoolValue;
	g_bBlockSpawn[TANK] = g_cvBlockSpawn[TANK].BoolValue;
	g_bBlockSpawn[WITCH] = g_cvBlockSpawn[WITCH].BoolValue;
}

public void OnMapStart()
{
	PrecacheSound(SPAWN_SOUND, true);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
	g_hRoundStartTimer = CreateTimer(1.0, RoundStart_Timer, _, TIMER_REPEAT);
}

Action RoundStart_Timer(Handle timer)
{
	// TerrorNavMesh::Update -> TerrorNavMesh::RecomputeFlowDistances
	// c5m2, c5m3, ...
	float fReFlowTime = LoadFromAddress(g_pReFlowTime, NumberType_Int32);
	if (fReFlowTime > 0.0)
		return Plugin_Continue;

	char sMap[256];
	GetCurrentMap(sMap, sizeof(sMap));
	g_fMapMaxFlowDist = L4D2Direct_GetMapMaxFlowDistance();

	GetBanFlow(sMap);
	GetSpawnData();
	SetTankSpawnFlow(sMap);
	SetWitchSpawnFlow(sMap);

	if (g_fSpawnFlow[TANK] < -1.0 && g_fSpawnFlow[WITCH] < -1.0)
	{
		director_no_bosses.BoolValue = false;
		g_bDisableDirectorBoss = false;
	}

	g_bSetBossFlow = true;
	g_hRoundStartTimer = null;
	return Plugin_Stop;
}

void GetBanFlow(const char[] sMap)
{
	g_aBanFlow.Clear();

	// Thanks: https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/cfg/cfgogl/zonemod/mapinfo.txt
	char sFile[PLATFORM_MAX_PATH];
	float fBanFlow[2];
	char key[256];

	BuildPath(Path_SM, sFile, sizeof(sFile), "data/mapinfo.txt");
	KeyValues kv = new KeyValues("");
	if (!kv.ImportFromFile(sFile))
	{
		delete kv;
		return;
	}

	FormatEx(key, sizeof(key), "%s/tank_ban_flow", sMap);
	if (kv.JumpToKey(key) && kv.GotoFirstSubKey())
	{
		do
		{
			fBanFlow[FLOW_MIN] = kv.GetNum("min", -1) * 0.01;
			fBanFlow[FLOW_MAX] = kv.GetNum("max", -1) * 0.01;
			g_aBanFlow.PushArray(fBanFlow);
		}
		while (kv.GotoNextKey());
	}

	delete kv;
}

void GetSpawnData()
{
	g_aSpawnData.Clear();

	NavArea pArea;
	SpawnData data;
	float fFlow, fTriggerSpawnFlow, fSpawnPos[3];

	int iAreaCount = g_pTheNavAreas.Count();
	float fSpawnBufferFlow = (BOSS_SURVIVOR_SAFE_DISTANCE / g_fMapMaxFlowDist);
	bool bFinaleArea = L4D_IsMissionFinalMap() && L4D2_GetCurrentFinaleStage() < 18;

	for (int i = 0; i < iAreaCount; i++)
	{
		pArea = g_pTheNavAreas.GetArea(i);
		if (pArea && IsValidFlags(pArea.SpawnAttributes, bFinaleArea))
		{
			fFlow = pArea.GetFlow()/g_fMapMaxFlowDist;
			if (!IsValidFlow(fFlow))
				continue;

			fTriggerSpawnFlow = fFlow - fSpawnBufferFlow;
			if (fTriggerSpawnFlow <= 0.0)
				continue;
	
			pArea.GetSpawnPos(fSpawnPos);
			if (WillStuck(fSpawnPos))
				continue;

			data.fFlow = fTriggerSpawnFlow;
			data.fPos = fSpawnPos;
			g_aSpawnData.PushArray(data);
		}
	}
	//PrintToServer("%i valid points", g_aSpawnData.Length);
}

void SetTankSpawnFlow(const char[] sMap)
{
	int index;
	SpawnData data;

	if (!g_bEnable[TANK])
	{
		g_fSpawnFlow[TANK] = FLOW_DISABLED;
		return;
	}

	if (g_smStaticMap[TANK].ContainsKey(sMap))
	{
		g_fSpawnFlow[TANK] = FLOW_STATIC;
		return;
	}

	if (!g_smSpawnMap[TANK].ContainsKey(sMap))
	{
		g_fSpawnFlow[TANK] = FLOW_DEFAULT;
		return;
	}

	if (g_aSpawnData.Length < 1)
	{
		g_fSpawnFlow[TANK] = FLOW_NONE;
		return;
	}

	index = GetRandomIntEx(0, g_aSpawnData.Length - 1);
	g_aSpawnData.GetArray(index, data);
	g_fSpawnFlow[TANK] = data.fFlow;
	g_fSpawnPos[TANK] = data.fPos;
	g_aSpawnData.Erase(index);
}

void SetWitchSpawnFlow(const char[] sMap)
{
	SpawnData data;

	if (!g_bEnable[WITCH])
	{
		g_fSpawnFlow[WITCH] = FLOW_DISABLED;
		return;
	}

	if (g_smStaticMap[WITCH].ContainsKey(sMap))
	{
		g_fSpawnFlow[WITCH] = FLOW_STATIC;
		return;
	}

	if (!g_smSpawnMap[WITCH].ContainsKey(sMap))
	{
		g_fSpawnFlow[WITCH] = FLOW_DEFAULT;
		return;
	}

	if (g_aSpawnData.Length < 1)
	{
		g_fSpawnFlow[WITCH] = FLOW_NONE;
		return;
	}

	for (int i = 0; i < 200; i++)
	{
		g_aSpawnData.GetArray(GetRandomIntEx(0, g_aSpawnData.Length - 1), data);

		if (FloatAbs(g_fSpawnFlow[TANK] - data.fFlow) > TANK_WITCH_SAFE_FLOW)
		{
			g_fSpawnFlow[WITCH] = data.fFlow;
			g_fSpawnPos[WITCH] = data.fPos;
			return;
		}
	}
	g_fSpawnFlow[WITCH] = FLOW_NONE;
}

bool IsValidFlags(int iFlags, bool bFinaleArea)
{
	if (iFlags)
	{
		if (bFinaleArea)
		{
			return (iFlags & TERROR_NAV_FINALE) && (iFlags & (TERROR_NAV_EMPTY|TERROR_NAV_RESCUE_CLOSET|TERROR_NAV_RESCUE_VEHICLE) == 0);
		}
		return (iFlags & (TERROR_NAV_EMPTY|TERROR_NAV_RESCUE_CLOSET|TERROR_NAV_RESCUE_VEHICLE) == 0);
	} 
	return true;
}

bool IsValidFlow(float fFlow)
{
	if (fFlow < BOSS_MIN_SPAWN_FLOW || fFlow > BOSS_MAX_SPAWN_FLOW)
		return false;

	static float fBanFlow[2];
	static int i, len;

	for (i = 0, len = g_aBanFlow.Length; i < len; i++)
	{
		g_aBanFlow.GetArray(i, fBanFlow);
		if (fBanFlow[FLOW_MIN] <= fFlow <= fBanFlow[FLOW_MAX])
		{
			return false;
		}
	}

	return true;
}

bool WillStuck(const float fPos[3])
{
	// All clients seem to be the same size.
	static const float fClientMinSize[3] = {-16.0, -16.0, 0.0};
	static const float fClientMaxSize[3] = {16.0, 16.0, 71.0};

	static bool bHit;
	static Handle hTrace;

	hTrace = TR_TraceHullFilterEx(fPos, fPos, fClientMinSize, fClientMaxSize, MASK_PLAYERSOLID, TraceFilter_Stuck);
	bHit = TR_DidHit(hTrace);

	delete hTrace;
	return bHit;
}

bool TraceFilter_Stuck(int entity, int contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	return true;
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
	delete g_hRoundStartTimer;
	g_bLeftSafeArea = false;
	g_bSetBossFlow = false;
	
	director_no_bosses.BoolValue = true;
	g_bDisableDirectorBoss = true;

	g_fSpawnFlow[TANK] = FLOW_DEFAULT;
	g_fSpawnFlow[WITCH] = FLOW_DEFAULT;

	delete g_hSpawnCheckTimer[TANK];
	g_bCanSpawn[TANK] = false;

	delete g_hSpawnCheckTimer[WITCH];
	g_bCanSpawn[WITCH] = false;
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bSetBossFlow)
	{
		CreateTimer(0.5, LeftSafeArea_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	g_bLeftSafeArea = true;

	if (g_fSpawnFlow[TANK] > 0.0)
	{
		delete g_hSpawnCheckTimer[TANK];
		g_hSpawnCheckTimer[TANK] = CreateTimer(0.5, SpawnCheck_Timer, TANK, TIMER_REPEAT);
	}

	if (g_fSpawnFlow[WITCH] > 0.0)
	{
		delete g_hSpawnCheckTimer[WITCH];
		g_hSpawnCheckTimer[WITCH] = CreateTimer(0.5, SpawnCheck_Timer, WITCH, TIMER_REPEAT);
	}

	PrintBossFlow();
}

Action LeftSafeArea_Timer(Handle timer)
{
	Event_PlayerLeftSafeArea(null, "", true);
	return Plugin_Continue;
}

Action SpawnCheck_Timer(Handle timer, int iBoss)
{
	if (g_fSpawnFlow[iBoss] > 0.0 && g_bLeftSafeArea)
	{
		if (GetSurMaxFlow() >= g_fSpawnFlow[iBoss])
		{
			g_bCanSpawn[iBoss] = true;

			if (iBoss == TANK)
				L4D2_SpawnTank(g_fSpawnPos[iBoss], NULL_VECTOR);
			else L4D2_SpawnWitch(g_fSpawnPos[iBoss], NULL_VECTOR);
			
			g_bCanSpawn[iBoss] = false;

			g_hSpawnCheckTimer[iBoss] = null;
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	g_hSpawnCheckTimer[iBoss] = null;
	return Plugin_Stop;
}

Action Cmd_PrintFlow(int client, int args)
{
	PrintBossFlow();
	return Plugin_Handled;
}

Action Cmd_ReFlow(int client, int args)
{
	if (!g_bLeftSafeArea)
	{
		RoundStart_Timer(null);
		PrintBossFlow();
	}
	return Plugin_Handled;
}

void PrintBossFlow()
{
	CPrintToChatAll("{olive}Current: {yellow}%i {default}%%", RoundToNearest(GetSurMaxFlow() * 100.0));

	// Tank
	if (g_fSpawnFlow[TANK] == FLOW_STATIC)
		CPrintToChatAll("{olive}Tank: {yellow}Static");
	else if (g_fSpawnFlow[TANK] == FLOW_DEFAULT)
		CPrintToChatAll("{olive}Tank: {yellow}Default");
	else if (g_fSpawnFlow[TANK] == FLOW_NONE)
		CPrintToChatAll("{olive}Tank: {yellow}None");
	else if (g_fSpawnFlow[TANK] > 0.0)
		CPrintToChatAll("{olive}Tank: {yellow}%i {default}%%", RoundToNearest(g_fSpawnFlow[TANK] * 100.0));

	// Witch
	if (g_fSpawnFlow[WITCH] == FLOW_STATIC)
		CPrintToChatAll("{olive}Witch: {yellow}Static");
	else if (g_fSpawnFlow[WITCH] == FLOW_DEFAULT)
		CPrintToChatAll("{olive}Witch: {yellow}Default");
	else if (g_fSpawnFlow[WITCH] == FLOW_NONE)
		CPrintToChatAll("{olive}Witch: {yellow}None");
	else if (g_fSpawnFlow[WITCH] > 0.0)
		CPrintToChatAll("{olive}Witch: {yellow}%i {default}%%", RoundToNearest(g_fSpawnFlow[WITCH] * 100.0));
}

public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawn[TANK] && g_bBlockSpawn[TANK] && g_fSpawnFlow[TANK] >= 0.0)
	{
		LogMessage("Tank not spawned by this plugin, blocked.");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
	if (client > 0)
	{
		EmitSoundToAll(SPAWN_SOUND);
		CPrintToChatAll("{blue}[提示] {olive}Tank {default}has spawned!");
	}
}

public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawn[WITCH] && g_bBlockSpawn[WITCH] && g_fSpawnFlow[WITCH] >= 0.0)
	{
		LogMessage("Witch not spawned by this plugin, blocked.");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

float GetSurMaxFlow()
{
	static float fSurMaxDistance;
	static int iFurthestSur;

	iFurthestSur = L4D_GetHighestFlowSurvivor();

	if (IsValidSur(iFurthestSur)) fSurMaxDistance = L4D2Direct_GetFlowDistance(iFurthestSur);
	else fSurMaxDistance = L4D2_GetFurthestSurvivorFlow();

	return (fSurMaxDistance / g_fMapMaxFlowDist);
}

bool IsValidSur(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

MRESReturn OnBossesProhibitedCheckPre(Address pThis, DHookReturn hReturn)
{
	if (g_bDisableDirectorBoss)
	{
		hReturn.Value = true;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

void GetOffset(GameData hGameData, int &offset, const char[] name)
{
	offset = hGameData.GetOffset(name);
	if (offset == -1)
		SetFailState("Failed to get offset: %s", name);
}

void GetAddress(GameData hGameData, Address &address, const char[] name)
{
	address = hGameData.GetAddress(name);
	if (address == Address_Null)
		SetFailState("Failed to get address: %s", name);
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_boss_spawn_control");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", sBuffer);

	GetOffset(hGameData, g_iSpawnAttributesOffset, "TerrorNavArea::SpawnAttributes");
	GetOffset(hGameData, g_iFlowDistanceOffset, "TerrorNavArea::FlowDistance");
	GetOffset(hGameData, g_iNavCountOffset, "TheNavAreas::Count");

	GetAddress(hGameData, view_as<Address>(g_pTheNavAreas), "TheNavAreas");
	GetAddress(hGameData, g_pReFlowTime, "TerrorNavMesh::UnknownTimer");

	// Vector CNavArea::GetRandomPoint( void ) const
	strcopy(sBuffer, sizeof(sBuffer), "TerrorNavArea::FindRandomSpot");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	g_hSDKFindRandomSpot = EndPrepSDKCall();
	if(g_hSDKFindRandomSpot == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "CDirector::AreBossesProhibited");
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, sBuffer);
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour: %s", sBuffer);
	if (!dDetour.Enable(Hook_Pre, OnBossesProhibitedCheckPre))
		SetFailState("Failed to enable DynamicDetour: %s", sBuffer);

	delete hGameData;

	g_aSpawnData = new ArrayList(sizeof(SpawnData));
	g_aBanFlow = new ArrayList(2);
	g_smSpawnMap[TANK] = new StringMap();
	g_smSpawnMap[WITCH] = new StringMap();
	g_smStaticMap[TANK] = new StringMap();
	g_smStaticMap[WITCH] = new StringMap();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D2_CanSpawnBoss", Native_CanSpawnBoss);
	CreateNative("L4D2_GetBossSpawnFlow", Native_GetBossSpawnFlow);

	RegPluginLibrary("l4d2_boss_spawn_control");
	return APLRes_Success;
}

// native void L4D2_CanSpawnBoss(int iBossType, bool bCanSpawn);
int Native_CanSpawnBoss(Handle plugin, int numParams)
{
	int iBossType = GetNativeCell(1);
	bool bCanSpawn = GetNativeCell(2);
	g_bCanSpawn[iBossType] = bCanSpawn;
	return 0;
}

// native float L4D2_GetBossSpawnFlow(int iBossType);
any Native_GetBossSpawnFlow(Handle plugin, int numParams)
{
	int iBossType = GetNativeCell(1);
	return g_fSpawnFlow[iBossType];
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
int GetRandomIntEx(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

