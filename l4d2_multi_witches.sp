#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <dhooks>

#define VERSION "0.3"

ConVar g_cvMaxWitchLimit, g_cvWitchSpawnTime, g_cvKillWitchDistance;
int g_iMaxWitchLimit;
float g_fWitchSpawnTime, g_fKillWitchDistance;
bool g_bLeftSafeArea;
Handle g_hSpawnWitchTimer;
DynamicDetour g_dGetWitchLimit;

public Plugin myinfo =
{
	name = "L4D2 Multi Witches",
	author = "Shele, Dragokas, fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_multi_witches_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvMaxWitchLimit = CreateConVar("l4d2_multi_witches_limit", "30", "限制活着的witch数量", FCVAR_NONE);
	g_cvWitchSpawnTime = CreateConVar("l4d2_multi_witches_spawn_time", "30.0", "witch产生的时间", FCVAR_NONE);
	g_cvKillWitchDistance = CreateConVar("l4d2_multi_witches_kill_distance", "1800.0", "超过这个距离的witch将会被自动杀死", FCVAR_NONE);
	
	GetCvars();

	g_cvMaxWitchLimit.AddChangeHook(ConVarChanged);
	g_cvWitchSpawnTime.AddChangeHook(ConVarChanged);
	g_cvKillWitchDistance.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	LoadGameData();
}

void ConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iMaxWitchLimit = g_cvMaxWitchLimit.IntValue;
	g_fWitchSpawnTime = g_cvWitchSpawnTime.FloatValue;
	g_fKillWitchDistance = g_cvKillWitchDistance.FloatValue;

	delete g_hSpawnWitchTimer;
	if (g_fWitchSpawnTime >= 0.1)
	{
		g_hSpawnWitchTimer = CreateTimer(g_fWitchSpawnTime, SpawnWitch_Timer, _, TIMER_REPEAT);
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapStart()
{
	if (!IsModelPrecached("models/infected/witch.mdl"))
	{
		PrecacheModel("models/infected/witch.mdl", false);
	}
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	g_bLeftSafeArea = false;
	delete g_hSpawnWitchTimer;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (g_fWitchSpawnTime >= 0.1)
	{
		g_bLeftSafeArea = true;
		delete g_hSpawnWitchTimer;
		g_hSpawnWitchTimer = CreateTimer(g_fWitchSpawnTime, SpawnWitch_Timer, _, TIMER_REPEAT);
	}
	return Plugin_Continue;
}

Action SpawnWitch_Timer(Handle timer)
{
	if (g_bLeftSafeArea)
	{
		if (GetWitchCount() < g_iMaxWitchLimit)
		{
			static float fSpawnPos[3];
			static int iRandomSur;
			iRandomSur = GetRandomSur();
			if (iRandomSur > 0)
			{
				if (L4D_GetRandomPZSpawnPosition(iRandomSur, 8, 20, fSpawnPos))
				{
					if (L4D2_SpawnWitch(fSpawnPos, NULL_VECTOR) <= 0)
					{
						LogMessage("[%s] 无法产生witch (%.1f %.1f %.1f)", CurrentMap(), fSpawnPos[0], fSpawnPos[1], fSpawnPos[2]);
					}
				}
			}
		}
		return Plugin_Continue;
	}
	g_hSpawnWitchTimer = null;
	return Plugin_Stop;
}

// Kill witches out of range, and return total count of witches on the map
int GetWitchCount()
{
	int i;
	bool bInRange;
	float fWitchPos[3];
	float fPlayerPos[3];
	int iWitch;
	int index = -1;
	while ((index = FindEntityByClassname(index, "witch")) != -1)
	{
		iWitch++;
		if (g_fKillWitchDistance > 0.0)
		{
			GetEntPropVector(index, Prop_Send, "m_vecOrigin", fWitchPos);
			bInRange = false;
			
			for (i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
				{
					GetClientAbsOrigin(i, fPlayerPos);
					if (GetVectorDistance(fWitchPos, fPlayerPos) < g_fKillWitchDistance)
					{
						bInRange = true;
						break;
					}
				}
			}

			if (!bInRange)
			{
				//PrintToChatAll("超过范围 杀死witch");
				AcceptEntityInput(index, "Kill");
				iWitch--;
			}
		}
	}

	return iWitch;
}

int GetRandomSur()
{
	int client;
	ArrayList aClients = new ArrayList();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			aClients.Push(i);
		}
	}

	if (aClients.Length > 0)
	{
		client = aClients.Get(GetRandomInt(0, aClients.Length - 1));
	}

	delete aClients;

	return client;
}

char[] CurrentMap()
{
	static char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return sMapName;
}

void LoadGameData()
{
	GameData hGameData = new GameData("l4d2_multi_witches");

	if (hGameData == null)
		SetFailState("加载 l4d2_multi_witches.txt 文件失败");
	g_dGetWitchLimit = DynamicDetour.FromConf(hGameData, "CDirector::GetWitchLimit");
	if (g_dGetWitchLimit == null)
		SetFailState("加载 CDirector::GetWitchLimit 签名失败");
	if (!g_dGetWitchLimit.Enable(Hook_Pre, mreOnGetWitchLimitPre))
		SetFailState("启用 mreOnGetWitchLimitPre 失败");

	delete hGameData;
}

// 修复有些结局地图无法产生witch的问题
MRESReturn mreOnGetWitchLimitPre(DHookReturn hReturn)
{
	hReturn.Value = -1;
	return MRES_Supercede;
}
