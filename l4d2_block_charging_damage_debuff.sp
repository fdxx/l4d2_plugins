

// This plugin is deprecated.
// Use better: https://github.com/fdxx/l4d2_plugins/blob/main/l4d2_charging_damage.sp

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name = "L4D2 Block charging damage debuff",
	author = "Tabun, dcx2, fdxx",
	description = "调整 Charger 冲刺减伤",
	version = "0.3",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_ai_damagefix.sp"
}

public void OnPluginStart()
{
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0) return Plugin_Continue;

	if (IsValidSI(victim) && GetEntProp(victim, Prop_Send, "m_zombieClass") == 6 && IsFakeClient(victim) && IsPlayerAlive(victim))
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			static int iAbilityEnt;
			iAbilityEnt = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
			if (IsValidEntity(iAbilityEnt) && (GetEntProp(iAbilityEnt, Prop_Send, "m_isCharging") > 0))
			{
				damage *= 3.5;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
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
