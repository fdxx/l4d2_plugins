#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define VERSION "2.5"

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>
#include <profiler>

#define GAMEDATA "l4d2_nav_area"

#define BOSS_SURVIVOR_SAFE_DISTANCE 2200.0	//boss和生还者之间的安全距离(考虑Flow转换)
#define TANK_WITCH_SAFE_FLOW 0.20			//witch和tank之间的安全流距离

#define BOSS_MIN_SPAWN_FLOW 0.20
#define BOSS_MAX_SPAWN_FLOW 0.85

#define FLOW_MIN 0
#define FLOW_MAX 1

ConVar 
	g_cvDirectorNoBoss,
	g_cvTankSpawnEnable,
	g_cvWitchSpawnEnable,
	g_cvBlockTankSpawn,
	g_cvBlockWitchSpawn;

bool
	g_bTankSpawnEnable,
	g_bWitchSpawnEnable,
	g_bBlockTankSpawn,
	g_bBlockWitchSpawn,
	g_bTankSpawnThisMap,
	g_bWitchSpawnThisMap,
	g_bCanSpawnTank,
	g_bCanSpawnWitch,
	g_bLeftSafeArea;

float
	g_fTankSpawnFlow,
	g_fWitchSpawnFlow,
	g_fTankSpawnPos[3],
	g_fWitchSpawnPos[3],
	g_fSpawnBufferFlow,
	g_fMapMaxFlowDist;

Handle
	g_hSDKFindRandomSpot,
	g_hTankFlowCheckTimer,
	g_hWitchFlowCheckTimer;

int
	g_iSpawnAttributesOffset,
	g_iFlowDistanceOffset,
	g_iNavCountOffset,
	g_iNavAreaCount;

char 
	g_sCfgPath[PLATFORM_MAX_PATH];

ArrayList
	g_aBanFlow;

StringMap
	g_smTankSpawnMap,
	g_smWitchSpawnMap;


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

	g_cvDirectorNoBoss = FindConVar("director_no_bosses");

	CreateConVar("l4d2_boss_spawn_control_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvTankSpawnEnable = CreateConVar("l4d2_boss_spawn_control_tank_enable", "1", "启用给定的地图上产生Tank", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvWitchSpawnEnable = CreateConVar("l4d2_boss_spawn_control_witch_enable", "1", "启用给定的地图上产生Witch", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBlockTankSpawn = CreateConVar("l4d2_boss_spawn_control_block_other_tank_spawn", "1", "阻止本插件以外的Tank产生 (通过L4D_OnSpawnTank)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBlockWitchSpawn = CreateConVar("l4d2_boss_spawn_control_block_other_witch_spawn", "1", "阻止本插件以外的Witch产生 (通过L4D_OnSpawnWitch)", FCVAR_NONE, true, 0.0, true, 1.0);
	
	GetCvars();

	g_cvTankSpawnEnable.AddChangeHook(OnConVarChange);
	g_cvWitchSpawnEnable.AddChangeHook(OnConVarChange);
	g_cvBlockTankSpawn.AddChangeHook(OnConVarChange);
	g_cvBlockWitchSpawn.AddChangeHook(OnConVarChange);

	RegConsoleCmd("sm_boss", Cmd_PrintFlow);
	RegConsoleCmd("sm_tank", Cmd_PrintFlow);
	RegConsoleCmd("sm_witch", Cmd_PrintFlow);
	RegConsoleCmd("sm_cur", Cmd_PrintFlow);
	RegConsoleCmd("sm_current", Cmd_PrintFlow);
	
	RegAdminCmd("sm_tank_spawn_map", Cmd_TankSpawnMap, ADMFLAG_ROOT);
	RegAdminCmd("sm_witch_spawn_map", Cmd_WitchSpawnMap, ADMFLAG_ROOT);

	//DEBUG
	RegAdminCmd("sm_reflow", Cmd_ReFlow, ADMFLAG_ROOT);
	//RegAdminCmd("sm_setflow_test", Cmd_SetFlowTest, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d2_boss_spawn_control");
}

Action Cmd_TankSpawnMap(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "sm_tank_spawn_map <add|remove> <MapName>");
		return Plugin_Handled;
	}

	char sType[8], sMapName[128];
	GetCmdArg(1, sType, sizeof(sType));
	GetCmdArg(2, sMapName, sizeof(sMapName));

	if (strcmp(sType, "add", false) == 0)
	{
		g_smTankSpawnMap.SetValue(sMapName, 1);
	}
	else if (strcmp(sType, "remove", false) == 0)
	{
		if (g_smTankSpawnMap.Remove(sMapName))
			ReplyToCommand(client, "remove tank spawn map: %s", sMapName);
	}

	return Plugin_Handled;
}

Action Cmd_WitchSpawnMap(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "sm_witch_spawn_map <add|remove> <MapName>");
		return Plugin_Handled;
	}

	char sType[8], sMapName[128];
	GetCmdArg(1, sType, sizeof(sType));
	GetCmdArg(2, sMapName, sizeof(sMapName));

	if (strcmp(sType, "add", false) == 0)
	{
		g_smWitchSpawnMap.SetValue(sMapName, 1);
	}
	else if (strcmp(sType, "remove", false) == 0)
	{
		if (g_smWitchSpawnMap.Remove(sMapName))
			ReplyToCommand(client, "remove witch spawn map: %s", sMapName);
	}

	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	SetDirectorBoss();
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	SetDirectorBoss();
}

void SetDirectorBoss()
{
	if (g_bTankSpawnEnable || g_bWitchSpawnEnable)
	{
		g_cvDirectorNoBoss.IntValue = 1;
	}
	else g_cvDirectorNoBoss.IntValue = 0;
}

void GetCvars()
{
	g_bTankSpawnEnable = g_cvTankSpawnEnable.BoolValue;
	g_bWitchSpawnEnable = g_cvWitchSpawnEnable.BoolValue;
	g_bBlockTankSpawn = g_cvBlockTankSpawn.BoolValue;
	g_bBlockWitchSpawn = g_cvBlockWitchSpawn.BoolValue;
}

public void OnMapStart()
{
	if (g_bTankSpawnEnable) PrecacheSound("ui/pickup_secret01.wav", true);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(2.0, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action RoundStart_Timer(Handle timer)
{
	Reset();

	g_iNavAreaCount = g_pTheNavAreas.Count();
	if (g_iNavAreaCount <= 0) LogError("当前地图Nav区域数量为0, 可能是某些测试地图");

	int shit;
	g_bTankSpawnThisMap = g_smTankSpawnMap.GetValue(CurrentMap(), shit) && g_bTankSpawnEnable;
	g_bWitchSpawnThisMap = g_smWitchSpawnMap.GetValue(CurrentMap(), shit) && g_bWitchSpawnEnable;

	g_fMapMaxFlowDist = L4D2Direct_GetMapMaxFlowDistance();
	g_fSpawnBufferFlow = (BOSS_SURVIVOR_SAFE_DISTANCE / g_fMapMaxFlowDist);

	GetBanFlow();
	SetBossSpawnFlow();

	return Plugin_Continue;
}

void GetBanFlow()
{
	g_aBanFlow.Clear();
	static float fBanFlow[2];
	KeyValues kv = new KeyValues("");

	if (kv.ImportFromFile(g_sCfgPath))
	{
		if (kv.JumpToKey(CurrentMap()) && kv.JumpToKey("tank_ban_flow") && kv.GotoFirstSubKey())
		{
			do
			{
				fBanFlow[FLOW_MIN] = kv.GetNum("min", -1) * 0.01;
				fBanFlow[FLOW_MAX] = kv.GetNum("max", -1) * 0.01;
				g_aBanFlow.PushArray(fBanFlow);
			}
			while (kv.GotoNextKey());
		}
	}
	else SetFailState("Failed to load mapinfo file");

	delete kv;
}

void SetBossSpawnFlow()
{
	#if DEBUG
	PrintToServer("--------- Start ---------");
	Profiler hProfiler = new Profiler();
	hProfiler.Start();
	#endif

	static NavArea pArea;
	static float fFlow, fTriggerSpawnFlow;
	static float fSpawnPos[3];
	static SpawnData data;
	static int i, iRandomIndex;

	ArrayList aSpawnData = new ArrayList(sizeof(SpawnData));

	for (i = 0; i < g_iNavAreaCount; i++)
	{
		pArea = g_pTheNavAreas.GetArea(i);
		if (!pArea.IsNull())
		{
			if (IsValidFlags(pArea.SpawnAttributes))
			{
				fFlow = pArea.GetFlow()/g_fMapMaxFlowDist;
				if (IsValidFlow(fFlow))
				{
					fTriggerSpawnFlow = fFlow - g_fSpawnBufferFlow;
					if (fTriggerSpawnFlow > 0.0)
					{
						pArea.GetSpawnPos(fSpawnPos);
						if (!IsWillStuck(fSpawnPos))
						{
							if (L4D2Direct_GetTerrorNavArea(fSpawnPos) != Address_Null)
							{
								data.fFlow = fTriggerSpawnFlow;
								data.fPos = fSpawnPos;
								aSpawnData.PushArray(data);
							}
						}
					}
				}
			}
		}
	}

	//PrintToServer("有效点位：%i", aSpawnData.Length);

	//设置Tank产生点
	if (g_bTankSpawnThisMap && aSpawnData.Length > 0)
	{
		SetRandomSeed(GetTime());
		iRandomIndex = GetRandomInt(0, aSpawnData.Length - 1);
		aSpawnData.GetArray(iRandomIndex, data);

		g_fTankSpawnFlow = data.fFlow;
		g_fTankSpawnPos = data.fPos;
		
		aSpawnData.Erase(iRandomIndex);
	}
	else g_fTankSpawnFlow = 0.0;

	//设置witch产生点
	if (g_bWitchSpawnThisMap && aSpawnData.Length > 0)
	{
		bool bValidPos;

		for (i = 0; i < 200; i++)
		{
			aSpawnData.GetArray(GetRandomInt(0, aSpawnData.Length - 1), data);

			//Tank和Witch间隔一定距离
			if (FloatAbs(g_fTankSpawnFlow - data.fFlow) > TANK_WITCH_SAFE_FLOW)
			{
				bValidPos = true;
				break;
			}
		}

		if (bValidPos)
		{
			g_fWitchSpawnFlow = data.fFlow;
			g_fWitchSpawnPos = data.fPos;
		}
		else g_fWitchSpawnFlow = 0.0;
	}
	else g_fWitchSpawnFlow = 0.0;

	#if DEBUG
	hProfiler.Stop();
	PrintToServer("执行时间: %f", hProfiler.Time);
	PrintToServer("[Tank] flow: %i, actual: %i", RoundToNearest(g_fTankSpawnFlow * 100), RoundToNearest((g_fTankSpawnFlow + g_fSpawnBufferFlow) * 100));
	delete hProfiler;
	#endif

	delete aSpawnData;
}

bool IsValidFlags(int iFlags)
{	
	return iFlags && !(iFlags & TERROR_NAV_EMPTY) && !(iFlags & TERROR_NAV_STOP_SCAN) && !(iFlags & TERROR_NAV_RESCUE_CLOSET);
}

bool IsValidFlow(float fFlow)
{
	if (fFlow < BOSS_MIN_SPAWN_FLOW || fFlow > BOSS_MAX_SPAWN_FLOW)
		return false;

	static float fBanFlow[2];
	static int i;

	for (i = 0; i < g_aBanFlow.Length; i++)
	{
		g_aBanFlow.GetArray(i, fBanFlow);
		if (fBanFlow[FLOW_MIN] <= fFlow <= fBanFlow[FLOW_MAX])
		{
			return false;
		}
	}

	return true;
}

bool IsWillStuck(const float fPos[3])
{
	//似乎所有客户端的尺寸都一样
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
	g_bLeftSafeArea = false;

	delete g_hTankFlowCheckTimer;
	g_bCanSpawnTank = false;

	delete g_hWitchFlowCheckTimer;
	g_bCanSpawnWitch = false;

	g_bTankSpawnThisMap = false;
	g_bWitchSpawnThisMap = false;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	g_bLeftSafeArea = true;

	if (g_bTankSpawnThisMap && g_fTankSpawnFlow > 0.0)
	{
		delete g_hTankFlowCheckTimer;
		g_hTankFlowCheckTimer = CreateTimer(0.5, TankSpawnCheck_Timer, _, TIMER_REPEAT);
	}

	if (g_bWitchSpawnThisMap && g_fWitchSpawnFlow > 0.0)
	{
		delete g_hWitchFlowCheckTimer;
		g_hWitchFlowCheckTimer = CreateTimer(0.5, WitchSpawnCheck_Timer, _, TIMER_REPEAT);
	}

	PrintBossFlow();

	return Plugin_Continue;
}

Action TankSpawnCheck_Timer(Handle timer)
{
	if (g_bTankSpawnThisMap && g_fTankSpawnFlow > 0.0 && g_bLeftSafeArea)
	{
		if (GetSurMaxFlow() >= g_fTankSpawnFlow)
		{
			g_bCanSpawnTank = true;
			L4D2_SpawnTank(g_fTankSpawnPos, NULL_VECTOR);
			g_bCanSpawnTank = false;

			g_hTankFlowCheckTimer = null;
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	g_hTankFlowCheckTimer = null;
	return Plugin_Stop;
}

Action WitchSpawnCheck_Timer(Handle timer)
{
	if (g_bWitchSpawnThisMap && g_fWitchSpawnFlow > 0.0 && g_bLeftSafeArea)
	{
		if (GetSurMaxFlow() >= g_fWitchSpawnFlow)
		{
			g_bCanSpawnWitch = true;
			L4D2_SpawnWitch(g_fWitchSpawnPos, NULL_VECTOR);
			g_bCanSpawnWitch = false;

			g_hWitchFlowCheckTimer = null;
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	g_hWitchFlowCheckTimer = null;
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
		SetBossSpawnFlow();
		PrintBossFlow();
	}
	else PrintToChat(client, "已离开安全区域，无法设置");
	return Plugin_Handled;
}
/* 
Action Cmd_SetFlowTest(int client, int args)
{
	if (!g_bLeftSafeArea)
	{
		CreateTimer(1.5, SetFlowTest_Timer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Handled;
}

Action SetFlowTest_Timer(Handle timer)
{
	static int iTestSetFlowcount;
	iTestSetFlowcount++;
	PrintToServer("第 %i 次 TestSetFlow", iTestSetFlowcount);
	SetBossSpawnFlow();
	return Plugin_Continue;
}
*/
void PrintBossFlow()
{
	CPrintToChatAll("Current: {yellow}%i {default}%%", RoundToNearest(GetSurMaxFlow() * 100.0));

	if (g_bTankSpawnThisMap)
	{
		if (g_fTankSpawnFlow > 0.0)
			CPrintToChatAll("Tank: {yellow}%i {default}%%", RoundToNearest(g_fTankSpawnFlow * 100.0));
		else CPrintToChatAll("Tank: {yellow}None");
	}
	else CPrintToChatAll("Tank: {yellow}Default");

	if (g_bWitchSpawnThisMap)
	{
		if (g_fWitchSpawnFlow > 0.0)
			CPrintToChatAll("Witch: {yellow}%i {default}%%", RoundToNearest(g_fWitchSpawnFlow * 100.0));
		else CPrintToChatAll("Witch: {yellow}None");
	}
	else CPrintToChatAll("Witch: {yellow}Default");
}

public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawnTank && g_bBlockTankSpawn && g_bTankSpawnThisMap)
	{
		LogMessage("不是本插件产生的 Tank, 已阻止");
		return Plugin_Handled;
	}

	EmitSoundToAll("ui/pickup_secret01.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
	CPrintToChatAll("{red}[{default}!{red}] {olive}Tank {default}has spawned!");

	return Plugin_Continue;
}

public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawnWitch && g_bBlockWitchSpawn && g_bWitchSpawnThisMap)
	{
		LogMessage("不是本插件产生的 Witch, 已阻止");
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

char[] CurrentMap()
{
	static char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return sMapName;
}

void Init()
{
	g_aBanFlow = new ArrayList(2);
	g_smTankSpawnMap = new StringMap();
	g_smWitchSpawnMap = new StringMap();

	// Thanks: https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/cfg/cfgogl/zonemod/mapinfo.txt
	BuildPath(Path_SM, g_sCfgPath, sizeof(g_sCfgPath), "data/mapinfo.txt");
	
	GameData hGameData = new GameData(GAMEDATA);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iSpawnAttributesOffset = hGameData.GetOffset("TerrorNavArea::ScriptGetSpawnAttributes");
	if (g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: TerrorNavArea::ScriptGetSpawnAttributes");

	g_iFlowDistanceOffset = hGameData.GetOffset("CTerrorPlayer::GetFlowDistance::m_flow");
	if(g_iFlowDistanceOffset == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::GetFlowDistance::m_flow");

	g_iNavCountOffset = hGameData.GetOffset("TheNavAreas::Count");
	if(g_iNavCountOffset == -1)
		SetFailState("Failed to find offset: TheNavAreas::Count");

	g_pTheNavAreas = view_as<TheNavAreas>(hGameData.GetAddress("TheNavAreas"));
	if (!g_pTheNavAreas)
		SetFailState("Failed to get address: TheNavAreas");	

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavArea::FindRandomSpot"))
		SetFailState("Failed to find signature: TerrorNavArea::FindRandomSpot");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	g_hSDKFindRandomSpot = EndPrepSDKCall();
	if(g_hSDKFindRandomSpot == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::FindRandomSpot");

	delete hGameData;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D2_CanSpawnBoss", Native_CanSpawnBoss);
	CreateNative("L4D2_GetBossSpawnFlow", Native_GetBossSpawnFlow);
	CreateNative("L4D2_IsBossSpawnMap", Native_IsBossSpawnMap);
	return APLRes_Success;
}

// native void L4D2_CanSpawnBoss(int iBossType, bool bCanSpawn);
int Native_CanSpawnBoss(Handle plugin, int numParams)
{
	int iBossType = GetNativeCell(1);
	bool bCanSpawn = GetNativeCell(2);
	switch (iBossType)
	{
		case 1: g_bCanSpawnTank = bCanSpawn;
		case 2: g_bCanSpawnWitch = bCanSpawn;
	}
	return 0;
}

// native float L4D2_GetBossSpawnFlow(int iBossType);
any Native_GetBossSpawnFlow(Handle plugin, int numParams)
{
	int iBossType = GetNativeCell(1);
	switch (iBossType)
	{
		case 1: return g_fTankSpawnFlow;
		case 2: return g_fWitchSpawnFlow;
	}
	return 0.0;
}

// native bool L4D2_IsBossSpawnMap(int iBossType, const char[] sMapName);
any Native_IsBossSpawnMap(Handle plugin, int numParams)
{
	int maxlength, shit;
	int iBossType = GetNativeCell(1);

	GetNativeStringLength(2, maxlength);
	maxlength += 1;
	char[] sMapName = new char[maxlength];
	GetNativeString(2, sMapName, maxlength);

	switch (iBossType)
	{
		case 1: return g_smTankSpawnMap.GetValue(sMapName, shit) && g_bTankSpawnEnable;
		case 2: return g_smWitchSpawnMap.GetValue(sMapName, shit) && g_bWitchSpawnEnable;
	}
	return false;
}
