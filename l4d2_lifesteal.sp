#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define VERSION "1.5"

#define RED_HEALTH		1
#define YELLOW_HEALTH	2
#define GREEN_HEALTH	3

ConVar
	g_cvHealthLimit,
	g_cvAddHealthFlame;

int
	g_iMaxHealthLimit,
	g_iAddHealthFlame,
	m_zombieClass_offset,
	m_isIncapacitated_offset,
	m_iHealth_offset;

public Plugin myinfo = 
{
	name = "L4D2 lifesteal",
	author = "fdxx",
	description = "Attack special infected to restore health",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_lifesteal_version", VERSION, "Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_cvHealthLimit = CreateConVar("l4d2_lifesteal_limit", "200", "Max health limit");
	g_cvAddHealthFlame = CreateConVar("l4d2_lifesteal_flame", "1", "How much does flame damage add health");

	OnConVarChanged(null, "", "");

	g_cvHealthLimit.AddChangeHook(OnConVarChanged);
	g_cvAddHealthFlame.AddChangeHook(OnConVarChanged);

	m_zombieClass_offset = FindSendPropInfo("CTerrorPlayer", "m_zombieClass");
	m_isIncapacitated_offset = FindSendPropInfo("CTerrorPlayer", "m_isIncapacitated");
	m_iHealth_offset = FindSendPropInfo("CTerrorPlayer", "m_iHealth");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iMaxHealthLimit = g_cvHealthLimit.IntValue;
	g_iAddHealthFlame = g_cvAddHealthFlame.IntValue;
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
}

void OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	static int iAttackerHealthPre, iHealthLevel, iAddHealth, iAttackerHealthPost;

	if (damage <= 1.0 || damage > 2000.0)
		return;

	if (victim > 0 && IsClientInGame(victim) && GetClientTeam(victim) == 3 && IsPlayerAlive(victim))
	{
		if (GetEntData(victim, m_zombieClass_offset, 1) == 8 && GetEntData(victim, m_isIncapacitated_offset, 1))
			return;

		if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == 2 && IsPlayerAlive(attacker) && !GetEntData(attacker, m_isIncapacitated_offset, 1))
		{
			iAttackerHealthPre = GetEntData(attacker, m_iHealth_offset, 4);
			if (iAttackerHealthPre >= g_iMaxHealthLimit)
				return;

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
			if (iAttackerHealthPost > g_iMaxHealthLimit)
				iAttackerHealthPost = g_iMaxHealthLimit;

			SetEntData(attacker, m_iHealth_offset, iAttackerHealthPost, 4);
			//PrintToChat(attacker, "%N attack %N, damage = %.1f, AddHealth = %i", attacker, victim, damage, iAddHealth);
		}
	}
}

int GetHealthStatus(int iHealth)
{
	if (iHealth >= 100)
		return GREEN_HEALTH;

	if (40 <= iHealth < 100)
		return YELLOW_HEALTH;

	if (0 < iHealth < 40)
		return RED_HEALTH;
		
	return 0;
}
