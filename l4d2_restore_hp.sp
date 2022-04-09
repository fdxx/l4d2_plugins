#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define VERSION "1.4"

ConVar
	g_cvHealthLimit,
	g_cvAddHealthFlame,
	g_cvDamageInfo;

int
	g_iMaxHealthLimit,
	g_iAddHealthFlame;

bool g_bDamageInfo;

#define RED_HEALTH		1
#define YELLOW_HEALTH	2
#define GREEN_HEALTH	3

public Plugin myinfo = 
{
	name = "L4D2 Restore health",
	author = "fdxx",
	description = "Attack special infected to restore health",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_restore_hp_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvHealthLimit = CreateConVar("l4d2_restore_hp_limit", "200", "Max health limit", FCVAR_NONE);
	g_cvAddHealthFlame = CreateConVar("l4d2_restore_hp_flame", "1", "How much does flame damage add health", FCVAR_NONE);
	g_cvDamageInfo = CreateConVar("l4d2_restore_hp_show_info", "0", "Chat box print info", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	g_cvHealthLimit.AddChangeHook(ConVarChanged);
	g_cvAddHealthFlame.AddChangeHook(ConVarChanged);
	g_cvDamageInfo.AddChangeHook(ConVarChanged);

	//HookEvent("player_hurt", Event_PlayerHurt);
	//AutoExecConfig(true, "l4d2_restore_hp");
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iMaxHealthLimit = g_cvHealthLimit.IntValue;
	g_iAddHealthFlame = g_cvAddHealthFlame.IntValue;
	g_bDamageInfo = g_cvDamageInfo.BoolValue;
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
}

void OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	static int iAttackerHealthPre, iHealthLevel, iAddHealth, iAttackerHealthPost;

	if (damage <= 1.0 || damage > 2000.0) return;

	if (IsValidSI(victim) && IsPlayerAlive(victim))
	{
		if (GetEntProp(victim, Prop_Send, "m_zombieClass") == 8 && GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
			return;

		if (IsValidSur(attacker) && IsPlayerAlive(attacker) && !GetEntProp(attacker, Prop_Send, "m_isIncapacitated"))
		{
			iAttackerHealthPre = GetEntProp(attacker, Prop_Data, "m_iHealth");
			if (iAttackerHealthPre >= g_iMaxHealthLimit) return;

			iHealthLevel = GetHealthStatus(iAttackerHealthPre);
			iAddHealth = 0;

			if (damagetype & DMG_SLASH || damagetype & DMG_CLUB)
			{
				switch (iHealthLevel)
				{
					case GREEN_HEALTH: iAddHealth = 7;
					case YELLOW_HEALTH: iAddHealth = 12;
					case RED_HEALTH: iAddHealth = 25;
				}
			}
			else if (damagetype & DMG_BURN)
			{
				iAddHealth = g_iAddHealthFlame;
			}
			else
			{
				switch (iHealthLevel)
				{
					case GREEN_HEALTH: iAddHealth = RoundToCeil(damage * 0.03);
					case YELLOW_HEALTH: iAddHealth = RoundToCeil(damage * 0.05);
					case RED_HEALTH: iAddHealth = RoundToCeil(damage * 0.08);
				}
			}

			iAttackerHealthPost = iAttackerHealthPre + iAddHealth;
			if (iAttackerHealthPost > g_iMaxHealthLimit) iAttackerHealthPost = g_iMaxHealthLimit;

			SetEntProp(attacker, Prop_Data, "m_iHealth", iAttackerHealthPost);

			if (g_bDamageInfo)
				PrintToChat(attacker, "%N attack %N, damage = %.1f, AddHealth = %i", attacker, victim, damage, iAddHealth);
		}
	}
}

int GetHealthStatus(int iHealth)
{
	if (iHealth >= 100)
		return GREEN_HEALTH;

	else if (40 <= iHealth < 100)
		return YELLOW_HEALTH;

	else if (0 < iHealth < 40)
		return RED_HEALTH;
		
	else return 0;
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


