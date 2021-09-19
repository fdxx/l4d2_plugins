#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>
#include <sdktools>

#define VERSION "0.8"

#define SMOKER	1
#define BOOMER	2
#define HUNTER	3
#define SPITTER	4
#define JOCKEY	5
#define CHARGER	6

#define CUT_SHOVED		1 // 推smoker
#define CUT_SHOVEDSURV	2 // 推生还者
#define CUT_KILL		3 // 枪杀
#define CUT_SLASH		4 // 砍舌头

bool g_bShotCounted[MAXPLAYERS+1][MAXPLAYERS+1]; //Victim/Attacker
int g_iShotsDealt[MAXPLAYERS+1][MAXPLAYERS+1];
int g_iHunterDamage[MAXPLAYERS+1][MAXPLAYERS+1]; 

bool g_bPouncing[MAXPLAYERS+1];
Handle hAbilityUseTimer[MAXPLAYERS+1];
char g_LogPath[PLATFORM_MAX_PATH];

ConVar CvarSmokerEnable, CvarHunterEnable, CvarJockeyEnable, CvarChargerEnable, CvarTankEnable;
bool g_bSmokerEnable, g_bHunterEnable, g_bJockeyEnable, g_bChargerEnable, g_bTankEnable;

public Plugin myinfo = 
{
	name = "L4D2 Skill announce",
	author = "Tabun, Visor, Mart, Sir, fdxx",
	description = "Only support coop mode",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_LogPath, sizeof(g_LogPath), "logs/l4d2_skill_announce.log");

	CreateConVar("l4d2_skill_announce_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarSmokerEnable = CreateConVar("l4d2_skill_announce_smoker", "1", "宣布smoker自救", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarHunterEnable = CreateConVar("l4d2_skill_announce_hunter", "1", "宣布空爆hunter", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarJockeyEnable = CreateConVar("l4d2_skill_announce_jockey", "1", "宣布空爆jockey", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarChargerEnable = CreateConVar("l4d2_skill_announce_charger", "1", "宣布击倒冲锋charger", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarTankEnable = CreateConVar("l4d2_skill_announce_tank", "1", "宣布空爆tank rock", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	CvarSmokerEnable.AddChangeHook(ConVarChanged);
	CvarHunterEnable.AddChangeHook(ConVarChanged);
	CvarJockeyEnable.AddChangeHook(ConVarChanged);
	CvarChargerEnable.AddChangeHook(ConVarChanged);
	CvarTankEnable.AddChangeHook(ConVarChanged);

	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("hunter_punched", Event_HunterPunched, EventHookMode_Pre);
	HookEvent("lunge_pounce", Event_LungePounce, EventHookMode_Pre);
	HookEvent("tongue_pull_stopped", Event_TonguePullStopped);
	HookEvent("charger_killed", Event_ChargerKilled);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_death", Event_PlayerDeath);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bSmokerEnable = CvarSmokerEnable.BoolValue;
	g_bHunterEnable = CvarHunterEnable.BoolValue;
	g_bJockeyEnable = CvarJockeyEnable.BoolValue;
	g_bChargerEnable = CvarChargerEnable.BoolValue;
	g_bTankEnable = CvarTankEnable.BoolValue;
}

public void OnConfigsExecuted()
{
	if (g_bTankEnable)
		HookTankRockEntity();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.5, RoundStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStart_Timer(Handle timer)
{
	Reset();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	for (int i = 0; i < MAXPLAYERS+1; i++)
	{
		delete hAbilityUseTimer[i];
		g_bPouncing[i] = false;
		ClearDamage(i);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void HookTankRockEntity()
{
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "tank_rock")) != INVALID_ENT_REFERENCE)
	{
		SDKHook(entity, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bTankEnable)
		return;
		
	if (!IsValidEntityIndex(entity))
		return;

	if (classname[0] != 't')
		return;

	if (StrEqual(classname, "tank_rock"))
		SDKHook(entity, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
}

public void OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3])
{
	if (GetEntProp(victim, Prop_Data, "m_iHealth") > 0)
		return;

	if (IsValidSur(attacker) && IsPlayerAlive(attacker) && !IsFakeClient(attacker))
	{
		CPrintToChatAll("{orange}★ {olive}%N {blue}skeeted {default}a tank rock", attacker);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (IsValidSI(victim) && IsPlayerAlive(victim))
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			static char sInflictor[64];
			if (GetEdictClassname(inflictor, sInflictor, sizeof(sInflictor)))
			{
				switch (GetZombieClass(victim))
				{
					case JOCKEY:
					{
						if (g_bJockeyEnable)
						{
							if (damage >= float(GetEntProp(victim, Prop_Data, "m_iHealth")))
							{
								if (!IsOnGround(victim) && !HasSIVictim(victim) && !IsOnLadder(victim))
								{
									if (!IsFakeClient(attacker))
									{
										if (strcmp(sInflictor, "weapon_melee") == 0)
										{
											CPrintToChatAll("{orange}★★ {olive}%N {default}was {blue}melee-skeeted {default}by {olive}%N", victim, attacker);
										}

										if (strcmp(sInflictor, "player") == 0)
										{
											CPrintToChatAll("{orange}★★ {olive}%N {blue}skeeted {olive}%N", attacker, victim);
										}
									}
								}
							}
						}
					}

					case HUNTER:
					{
						if (g_bHunterEnable)
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
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bHunterEnable)
	{
		static int iVictim, iAttacker;
		iVictim = GetClientOfUserId(event.GetInt("userid"));
		iAttacker = GetClientOfUserId(event.GetInt("attacker"));
		
		if (IsValidSI(iVictim) && GetZombieClass(iVictim) == HUNTER)
		{
			if (g_bPouncing[iVictim] && !HasSIVictim(iVictim) && !IsOnLadder(iVictim))
			{
				if (IsValidSur(iAttacker) && !IsFakeClient(iAttacker) && IsPlayerAlive(iAttacker))
				{
					static char sWeapon[64];
					event.GetString("weapon", sWeapon, sizeof(sWeapon));

					if (strcmp(sWeapon, "melee") == 0)
					{
						CPrintToChatAll("{orange}★ {olive}%N {default}was {blue}melee-skeeted {default}by {olive}%N", iVictim, iAttacker);
					}

					else if (strcmp(sWeapon, "entityflame") != 0 && strcmp(sWeapon, "inferno") != 0) //火伤害
					{
						int iAssisterCount;
						//1D=AssisterCount, 2D[0]=AssisterIndex, 2D[1]=AssisterDamage, 2D[2]=AssisterShots
						int[][] iAssisterData = new int[MaxClients][3]; 

						for (int i = 1; i <= MaxClients; i++)
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
							Format(sAssisterString, sizeof(sAssisterString), "%N (%i/%i shot%s)", iAssisterData[0][0], iAssisterData[0][1], iAssisterData[0][2], (iAssisterData[0][2] == 1 ? "" : "s"));
							for (int i = 1; i < iAssisterCount; i++)
							{
								Format(sBuffer, sizeof(sBuffer), ", %N (%i/%i shot%s)", iAssisterData[i][0], iAssisterData[i][1], iAssisterData[i][2], (iAssisterData[i][2] == 1 ? "" : "s"));
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
			//CPrintToChatAll("伤害 %i", g_iHunterDamage[iVictim][iAttacker]);
			g_bPouncing[iVictim] = false;
			ClearDamage(iVictim);
		}
	}
}

public int SortByDamageDesc(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	for (int i = 1; i <= MaxClients; i++)
	{
		// [Victim][Attacker]
		g_bShotCounted[i][client] = false;
	}
}

public void Event_ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	bool bMelee = event.GetBool("melee");
	bool bCharging = event.GetBool("charging");

	if (g_bChargerEnable)
	{
		if (bCharging && IsValidSI(iVictim))
		{
			if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker) && !IsFakeClient(iAttacker))
			{
				if (bMelee)
				{
					CPrintToChatAll("{orange}★★ {olive}%N {blue}leveled {olive}%N {default}by {blue}Melee", iAttacker, iVictim);
				}
				else CPrintToChatAll("{orange}★★ {olive}%N {blue}leveled {olive}%N", iAttacker, iVictim);
			}
		}
	}
}

public void Event_TonguePullStopped(Event event, const char[] name, bool dontBroadcast)
{
	int StopTonguePlayer = GetClientOfUserId(event.GetInt("userid"));
	int BeingPulledPlayer = GetClientOfUserId(event.GetInt("victim"));
	int Smoker = GetClientOfUserId(event.GetInt("smoker"));
	int Reason = event.GetInt("release_type");

	if (g_bSmokerEnable)
	{
		if (IsValidSur(StopTonguePlayer) && IsPlayerAlive(StopTonguePlayer) && !IsFakeClient(StopTonguePlayer))
		{
			if (IsValidSI(Smoker) && IsPlayerAlive(Smoker))
			{
				if (StopTonguePlayer == BeingPulledPlayer)
				{
					switch (Reason)
					{
						case CUT_SHOVED: CPrintToChatAll("{orange}★★ {olive}%N {blue}self-cleared {default}from a {olive}%N{default}'s tongue by {blue}shoving", StopTonguePlayer, Smoker);
						case CUT_KILL: CPrintToChatAll("{orange}★★ {olive}%N {blue}self-cleared {default}from a {olive}%N{default}'s tongue", StopTonguePlayer, Smoker);
						case CUT_SLASH: CPrintToChatAll("{orange}★★★ {olive}%N {blue}cut {olive}%N{default}'s tongue", StopTonguePlayer, Smoker);
					}
				}
			}
		}
	}
}

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsValidSI(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == HUNTER)
	{
		delete hAbilityUseTimer[client];
		g_bPouncing[client] = true;
		hAbilityUseTimer[client] = CreateTimer(0.1, AbilityUse_Timer, client, TIMER_REPEAT);
	}
}

public Action AbilityUse_Timer(Handle timer, int client)
{
	if (!IsValidSI(client) || !IsPlayerAlive(client) || IsOnGround(client))
	{
		g_bPouncing[client] = false;
		hAbilityUseTimer[client] = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

//hunter被推
public Action Event_HunterPunched(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("hunteruserid"));
	if (IsValidSI(client))
	{
		g_bPouncing[client] = false;
	}
	return Plugin_Continue;
}

//hunter扑中人
public Action Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidSI(client) && GetZombieClass(client) == HUNTER)
	{
		g_bPouncing[client] = false;
	}
	return Plugin_Continue;
}

//在梯子上
bool IsOnLadder(int client)
{
	return (GetEntityMoveType(client) == MOVETYPE_LADDER);
}

//在控人
bool HasSIVictim(int client)
{
	int Victim = -1;
	int ZombieClass = GetZombieClass(client);

	switch (ZombieClass)
	{
		case CHARGER:
		{
			Victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
		}

		case JOCKEY:
		{
			Victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
		}

		case HUNTER:
		{
			Victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
		}

		case SMOKER:
		{
			Victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
		}
	}

	return (IsValidSur(Victim) && IsPlayerAlive(Victim));
}


//在地上
bool IsOnGround(int client)
{
	return (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) > 0;
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

void ClearDamage(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iShotsDealt[client][i] = 0;
		g_iHunterDamage[client][i] = 0;
	}
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}
