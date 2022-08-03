#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0
#define VERSION "3.0"

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <profiler>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define GAMEDATA "l4d2_si_spawn_control"

ConVar
	z_special_limit[7],
	z_attack_flow_range,
	z_spawn_flow_limit,
	director_spectate_specials,
	z_spawn_safety_range,
	z_finale_spawn_safety_range,
	z_spawn_range,
	g_cvSpecialLimit[7],
	g_cvMaxSILimit,
	g_cvSpawnTime,
	g_cvFirstSpawnTime,
	g_cvKillSITime,
	g_cvBlockSpawn,
	g_cvRadicalSpawn,
	g_cvNormalSpawnRange;

int
	g_iSpecialLimit[7],
	g_iMaxSILimit,
	g_iSpawnMaxSICount,
	g_iSpawnAttributesOffset,
	g_iFlowDistanceOffset,
	g_iNavCountOffset,
	g_iSurPosDataLength,
	g_iNavAreaCount;
	
float
	g_fSpawnTime,
	g_fFirstSpawnTime,
	g_fKillSITime,
	g_fSpawnDist,
	g_fSpecialActionTime[MAXPLAYERS+1];

bool
	g_bBlockSpawn,
	g_bCanSpawn,
	g_bRadicalSpawn,
	g_bFinalMap,
	g_bLeftSafeArea,
	g_bMark[MAXPLAYERS+1];

Handle
	g_hSpawnSITimer[MAXPLAYERS+1],
	g_hKillSICheckTimer,
	g_hFirstSpawnSITimer,
	g_hSpawnMaxSITimer,
	g_hSDKIsVisibleToPlayer,
	g_hSDKFindRandomSpot;

ArrayList
	g_aClientsArray,
	g_aClassArray,
	g_aSpawnData,
	g_aSurPosData;

enum struct SurPosData
{
	float fFlow;
	float fPos[3];
}

enum struct SpawnData
{
	float fDist;
	float fPos[3];
}

// ZombieClass
#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6
#define	TANK	8

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
	name = "L4D2 Special infected spawn control",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_si_spawn_control_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	z_special_limit[SMOKER] = FindConVar("z_smoker_limit");
	z_special_limit[BOOMER] = FindConVar("z_boomer_limit");
	z_special_limit[HUNTER] = FindConVar("z_hunter_limit");
	z_special_limit[SPITTER] = FindConVar("z_spitter_limit");
	z_special_limit[JOCKEY] = FindConVar("z_jockey_limit");
	z_special_limit[CHARGER] = FindConVar("z_charger_limit");
	z_attack_flow_range = FindConVar("z_attack_flow_range");
	z_spawn_flow_limit = FindConVar("z_spawn_flow_limit");
	director_spectate_specials = FindConVar("director_spectate_specials");
	z_spawn_safety_range = FindConVar("z_spawn_safety_range");
	z_finale_spawn_safety_range = FindConVar("z_finale_spawn_safety_range");
	z_spawn_range = FindConVar("z_spawn_range");

	g_cvSpecialLimit[HUNTER] = CreateConVar("l4d2_si_spawn_control_hunter_limit", "1", "Hunter数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_cvSpecialLimit[JOCKEY] = CreateConVar("l4d2_si_spawn_control_jockey_limit", "1", "jockey数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_cvSpecialLimit[SMOKER] = CreateConVar("l4d2_si_spawn_control_smoker_limit", "1", "smoker数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_cvSpecialLimit[BOOMER] = CreateConVar("l4d2_si_spawn_control_boomer_limit", "1", "boomer数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_cvSpecialLimit[SPITTER] = CreateConVar("l4d2_si_spawn_control_spitter_limit", "1", "spitter数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_cvSpecialLimit[CHARGER] = CreateConVar("l4d2_si_spawn_control_charger_limit", "1", "charger数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_cvMaxSILimit = CreateConVar("l4d2_si_spawn_control_max_specials", "6", "最大特感数量", FCVAR_NONE, true, 0.0, true, 31.0);
	g_cvSpawnTime = CreateConVar("l4d2_si_spawn_control_spawn_time", "10.0", "特感产生时间", FCVAR_NONE, true, 1.0, true, 9999.0);
	g_cvFirstSpawnTime = CreateConVar("l4d2_si_spawn_control_first_spawn_time", "10.0", "离开安全区域首次产生特感的时间", FCVAR_NONE, true, 1.0, true, 9999.0);
	g_cvKillSITime = CreateConVar("l4d2_si_spawn_control_kill_si_time", "25.0", "多少秒后摸鱼的特感将会被自动杀死", FCVAR_NONE, true, 2.0, true, 9999.0);
	g_cvBlockSpawn = CreateConVar("l4d2_si_spawn_control_block_other_si_spawn", "1", "阻止本插件以外的特感产生 (通过L4D_OnSpawnSpecial限制)", FCVAR_NONE, true, 0.0, true, 1.0);

	//阴间找位对服务器性能要求比较高，谨慎使用
	g_cvRadicalSpawn = CreateConVar("l4d2_si_spawn_control_radical_spawn", "0", "开启特感阴间找位, 将会在距离生还者最近的地方产生", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvNormalSpawnRange = CreateConVar("l4d2_si_spawn_control_spawn_range_normal", "1500", "普通特感产生范围，从1到这个范围随机产生", FCVAR_NONE, true, 1.0);
	
	GetCvars();

	for (int i = 1; i <= 6; i++)
	{
		g_cvSpecialLimit[i].AddChangeHook(ConVarChanged);
	}
	g_cvMaxSILimit.AddChangeHook(ConVarChanged);
	g_cvSpawnTime.AddChangeHook(ConVarChanged);
	g_cvFirstSpawnTime.AddChangeHook(ConVarChanged);
	g_cvKillSITime.AddChangeHook(ConVarChanged);
	g_cvBlockSpawn.AddChangeHook(ConVarChanged);
	g_cvRadicalSpawn.AddChangeHook(ConVarChanged);
	g_cvNormalSpawnRange.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	//HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);

	RegConsoleCmd("sm_sicvar", Cmd_CvarPrint);
	RegConsoleCmd("sm_si_cvar", Cmd_CvarPrint);

	g_aClientsArray = new ArrayList();
	g_aClassArray = new ArrayList();
	g_aSpawnData = new ArrayList(sizeof(SpawnData));
	g_aSurPosData = new ArrayList(sizeof(SurPosData));
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();

	//游戏途中改变特感数量，产生特感到最大特感限制
	if (convar == g_cvMaxSILimit)
	{
		if (StringToInt(newValue) > StringToInt(oldValue))
		{
			delete g_hSpawnMaxSITimer;
			g_iSpawnMaxSICount = 0;
			g_hSpawnMaxSITimer = CreateTimer(0.3, SpawnMaxSI_Timer, _, TIMER_REPEAT);
		}
	}
}

void GetCvars()
{
	for (int i = 1; i <= 6; i++)
	{
		g_iSpecialLimit[i] = g_cvSpecialLimit[i].IntValue;
	}
	g_iMaxSILimit = g_cvMaxSILimit.IntValue;
	g_fSpawnTime = g_cvSpawnTime.FloatValue;
	g_fFirstSpawnTime = g_cvFirstSpawnTime.FloatValue;
	g_fKillSITime = g_cvKillSITime.FloatValue;
	g_bBlockSpawn = g_cvBlockSpawn.BoolValue;

	g_bRadicalSpawn = g_cvRadicalSpawn.BoolValue;
	z_spawn_range.IntValue = g_cvNormalSpawnRange.IntValue;
}

public void OnConfigsExecuted()
{
	for (int i = 1; i <= 6; i++)
		z_special_limit[i].IntValue = 0;

	z_attack_flow_range.IntValue = 50000;
	z_spawn_flow_limit.IntValue = 50000;
	director_spectate_specials.IntValue = 1;
	z_spawn_safety_range.IntValue = 1;
	z_finale_spawn_safety_range.IntValue = 1;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();

	delete g_hKillSICheckTimer;
	g_hKillSICheckTimer = CreateTimer(2.0, KillSICheck_Timer, _, TIMER_REPEAT);

	CreateTimer(2.0, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action RoundStart_Timer(Handle timer)
{
	g_iNavAreaCount = g_pTheNavAreas.Count();
	if (g_iNavAreaCount <= 0) LogError("当前地图Nav区域数量为0, 可能是某些测试地图");

	g_bFinalMap = L4D_IsMissionFinalMap();
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

public void OnClientDisconnect(int client)
{
	g_bMark[client] = false;
}

void Reset()
{
	g_bLeftSafeArea = false;

	delete g_hFirstSpawnSITimer;
	delete g_hSpawnMaxSITimer;
	delete g_hKillSICheckTimer;

	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		delete g_hSpawnSITimer[i];
		g_bMark[i] = false;
	}

	g_bCanSpawn = false;
	g_fSpawnDist = 1500.0;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	g_bLeftSafeArea = true;

	delete g_hFirstSpawnSITimer;
	g_hFirstSpawnSITimer = CreateTimer(g_fFirstSpawnTime, FirstSpawnSI_Timer);
	
	return Plugin_Continue;
}

Action FirstSpawnSI_Timer(Handle timer)
{
	g_hFirstSpawnSITimer = null;

	if (g_bLeftSafeArea)
	{
		delete g_hSpawnMaxSITimer;
		g_iSpawnMaxSICount = 0;
		g_hSpawnMaxSITimer = CreateTimer(0.3, SpawnMaxSI_Timer, _, TIMER_REPEAT); //间隔0.3s陆续产生特感
	}
	return Plugin_Continue;
}

Action SpawnMaxSI_Timer(Handle timer)
{
	if (g_bLeftSafeArea && GetAllSpecialsTotal() < g_iMaxSILimit && ++g_iSpawnMaxSICount < MaxClients)
	{
		SpawnSpecial();
		return Plugin_Continue;
	}
	g_hSpawnMaxSITimer = null;
	return Plugin_Stop;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bLeftSafeArea)
	{
		static int userid, client, iClass;

		userid = event.GetInt("userid");
		client = GetClientOfUserId(userid);

		if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsFakeClient(client))
		{
			if (g_bMark[client])
			{
				iClass = GetZombieClass(client);
				switch (iClass)
				{
					case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER:
					{
						SpecialDeathSpawn(g_fSpawnTime);

						// 踢出bot释放客户端索引，排除spitter避免无声痰
						if (iClass != SPITTER) CreateTimer(0.2, kickbot, userid);
					}
				}
			}
		}
		g_bMark[client] = false;
	}
}

void SpecialDeathSpawn(float fTime)
{
	static int iSpawnNum;
	if (iSpawnNum >= MAXPLAYERS) iSpawnNum = 0;
	g_hSpawnSITimer[iSpawnNum] = CreateTimer(fTime, SpecialDeathSpawn_Timer, iSpawnNum);
	iSpawnNum++;
}

Action SpecialDeathSpawn_Timer(Handle timer, int iSpawnNum)
{
	g_hSpawnSITimer[iSpawnNum] = null;
	SpawnSpecial();
	return Plugin_Continue;
}

Action ReSpawnSpecial_Timer(Handle timer)
{
	SpawnSpecial();
	return Plugin_Continue;
}

void SpawnSpecial()
{
	if (g_bLeftSafeArea)
	{
		#if DEBUG
		Profiler hProfiler = new Profiler();
		hProfiler.Start();
		PrintToChatAll("----- 开始产生特感 -----");
		#endif

		static float fSpawnPos[3];
		static int iRandomSur, iSpawnClass;

		iRandomSur = GetRandomSur();
		if (iRandomSur > 0 && GetAllSpecialsTotal() < g_iMaxSILimit)
		{
			iSpawnClass = FindSpawnClass();
			if (1 <= iSpawnClass <= 6)
			{
				bool bFindSpawnPos;
				int index;
				
				if (g_bRadicalSpawn && g_iNavAreaCount > 0)
				{
					bFindSpawnPos = GetSpawnPosByNavArea(fSpawnPos);
					if (!bFindSpawnPos)
					{
						//PrintToChatAll("%f 距离找位失败，暂时重置g_fSpawnDist", g_fSpawnDist);
						g_fSpawnDist = 1500.0;
					}
				}
				else
				{
					bFindSpawnPos = L4D_GetRandomPZSpawnPosition(iRandomSur, iSpawnClass, 30, fSpawnPos);
				}

				if (bFindSpawnPos)
				{
					g_bCanSpawn = true;
					index = L4D2_SpawnSpecial(iSpawnClass, fSpawnPos, NULL_VECTOR);
					g_bCanSpawn = false;

					if (index > 0) g_bMark[index] = true;
				}

				if (!bFindSpawnPos || index <= 0)
				{
					//PrintToChatAll("产生特感失败, 重新产生, bFindSpawnPos: %b", bFindSpawnPos);
					CreateTimer(1.0, ReSpawnSpecial_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}

		#if DEBUG
		hProfiler.Stop();
		PrintToChatAll("执行时间: %f", hProfiler.Time);
		delete hProfiler;
		#endif
	}
}

bool GetSpawnPosByNavArea(float fPos[3])
{
	static TheNavAreas pTheNavAreas;
	static NavArea pArea;
	static float fSpawnPos[3], fFlow, fDist, fMapMaxFlowDist;
	static bool bFindValidPos;
	static int iArrayIndex, i;
	static SpawnData data;

	pTheNavAreas = view_as<TheNavAreas>(g_pTheNavAreas.Dereference());
	bFindValidPos = false;
	GetSurPos();
	g_aSpawnData.Clear();
	fMapMaxFlowDist = L4D2Direct_GetMapMaxFlowDistance();

	for (i = 0; i < g_iNavAreaCount; i++)
	{
		pArea = pTheNavAreas.GetArea(i, false);
		if (!pArea.IsNull())
		{
			if (IsValidFlags(pArea.SpawnAttributes))
			{
				fFlow = pArea.GetFlow();
				if (0.0 < fFlow < fMapMaxFlowDist)
				{
					pArea.GetSpawnPos(fSpawnPos);
					if (IsNearTheSur(fFlow, fSpawnPos, fDist))
					{
						if (!IsSurVisible(fSpawnPos, pArea))
						{
							if (!IsWillStuck(fSpawnPos))
							{
								data.fDist = fDist;
								data.fPos = fSpawnPos;
								g_aSpawnData.PushArray(data);
							}
						}
					}
				}
			}
		}
	}

	if (g_aSpawnData.Length > 0)
	{
		g_aSpawnData.Sort(Sort_Ascending, Sort_Float);

		if (g_aSpawnData.Length >= 2) iArrayIndex = GetRandomInt(0, 1);
		else iArrayIndex = 0;

		g_aSpawnData.GetArray(iArrayIndex, data);
		fPos = data.fPos;
		g_fSpawnDist = data.fDist + 400.0;

		bFindValidPos = true;
	}

	return bFindValidPos;
}

bool IsValidFlags(int iFlags)
{
	if (iFlags)
	{
		if (g_bFinalMap)
		{
			if (L4D2_GetCurrentFinaleStage() != 18) //防止结局地图特感产生在结局区域之外
			{
				return !(iFlags & TERROR_NAV_STOP_SCAN) && !(iFlags & TERROR_NAV_RESCUE_CLOSET) && (iFlags & TERROR_NAV_FINALE);
			}
		}
		return !(iFlags & TERROR_NAV_STOP_SCAN) && !(iFlags & TERROR_NAV_RESCUE_CLOSET);
	}
	return true;
}

void GetSurPos()
{
	g_aSurPosData.Clear();
	static SurPosData data;
	static int i;

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			data.fFlow = L4D2Direct_GetFlowDistance(i);
			GetClientEyePosition(i, data.fPos);
			g_aSurPosData.PushArray(data);
		}
	}

	g_iSurPosDataLength = g_aSurPosData.Length;
}

bool IsNearTheSur(const float fAreaFlow, const float fAreaSpawnPos[3], float &fDist)
{
	static SurPosData data;
	static int i;

	for (i = 0; i < g_iSurPosDataLength; i++)
	{
		g_aSurPosData.GetArray(i, data);
		if (FloatAbs(fAreaFlow - data.fFlow) <= g_fSpawnDist)
		{
			fDist = GetVectorDistance(data.fPos, fAreaSpawnPos);
			if (fDist <= g_fSpawnDist)
			{
				return true;
			}
		}
	}
	return false;
}

bool IsSurVisible(const float fAreaSpawnPos[3], NavArea pArea)
{
	static int i;
	static float fTargetPos[3];

	fTargetPos = fAreaSpawnPos;
	fTargetPos[2] += 62.0; //眼睛位置

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			if (SDKCall(g_hSDKIsVisibleToPlayer, fTargetPos, i, 2, 3, 0.0, 0, pArea, true))
			{
				return true;
			}
		}
	}

	return false;
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

int GetRandomSur()
{
	static int client, i;

	client = 0;
	g_aClientsArray.Clear();
	SetRandomSeed(GetTime());

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			g_aClientsArray.Push(i);
		}
	}

	if (g_aClientsArray.Length > 0)
	{
		client = g_aClientsArray.Get(GetRandomInt(0, g_aClientsArray.Length - 1));
	}

	return client;
}

int FindSpawnClass()
{
	static int iClass, i;
	int iSpecialCount[7];
	g_aClassArray.Clear();

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsFakeClient(i) && g_bMark[i])
		{
			iClass = GetZombieClass(i);
			if (1 <= iClass <= 6)
			{
				iSpecialCount[iClass]++;
			}
		}
	}

	for (i = 1; i <= 6; i++)
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

	return iClass;
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
	if (g_bLeftSafeArea)
	{
		static int iVictim, iAttacker;

		iVictim = GetClientOfUserId(event.GetInt("userid"));
		iAttacker = GetClientOfUserId(event.GetInt("attacker"));

		g_fSpecialActionTime[iVictim] = GetEngineTime();
		g_fSpecialActionTime[iAttacker] = GetEngineTime();
	}
}

public void L4D_OnSpawnSpecial_Post(int client, int zombieClass, const float vecPos[3], const float vecAng[3])
{
	if (client > 0)
		g_fSpecialActionTime[client] = GetEngineTime();
}

Action KillSICheck_Timer(Handle timer)
{
	if (g_bLeftSafeArea)
	{
		static int iClass, i;
		static float fEngineTime;
		fEngineTime = GetEngineTime();

		for (i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsFakeClient(i))
			{
				iClass = GetZombieClass(i);
				if (1 <= iClass <= 6)
				{
					if (fEngineTime - g_fSpecialActionTime[i] > g_fKillSITime)
					{
						if (!GetEntProp(i, Prop_Send, "m_hasVisibleThreats") && !HasSurVictim(i, iClass))
						{
							ForcePlayerSuicide(i);
						}
						else g_fSpecialActionTime[i] = fEngineTime;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

bool HasSurVictim(int client, int iClass)
{
	switch (iClass)
	{
		case SMOKER:
			return GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0;
		case HUNTER:
			return GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0;
		case JOCKEY:
			return GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0;
		case CHARGER:
			return GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0;
	}
	return false;
}

int GetAllSpecialsTotal()
{
	static int iCount, i;
	iCount = 0;

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsFakeClient(i) && g_bMark[i])
		{
			switch (GetZombieClass(i))
			{
				case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER:
				{
					iCount++;
				}
			}
		}
	}
	return iCount;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

static const char g_sSpecialName[][] =
{
	"", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"
};

//阻止本插件以外的特感产生
public Action L4D_OnSpawnSpecial(int &zombieClass, const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawn && g_bBlockSpawn)
	{
		LogMessage("不是本插件产生的 %s, 已阻止", g_sSpecialName[zombieClass]);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action kickbot(Handle timer, int userid)
{
	static int client;
	client = GetClientOfUserId(userid);
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client))
	{
		if (!IsClientInKickQueue(client)) KickClient(client);
	}
	return Plugin_Continue;
}

void Init()
{
	GameData hGameData = new GameData(GAMEDATA);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iSpawnAttributesOffset = hGameData.GetOffset("TerrorNavArea::SpawnAttributes");
	if (g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: TerrorNavArea::SpawnAttributes");

	g_iFlowDistanceOffset = hGameData.GetOffset("TerrorNavArea::FlowDistance");
	if(g_iFlowDistanceOffset == -1)
		SetFailState("Failed to find offset: TerrorNavArea::FlowDistance");

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

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "IsVisibleToPlayer"))
		SetFailState("Failed to find signature: IsVisibleToPlayer");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);									// 目标点位
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);								// 客户端
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);								// 客户端团队
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);								// 目标点位团队, 如果为0将考虑客户端的角度
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);										// 不清楚
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWWORLD);	// 不清楚
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);							// 目标点位 NavArea 区域
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);									// 如果为 false，将自动获取目标点位的 NavArea (GetNearestNavArea)
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsVisibleToPlayer = EndPrepSDKCall();
	if (g_hSDKIsVisibleToPlayer == null)
		SetFailState("Failed to create SDKCall: IsVisibleToPlayer");

	MemoryPatch mPatch = MemoryPatch.CreateFromConf(hGameData, "CDirector::GetMaxPlayerZombies");
	if (!mPatch.Validate())
		SetFailState("Verify patch failed.");
	if (!mPatch.Enable())
		SetFailState("Enable patch failed.");

	delete hGameData;
}

Action Cmd_CvarPrint(int client, int args)
{
	ReplyToCommand(client, "--------------");
	ReplyToCommand(client, "L4D2 Special infected spawn control Cvar:");
	char sVer[12];
	FindConVar("l4d2_si_spawn_control_version").GetString(sVer, sizeof(sVer));
	ReplyToCommand(client, "l4d2_si_spawn_control_version = %s", sVer);
	ReplyToCommand(client, "l4d2_si_spawn_control_hunter_limit = %i", FindConVar("l4d2_si_spawn_control_hunter_limit").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_jockey_limit = %i", FindConVar("l4d2_si_spawn_control_jockey_limit").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_smoker_limit = %i", FindConVar("l4d2_si_spawn_control_smoker_limit").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_boomer_limit = %i", FindConVar("l4d2_si_spawn_control_boomer_limit").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_spitter_limit = %i", FindConVar("l4d2_si_spawn_control_spitter_limit").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_charger_limit = %i", FindConVar("l4d2_si_spawn_control_charger_limit").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_max_specials = %i", FindConVar("l4d2_si_spawn_control_max_specials").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_spawn_time = %.1f", FindConVar("l4d2_si_spawn_control_spawn_time").FloatValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_first_spawn_time = %.1f", FindConVar("l4d2_si_spawn_control_first_spawn_time").FloatValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_kill_si_time = %.1f", FindConVar("l4d2_si_spawn_control_kill_si_time").FloatValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_block_other_si_spawn = %i", FindConVar("l4d2_si_spawn_control_block_other_si_spawn").IntValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_radical_spawn = %b", FindConVar("l4d2_si_spawn_control_radical_spawn").BoolValue);
	ReplyToCommand(client, "l4d2_si_spawn_control_spawn_range_normal = %i", FindConVar("l4d2_si_spawn_control_spawn_range_normal").IntValue);
	ReplyToCommand(client, "--------------");

	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D2_CanSpawnSpecial", Native_CanSpawnSpecial);
	RegPluginLibrary("l4d2_si_spawn_control");
	return APLRes_Success;
}

// L4D2_CanSpawnSpecial(bool bCanSpawn);
int Native_CanSpawnSpecial(Handle plugin, int numParams)
{
	bool bCanSpawn = GetNativeCell(1);
	g_bCanSpawn = bCanSpawn;
	return 0;
}
