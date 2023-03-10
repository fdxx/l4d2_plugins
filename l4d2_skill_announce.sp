#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>   
#include <dhooks>

#define VERSION "1.4"

#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6

#define	CUT_SHOVED		1
#define CUT_SHOVEDSURV	2
#define CUT_KILL		3
#define CUT_SLASH		4

#define DMGTYPE_MELEE	1
#define DMGTYPE_WEAPON	2

#define ASSIST_PLAYER	0
#define ASSIST_DMG		1
#define ASSIST_SHOTS	2

bool
	g_bBlockRockNotify[MAXPLAYERS],
	g_bSkeetDead[MAXPLAYERS],
	g_bShotCounted[MAXPLAYERS][MAXPLAYERS]; //[Victim][Attacker]

int
	g_iShotsDealt[MAXPLAYERS][MAXPLAYERS],
	g_iHunterDamage[MAXPLAYERS][MAXPLAYERS]; 

public Plugin myinfo = 
{
	name = "L4D2 Skill announce",
	author = "Tabun, zonemod, fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_skill_announce_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("tank_rock_killed", Event_RockKilled);
	HookEvent("charger_killed", Event_ChargerKilled);
	HookEvent("tongue_pull_stopped", Event_TonguePullStopped);
	//HookEvent("pounce_attempt_stopped", Event_PounceAttemptStopped);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("lunge_pounce", Event_LungePounce);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
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
	for (int i = 0; i <= MaxClients; i++)
	{
		g_bBlockRockNotify[i] = false;
		g_bSkeetDead[i] = false;
		ClearHunterDamage(i);
	}
}

void ClearHunterDamage(int iHunter)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_iShotsDealt[iHunter][i] = 0;
		g_iHunterDamage[iHunter][i] = 0;
	}
}

void Event_RockKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	// The moment of breaking the rock will trigger this event multiple times, so we suppress the notify for a short time.
	if (!g_bBlockRockNotify[client])
	{
		g_bBlockRockNotify[client] = true;

		if (IsValidSur(client) && !IsFakeClient(client) && IsPlayerAlive(client))
		{
			CPrintToChatAll("{orange}★ {olive}%N {blue}skeeted {default}a {olive}tank {default}rock", client);
		}

		CreateTimer(0.1, ResetRockNotify_Timer, client);
	}
}

Action ResetRockNotify_Timer(Handle timer, int client)
{
	g_bBlockRockNotify[client] = false;
	return Plugin_Continue;
}

void Event_ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("charging"))
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	bool bMelee = event.GetBool("melee");

	if (IsValidSI(victim) && IsValidSur(attacker) && IsPlayerAlive(attacker) && !IsFakeClient(attacker))
	{
		if (bMelee)
			CPrintToChatAll("{orange}★★ {olive}%N {blue}leveled {olive}%N {default}by {blue}melee", attacker, victim);
		else
			CPrintToChatAll("{orange}★★ {olive}%N {blue}leveled {olive}%N", attacker, victim);
	}
}

void Event_TonguePullStopped(Event event, const char[] name, bool dontBroadcast)
{
	int rescuer = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	int smoker = GetClientOfUserId(event.GetInt("smoker"));
	int reason = event.GetInt("release_type");

	if (rescuer != victim)
		return;

	if (IsValidSur(victim) && IsPlayerAlive(victim) && !IsFakeClient(victim))
	{
		if (IsValidSI(smoker) && IsPlayerAlive(smoker))
		{
			switch (reason)
			{
				case CUT_SHOVED:
					CPrintToChatAll("{orange}★★ {olive}%N {blue}self-cleared {default}from a {olive}%N{default}'s tongue by {blue}shoving", victim, smoker);

				case CUT_KILL:
					CPrintToChatAll("{orange}★★ {olive}%N {blue}self-cleared {default}from a {olive}%N{default}'s tongue", victim, smoker);

				case CUT_SLASH:
					CPrintToChatAll("{orange}★★★ {olive}%N {blue}cut {olive}%N{default}'s tongue", victim, smoker);
			}
		}
	}
}

void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int damage = event.GetInt("damage");
	if (damage >= 20)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		int victim = GetClientOfUserId(event.GetInt("victim"));
		//int distance = event.GetInt("distance");

		if (IsValidSI(client) && IsValidSur(victim))
		{
			CPrintToChatAll("{orange}★★★ {olive}%N {red}high-pounced {olive}%N {orange}%i {default}damage", client, victim, damage);
		}
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
	{
		g_bBlockRockNotify[client] = false;
		g_bSkeetDead[client] = false;
		ClearHunterDamage(client);
	}
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	static int client, i;
	client = GetClientOfUserId(event.GetInt("userid"));

	for (i = 1; i <= MaxClients; i++)
		g_bShotCounted[i][client] = false; // [Victim][Attacker]
}

Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0)
		return Plugin_Continue;

	if (IsValidSI(victim) && GetZombieClass(victim) == HUNTER && IsPlayerAlive(victim))
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			if (!g_bShotCounted[victim][attacker])
			{
				g_iShotsDealt[victim][attacker]++;
				g_bShotCounted[victim][attacker] = true;
			}

			static int iHealth;
			iHealth = GetEntProp(victim, Prop_Data, "m_iHealth");

			if (damage >= float(iHealth))
				g_iHunterDamage[victim][attacker] += iHealth;
			else
				g_iHunterDamage[victim][attacker] += RoundToFloor(damage);
		}
	}
	return Plugin_Continue;
}

MRESReturn OnEventKilledPre(int client, DHookParam hParams)
{
	if (IsValidSI(client))
	{
		int iClass = GetZombieClass(client);
		if (iClass == HUNTER || iClass == JOCKEY)
			g_bSkeetDead[client] = IsInTheAir(client, iClass);
	}
	return MRES_Ignored;
}

MRESReturn OnEventKilledPost(int client, DHookParam hParams)
{
	g_bSkeetDead[client] = false;
	ClearHunterDamage(client);
	return MRES_Ignored;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int victim, class, attacker, type, i;

	victim = GetClientOfUserId(event.GetInt("userid"));
	if (!g_bSkeetDead[victim] || !IsValidSI(victim))
		return;

	class = GetZombieClass(victim);
	if (class != HUNTER && class != JOCKEY)
		return;

	attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidSur(attacker) || IsFakeClient(attacker) || !IsPlayerAlive(attacker))
		return;

	type = event.GetInt("type");

	switch (class)
	{
		case JOCKEY:
		{
			if (type & DMG_SLASH || type & DMG_CLUB)
				CPrintToChatAll("{orange}★★ {olive}%N {default}was {blue}melee-skeeted {default}by {olive}%N", victim, attacker);
			else if (type & DMG_BURN == 0)
				CPrintToChatAll("{orange}★★ {olive}%N {blue}skeeted {olive}%N", attacker, victim);
		}
		case HUNTER:
		{
			if (type & DMG_SLASH || type & DMG_CLUB)
				CPrintToChatAll("{orange}★★ {olive}%N {default}was {blue}melee-skeeted {default}by {olive}%N", victim, attacker);

			else if (type & DMG_BURN == 0)
			{
				int[][] assist = new int[MaxClients][3];
				int iCount;

				for (i = 1; i <= MaxClients; i++)
				{
					if (i == attacker)
						continue;

					if (g_iHunterDamage[victim][i] > 0 && IsClientInGame(i) && GetClientTeam(i) == 2)
					{
						assist[iCount][ASSIST_PLAYER] = i;
						assist[iCount][ASSIST_DMG] = g_iHunterDamage[victim][i];
						assist[iCount][ASSIST_SHOTS] = g_iShotsDealt[victim][i];
						iCount++;
					}
				}

				if (iCount)
				{
					SortCustom2D(assist, iCount, SortDamageByDescending);

					static char sAssistData[MAX_MESSAGE_LENGTH], sBuffer[128];
					FormatEx(sAssistData, sizeof(sAssistData), "%N (%i dmg/%i shot%s)", assist[0][ASSIST_PLAYER], assist[0][ASSIST_DMG], assist[0][ASSIST_SHOTS], (assist[0][ASSIST_SHOTS] == 1 ? "":"s"));

					for (i = 1; i < iCount; i++)
					{
						FormatEx(sBuffer, sizeof(sBuffer), ", %N (%i dmg/%i shot%s)", assist[i][ASSIST_PLAYER], assist[i][ASSIST_DMG], assist[i][ASSIST_SHOTS], (assist[i][ASSIST_SHOTS] == 1 ? "":"s"));
						StrCat(sAssistData, sizeof(sAssistData), sBuffer);
					}

					CPrintToChatAll("{orange}★ {olive}%N {blue}teamskeeted {olive}%N {default}for {orange}%i {default}dmg in {orange}%i {default}shot%s. {blue}Assisted by: {default}%s", attacker, victim, g_iHunterDamage[victim][attacker], g_iShotsDealt[victim][attacker], (g_iShotsDealt[victim][attacker] == 1 ? "":"s"), sAssistData);
				}
				else
				{
					CPrintToChatAll("{orange}★ {olive}%N {blue}skeeted {olive}%N {default}in {orange}%i {default}shot%s.", attacker, victim, g_iShotsDealt[victim][attacker], (g_iShotsDealt[victim][attacker] == 1 ? "":"s"));
				}
			}
		}
	}
}

int SortDamageByDescending(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[ASSIST_DMG] > y[ASSIST_DMG])
		return -1;
	if (x[ASSIST_DMG] < y[ASSIST_DMG])
		return 1;
	return 0;
}

bool IsInTheAir(int client, int iClass)
{
	if ((GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) > 0)
		return false;

	switch (iClass)
	{
		case HUNTER:
		{
			if (GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0)
				return false;
		}
		case JOCKEY:
		{
			if (GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0)
				return false;
		}
	}

	return GetEntityMoveType(client) != MOVETYPE_LADDER;
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

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

void Init()
{
	GameData hGameData = new GameData("l4d2_skill_announce");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_skill_announce.txt\" gamedata.");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::Event_Killed");
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::Event_Killed");
	if (!dDetour.Enable(Hook_Pre, OnEventKilledPre))
		SetFailState("Failed to detour pre: OnEventKilledPre");
	if (!dDetour.Enable(Hook_Post, OnEventKilledPost))
		SetFailState("Failed to detour pre: OnEventKilledPost");

	delete hGameData;
}
