#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>

#if DEBUG
#include <profiler>
#endif

#define VERSION "2.1"

#define GAMEDATA "l4d2_nav_area"
#define MAX_VALID_POS 3000

#define SMOKER	1
#define BOOMER	2
#define HUNTER	3
#define SPITTER	4
#define JOCKEY	5
#define CHARGER	6
#define TANK	8
#define NUMBER_OF_ATTEMPTS 30

static const char g_sSpecialName[][] =
{
	"", "smoker", "boomer", "hunter", "spitter", "jockey", "charger"
};

ConVar CvarHunterLimit, CvarJockeyLimit, CvarSmokerLimit, CvarBoomerLimit, CvarSpitterLimit, CvarChargerLimit, CvarMaxSILimit;
ConVar CvarSpawnTime, CvarFirstSpawnTime, CvarKillSITime;
ConVar CvarBlockSpawn;
ConVar CvarRadicalSpawn, CvarNormalSpawnRange;

int g_iHunterLimit, g_iJockeyLimit, g_iSmokerLimit, g_iBoomerLimit, g_iSpitterLimit, g_iChargerLimit, g_iMaxSILimit;
float g_fSpawnTime, g_fFirstSpawnTime, g_fKillSITime;
bool g_bBlockSpawn, g_bCanSpawn, g_bRadicalSpawn;
int g_iNormalSpawnRange;

float g_fMapMaxFlowDist, g_fSpawnDist;

int g_iSpawnTimerNum;
Handle g_hSpawnSITimer[MAXPLAYERS+1], g_hKillSITimer[MAXPLAYERS+1];
Handle g_hFirstSpawnSITimer, g_hSpawnMaxSITimer;

bool g_bShowSIhud[MAXPLAYERS+1], g_bLeftSafeArea;
bool g_bFinalMap;

char g_sLogPath[PLATFORM_MAX_PATH];

Handle g_hSDKFindRandomSpot;
int g_iSpawnAttributesOffset, g_iFlowDistanceOffset, g_iNavAreaCount;
Address g_pTheNavAreas;

ArrayList g_aClientsArray, g_aSurPosData;

enum struct g_esSurPosData
{
	float fPos[3];
	float fFlow;
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

	/*
	public void GetMinPos(float fPos[3])
	{
		fPos[0] = view_as<float>(LoadFromAddress(this + view_as<Address>(4), NumberType_Int32));
		fPos[1] = view_as<float>(LoadFromAddress(this + view_as<Address>(8), NumberType_Int32));
		fPos[2] = view_as<float>(LoadFromAddress(this + view_as<Address>(12), NumberType_Int32));
	}

	public void GetMaxPos(float fPos[3])
	{
		fPos[0] = view_as<float>(LoadFromAddress(this + view_as<Address>(16), NumberType_Int32));
		fPos[1] = view_as<float>(LoadFromAddress(this + view_as<Address>(20), NumberType_Int32));
		fPos[2] = view_as<float>(LoadFromAddress(this + view_as<Address>(24), NumberType_Int32));
	}
	
	public void GetCenterPos(float fPos[3])
	{
		static float fMin[3];
		static float fMax[3];

		fMin[0] = view_as<float>(LoadFromAddress(this + view_as<Address>(4), NumberType_Int32));
		fMin[1] = view_as<float>(LoadFromAddress(this + view_as<Address>(8), NumberType_Int32));
		fMin[2] = view_as<float>(LoadFromAddress(this + view_as<Address>(12), NumberType_Int32));

		fMax[0] = view_as<float>(LoadFromAddress(this + view_as<Address>(16), NumberType_Int32));
		fMax[1] = view_as<float>(LoadFromAddress(this + view_as<Address>(20), NumberType_Int32));
		fMax[2] = view_as<float>(LoadFromAddress(this + view_as<Address>(24), NumberType_Int32));

		AddVectors(fMin, fMax, fPos);
		ScaleVector(fPos, 0.5);
	}
	*/
	
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
		/*
		public set(int value)
		{
			StoreToAddress(this + view_as<Address>(g_iSpawnAttributesOffset), value, NumberType_Int32);
		}*/
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
	name = "L4D2 Special infected spawn control",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_si_spawn_control.log");

	CreateConVar("l4d2_si_spawn_control_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarHunterLimit = CreateConVar("l4d2_si_spawn_control_hunter_limit", "1", "Hunter数量", FCVAR_NONE, true, 0.0, true, 26.0);
	CvarJockeyLimit = CreateConVar("l4d2_si_spawn_control_jockey_limit", "1", "jockey数量", FCVAR_NONE, true, 0.0, true, 26.0);
	CvarSmokerLimit = CreateConVar("l4d2_si_spawn_control_smoker_limit", "1", "smoker数量", FCVAR_NONE, true, 0.0, true, 26.0);
	CvarBoomerLimit = CreateConVar("l4d2_si_spawn_control_boomer_limit", "1", "boomer数量", FCVAR_NONE, true, 0.0, true, 26.0);
	CvarSpitterLimit = CreateConVar("l4d2_si_spawn_control_spitter_limit", "1", "spitter数量", FCVAR_NONE, true, 0.0, true, 26.0);
	CvarChargerLimit = CreateConVar("l4d2_si_spawn_control_charger_limit", "1", "charger数量", FCVAR_NONE, true, 0.0, true, 26.0);
	CvarMaxSILimit = CreateConVar("l4d2_si_spawn_control_max_specials", "6", "最大特感数量", FCVAR_NONE, true, 0.0, true, 26.0);
	CvarSpawnTime = CreateConVar("l4d2_si_spawn_control_spawn_time", "10.0", "特感产生时间", FCVAR_NONE, true, 2.0, true, 9999.0);
	CvarFirstSpawnTime = CreateConVar("l4d2_si_spawn_control_first_spawn_time", "10.0", "离开安全区域首次产生特感的时间", FCVAR_NONE, true, 1.0, true, 9999.0);
	CvarKillSITime = CreateConVar("l4d2_si_spawn_control_kill_si_time", "25.0", "多少秒后摸鱼的特感将会被自动杀死", FCVAR_NONE, true, 2.0, true, 9999.0);
	CvarBlockSpawn = CreateConVar("l4d2_si_spawn_control_block_other_si_spawn", "1", "阻止本插件以外的特感产生 (通过L4D_OnSpawnSpecial限制)", FCVAR_NONE, true, 0.0, true, 1.0);

	//阴间找位对服务器性能要求比较高，谨慎使用
	CvarRadicalSpawn = CreateConVar("l4d2_si_spawn_control_radical_spawn", "0", "开启特感阴间找位, 将会在距离生还者最近的地方产生", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarNormalSpawnRange = CreateConVar("l4d2_si_spawn_control_spawn_range_normal", "1500", "普通特感产生范围，从1到这个范围随机产生", FCVAR_NONE, true, 1.0);
	
	GetCvars();

	CvarHunterLimit.AddChangeHook(ConVarChanged);
	CvarJockeyLimit.AddChangeHook(ConVarChanged);
	CvarSmokerLimit.AddChangeHook(ConVarChanged);
	CvarBoomerLimit.AddChangeHook(ConVarChanged);
	CvarSpitterLimit.AddChangeHook(ConVarChanged);
	CvarChargerLimit.AddChangeHook(ConVarChanged);
	CvarMaxSILimit.AddChangeHook(ConVarChanged);
	CvarSpawnTime.AddChangeHook(ConVarChanged);
	CvarFirstSpawnTime.AddChangeHook(ConVarChanged);
	CvarKillSITime.AddChangeHook(ConVarChanged);
	CvarBlockSpawn.AddChangeHook(ConVarChanged);

	CvarRadicalSpawn.AddChangeHook(ConVarChanged);
	CvarNormalSpawnRange.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);

	RegAdminCmd("sm_sihud", Cmd_ShowSIhud, ADMFLAG_ROOT);
	RegConsoleCmd("sm_sicvar", Cmd_CvarPrint);
	RegConsoleCmd("sm_si_cvar", Cmd_CvarPrint);

	TweakSettings();

	g_aClientsArray = new ArrayList();
	g_aSurPosData = new ArrayList(sizeof(g_esSurPosData));
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();

	//游戏途中改变特感数量，产生特感到最大特感限制
	if (convar == CvarMaxSILimit)
	{
		if (StringToInt(newValue) > StringToInt(oldValue))
		{
			delete g_hSpawnMaxSITimer;
			g_hSpawnMaxSITimer = CreateTimer(0.3, SpawnMaxSI_Timer, _, TIMER_REPEAT);
		}
	}
}

void GetCvars()
{
	g_iHunterLimit = CvarHunterLimit.IntValue;
	g_iJockeyLimit = CvarJockeyLimit.IntValue;
	g_iSmokerLimit = CvarSmokerLimit.IntValue;
	g_iBoomerLimit = CvarBoomerLimit.IntValue;
	g_iSpitterLimit = CvarSpitterLimit.IntValue;
	g_iChargerLimit = CvarChargerLimit.IntValue;
	g_iMaxSILimit = CvarMaxSILimit.IntValue;
	g_fSpawnTime = CvarSpawnTime.FloatValue;
	g_fFirstSpawnTime = CvarFirstSpawnTime.FloatValue;
	g_fKillSITime = CvarKillSITime.FloatValue;
	g_bBlockSpawn = CvarBlockSpawn.BoolValue;

	g_bRadicalSpawn = CvarRadicalSpawn.BoolValue;
	g_iNormalSpawnRange = CvarNormalSpawnRange.IntValue;
}

public void OnConfigsExecuted()
{
	TweakSettings(); //防止地图加载后重置cvar
}

void TweakSettings()
{
	//某些地图固定路段依然会刷特感 (如c2m1下坡，c2m3过山车)，使用l4d2_si_spawn_control_block_other_si_spawn阻止.
	FindConVar("z_smoker_limit").SetInt(0);
	FindConVar("z_boomer_limit").SetInt(0);
	FindConVar("z_hunter_limit").SetInt(0);
	FindConVar("z_spitter_limit").SetInt(0);
	FindConVar("z_jockey_limit").SetInt(0);
	FindConVar("z_charger_limit").SetInt(0);

	FindConVar("z_attack_flow_range").SetInt(50000);
	FindConVar("z_spawn_flow_limit").SetInt(50000);
	FindConVar("director_spectate_specials").SetInt(1);

	if (!g_bRadicalSpawn)
	{
		FindConVar("z_spawn_safety_range").SetInt(1);
		FindConVar("z_finale_spawn_safety_range").SetInt(1);
		FindConVar("z_spawn_range").SetInt(g_iNormalSpawnRange);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
	CreateTimer(2.0, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStart_Timer(Handle timer)
{
	GetMapNavAreaData();
	g_bFinalMap = L4D_IsMissionFinalMap();
	g_fMapMaxFlowDist = L4D2Direct_GetMapMaxFlowDistance();
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

	delete g_hFirstSpawnSITimer;
	delete g_hSpawnMaxSITimer;

	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		delete g_hSpawnSITimer[i];
		delete g_hKillSITimer[i];
	}

	g_iSpawnTimerNum = 0;
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

public Action FirstSpawnSI_Timer(Handle timer)
{
	g_hFirstSpawnSITimer = null;

	if (g_bLeftSafeArea)
	{
		delete g_hSpawnMaxSITimer;
		g_hSpawnMaxSITimer = CreateTimer(0.3, SpawnMaxSI_Timer, _, TIMER_REPEAT); //间隔0.3s陆续产生特感
	}
}

public Action SpawnMaxSI_Timer(Handle timer)
{
	if (g_bLeftSafeArea && GetAliveSpecialsTotal() < g_iMaxSILimit)
	{
		SpawnSpecial();
		return Plugin_Continue;
	}
	else
	{
		g_hSpawnMaxSITimer = null;
		return Plugin_Stop;
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bLeftSafeArea)
	{
		int userid = event.GetInt("userid");
		int client = GetClientOfUserId(userid);

		if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3)
		{
			int iZombieClass = GetZombieClass(client);
			switch (iZombieClass)
			{
				case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER, TANK:
				{
					delete g_hKillSITimer[client];
					SpecialDeathSpawn(g_fSpawnTime);

					// 踢出bot释放客户端索引，排除spitter避免无声痰
					if (iZombieClass != SPITTER) CreateTimer(0.2, kickbot, userid);
				}
			}
		}
	}
	return Plugin_Continue;
}

void SpecialDeathSpawn(float fTime)
{
	if (g_iSpawnTimerNum >= MAXPLAYERS) g_iSpawnTimerNum = 0;
	g_iSpawnTimerNum++;
	g_hSpawnSITimer[g_iSpawnTimerNum] = CreateTimer(fTime, SpecialDeathSpawn_Timer, g_iSpawnTimerNum);
}

public Action SpecialDeathSpawn_Timer(Handle timer, int iSpawnNum)
{
	g_hSpawnSITimer[iSpawnNum] = null;
	SpawnSpecial();
}

public Action ReSpawnSpecial_Timer(Handle timer)
{
	SpawnSpecial();
}

void SpawnSpecial()
{
	if (g_bLeftSafeArea)
	{
		#if DEBUG
		Profiler hProfiler = new Profiler();
		hProfiler.Start();
		LogToFileEx_Debug("开始产生特感");
		#endif

		static int iRandomSur;
		iRandomSur = GetRandomSurvivor();

		if (iRandomSur > 0 && GetAliveSpecialsTotal() < g_iMaxSILimit)
		{
			static int iSpawnClass;
			iSpawnClass = FindSpawnClass();

			if (1 <= iSpawnClass <= 6)
			{
				static float fSpawnPos[3];
				bool bFindSpawnPos, bSpawnSuccess;
				
				if (g_bRadicalSpawn && g_iNavAreaCount > 0)
				{
					bFindSpawnPos = GetSpawnPosByNavArea(fSpawnPos);
					if (!bFindSpawnPos)
					{
						g_fSpawnDist = 1500.0;
						//LogToFileEx(g_sLogPath, "找位失败，暂时重置g_fSpawnDist");
					}
				}
				else
				{
					bFindSpawnPos = L4D_GetRandomPZSpawnPosition(iRandomSur, iSpawnClass, NUMBER_OF_ATTEMPTS, fSpawnPos);
				}

				if (bFindSpawnPos)
				{
					g_bCanSpawn = true;
					bSpawnSuccess = L4D2_SpawnSpecial(iSpawnClass, fSpawnPos, NULL_VECTOR) > 0;
					g_bCanSpawn = false;
				}

				if (!bFindSpawnPos || !bSpawnSuccess)
				{
					LogToFileEx_Debug("产生特感失败, 重新产生, bFindSpawnPos: %b, bSpawnSuccess: %b", bFindSpawnPos, bSpawnSuccess);
					CreateTimer(1.0, ReSpawnSpecial_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			else LogToFileEx_Debug("寻找产生特感类型失败, 不再产生, iSpawnClass: %i, 当前类型特感数量和限制: %i/%i", iSpawnClass, GetSICountByClass(iSpawnClass), GetSpecialLimit(iSpawnClass));
		}
		else LogToFileEx_Debug("产生特感失败, 不再产生, iRandomSur: %i, 当前特感总数和最大特感限制: %i/%i", iRandomSur, GetAliveSpecialsTotal(), g_iMaxSILimit);

		#if DEBUG
		hProfiler.Stop();
		LogToFileEx_Debug("执行时间: %f", hProfiler.Time);
		delete hProfiler;
		#endif	
	}
}

bool GetSpawnPosByNavArea(float fSpawnPos[3])
{
	static Address pThisArea;
	static float fThisSpawnPos[3], fThisFlowDist, fThisDist;
	static float fSpawnData[MAX_VALID_POS][4];
	static bool bFindValidPos;
	static int iPosCount, iValidPosCount;

	bFindValidPos = false;
	iPosCount = 0;
	iValidPosCount = 0;
	GetSurPos();

	for (int i = 1; i < g_iNavAreaCount; i++)
	{
		pThisArea = view_as<Address>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32));
		if (!pThisArea.IsNull())
		{
			if (IsValidFlags(pThisArea.SpawnAttributes))
			{
				fThisFlowDist = pThisArea.Flow;
				if (0.0 < fThisFlowDist < g_fMapMaxFlowDist)
				{
					pThisArea.GetSpawnPos(fThisSpawnPos);
					if (IsNearAndInvisible(fThisFlowDist, fThisSpawnPos, fThisDist))
					{
						iPosCount++;
						if (!IsWillStuck(fThisSpawnPos))
						{
							if (iValidPosCount < MAX_VALID_POS)
							{
								fSpawnData[iValidPosCount][0] = fThisSpawnPos[0];
								fSpawnData[iValidPosCount][1] = fThisSpawnPos[1];
								fSpawnData[iValidPosCount][2] = fThisSpawnPos[2];
								fSpawnData[iValidPosCount][3] = fThisDist;
								iValidPosCount++;
							}
							else LogError("超出 MAX_VALID_POS 最大限制");
						}
						//else LogToFileEx_Debug("无效点位，会卡住(%.0f %.0f %.0f)", fThisSpawnPos[0], fThisSpawnPos[1], fThisSpawnPos[2]);
					}
				}
			}
			//else LogToFileEx_Debug("无效iFlags");
		}
	}

	if (iValidPosCount > 0)
	{
		//距离排序
		SortCustom2D(fSpawnData, iValidPosCount, SortAscendingByDist);
		
		//CheckArray(fSpawnData, iValidPosCount);

		//从最近的3个距离中随机选一个，防止产生的位置过于集中
		static int iNum;
		if (iValidPosCount >= 3) iNum = GetRandomInt(0, 2);
		else iNum = 0;

		fSpawnPos[0] = fSpawnData[iNum][0];
		fSpawnPos[1] = fSpawnData[iNum][1];
		fSpawnPos[2] = fSpawnData[iNum][2];

		//将找位距离设置为最后产生的距离再增加一点
		g_fSpawnDist = fSpawnData[iNum][3] + 400.0;
		//PrintToServer("fSpawnData[%i][3] = %.1f, g_fSpawnDist = %.1f", iNum, fSpawnData[iNum][3], g_fSpawnDist);

		bFindValidPos = true;
	}

	//LogToFileEx_Debug("找到 %i 个点位, 其中有效点位 %i 个, 最终产生的点位(%.0f %.0f %.0f)", iPosCount, iValidPosCount, fSpawnPos[0], fSpawnPos[1], fSpawnPos[2]);

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
				return (!(iFlags & TERROR_NAV_STOP) && !(iFlags & TERROR_NAV_RESCUE_CLOSET) && (iFlags & TERROR_NAV_FINALE));
			}
		}
		return (!(iFlags & TERROR_NAV_STOP) && !(iFlags & TERROR_NAV_RESCUE_CLOSET));
	}
	return false;
}

void GetSurPos()
{
	g_aSurPosData.Clear();
	static g_esSurPosData SurPosData;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			GetClientEyePosition(i, SurPosData.fPos);
			SurPosData.fFlow = L4D2Direct_GetFlowDistance(i);
			g_aSurPosData.PushArray(SurPosData);
		}
	}
}

bool IsNearAndInvisible(const float fAreaFlow, const float fAreaSpawnPos[3], float &fDist)
{
	static float fTargetPos[3];
	static g_esSurPosData SurPosData;

	for (int i = 0; i < g_aSurPosData.Length; i++)
	{
		g_aSurPosData.GetArray(i, SurPosData);
		if (FloatAbs(fAreaFlow - SurPosData.fFlow) <= g_fSpawnDist)
		{
			fDist = GetVectorDistance(SurPosData.fPos, fAreaSpawnPos);
			if (fDist <= g_fSpawnDist)
			{
				fTargetPos[0] = fAreaSpawnPos[0];
				fTargetPos[1] = fAreaSpawnPos[1];
				fTargetPos[2] = fAreaSpawnPos[2] + 62.0; //眼睛位置

				if (!IsVisible(SurPosData.fPos, fTargetPos))
				{
					return true;
				}
			}
		}
	}
	return false;
}

//https://forums.alliedmods.net/showthread.php?t=132264
bool IsVisible(const float fStartPos[3], const float fTargetPos[3])
{
	static float fAng[3], fVecbuffer[3];
	static bool bVisible;
	static Handle hTrace;

	bVisible = false;

	//获取角度
	MakeVectorFromPoints(fStartPos, fTargetPos, fVecbuffer);
	GetVectorAngles(fVecbuffer, fAng); 
	
	//执行射线
	hTrace = TR_TraceRayFilterEx(fStartPos, fAng, MASK_VISIBLE, RayType_Infinite, TraceFilter);

	if (TR_DidHit(hTrace))
	{
		static float fEndPos[3];
		TR_GetEndPosition(fEndPos, hTrace); //获得碰撞点
		
		//如果碰撞点的距离超过目标点位的距离，则可见
		if ((GetVectorDistance(fStartPos, fEndPos) + 25.0) >= GetVectorDistance(fStartPos, fTargetPos))
		{
			bVisible = true;
		}
	}
	else
	{
		//LogToFileEx_Debug("Tracer Bug: 射线没碰见任何东西");
		bVisible = true;
	}

	delete hTrace;
	return bVisible;
}

public bool TraceFilter(int entity, int contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	
	static char sEntClassName[16];
	if (GetEdictClassname(entity, sEntClassName, sizeof(sEntClassName)))
	{
		if (strcmp(sEntClassName, "infected", false) == 0 || strcmp(sEntClassName, "witch", false) == 0 || strcmp(sEntClassName, "prop_physics", false) == 0)
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

	static bool bStuck;
	static Handle hTrace;

	hTrace = TR_TraceHullFilterEx(fPos, fPos, fClientMinSize, fClientMaxSize, MASK_PLAYERSOLID, TraceFilter_Stuck);
	bStuck = TR_DidHit(hTrace);

	delete hTrace;
	return bStuck;
}

public bool TraceFilter_Stuck(int entity, int contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	return true;
}

//实际上浮点也可以正确排序。
public int SortAscendingByDist(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[3] < y[3]) return -1;
	else if (x[3] > y[3]) return 1;
	else return 0;
}

stock void CheckArray(const float[][] fArray, int size)
{
	for (int i; i < size; i++)
	{
		LogToFileEx_Debug("fArray[%i][3] = %f", i, fArray[i][3]);
	}
}

int GetRandomSurvivor()
{
	static int client;

	client = 0;
	g_aClientsArray.Clear();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
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

//https://github.com/fbef0102/L4D1_2-Plugins/blob/master/l4dinfectedbots/scripting/l4dinfectedbots.sp
int FindSpawnClass()
{
	int iSmokers, iBoomers, iHunters, iSpitters, iJockeys, iChargers;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			switch (GetZombieClass(i))
			{
				case SMOKER: iSmokers++;
				case BOOMER: iBoomers++;
				case HUNTER: iHunters++;
				case SPITTER: iSpitters++;
				case JOCKEY: iJockeys++;
				case CHARGER: iChargers++;
			}
		}
	}

	int iRandomClass = GetRandomInt(1, 6);
	int i = 0;
	while (i++ < 5)
	{
		if (iRandomClass == 1)
		{
			if (iSmokers < g_iSmokerLimit)
			{
				return SMOKER;
			}
			iRandomClass++;
		}
		if (iRandomClass == 2)
		{
			if (iBoomers < g_iBoomerLimit)
			{
				return BOOMER;
			}
			iRandomClass++;
		}
		if (iRandomClass == 3)
		{
			if (iHunters < g_iHunterLimit)
			{
				return HUNTER;
			}
			iRandomClass++;
		}
		if (iRandomClass == 4)
		{
			if (iSpitters < g_iSpitterLimit)
			{
				return SPITTER;
			}
			iRandomClass++;
		}
		if (iRandomClass == 5)
		{
			if (iJockeys < g_iJockeyLimit)
			{
				return JOCKEY;
			}
			iRandomClass++;
		}
		if (iRandomClass == 6)
		{
			if (iChargers < g_iChargerLimit)
			{
				return CHARGER;
			}
			iRandomClass = 1;
		}
	}
	return 0;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
	if (g_bLeftSafeArea)
	{
		static int iVictim, iAttacker;

		iVictim = GetClientOfUserId(event.GetInt("userid"));
		iAttacker = GetClientOfUserId(event.GetInt("attacker"));

		delete g_hKillSITimer[iVictim];
		g_hKillSITimer[iVictim] = CreateTimer(g_fKillSITime, KillSI_Timer, iVictim);

		delete g_hKillSITimer[iAttacker];
		g_hKillSITimer[iAttacker] = CreateTimer(g_fKillSITime, KillSI_Timer, iAttacker);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsAliveSI(client))
	{
		delete g_hKillSITimer[client];
		g_hKillSITimer[client] = CreateTimer(g_fKillSITime, KillSI_Timer, client);
	}
}

public Action KillSI_Timer(Handle timer, int client)
{
	if (IsAliveSI(client))
	{
		// 特感在控人，或者能看见生还者
		if (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") || GetSurvivorVictim(client) != -1)
		{
			g_hKillSITimer[client] = null;
			g_hKillSITimer[client] = CreateTimer(g_fKillSITime, KillSI_Timer, client);
			return;
		}
		else
		{
			g_hKillSITimer[client] = null;
			ForcePlayerSuicide(client);
			return;
		}
	}
	else g_hKillSITimer[client] = null;
}


bool IsAliveSI(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && IsFakeClient(client))
	{
		switch (GetZombieClass(client))
		{
			case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER:
			{
				return true;
			}
		}
	}
	return false;
}

int GetSurvivorVictim(int client)
{
	int victim;

	/* Charger */
	victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
	if (victim > 0)
	{
		return victim;
	}

	victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
	if (victim > 0)
	{
		return victim;
	}

	/* Jockey */
	victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
	if (victim > 0)
	{
		return victim;
	}

	/* Hunter */
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if (victim > 0)
	{
		return victim;
 	}

	/* Smoker */
 	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if (victim > 0)
	{
		return victim;	
	}

	return -1;
}

public Action Cmd_ShowSIhud(int client, int args)
{
	g_bShowSIhud[client] = !g_bShowSIhud[client];
	if (g_bShowSIhud[client]) CreateTimer(0.5, ShowSIHud_Timer, client, TIMER_REPEAT);
	PrintToChat(client, "特感面板状态: %s", (g_bShowSIhud[client] ? "已开启" : "已关闭"));
}

public Action ShowSIHud_Timer(Handle timer, int client)
{
	if (g_bShowSIhud[client] && IsRealClient(client) && IsAdminClient(client))
	{
		char sBuffer[64];
		Panel panel = new Panel();

		panel.SetTitle("特感面板");
		panel.DrawText("__________");

		FormatEx(sBuffer, sizeof(sBuffer), "Smoker数量: %i", GetSICountByClass(SMOKER));
		panel.DrawText(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "Boomer数量: %i", GetSICountByClass(BOOMER));
		panel.DrawText(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "Hunter数量: %i", GetSICountByClass(HUNTER));
		panel.DrawText(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "Spitter数量: %i", GetSICountByClass(SPITTER));
		panel.DrawText(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "Jockey数量: %i", GetSICountByClass(JOCKEY));
		panel.DrawText(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "Charger数量: %i", GetSICountByClass(CHARGER));
		panel.DrawText(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "全部特感数量: %i", GetAliveSpecialsTotal());
		panel.DrawText(sBuffer);

		panel.Send(client, NullMenuHandler, 1);
		delete panel;
		
		return Plugin_Continue;
	}
	else
	{
		LogToFileEx_Debug("client %i: 特感HUD已关闭", client);
		g_bShowSIhud[client] = false;
		return Plugin_Stop;
	}
}

public int NullMenuHandler(Handle hMenu, MenuAction action, int param1, int param2) {}

int GetSICountByClass(int iZombieClass)
{
	int iCount;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetZombieClass(i) == iZombieClass && IsPlayerAlive(i))
		{
			iCount++;
		}
	}
	return iCount;
}

int GetAliveSpecialsTotal() 
{
	int iCount;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			switch (GetZombieClass(i))
			{
				case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER, TANK:
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

int GetSpecialLimit(int iClass)
{
	if (iClass == 0) return 0;
	char sBuff[256];
	Format(sBuff, sizeof(sBuff), "l4d2_si_spawn_control_%s_limit", g_sSpecialName[iClass]);
	return FindConVar(sBuff).IntValue;
}

//阻止本插件以外的特感产生
public Action L4D_OnSpawnSpecial(int &zombieClass, const float vecPos[3], const float vecAng[3])
{
	if (!g_bCanSpawn && g_bBlockSpawn)
	{
		//LogToFileEx_Debug("不是本插件产生的 %s, 已阻止", g_sSpecialName[zombieClass]);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

 //解锁最大特感数量限制
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if (strcmp(key, "MaxSpecials", false) == 0 || strcmp(key, "cm_MaxSpecials", false) == 0 || strcmp(key, "DominatorLimit", false) == 0 || strcmp(key, "cm_DominatorLimit", false) == 0)
	{
		retVal = 28;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action kickbot(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client))
	{
		if (!IsClientInKickQueue(client)) KickClient(client);
	}
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

public Action Cmd_CvarPrint(int client, int args)
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
}

stock void LogToFileEx_Debug(const char[] sMsg, any ...)
{
	static char buffer[254];
	VFormat(buffer, sizeof(buffer), sMsg, 2);

	#if DEBUG
	LogToFileEx(g_sLogPath, "%s", buffer);
	#endif
}
