#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "0.4"

#define SMOKER	1
#define BOOMER	2
#define HUNTER	3
#define SPITTER	4
#define JOCKEY	5
#define CHARGER	6
#define WITCH	7
#define TANK	8

ConVar g_cvRestoreHealth[9], g_cvMaxHealthLimit;
int g_iRestoreHealth[9];
int g_iMaxHealthLimit;

public Plugin myinfo =
{
	name = "L4D2 Kill si restore health",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_kill_si_restore_health_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvRestoreHealth[SMOKER] = CreateConVar("l4d2_kill_smoker_restore_health", "0");
	g_cvRestoreHealth[BOOMER] = CreateConVar("l4d2_kill_boomer_restore_health", "0");
	g_cvRestoreHealth[HUNTER] = CreateConVar("l4d2_kill_hunter_restore_health", "0");
	g_cvRestoreHealth[SPITTER] = CreateConVar("l4d2_kill_spitter_restore_health", "0");
	g_cvRestoreHealth[JOCKEY] = CreateConVar("l4d2_kill_jockey_restore_health", "0");
	g_cvRestoreHealth[CHARGER] = CreateConVar("l4d2_kill_charger_restore_health", "0");

	g_cvRestoreHealth[WITCH] = CreateConVar("l4d2_kill_witch_restore_health", "10");
	g_cvRestoreHealth[TANK] = CreateConVar("l4d2_kill_tank_restore_health", "0");

	g_cvMaxHealthLimit = CreateConVar("l4d2_kill_si_restore_health_Limit", "110");
	
	GetCvars();

	for (int i = 1; i <= 8; i++)
		g_cvRestoreHealth[i].AddChangeHook(ConVarChanged);
	g_cvMaxHealthLimit.AddChangeHook(ConVarChanged);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Pre);
}

void ConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	for (int i = 1; i <= 8; i++)
		g_iRestoreHealth[i] = g_cvRestoreHealth[i].IntValue;
	g_iMaxHealthLimit = g_cvMaxHealthLimit.IntValue;
}


void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidSI(iVictim))
		return;

	int iZombieClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass");
	if (iZombieClass < 1 || iZombieClass > 8)
		return;

	if (g_iRestoreHealth[iZombieClass] < 1)
		return;

	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidSur(iAttacker) || !IsPlayerAlive(iAttacker) || GetEntProp(iAttacker, Prop_Send, "m_isIncapacitated"))
		return;

	int iCurrentHealth = GetEntProp(iAttacker, Prop_Data, "m_iHealth");
	if (iCurrentHealth >= g_iMaxHealthLimit)
		return;

	int iPostHealth = iCurrentHealth + g_iRestoreHealth[iZombieClass];
	if (iPostHealth > g_iMaxHealthLimit)
		iPostHealth = g_iMaxHealthLimit;

	SetEntProp(iAttacker, Prop_Data, "m_iHealth", iPostHealth);
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iRestoreHealth[WITCH] < 1)
		return;

	int iAttacker = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidSur(iAttacker) || !IsPlayerAlive(iAttacker) || GetEntProp(iAttacker, Prop_Send, "m_isIncapacitated"))
		return;

	int witchid = event.GetInt("witchid");
	if (witchid <= MaxClients || !IsValidEntity(witchid))
		return;

	int iCurrentHealth = GetEntProp(iAttacker, Prop_Data, "m_iHealth");
	if (iCurrentHealth >= g_iMaxHealthLimit)
		return;

	int iPostHealth = iCurrentHealth + g_iRestoreHealth[WITCH];
	if (iPostHealth > g_iMaxHealthLimit)
		iPostHealth = g_iMaxHealthLimit;
				
	SetEntProp(iAttacker, Prop_Data, "m_iHealth", iPostHealth);
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
