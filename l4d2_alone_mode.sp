#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.2"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

ConVar
	g_cvAloneTrack,
	g_cvPinnedDmg[7];

float
	g_fPinnedDmg[7];

bool
	g_bDisable,
	g_bAllowNotif,
	g_bAlone;

Handle
	g_hTimer;

enum
{
	SMOKER	= 1,
	BOOMER	= 2,
	HUNTER	= 3,
	SPITTER	= 4,
	JOCKEY	= 5,
	CHARGER	= 6,
};

public Plugin myinfo =
{
	name = "L4D2 Alone mode",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_alone_mode_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvAloneTrack = CreateConVar("l4d2_alone_track", "0", "Don't touch this", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvPinnedDmg[SMOKER] = CreateConVar("l4d2_alone_damage_smoker", "5.0");
	g_cvPinnedDmg[HUNTER] = CreateConVar("l4d2_alone_damage_hunter", "9.0");
	g_cvPinnedDmg[JOCKEY] = CreateConVar("l4d2_alone_damage_jockey", "9.0");
	g_cvPinnedDmg[CHARGER] = CreateConVar("l4d2_alone_damage_charger", "0.0");
	
	GetCvars();

	g_cvAloneTrack.AddChangeHook(OnAloneModeChanged);
	g_cvPinnedDmg[SMOKER].AddChangeHook(OnConVarChanged);
	g_cvPinnedDmg[HUNTER].AddChangeHook(OnConVarChanged);
	g_cvPinnedDmg[JOCKEY].AddChangeHook(OnConVarChanged);
	g_cvPinnedDmg[CHARGER].AddChangeHook(OnConVarChanged);

	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_alone", Cmd_SwitchAloneMode);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}

	delete g_hTimer;
	g_hTimer = CreateTimer(0.3, CheckPlayerCount_Timer, _, TIMER_REPEAT);

	AutoExecConfig(true, "l4d2_alone_mode");
}

Action Cmd_SwitchAloneMode(int client, int args)
{
	if (g_bAlone)
	{
		g_bDisable = !g_bDisable;
		CPrintToChat(client, "{default}[{yellow}提示{default}] 已手动%s单人模式, 再次输入本命令%s", g_bDisable ? "关闭" : "开启", g_bDisable ? "开启" : "关闭");
		return Plugin_Handled;
	}

	CPrintToChat(client, "{default}[{yellow}提示{default}] 多人下无法使用本命令");
	return Plugin_Handled;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fPinnedDmg[SMOKER] = g_cvPinnedDmg[SMOKER].FloatValue;
	g_fPinnedDmg[HUNTER] = g_cvPinnedDmg[HUNTER].FloatValue;
	g_fPinnedDmg[JOCKEY] = g_cvPinnedDmg[JOCKEY].FloatValue;
	g_fPinnedDmg[CHARGER] = g_cvPinnedDmg[CHARGER].FloatValue;
}

Action CheckPlayerCount_Timer(Handle timer)
{
	static int i, iCount;
	iCount = 0;

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			iCount++;
		}
	}

	g_bAlone = iCount == 1 ? true : false;
	g_cvAloneTrack.BoolValue = g_bAlone;

	return Plugin_Continue;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	g_bAllowNotif = false;
}

void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	g_bAllowNotif = false;
}

public void OnMapEnd()
{
	g_bAllowNotif = false;
}

public void OnMapStart()
{
	g_bAllowNotif = false;
	CreateTimer(20.0, AllowNotif_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action AllowNotif_Timer(Handle timer)
{
	g_bAllowNotif = true;
	return Plugin_Continue;
}

void OnAloneModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bAllowNotif && !g_bDisable)
	{
		CPrintToChatAll("{default}[{yellow}提示{default}] 已自动%s单人模式", g_bAlone ? "开启" : "关闭");
		LogToFilePlus("已自动%s单人模式", g_bAlone ? "开启" : "关闭");
	}
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!g_bAlone || g_bDisable || damage <= 0.0) return;

	if (IsValidSur(victim) && IsPlayerAlive(victim))
	{
		if (IsValidSI(attacker) && IsPlayerAlive(attacker))
		{
			if (!IsFakeClient(victim) || !IsFakeClient(attacker))
			{
				static int iClass;
				iClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");

				switch (iClass)
				{
					case SMOKER, HUNTER, JOCKEY, CHARGER:
					{
						if (g_fPinnedDmg[iClass] >= 0.0 && GetPinnedSurvivor(attacker, iClass) == victim)
						{
							SDKHooks_TakeDamage(victim, attacker, attacker, g_fPinnedDmg[iClass]);

							if (!IsFakeClient(attacker))
								CPrintToChatAll("{default}[{yellow}Alone{default}] {red}%N {default}还剩余 {yellow}%i {default}血量.", attacker, GetEntProp(attacker, Prop_Data, "m_iHealth"));
							else CPrintToChatAll("{default}[{yellow}Alone{default}] {olive}%N {default}还剩余 {yellow}%i {default}血量.", attacker, GetEntProp(attacker, Prop_Data, "m_iHealth"));
							
							ForcePlayerSuicide(attacker);
						}
					}
				}
			}
		}
	}
}

int GetPinnedSurvivor(int iSpecial, int iClass)
{
	switch (iClass)
	{
		case SMOKER: return GetEntPropEnt(iSpecial, Prop_Send, "m_tongueVictim");
		case HUNTER: return GetEntPropEnt(iSpecial, Prop_Send, "m_pounceVictim");
		case JOCKEY: return GetEntPropEnt(iSpecial, Prop_Send, "m_jockeyVictim");
		case CHARGER: return GetEntPropEnt(iSpecial, Prop_Send, "m_pummelVictim");
	}
	return -1;
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

bool IsValidSur(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			return true;
		}
	}
	return false;
}

void LogToFilePlus(const char[] sMsg, any ...)
{
	static char sDate[32], sLogPath[PLATFORM_MAX_PATH];
	static char sBuffer[256];

	FormatTime(sDate, sizeof(sDate), "%Y%m%d");
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), "logs/%s_logging.log", sDate);
	VFormat(sBuffer, sizeof(sBuffer), sMsg, 2);

	LogToFileEx(sLogPath, "%s", sBuffer);
}
