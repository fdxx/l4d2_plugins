#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.2"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>

#define MIN_DURATION 0.0
#define MAX_DURATION 10.0
#define HORDE_END_SOUND "level/bell_normal.wav"

ConVar
	g_cvAnnounceNum,
	g_cvPauseWhenTankAlive;

int g_iAnnounceNum,
	g_iCommInfCount, 
	g_iHordeLimit;

bool 
	g_bPauseWhenTankAlive,
	g_bAnnounceStart,
	g_bAnnounceRemain,
	g_bAnnounceEnd;

KeyValues g_kv;

public Plugin myinfo = 
{
	name = "L4D2 Horde Equaliser",
	author = "Visor, sir, A1m, fdxx",
	description = "Make certain event hordes finite",
	version = VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	char sCfgPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sCfgPath, sizeof(sCfgPath), "data/mapinfo.txt");

	delete g_kv;
	g_kv = new KeyValues("");
	if (!g_kv.ImportFromFile(sCfgPath))
		SetFailState("无法加载 mapinfo.txt!");

	CreateConVar("l4d2_horde_equaliser_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvAnnounceNum = CreateConVar("l4d2_horde_equaliser_announce_num", "30", "剩余多少尸潮时公告", FCVAR_NONE);
	g_cvPauseWhenTankAlive  = CreateConVar("l4d2_horde_equaliser_pause_when_tank_alive", "1", "Tank活着时暂停事件尸潮", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	g_cvAnnounceNum.AddChangeHook(ConVarChange);
	g_cvPauseWhenTankAlive.AddChangeHook(ConVarChange);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iAnnounceNum = g_cvAnnounceNum.IntValue;
	g_bPauseWhenTankAlive = g_cvPauseWhenTankAlive.BoolValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
	CreateTimer(1.0, GetHordeLimit_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action GetHordeLimit_Timer(Handle timer)
{
	g_iHordeLimit = GetHordeLimit();
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
	g_iHordeLimit = 0;
	g_iCommInfCount = 0;
	g_bAnnounceRemain = false;
	g_bAnnounceStart = false;
	g_bAnnounceEnd = false;
}

public void OnMapStart()
{
	PrecacheSound(HORDE_END_SOUND, true);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_iHordeLimit > 0)
	{
		if (classname[0] == 'i' && strcmp(classname, "infected") == 0)
		{
			if (IsInfiniteHordeActive())
			{
				if (g_bPauseWhenTankAlive && IsTankAlive()) return;
				
				if (g_iCommInfCount < g_iHordeLimit)
				{
					g_iCommInfCount++;

					if (!g_bAnnounceRemain && (g_iHordeLimit - g_iCommInfCount <= g_iAnnounceNum))
					{
						g_bAnnounceRemain = true;
						CPrintToChatAll("{default}[{yellow}Horde{default}] {yellow}%i {default}commons remaining..", g_iAnnounceNum);
					}
				}
			}
		}
	}
}

public Action L4D_OnSpawnMob(int &amount)
{
	if (g_iHordeLimit > 0)
	{
		if (IsInfiniteHordeActive())
		{
			if (g_bPauseWhenTankAlive && IsTankAlive())
			{
				L4D2Direct_SetPendingMobCount(0);
				return Plugin_Handled;
			}

			if (!g_bAnnounceStart)
			{
				g_bAnnounceStart = true;
				CPrintToChatAll("{default}[{yellow}Horde{default}] A {blue}finite event{default} of {yellow}%i {default}commons has started!", g_iHordeLimit);
			}

			if (g_iCommInfCount >= g_iHordeLimit)
			{
				if (!g_bAnnounceEnd)
				{
					g_bAnnounceEnd = true;
					EmitSoundToAll(HORDE_END_SOUND);
				}

				L4D2Direct_SetPendingMobCount(0);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

bool IsInfiniteHordeActive()
{
	return MIN_DURATION < L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer) <= MAX_DURATION;
}

int GetHordeLimit()
{
	g_kv.Rewind();
	if (g_kv.JumpToKey(GetCurMap()))
	{
		return g_kv.GetNum("horde_limit", 0);
	}
	return 0;
}

char[] GetCurMap()
{
	char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return sMapName;
}

bool IsTankAlive()
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i))
		{
			return true;
		}
	}
	return false;
}
