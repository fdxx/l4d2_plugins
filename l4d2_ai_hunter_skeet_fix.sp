#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <sdkhooks>

ConVar
	g_cvEnable,
	g_cvPounceInterrupt; // z_pounce_damage_interrupt. Default for coop: 50, for versus: 150.

int
	g_iHunterSkeetDmg[MAXPLAYERS],
	g_iPounceInterrupt;

bool g_bEnable;

public Plugin myinfo =
{
	name = "L4D2 AI hunter skeet fix",
	author = "Tabun, dcx2, fdxx",
	version = VERSION,
	url = "https://github.com/Tabbernaut/L4D2-Plugins/tree/master/ai_damagefix"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_ai_hunter_skeet_fix_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvEnable = CreateConVar("l4d2_ai_hunter_skeet_fix_enable", "1", "Enable", FCVAR_NONE);
	g_cvPounceInterrupt = CreateConVar("l4d2_ai_hunter_skeet_fix_interrupt", "150", "Pounce interrupt value", FCVAR_NONE);

	GetCvars();

	g_cvEnable.AddChangeHook(ConVarChanged);
	g_cvPounceInterrupt.AddChangeHook(ConVarChanged);

	HookEvent("ability_use", Event_AbilityUse);
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void OnConfigsExecuted()
{
	FindConVar("z_pounce_damage_interrupt").IntValue = g_iPounceInterrupt;
}

void GetCvars()
{
	g_bEnable = g_cvEnable.BoolValue;
	g_iPounceInterrupt = g_cvPounceInterrupt.IntValue;
}

public void OnClientPutInServer(int client)
{
	g_iHunterSkeetDmg[client] = 0;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_bEnable || damage <= 0.0) return Plugin_Continue;

	if (IsValidSI(victim) && IsFakeClient(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") == 3 && GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") && IsPlayerAlive(victim))
	{
		if (IsValidSur(attacker))
		{
			g_iHunterSkeetDmg[victim] += RoundToFloor(damage);

			if (g_iHunterSkeetDmg[victim] >= g_iPounceInterrupt)
			{
				g_iHunterSkeetDmg[victim] = 0;
				damage = float(GetClientHealth(victim));
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	static char sAbilityName[64];

	client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidSI(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 3)
	{
		event.GetString("ability", sAbilityName, sizeof(sAbilityName));
		if (strcmp(sAbilityName, "ability_lunge") == 0)
		{
			g_iHunterSkeetDmg[client] = 0;
		}
	}
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
