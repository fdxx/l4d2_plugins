#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.9"

#include <sourcemod>
#include <sdkhooks>
#include <multicolors> // https://github.com/Bara/Multi-Colors
#include <dhooks>

enum
{
	SMOKER	= 1,
	BOOMER	= 2,
	HUNTER	= 3,
	SPITTER	= 4,
	JOCKEY	= 5,
	CHARGER	= 6,
}

enum DamageType
{
	Dmg_None,
	Dmg_Melee,
	Dmg_Weapon,
}

enum
{
	CUT_SHOVED		= 1,
	CUT_SHOVEDSURV	= 2,
	CUT_KILL		= 3,
	CUT_SLASH		= 4,
}

bool
	g_bRock[MAXPLAYERS] = {true, ...},
	g_bSkeetDead[MAXPLAYERS],
	g_bShotCounted[MAXPLAYERS][MAXPLAYERS]; //Victim/Attacker

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
	InitGameData();

	CreateConVar("l4d2_skill_announce_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("tank_rock_killed", Event_RockKilled);
	HookEvent("charger_killed", Event_ChargerKilled);
	HookEvent("tongue_pull_stopped", Event_TonguePullStopped);
	//HookEvent("pounce_attempt_stopped", Event_PounceAttemptStopped);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_spawn", Event_PlayerSpawn);
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
	static int i;
	for (i = 0; i <= MaxClients; i++)
	{
		g_bRock[i] = true;
		g_bSkeetDead[i] = false;
		ClearHunterDamage(i);
	}
}

void ClearHunterDamage(int iHunter)
{
	static int i;
	for (i = 0; i <= MaxClients; i++)
	{
		g_iShotsDealt[iHunter][i] = 0;
		g_iHunterDamage[iHunter][i] = 0;
	}
}

void Event_RockKilled(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (g_bRock[client])
	{
		g_bRock[client] = false;

		if (IsValidSur(client) && !IsFakeClient(client) && IsPlayerAlive(client))
		{
			CPrintToChatAll("{orange}★ {olive}%N {blue}skeeted {default}a {olive}tank {default}rock", client);
		}

		CreateTimer(0.1, ResetRock_Timer, client);
	}
}

Action ResetRock_Timer(Handle timer, int client)
{
	g_bRock[client] = true;
	return Plugin_Continue;
}

void Event_ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	bool bMelee = event.GetBool("melee");
	bool bCharging = event.GetBool("charging");

	if (bCharging && IsValidSI(iVictim))
	{
		if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker) && !IsFakeClient(iAttacker))
		{
			if (bMelee) CPrintToChatAll("{orange}★★ {olive}%N {blue}leveled {olive}%N {default}by {blue}melee", iAttacker, iVictim);
			else CPrintToChatAll("{orange}★★ {olive}%N {blue}leveled {olive}%N", iAttacker, iVictim);
		}
	}
}

void Event_TonguePullStopped(Event event, const char[] name, bool dontBroadcast)
{
	int iStopTonguePlayer = GetClientOfUserId(event.GetInt("userid"));
	int iBeingPulledPlayer = GetClientOfUserId(event.GetInt("victim"));
	int iSmoker = GetClientOfUserId(event.GetInt("smoker"));
	int iReason = event.GetInt("release_type");

	if (IsValidSur(iStopTonguePlayer) && IsPlayerAlive(iStopTonguePlayer) && !IsFakeClient(iStopTonguePlayer))
	{
		if (IsValidSI(iSmoker) && IsPlayerAlive(iSmoker))
		{
			if (iStopTonguePlayer == iBeingPulledPlayer)
			{
				switch (iReason)
				{
					case CUT_SHOVED: CPrintToChatAll("{orange}★★ {olive}%N {blue}self-cleared {default}from a {olive}%N{default}'s tongue by {blue}shoving", iStopTonguePlayer, iSmoker);
					case CUT_KILL: CPrintToChatAll("{orange}★★ {olive}%N {blue}self-cleared {default}from a {olive}%N{default}'s tongue", iStopTonguePlayer, iSmoker);
					case CUT_SLASH: CPrintToChatAll("{orange}★★★ {olive}%N {blue}cut {olive}%N{default}'s tongue", iStopTonguePlayer, iSmoker);
				}
			}
		}
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0)
	{
		g_bRock[client] = true;
		g_bSkeetDead[client] = false;
		ClearHunterDamage(client);
	}
}

public void OnClientPutInServer(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0) return Plugin_Continue;

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
			{
				g_iHunterDamage[victim][attacker] += iHealth;
			}
			else g_iHunterDamage[victim][attacker] += RoundToFloor(damage);
		}
	}
	return Plugin_Continue;
}

MRESReturn mreOnEventKilledPre(int client)
{
	if (IsValidSI(client))
	{
		switch (GetZombieClass(client))
		{
			case JOCKEY:
			{
				// GetEntProp(client, Prop_Send, "m_duckUntilOnGround")
				if (IsInTheAir(client))
				{
					g_bSkeetDead[client] = true;
				}
			}
			case HUNTER:
			{
				if (GetEntProp(client, Prop_Send, "m_isAttemptingToPounce"))
				{
					g_bSkeetDead[client] = true;
				}
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreOnEventKilledPost(int client)
{
	g_bSkeetDead[client] = false;
	return MRES_Ignored;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int iVictim, iClass, iAttacker, iDmgType, i;
	static DamageType eDmgType;

	iVictim = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSI(iVictim))
	{
		if (g_bSkeetDead[iVictim])
		{
			g_bSkeetDead[iVictim] = false;

			iClass = GetZombieClass(iVictim);
			if (iClass == JOCKEY || iClass == HUNTER)
			{
				iAttacker = GetClientOfUserId(event.GetInt("attacker"));
				if (IsValidSur(iAttacker) && !IsFakeClient(iAttacker) && IsPlayerAlive(iAttacker))
				{
					iDmgType = event.GetInt("type");
					eDmgType = Dmg_None;
					
					if (iDmgType & DMG_SLASH || iDmgType & DMG_CLUB)
						eDmgType = Dmg_Melee;
					else if (!(iDmgType & DMG_BURN))
						eDmgType = Dmg_Weapon;

					switch (iClass)
					{
						case JOCKEY:
						{
							switch (eDmgType)
							{
								case Dmg_Melee: CPrintToChatAll("{orange}★★ {olive}%N {default}was {blue}melee-skeeted {default}by {olive}%N", iVictim, iAttacker);
								case Dmg_Weapon: CPrintToChatAll("{orange}★★ {olive}%N {blue}skeeted {olive}%N", iAttacker, iVictim);
							}
						}
						case HUNTER:
						{
							switch (eDmgType)
							{
								case Dmg_Melee: CPrintToChatAll("{orange}★ {olive}%N {default}was {blue}melee-skeeted {default}by {olive}%N", iVictim, iAttacker);
								case Dmg_Weapon:
								{
									//1D=AssisterCount, 2D[0]=AssisterIndex, 2D[1]=AssisterDamage, 2D[2]=AssisterShots
									int[][] iAssisterData = new int[MaxClients][3];
									int iAssisterCount;

									for (i = 1; i <= MaxClients; i++)
									{
										if (i == iAttacker) continue;

										if (g_iHunterDamage[iVictim][i] > 0 && IsValidSur(i))
										{
											iAssisterData[iAssisterCount][0] = i;
											iAssisterData[iAssisterCount][1] = g_iHunterDamage[iVictim][i];
											iAssisterData[iAssisterCount][2] = g_iShotsDealt[iVictim][i];
											iAssisterCount++;
										}
									}

									if (iAssisterCount)
									{
										SortCustom2D(iAssisterData, iAssisterCount, SortByDamageDesc);

										static char sAssisterString[256], sBuffer[128];
										FormatEx(sAssisterString, sizeof(sAssisterString), "%N (%i dmg /%i shot%s)", iAssisterData[0][0], iAssisterData[0][1], iAssisterData[0][2], (iAssisterData[0][2] == 1 ? "" : "s"));

										for (i = 1; i < iAssisterCount; i++)
										{
											FormatEx(sBuffer, sizeof(sBuffer), ", %N (%i dmg /%i shot%s)", iAssisterData[i][0], iAssisterData[i][1], iAssisterData[i][2], (iAssisterData[i][2] == 1 ? "" : "s"));
											StrCat(sAssisterString, sizeof(sAssisterString), sBuffer);
										}

										CPrintToChatAll("{orange}★ {olive}%N {blue}teamskeeted {olive}%N {default}for {orange}%i {default}damage in {orange}%i {default}shot%s. {blue}Assisted by: {default}%s", iAttacker, iVictim, g_iHunterDamage[iVictim][iAttacker], g_iShotsDealt[iVictim][iAttacker], (g_iShotsDealt[iVictim][iAttacker] == 1 ? "" : "s"), sAssisterString);
									}
									else
									{
										CPrintToChatAll("{orange}★ {olive}%N {blue}skeeted {olive}%N {default}in {orange}%i {default}shot%s.", iAttacker, iVictim, g_iShotsDealt[iVictim][iAttacker], (g_iShotsDealt[iVictim][iAttacker] == 1 ? "" : "s"));
									}
								}
							}
						}
					}
				}
			}
		}

		ClearHunterDamage(iVictim);
	}
}

int SortByDamageDesc(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	static int client, i;

	client = GetClientOfUserId(event.GetInt("userid"));
	for (i = 0; i <= MaxClients; i++)
	{
		// [Victim][Attacker]
		g_bShotCounted[i][client] = false;
	}
}

bool IsInTheAir(int client)
{
	if ((GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) > 0)
		return false;
	
	static int iVictim;
	iVictim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
	if (IsValidSur(iVictim) && IsPlayerAlive(iVictim))
		return false;

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

void InitGameData()
{
	GameData hGameData = new GameData("l4d2_skill_announce");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_skill_announce.txt\" gamedata.");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::Event_Killed");
	if (dDetour == null)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::Event_Killed");
	if (!dDetour.Enable(Hook_Pre, mreOnEventKilledPre))
		SetFailState("Failed to detour pre: mreOnEventKilledPre");
	if (!dDetour.Enable(Hook_Post, mreOnEventKilledPost))
		SetFailState("Failed to detour pre: mreOnEventKilledPost");

	delete hGameData;
}
