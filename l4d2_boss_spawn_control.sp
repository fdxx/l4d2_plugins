#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>

#if DEBUG
#include <profiler>
#endif

#define VERSION "2.1"

#define GAMEDATA "l4d2_nav_area"
#define BOSS_SURVIVOR_SAFE_DISTANCE 2200.0	//boss和生还者之间的安全距离(考虑Flow转换)
#define TANK_WITCH_SAFE_FLOW 0.15			//witch和tank之间的安全流距离
#define BOSS_MIN_SPAWN_FLOW 0.20
#define BOSS_MAX_SPAWN_FLOW 0.90

ConVar CvarDirectorNoBoss;
ConVar CvarTankSpawnEnable, CvarWitchSpawnEnable;
ConVar CvarBlockTankSpawn, CvarBlockWitchSpawn;
bool g_bTankSpawnEnable, g_bWitchSpawnEnable;
bool g_bBlockTankSpawn, g_bBlockWitchSpawn;

float g_fTankSpawnFlow, g_fWitchSpawnFlow;
float g_fTankSpawnPos[3], g_fWitchSpawnPos[3];
float g_fSpawnDistFlow;
float g_fMapMaxFlowDist;

bool g_bStaticTankMap = true;
bool g_bStaticWitchMap = true;
bool g_bLeftSafeArea;

bool g_bShowFlow[MAXPLAYERS];
bool g_bCanSpawnTank, g_bCanSpawnWitch;

Handle g_hTankFlowCheckTimer, g_hWitchFlowCheckTimer;

Handle g_hSDKFindRandomSpot;
int g_iSpawnAttributesOffset, g_iFlowDistanceOffset, g_iNavAreaCount;
Address g_pTheNavAreas;

char g_sLogPath[PLATFORM_MAX_PATH];

enum struct g_eSpawanInfo
{
	float fFlow;
    float fSpawnPos[3];
}

//https://github.com/KitRifty/sourcepawn-navmesh/blob/master/addons/sourcemod/scripting/include/navmesh.inc
//https://developer.valvesoftware.com/wiki/List_of_L4D_Series_Nav_Mesh_Attributes:zh-cn
enum
{
	TERROR_NAV_EMPTY				= 2,			//防止只有游荡/休息的普通感染者生成。有助于防止普通感染者在它们不起作用的地方生成，通常在幸存者的可玩区域之外（例如建筑屋顶)。
	TERROR_NAV_STOP					= 4,			//感染者 AI 不会通过这个导航。如果STOP_SCAN属性占据了一个路径入口，如果所有幸存者都通过它，感染者将在入口之外生成。
	TERROR_NAV_FINALE				= 64,			//表示终局区域。其他特征类似于BATTLEFIELD属性。这应该在您的终局的导航区域广泛使用，并在其中包含一个BATTLESTATION属性。
	TERROR_NAV_PLAYER_START			= 128,			//此属性将应用于玩家生成的确切导航区域区域，因此流(Flow)计算将按预期工作。仅对每个战役的第一章是必需的（即“每个战役的第一章必须有此属性”)。
	TERROR_NAV_BATTLEFIELD			= 256,			//一旦恐慌事件开始，所有感染者 AI 只会在BATTLEFIELD属性指定的区域生成，这意味着如果幸存者设法走出这些区域，感染者的生成就会停止。
	TERROR_NAV_IGNORE_VISIBILITY	= 512,
	TERROR_NAV_NOT_CLEARABLE		= 1024,			//防止某个导航区域被幸存者标记为“已清除”,否则将禁止非玩家感染者生成；一旦幸存者看到一个导航区域，它就会被“清除”,并移除所有生成的感染者。
	TERROR_NAV_CHECKPOINT			= 2048,			//指定地图的起始/过渡区域。当一个幸存者离开这个区域时，回合开始，以所有和只有幸存者站在此导航属性上面，并把安全室的门关上，回合便结束。
	TERROR_NAV_OBSCURED				= 4096,			//一个非常强大的导航属性；即使在幸存者的视线范围内，也允许感染者生成。用于视觉模糊但导演未考虑的导航区域。
	TERROR_NAV_NO_MOBS				= 8192,			//防止丧尸和玩家 Tank 生成，但也防止特殊感染者在BATTLEFIELD导航区域生成。适合让丧尸生成理想或更有趣的区域，或者让丧尸远离导致不自然生成的已知区域。
	TERROR_NAV_THREAT				= 16384,		//作为终极感染者 AI (Tank 和 Witch) 的生成建议区域。
	TERROR_NAV_RESCUE_VEHICLE		= 32768,		//禁用导航区域，直到触发 info_director 输入“FinaleEscapeVehicleReadyForSurvivors”,然后使用此属性取消禁用导航区域。
	TERROR_NAV_RESCUE_CLOSET		= 65536,		//一个救援壁橱房间，波及DOOR属性所包含的属性。流浪者不得进入。在nav_analyze会话期间自动分配。
	TERROR_NAV_NOTHREAT				= 524288,		//禁止THREAT属性执行任何操作，如果它应用于同一导航区域。
	TERROR_NAV_LYINGDOWN			= 1048576,		//当未被玩家唤醒时，普通感染者躺下休息。
};

//https://github.com/umlka/l4d2/blob/main/safearea_teleport/safearea_teleport.sp
methodmap Address
{
	public bool IsNull()
	{
		return this == Address_Null;
	}

	public void GetSpawnPos(float fPos[3])
	{
		SDKCall(g_hSDKFindRandomSpot, view_as<int>(this), fPos, sizeof(fPos));
	}

	property int SpawnAttributes
	{
		public get()
		{
			return LoadFromAddress(this + view_as<Address>(g_iSpawnAttributesOffset), NumberType_Int32);
		}
	}
	
	property float Flow
	{
		public get()
		{
			return view_as<float>(LoadFromAddress(this + view_as<Address>(g_iFlowDistanceOffset), NumberType_Int32));
		}
	}
};

public Plugin myinfo = 
{
	name = "L4D2 Boss spawn control",
	author = "fdxx",
	description = "Set tank and witch spawn on every map",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_boss_spawn_control.log");

	CvarDirectorNoBoss = FindConVar("director_no_bosses");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

	CreateConVar("l4d2_boss_spawn_control_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	CvarTankSpawnEnable = CreateConVar("l4d2_boss_spawn_control_tank_enable", "1", "每个关卡产生一个Tank, 结局地图和第三方地图除外", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarWitchSpawnEnable = CreateConVar("l4d2_boss_spawn_control_witch_enable", "1", "每个关卡产生一个Witch, 结局地图和第三方地图除外", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarBlockTankSpawn = CreateConVar("l4d2_boss_spawn_control_block_other_tank_spawn", "1", "阻止本插件以外的Tank产生 (通过L4D_OnSpawnTank)", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarBlockWitchSpawn = CreateConVar("l4d2_boss_spawn_control_block_other_witch_spawn", "1", "阻止本插件以外的Witch产生 (通过L4D_OnSpawnWitch)", FCVAR_NONE, true, 0.0, true, 1.0);
	
	GetCvars();

	CvarTankSpawnEnable.AddChangeHook(ConVarChange);
	CvarWitchSpawnEnable.AddChangeHook(ConVarChange);
	CvarBlockTankSpawn.AddChangeHook(ConVarChange);
	CvarBlockWitchSpawn.AddChangeHook(ConVarChange);

	RegConsoleCmd("sm_boss", Bossflow);
	RegConsoleCmd("sm_tank", Bossflow);
	RegConsoleCmd("sm_witch", Bossflow);
	RegConsoleCmd("sm_cur", Bossflow);
	RegConsoleCmd("sm_current", Bossflow);

	//DEBUG
	RegAdminCmd("sm_flowhud", ShowFlowHud, ADMFLAG_ROOT);
	RegAdminCmd("sm_reflow", ReFlow, ADMFLAG_ROOT);
	RegAdminCmd("sm_setflow_test", SetFlow_Test, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d2_boss_spawn_control");
}

public void OnConfigsExecuted()
{
	if (g_bTankSpawnEnable || g_bWitchSpawnEnable)
	{
		CvarDirectorNoBoss.SetInt(1);
	}
	else CvarDirectorNoBoss.SetInt(0);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();

	if (g_bTankSpawnEnable || g_bWitchSpawnEnable)
	{
		CvarDirectorNoBoss.SetInt(1);
	}
	else CvarDirectorNoBoss.SetInt(0);
}

void GetCvars()
{
	g_bTankSpawnEnable = CvarTankSpawnEnable.BoolValue;
	g_bWitchSpawnEnable = CvarWitchSpawnEnable.BoolValue;
	g_bBlockTankSpawn = CvarBlockTankSpawn.BoolValue;
	g_bBlockWitchSpawn = CvarBlockWitchSpawn.BoolValue;
}

public void OnMapStart()
{
	if (g_bTankSpawnEnable) PrecacheSound("ui/pickup_secret01.wav");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(2.0, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStart_Timer(Handle timer)
{
	//LogToFileEx_Debug("====================   Map: %s   ====================", CurrentMap());

	Reset();
	GetMapNavAreaData();

	g_bStaticTankMap = StaticTankMap();
	g_bStaticWitchMap = StaticWitchMap();
	g_fMapMaxFlowDist = L4D2Direct_GetMapMaxFlowDistance();
	g_fSpawnDistFlow = (BOSS_SURVIVOR_SAFE_DISTANCE / g_fMapMaxFlowDist);

	SetBossSpawnFlow();
}

void SetBossSpawnFlow()
{
	#if DEBUG
	Profiler hProfiler = new Profiler();
	hProfiler.Start();
	#endif

	static Address pThisArea, pThreatArea;
	static int iFlags;
	static float fThisSpawnPos[3], fThreatSpawnPos[3], fThisFlowDist;
	static float fTriggerSpawnFlow;
	static g_eSpawanInfo eSpawanInfo;

	int iValidPosCount, iPosCount;

	ArrayList aThreatAreaArray = new ArrayList();
	ArrayList aSpawnDataArray = new ArrayList(sizeof(g_eSpawanInfo));

	//保存Threat区域
	for (int i = 1; i < g_iNavAreaCount; i++)
	{
		pThisArea = view_as<Address>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32));
		if (!pThisArea.IsNull())
		{
			iFlags = pThisArea.SpawnAttributes;
			if (iFlags && (iFlags & TERROR_NAV_THREAT))
			{
				aThreatAreaArray.Push(pThisArea);
				//pThisArea.GetSpawnPos(fThreatSpawnPos);
				//LogToFileEx_Debug("fThreatFlow = %.2f, fThreatSpawnPos(%.1f %.1f %.1f)", (pThisArea.Flow/g_fMapMaxFlowDist*100.0), fThreatSpawnPos[0], fThreatSpawnPos[1], fThreatSpawnPos[2]);
			}
		}
	}

	//保存Threat区域附近点位
	for (int p = 0; p < aThreatAreaArray.Length; p++)
	{
		pThreatArea = aThreatAreaArray.Get(p);
		pThreatArea.GetSpawnPos(fThreatSpawnPos);

		for (int i = 1; i < g_iNavAreaCount; i++)
		{
			pThisArea = view_as<Address>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32));
			if (!pThisArea.IsNull())
			{
				if (pThisArea.SpawnAttributes)
				{
					fThisFlowDist = pThisArea.Flow;
					if (0.0 < fThisFlowDist < g_fMapMaxFlowDist)
					{
						if (FloatAbs((fThisFlowDist/g_fMapMaxFlowDist) - (pThreatArea.Flow/g_fMapMaxFlowDist)) <= 0.03)
						{
							pThisArea.GetSpawnPos(fThisSpawnPos);
							if (GetVectorDistance(fThisSpawnPos, fThreatSpawnPos) <= 300.0)
							{
								iPosCount++;
								if (!IsWillStuck(fThisSpawnPos))
								{
									if (L4D2Direct_GetTerrorNavArea(fThisSpawnPos) != Address_Null)
									{
										fTriggerSpawnFlow = (fThisFlowDist/g_fMapMaxFlowDist) - g_fSpawnDistFlow;
										if (BOSS_MIN_SPAWN_FLOW <= fTriggerSpawnFlow <= BOSS_MAX_SPAWN_FLOW)
										{
											iValidPosCount++;
											eSpawanInfo.fFlow = fTriggerSpawnFlow;
											eSpawanInfo.fSpawnPos = fThisSpawnPos;
											aSpawnDataArray.PushArray(eSpawanInfo);
											//LogToFileEx_Debug("fThisSpawnPos(%.1f %.1f %.1f)", fThisSpawnPos[0], fThisSpawnPos[1], fThisSpawnPos[2]);
										}
									}
									//else LogToFileEx_Debug("无效 Flow: %.3f", fTriggerSpawnFlow);
								}
								//else LogToFileEx_Debug("无效点位会卡住");
							}
						}
					}
				}
			}
		}
	}

	//PrintBossSpawnData(aSpawnDataArray, 1);

	//设置Tank产生点
	if (!g_bStaticTankMap)
	{
		if (aSpawnDataArray.Length > 0)
		{
			int iRandomIndex = GetRandomInt(0, aSpawnDataArray.Length - 1);
			aSpawnDataArray.GetArray(iRandomIndex, eSpawanInfo);

			g_fTankSpawnPos = eSpawanInfo.fSpawnPos;
			g_fTankSpawnFlow = eSpawanInfo.fFlow;

			aSpawnDataArray.Erase(iRandomIndex);
		}
		else g_fTankSpawnFlow = 0.0;
	}
	else g_fTankSpawnFlow = 0.0;

	//PrintBossSpawnData(aSpawnDataArray, 2);

	//设置witch产生点
	if (!g_bStaticWitchMap)
	{
		if (aSpawnDataArray.Length > 0)
		{
			bool bValidPos;

			for (int i = 0; i < 200; i++)
			{
				aSpawnDataArray.GetArray(GetRandomInt(0, aSpawnDataArray.Length - 1), eSpawanInfo);

				//Tank和Witch间隔一定距离
				if (FloatAbs(g_fTankSpawnFlow - eSpawanInfo.fFlow) > TANK_WITCH_SAFE_FLOW)
				{
					bValidPos = true;
					break;
				}
				//LogToFileEx_Debug("[%i] 距离 = %.2f", i, FloatAbs(g_fTankSpawnFlow - eSpawanInfo.fFlow));
			}

			if (bValidPos)
			{
				g_fWitchSpawnPos = eSpawanInfo.fSpawnPos;
				g_fWitchSpawnFlow = eSpawanInfo.fFlow;
			}
			else g_fWitchSpawnFlow = 0.0;
		}
		else g_fWitchSpawnFlow = 0.0;
	}
	else g_fWitchSpawnFlow = 0.0;

	#if DEBUG
	hProfiler.Stop();
	LogToFileEx_Debug("区域 %i 个, 点位 %i 个, 有效点位 %i 个, 执行时间: %f", aThreatAreaArray.Length, iPosCount, iValidPosCount, hProfiler.Time);
	LogToFileEx_Debug("TankSpawnFlow(%.1f %.1f %.1f) = %i, WitchSpawnFlow(%.1f %.1f %.1f) = %i", g_fTankSpawnPos[0], g_fTankSpawnPos[1], g_fTankSpawnPos[2], RoundToNearest(g_fTankSpawnFlow * 100.0), g_fWitchSpawnPos[0], g_fWitchSpawnPos[1], g_fWitchSpawnPos[2], RoundToNearest(g_fWitchSpawnFlow * 100.0));
	delete hProfiler;
	#endif

	delete aThreatAreaArray;
	delete aSpawnDataArray;
}

bool IsWillStuck(const float fPos[3])
{
	bool bStuck;

	//似乎所有客户端大小都一样
	static const float fTankMinSize[3] = {-16.0, -16.0, 0.0};
	static const float fTankMaxSize[3] = {16.0, 16.0, 71.0};

	Handle hTrace;
	hTrace = TR_TraceHullFilterEx(fPos, fPos, fTankMinSize, fTankMaxSize, MASK_PLAYERSOLID, TraceFilter);
	bStuck = TR_DidHit(hTrace);
	delete hTrace;

	return bStuck;
}

public bool TraceFilter(int entity, int contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	return true;
}

stock void PrintBossSpawnData(ArrayList aSpawnDataArray, int iNum)
{
	g_eSpawanInfo eSpawanInfo;
	float fThisSpawnFlow, fThisSpawnPos[3];

	for (int i = 0; i < aSpawnDataArray.Length; i++)
	{
		aSpawnDataArray.GetArray(i, eSpawanInfo);
		fThisSpawnFlow = eSpawanInfo.fFlow;
		fThisSpawnPos = eSpawanInfo.fSpawnPos;
		LogToFileEx_Debug("[检查数组 %i] (%i) fThisSpawnFlow: %.3f, fThisSpawnPos: (%.0f %.0f %.0f)", iNum, i, fThisSpawnFlow, fThisSpawnPos[0], fThisSpawnPos[1], fThisSpawnPos[2]);
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
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

	g_bStaticTankMap = true;
	g_bStaticWitchMap = true;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	g_bLeftSafeArea = true;

	if (g_bTankSpawnEnable && g_fTankSpawnFlow > 0.0)
	{
		delete g_hTankFlowCheckTimer;
		g_hTankFlowCheckTimer = CreateTimer(0.5, TankSpawnCheck_Timer, _, TIMER_REPEAT);
	}

	if (g_bWitchSpawnEnable && g_fWitchSpawnFlow > 0.0)
	{
		delete g_hWitchFlowCheckTimer;
		g_hWitchFlowCheckTimer = CreateTimer(0.5, WitchSpawnCheck_Timer, _, TIMER_REPEAT);
	}

	PrintBossflow();

	return Plugin_Continue;
}

public Action TankSpawnCheck_Timer(Handle timer)
{
	if (g_bTankSpawnEnable && g_fTankSpawnFlow > 0.0 && g_bLeftSafeArea)
	{
		if (fSurMaxFlow() >= g_fTankSpawnFlow)
		{
			CreateTimer(0.1, SpawnTank_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
			g_hTankFlowCheckTimer = null;
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	else
	{
		g_hTankFlowCheckTimer = null;
		return Plugin_Stop;
	}
}

public Action SpawnTank_Timer(Handle timer)
{
	if (g_bTankSpawnEnable && g_fTankSpawnFlow > 0.0 && g_bLeftSafeArea)
	{
		g_bCanSpawnTank = true;
		bool bSpawnSuccess = L4D2_SpawnTank(g_fTankSpawnPos, NULL_VECTOR) > 0;
		g_bCanSpawnTank = false;
		
		if (!bSpawnSuccess)
		{
			LogError("产生Tank失败, g_fTankSpawnFlow = %.3f, g_fTankSpawnPos(%.0f %.0f %.0f)", g_fTankSpawnFlow, g_fTankSpawnPos[0], g_fTankSpawnPos[1], g_fTankSpawnPos[2]);
			CPrintToChatAll("{default}[{yellow}提示{default}] WTF bug? 产生{olive}Tank{default}失败");
		}
	}
}

public Action WitchSpawnCheck_Timer(Handle timer)
{
	if (g_bWitchSpawnEnable && g_fWitchSpawnFlow > 0.0 && g_bLeftSafeArea)
	{
		if (fSurMaxFlow() >= g_fWitchSpawnFlow)
		{
			CreateTimer(0.1, SpawnWitch_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
			g_hWitchFlowCheckTimer = null;
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	else
	{
		g_hWitchFlowCheckTimer = null;
		return Plugin_Stop;
	}
}

public Action SpawnWitch_Timer(Handle timer)
{
	if (g_bWitchSpawnEnable && g_fWitchSpawnFlow > 0.0 && g_bLeftSafeArea)
	{
		g_bCanSpawnWitch = true;
		bool bSpawnSuccess = L4D2_SpawnWitch(g_fWitchSpawnPos, NULL_VECTOR) > 0;
		g_bCanSpawnWitch = false;
		
		if (!bSpawnSuccess)
		{
			LogError("产生Witch失败, g_fWitchSpawnFlow = %.3f, g_fWitchSpawnPos(%.0f %.0f %.0f)", g_fWitchSpawnFlow, g_fWitchSpawnPos[0], g_fWitchSpawnPos[1], g_fWitchSpawnPos[2]);
			CPrintToChatAll("{default}[{yellow}提示{default}] WTF bug? 产生{olive}Witch{default}失败");
		}
	}
}

public Action Bossflow(int client, int args)
{
	PrintBossflow();
}

public Action ReFlow(int client, int args)
{
	if (!g_bLeftSafeArea)
	{
		SetBossSpawnFlow();
		PrintBossflow();
	}
	else PrintToChat(client, "已离开安全区域，无法设置");
}

public Action SetFlow_Test(int client, int args)
{
	if (!g_bLeftSafeArea)
	{
		CreateTimer(1.5, SetFlowTest_Timer, _, TIMER_REPEAT);
	}
}

public Action SetFlowTest_Timer(Handle timer)
{
	static int iTestSetFlowcount;
	iTestSetFlowcount++;
	LogToFileEx_Debug("第 %i 次 TestSetFlow", iTestSetFlowcount);
	SetBossSpawnFlow();
}

void PrintBossflow()
{
	int SurvivorMaxFlow = RoundToNearest(fSurMaxFlow() * 100.0);
	CPrintToChatAll("Current: {yellow}%i {default}%%", SurvivorMaxFlow);

	if (g_bTankSpawnEnable)
	{
		if (g_fTankSpawnFlow > 0.0)
		{
			int iTankSpawnFlow = RoundToNearest(g_fTankSpawnFlow * 100.0);
			CPrintToChatAll("Tank: {yellow}%i {default}%%", iTankSpawnFlow);
		}
		else CPrintToChatAll("Tank: {yellow}None");
	}

	if (g_bWitchSpawnEnable)
	{
		if (g_fWitchSpawnFlow > 0.0)
		{
			int iWitchSpawnFlow = RoundToNearest(g_fWitchSpawnFlow * 100.0);
			CPrintToChatAll("Witch: {yellow}%i {default}%%", iWitchSpawnFlow);
		}
		else CPrintToChatAll("Witch: {yellow}None");
	}
}

public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawnTank && g_bBlockTankSpawn && !g_bStaticTankMap)
	{
		return Plugin_Handled;
	}

	EmitSoundToAll("ui/pickup_secret01.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
	CPrintToChatAll("{red}[{default}!{red}] {olive}Tank {default}has spawned!");

	return Plugin_Continue;
}

public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawnWitch && g_bBlockWitchSpawn && !g_bStaticWitchMap)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action ShowFlowHud(int client, int args)
{
	g_bShowFlow[client] = !g_bShowFlow[client];
	if (g_bShowFlow[client]) CreateTimer(1.0, ShowFlowHud_Timer, client, TIMER_REPEAT);
	CPrintToChat(client, "Flow 面板状态: {yellow}%s", (g_bShowFlow[client] ? "已开启" : "已关闭"));
}

public Action ShowFlowHud_Timer(Handle timer, int client)
{
	if (g_bShowFlow[client] && IsRealClient(client) && IsAdminClient(client))
	{
		char sBuffer[64];
		Panel panel = new Panel();

		panel.SetTitle("Flow Hud");
		panel.DrawText("__________");

		FormatEx(sBuffer, sizeof(sBuffer), "Current: %i%%", RoundToNearest(fSurMaxFlow() * 100.0));
		panel.DrawText(sBuffer);

		if (g_bTankSpawnEnable)
		{
			if (g_fTankSpawnFlow > 0.0)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "Tank: %i%%", RoundToNearest(g_fTankSpawnFlow * 100.0));
				panel.DrawText(sBuffer);
			}
			else panel.DrawText("Tank: None");
		}

		if (g_bWitchSpawnEnable)
		{
			if (g_fWitchSpawnFlow > 0.0)
			{
				FormatEx(sBuffer, sizeof(sBuffer), "Witch: %i%%", RoundToNearest(g_fWitchSpawnFlow * 100.0));
				panel.DrawText(sBuffer);
			}
			else panel.DrawText("Witch: None");
		}

		panel.Send(client, NullMenuHandler, 2);
		delete panel;

		return Plugin_Continue;
	}
	else
	{
		LogToFileEx_Debug("client %i: Flow HUD已关闭", client);
		g_bShowFlow[client] = false;
		return Plugin_Stop;
	}
}

public int NullMenuHandler(Handle hMenu, MenuAction action, int param1, int param2) {}

bool StaticTankMap()
{
	if (StrEqual(CurrentMap(), "c7m1_docks") || StrEqual(CurrentMap(), "c13m2_southpinestream") || L4D_IsMissionFinalMap() || !IsOfficialMap())
	{
		return true;
	}
	return false;
}

bool StaticWitchMap()
{
	if (StrEqual(CurrentMap(), "c6m1_riverbank") || StrEqual(CurrentMap(), "c4m2_sugarmill_a") || L4D_IsMissionFinalMap() || !IsOfficialMap())
	{
		return true;
	}
	return false;
}

float fSurMaxFlow()
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

bool IsOfficialMap()
{
	static const char sMaplist[][] =
	{
		"c1m1_hotel","c1m2_streets","c1m3_mall","c1m4_atrium",
		"c2m1_highway","c2m2_fairgrounds","c2m3_coaster","c2m4_barns","c2m5_concert",
		"c3m1_plankcountry","c3m2_swamp","c3m3_shantytown","c3m4_plantation",
		"c4m1_milltown_a","c4m2_sugarmill_a","c4m3_sugarmill_b","c4m4_milltown_b","c4m5_milltown_escape",
		"c5m1_waterfront","c5m1_waterfront_sndscape","c5m2_park","c5m3_cemetery","c5m4_quarter","c5m5_bridge",
		"c6m1_riverbank","c6m2_bedlam","c6m3_port",
		"c7m1_docks","c7m2_barge","c7m3_port",
		"c8m1_apartment","c8m2_subway","c8m3_sewers","c8m4_interior","c8m5_rooftop",
		"c9m1_alleys","c9m2_lots",
		"c10m1_caves","c10m2_drainage","c10m3_ranchhouse","c10m4_mainstreet","c10m5_houseboat",
		"c11m1_greenhouse","c11m2_offices","c11m3_garage","c11m4_terminal","c11m5_runway",
		"c12m1_hilltop","c12m2_traintunnel","c12m3_bridge","c12m4_barn","c12m5_cornfield",
		"c13m1_alpinecreek","c13m2_southpinestream","c13m3_memorialbridge","c13m4_cutthroatcreek",
		"c14m1_junkyard","c14m2_lighthouse"
	};
	
	static char sMapName[64];
	GetCurrentMap(sMapName, sizeof(sMapName));

	for (int i; i < sizeof(sMaplist); i++)
	{
		if (strcmp(sMapName, sMaplist[i], false) == 0)
			return true;
	}
	return false;
}

char CurrentMap()
{
	static char sMapName[256];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return sMapName;
}

void GetMapNavAreaData()
{
	GameData hGameData = new GameData(GAMEDATA);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iSpawnAttributesOffset = hGameData.GetOffset("TerrorNavArea::ScriptGetSpawnAttributes");
	if (g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: TerrorNavArea::ScriptGetSpawnAttributes");
	
	g_iFlowDistanceOffset = hGameData.GetOffset("CTerrorPlayer::GetFlowDistance::m_flow");
	if(g_iFlowDistanceOffset == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::GetFlowDistance::m_flow");
	
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavArea::FindRandomSpot") == false)
		SetFailState("Failed to find signature: TerrorNavArea::FindRandomSpot");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	g_hSDKFindRandomSpot = EndPrepSDKCall();
	if(g_hSDKFindRandomSpot == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::FindRandomSpot");

	Address pTheCount = hGameData.GetAddress("TheCount");
	if (pTheCount == Address_Null)
		SetFailState("Failed to find address: TheCount");

	g_pTheNavAreas = view_as<Address>(LoadFromAddress(pTheCount + view_as<Address>(4), NumberType_Int32));
	if (g_pTheNavAreas == Address_Null)
		SetFailState("Failed to find address: TheNavAreas");

	g_iNavAreaCount = LoadFromAddress(pTheCount, NumberType_Int32);
	if (g_iNavAreaCount <= 0)
		LogError("当前地图Nav区域数量为0, 可能是某些测试地图");

	delete hGameData;
}

stock void LogToFileEx_Debug(const char[] format, any ...)
{
	static char buffer[254];
	VFormat(buffer, sizeof(buffer), format, 2);

	#if DEBUG
	LogToFileEx(g_sLogPath, "%s", buffer);
	#endif
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

bool IsAdminClient(int client)
{
	int iFlags = GetUserFlagBits(client);
	if ((iFlags != 0) && (iFlags & ADMFLAG_ROOT)) 
	{
		return true;
	}
	return false;
}


