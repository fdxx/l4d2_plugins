#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>  

#define VERSION "0.3"

#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6
#define	SI_CLASS_SIZE	7

#define	TOTAL	0
#define	SUR		2
#define	INF		3

ConVar g_cvPinnedDmg[SI_CLASS_SIZE];
float g_fPinnedDmg[SI_CLASS_SIZE];
bool g_bDisable, g_bAlone;

public Plugin myinfo =
{
	name = "L4D2 Alone mode",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_alone_mode_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_cvPinnedDmg[SMOKER] = CreateConVar("l4d2_alone_damage_smoker", "5.0");
	g_cvPinnedDmg[HUNTER] = CreateConVar("l4d2_alone_damage_hunter", "9.0");
	g_cvPinnedDmg[JOCKEY] = CreateConVar("l4d2_alone_damage_jockey", "9.0");
	g_cvPinnedDmg[CHARGER] = CreateConVar("l4d2_alone_damage_charger", "0.0");
	
	OnConVarChanged(null, "", "");

	g_cvPinnedDmg[SMOKER].AddChangeHook(OnConVarChanged);
	g_cvPinnedDmg[HUNTER].AddChangeHook(OnConVarChanged);
	g_cvPinnedDmg[JOCKEY].AddChangeHook(OnConVarChanged);
	g_cvPinnedDmg[CHARGER].AddChangeHook(OnConVarChanged);

	CreateTimer(0.5, CheckPlayerCount_Timer, _, TIMER_REPEAT);
	LoadTranslations("l4d2_alone_mode.phrases.txt");

	RegConsoleCmd("sm_alone", Cmd_SwitchAloneMode);
	// AutoExecConfig(true, "l4d2_alone_mode");
}

Action Cmd_SwitchAloneMode(int client, int args)
{
	if (g_bAlone)
	{
		g_bDisable = !g_bDisable;
		CPrintToChatAll("%t", g_bDisable ? "ManuallyDisabled" : "ManuallyEnabled", client);
		return Plugin_Handled;
	}

	CPrintToChat(client, "%t", "UnavailableInMultiplayer");
	return Plugin_Handled;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fPinnedDmg[SMOKER] = g_cvPinnedDmg[SMOKER].FloatValue;
	g_fPinnedDmg[HUNTER] = g_cvPinnedDmg[HUNTER].FloatValue;
	g_fPinnedDmg[JOCKEY] = g_cvPinnedDmg[JOCKEY].FloatValue;
	g_fPinnedDmg[CHARGER] = g_cvPinnedDmg[CHARGER].FloatValue;
}

Action CheckPlayerCount_Timer(Handle timer)
{
	bool oldValue = g_bAlone;
	int iCount[4], iTeam;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			iTeam = GetClientTeam(i);
			if (iTeam == SUR || iTeam == INF)
			{
				iCount[TOTAL]++;
				iCount[iTeam]++;
			}
		}
	}

	if (iCount[TOTAL] > 0 && iCount[TOTAL] < 3)
		g_bAlone = iCount[SUR] == 1 || iCount[INF] == 1;
	else
		g_bAlone = false;

	if (g_bAlone != oldValue)
		Notify();

	return Plugin_Continue;
}

void Notify()
{
	if (!g_bDisable)
		CPrintToChatAll("%t", g_bAlone ? "AutoEnabled" : "AutoDisabled");
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!g_bAlone || g_bDisable || damage <= 0.0)
		return;

	if (!IsValidSur(victim) || !IsPlayerAlive(victim))
		return;

	if (!IsValidSI(attacker) || !IsPlayerAlive(attacker))
		return;

	if (IsFakeClient(victim) && IsFakeClient(attacker))
		return;

	static int iClass;
	iClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");

	switch (iClass)
	{
		case SMOKER, HUNTER, JOCKEY, CHARGER:
		{
			if (g_fPinnedDmg[iClass] >= 0.0 && GetPinnedSurvivor(attacker, iClass) == victim)
			{
				SDKHooks_TakeDamage(victim, attacker, attacker, g_fPinnedDmg[iClass]);
				CPrintToChatAll("%t", "RemainingHealth", attacker, GetEntProp(attacker, Prop_Data, "m_iHealth"));
				ForcePlayerSuicide(attacker);
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

