#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "1.3"

ConVar CvarHealthLimit, CvarAddHealthFlame, CvarDamageInfo;
int g_iMaxHealthLimit, g_iAddHealthFlame;
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
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_restore_hp_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarHealthLimit = CreateConVar("l4d2_restore_hp_limit", "200", "达到多少血量后不再加血", FCVAR_NONE);
	CvarAddHealthFlame = CreateConVar("l4d2_restore_hp_flame", "1", "火焰伤害加多少血", FCVAR_NONE);
	CvarDamageInfo = CreateConVar("l4d2_restore_hp_show_info", "0", "聊天框打印加血信息", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	CvarHealthLimit.AddChangeHook(ConVarChanged);
	CvarAddHealthFlame.AddChangeHook(ConVarChanged);
	CvarDamageInfo.AddChangeHook(ConVarChanged);

	HookEvent("player_hurt", Event_PlayerHurt);

	//AutoExecConfig(true, "l4d2_restore_hp");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iMaxHealthLimit = CvarHealthLimit.IntValue;
	g_iAddHealthFlame = CvarAddHealthFlame.IntValue;
	g_bDamageInfo = CvarDamageInfo.BoolValue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	static int iDamage, iVictim, iAttacker, iAttackerPreHealth, iHealthLevel, iAddHealth, iAttackerPostHealth;
	static char sWeapon[64];

	iDamage = event.GetInt("dmg_health");
	if (iDamage <= 1 || iDamage > 2000) return Plugin_Continue; //排除异常伤害

	iVictim = GetClientOfUserId(event.GetInt("userid"));

	if (IsValidSI(iVictim) && IsPlayerAlive(iVictim))
	{
		iAttacker = GetClientOfUserId(event.GetInt("attacker"));

		if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker) && !GetEntProp(iAttacker, Prop_Send, "m_isIncapacitated"))
		{
			iAttackerPreHealth = GetEntProp(iAttacker, Prop_Data, "m_iHealth");
			if (iAttackerPreHealth >= g_iMaxHealthLimit) return Plugin_Continue;

			event.GetString("weapon", sWeapon, sizeof(sWeapon));
			iHealthLevel = GetHealthStatus(iAttackerPreHealth);
			iAddHealth = 0;

			if (strcmp(sWeapon, "melee") == 0)
			{
				switch (iHealthLevel)
				{
					case GREEN_HEALTH: iAddHealth = 7;
					case YELLOW_HEALTH: iAddHealth = 12;
					case RED_HEALTH: iAddHealth = 25;
				}
			}
			else if (strcmp(sWeapon, "entityflame") == 0 || strcmp(sWeapon, "inferno") == 0) //火伤害
			{
				iAddHealth = g_iAddHealthFlame;
			}
			else
			{
				switch (iHealthLevel)
				{
					case GREEN_HEALTH: iAddHealth = RoundToCeil(iDamage * 0.03);
					case YELLOW_HEALTH: iAddHealth = RoundToCeil(iDamage * 0.05);
					case RED_HEALTH: iAddHealth = RoundToCeil(iDamage * 0.08);
				}
			}

			iAttackerPostHealth = iAttackerPreHealth + iAddHealth;
			if (iAttackerPostHealth > g_iMaxHealthLimit) iAttackerPostHealth = g_iMaxHealthLimit;

			SetEntProp(iAttacker, Prop_Data, "m_iHealth", iAttackerPostHealth);

			if (g_bDamageInfo)
				PrintToChat(iAttacker, "\x01你使用 \x04%s \x01对 \x05%N \x01造成 \x04%i \x01伤害, \x01加 \x04%i \x01血", sWeapon, iVictim, iDamage, iAddHealth);
		}
	}
	return Plugin_Continue;
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


