#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>  

#define VERSION "2.5"

#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6
#define	TANK	8

#define	CLEAR_ATTACKER	0
#define	CLEAR_VICTIM	1

#define	MAX_ENTITY	2049

#define	SORT_DAMAGE	1
#define	SORT_FF	2
#define	SORT_WITCHDMG 3


enum struct killData
{
	int player;
	int damage;
	float WitchDmg;
	int SI;
	int CI;
	int FF;
}

ConVar
	z_witch_health,
	g_cvDmgWithTank,
	g_cvDmgWithWitch,
	g_cvDmgWithCI,
	g_cvTankDmgNotify,
	g_cvWitchDmgNotify;

bool
	g_bDmgWithTank,
	g_bDmgWithWitch,
	g_bDmgWithCI,
	g_bTankDmgNotify,
	g_bWitchDmgNotify,
	g_bTankAlive[MAXPLAYERS+1];

int
	g_iTotalDmg[MAXPLAYERS+1],
	g_iKillSI[MAXPLAYERS+1],
	g_iKillCI[MAXPLAYERS+1],
	g_iFriendlyFire[MAXPLAYERS+1],
	g_iTankDmg[MAXPLAYERS+1][MAXPLAYERS+1];	//[victim][attacker]

float
	g_fWitchHealth[MAX_ENTITY],
	g_fWitchDmg[MAX_ENTITY][MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "L4D2 Kill mvp",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_kill_mvp_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	z_witch_health = FindConVar("z_witch_health");

	g_cvDmgWithTank =		CreateConVar("l4d2_kill_mvp_add_tank_damage",				"1", "Total damage includes Tank damage.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvDmgWithWitch =		CreateConVar("l4d2_kill_mvp_add_witch_damage",				"1", "Total damage includes Witch damage.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvDmgWithCI =			CreateConVar("l4d2_kill_mvp_add_ci_damage",					"1", "Total damage includes common infected damage.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvTankDmgNotify =		CreateConVar("l4d2_kill_mvp_tank_death_damage_announce",	"1", "Notify Tank damage when Tank dies.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvWitchDmgNotify =	CreateConVar("l4d2_kill_mvp_witch_death_damage_announce",	"1", "Notify Witch damage when Witch dies.", FCVAR_NONE, true, 0.0, true, 1.0);

	OnConVarChanged(null, "", "");

	g_cvDmgWithTank.AddChangeHook(OnConVarChanged);
	g_cvDmgWithWitch.AddChangeHook(OnConVarChanged);
	g_cvDmgWithCI.AddChangeHook(OnConVarChanged);
	g_cvTankDmgNotify.AddChangeHook(OnConVarChanged);
	g_cvWitchDmgNotify.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Pre);

	HookEvent("infected_hurt", Event_InfectedHurt);
	HookEvent("infected_death", Event_InfectedDeath);

	HookEvent("player_bot_replace", Event_BotReplacedPlayer);
	HookEvent("bot_player_replace", Event_PlayerReplacedBot);

	RegConsoleCmd("sm_mvp", Cmd_ShowTotalDamageRank);
	RegAdminCmd("sm_clear_mvp", Cmd_ClearMvp, ADMFLAG_ROOT);

	//AutoExecConfig(true, "l4d2_kill_mvp");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bDmgWithTank = g_cvDmgWithTank.BoolValue;
	g_bDmgWithWitch = g_cvDmgWithWitch.BoolValue;
	g_bDmgWithCI = g_cvDmgWithCI.BoolValue;
	g_bTankDmgNotify = g_cvTankDmgNotify.BoolValue;
	g_bWitchDmgNotify = g_cvWitchDmgNotify.BoolValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_iTotalDmg[i] = 0;
		g_iKillSI[i] = 0;
		g_iKillCI[i] = 0;
		g_iFriendlyFire[i] = 0;

		ClearTankDamage(i, CLEAR_VICTIM);
		g_bTankAlive[i] = false;
	}

	for (int i = 0; i < MAX_ENTITY; i++)
	{
		ClearWitchDamage(i, CLEAR_VICTIM);
		g_fWitchHealth[i] = 0.0;
	}
}

void ClearTankDamage(int index, int type)
{
	if (!g_bTankDmgNotify)
		return;

	// Clear all players to this Tank's damage.
	if (type == CLEAR_VICTIM)
	{
		for (int i = 0; i <= MaxClients; i++)
			g_iTankDmg[index][i] = 0;
	}

	// Clear this player's damage to all Tanks.
	else if (type == CLEAR_ATTACKER)
	{
		for (int i = 0; i <= MaxClients; i++)
			g_iTankDmg[i][index] = 0;
	}
}

void ClearWitchDamage(int index, int type)
{
	if (!g_bWitchDmgNotify)
		return;

	// Clear all players to this Witch's damage.
	if (type == CLEAR_VICTIM)
	{
		for (int i = 0; i <= MaxClients; i++)
			g_fWitchDmg[index][i] = 0.0;
	}

	// Clear this player's damage to all Witchs.
	else if (type == CLEAR_ATTACKER)
	{
		for (int i = 0; i < MAX_ENTITY; i++)
			g_fWitchDmg[i][index] = 0.0;
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ShowTotalDamageRank();
}

Action Cmd_ShowTotalDamageRank(int client, int args)
{
	ShowTotalDamageRank();
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	g_iTotalDmg[client] = 0;
	g_iKillSI[client] = 0;
	g_iKillCI[client] = 0;
	g_iFriendlyFire[client] = 0;
	
	ClearTankDamage(client, CLEAR_ATTACKER);
	ClearWitchDamage(client, CLEAR_ATTACKER);

	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 3 && GetZombieClass(client) == TANK)
	{
		ClearTankDamage(client, CLEAR_VICTIM);
		g_bTankAlive[client] = true;
	}
}

Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0)
		return Plugin_Continue;

	if (!IsValidSur(attacker) || !IsPlayerAlive(attacker))
		return Plugin_Continue;

	if (IsValidSI(victim) && IsPlayerAlive(victim))
	{
		static int iVictimHealth;
		iVictimHealth = GetEntProp(victim, Prop_Data, "m_iHealth");

		switch (GetZombieClass(victim))
		{
			case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER:
			{
				if (damage >= float(iVictimHealth))
					g_iTotalDmg[attacker] += iVictimHealth;
				else
					g_iTotalDmg[attacker] += RoundToFloor(damage);
			}
			case TANK:
			{
				static int iLastAttacker[MAXPLAYERS+1];
				static int iVictimHealthPost[MAXPLAYERS+1];

				if (!g_bTankAlive[victim])
					return Plugin_Continue;

				if (!GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
				{
					iLastAttacker[victim] = attacker;
					iVictimHealthPost[victim] = iVictimHealth - RoundToFloor(damage);
					
					if (g_bDmgWithTank)
						g_iTotalDmg[attacker] += RoundToFloor(damage);

					if (g_bTankDmgNotify)
						g_iTankDmg[victim][attacker] += RoundToFloor(damage);
				}
				else
				{
					g_bTankAlive[victim] = false;

					if (g_bDmgWithTank)
						g_iTotalDmg[iLastAttacker[victim]] += iVictimHealthPost[victim];

					if (g_bTankDmgNotify)
						g_iTankDmg[victim][iLastAttacker[victim]] += iVictimHealthPost[victim];
				}
			}
		}
	}
	else if (IsValidSur(victim) && IsPlayerAlive(victim))
	{
		if (attacker != victim)
		{
			g_iFriendlyFire[attacker] += RoundToFloor(damage);
		}
	}

	return Plugin_Continue;
}

// Bot replaced a player.
// The player lost control of Tank. add damage to the new Tank bot.
void Event_BotReplacedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));

	if (bot > 0 && IsClientInGame(bot) && GetClientTeam(bot) == 3 && GetZombieClass(bot) == TANK)
	{
		for (int i = 1; i <= MaxClients; i++)
			g_iTankDmg[bot][i] += g_iTankDmg[player][i];

		ClearTankDamage(player, CLEAR_VICTIM);
	}
}

// Player replaced a bot.
// The player has take over a Tank bot. add damage to the new Tank player.
void Event_PlayerReplacedBot(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));

	if (player > 0 && IsClientInGame(player) && GetClientTeam(player) == 3 && GetZombieClass(player) == TANK)
	{
		for (int i = 1; i <= MaxClients; i++)
			g_iTankDmg[player][i] += g_iTankDmg[bot][i];

		ClearTankDamage(bot, CLEAR_VICTIM);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));

	g_bTankAlive[victim] = false;

	if (IsValidSI(victim))
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
			g_iKillSI[attacker]++;

		if (GetZombieClass(victim) != TANK)
			return;

		ShowTankDamageRank(victim);
		ClearTankDamage(victim, CLEAR_VICTIM);
	}
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (IsValidEntityEx(witch))
	{
		ClearWitchDamage(witch, CLEAR_VICTIM);
		g_fWitchHealth[witch] = z_witch_health.FloatValue;

		SDKUnhook(witch, SDKHook_OnTakeDamageAlive, OnWitchTakeDamageAlive);
		SDKHook(witch, SDKHook_OnTakeDamageAlive, OnWitchTakeDamageAlive);
	}
}

Action OnWitchTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0 || g_fWitchHealth[victim] <= 0.0 || !IsValidEntityEx(victim))
		return Plugin_Continue;

	if (damage >= g_fWitchHealth[victim])
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			if (g_bDmgWithWitch)
				g_iTotalDmg[attacker] += RoundToNearest(g_fWitchHealth[victim]);

			if (g_bWitchDmgNotify)
				g_fWitchDmg[victim][attacker] += g_fWitchHealth[victim];
		}
		
		g_fWitchHealth[victim] = 0.0;
	}
	else
	{
		g_fWitchHealth[victim] -= damage;

		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			if (g_bDmgWithWitch)
				g_iTotalDmg[attacker] += RoundToNearest(damage);

			if (g_bWitchDmgNotify)
				g_fWitchDmg[victim][attacker] += damage;
		}
		
	}
	return Plugin_Continue;
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	g_fWitchHealth[witch] = 0.0;

	ShowWitchDamageRank(witch);
	ClearWitchDamage(witch, CLEAR_VICTIM);
}

void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bDmgWithCI)
		return;

	static int attacker, damage, victim;
	static char sClassName[6];
		
	attacker = GetClientOfUserId(event.GetInt("attacker"));
	damage  = event.GetInt("amount");
	victim = event.GetInt("entityid");

	if (!IsValidEntityEx(victim))
		return;

	if (!GetEdictClassname(victim, sClassName, sizeof(sClassName)) || !strcmp(sClassName, "witch", false))
		return;

	if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		g_iTotalDmg[attacker] += damage;
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		g_iKillCI[attacker]++;
}

void ShowTankDamageRank(int tank)
{
	if (!g_bTankDmgNotify)
		return;

	killData data;
	ArrayList array = new ArrayList(sizeof(killData));
	int iTotalDmg;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iTankDmg[tank][i] > 0 && IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			data.player = i;
			data.damage = g_iTankDmg[tank][i];
			iTotalDmg += g_iTankDmg[tank][i];
			array.PushArray(data);
		}
	}

	int len = array.Length;
	if (len > 0)
	{
		array.SortCustom(SortByDescending, view_as<Handle>(SORT_DAMAGE));

		if (!IsFakeClient(tank))
			CPrintToChatAll("{blue}[Tank {olive}(%N) {blue}Damage]{default}:", tank);
		else
			CPrintToChatAll("{blue}[Tank Damage]{default}:");

		for (int i = 0; i < len; i++)
		{
			array.GetArray(i, data);
			CPrintToChatAll("{blue}[{yellow}%i{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", data.damage, RoundToNearest(float(data.damage)/iTotalDmg*100), data.player);
		}
	}

	delete array;
}

void ShowWitchDamageRank(int witch)
{
	if (!g_bWitchDmgNotify)
		return;

	killData data;
	ArrayList array = new ArrayList(sizeof(killData));
	float fTotalDmg;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_fWitchDmg[witch][i] > 0.0 && IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			data.player = i;
			data.WitchDmg = g_fWitchDmg[witch][i];
			fTotalDmg += g_fWitchDmg[witch][i];
			array.PushArray(data);
		}
	}

	int len = array.Length;
	if (len > 0)
	{
		array.SortCustom(SortByDescending, view_as<Handle>(SORT_WITCHDMG));
		CPrintToChatAll("{blue}[Witch Damage]{default}:");

		for (int i = 0; i < len; i++)
		{
			array.GetArray(i, data);
			CPrintToChatAll("{blue}[{yellow}%i{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", RoundToNearest(data.WitchDmg), RoundToNearest(data.WitchDmg/fTotalDmg*100), data.player);
		}
	}

	delete array;
}

void ShowTotalDamageRank()
{
	killData data;
	ArrayList array = new ArrayList(sizeof(killData));
	int iTotalDmg, iTotalFF;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			data.player = i;
			data.damage = g_iTotalDmg[i];
			data.SI = g_iKillSI[i];
			data.CI = g_iKillCI[i];
			data.FF = g_iFriendlyFire[i];

			iTotalDmg += g_iTotalDmg[i];
			iTotalFF += g_iFriendlyFire[i];
			array.PushArray(data);
		}
	}
	
	int len = array.Length;
	if (len > 0)
	{
		array.SortCustom(SortByDescending, view_as<Handle>(SORT_DAMAGE));
		CPrintToChatAll("{blue}[击杀排名]{default}:");

		for (int i = 0; i < len; i++)
		{
			array.GetArray(i, data);
			CPrintToChatAll("{blue}伤害{default}:  {yellow}%-6i  {blue}特感{default}:  {yellow}%-3i  {blue}丧尸{default}:  {yellow}%-4i  {blue}友伤{default}:  {yellow}%-5i  {blue}|{default}  {olive}%N", data.damage, data.SI, data.CI, data.FF, data.player);
		}

		if (iTotalDmg > 0)
		{
			array.GetArray(0, data);
			CPrintToChatAll("{blue}[MVP]{default}: {olive}%N   {blue}总伤害{default}:  {yellow}%i  {default}({yellow}%i{default}%%)", data.player, data.damage, RoundToNearest(float(data.damage)/iTotalDmg*100));
		}
		
		if (iTotalFF > 0)
		{
			array.SortCustom(SortByDescending, view_as<Handle>(SORT_FF));
			array.GetArray(0, data);
			CPrintToChatAll("{blue}[LVP]{default}: {olive}%N   {blue}黑枪值{default}:  {yellow}%i  {default}({yellow}%i{default}%%)", data.player, data.FF, RoundToNearest(float(data.FF)/iTotalFF*100));
		}
	}

	delete array;
}

int SortByDescending(int index1, int index2, ArrayList array, Handle hndl)
{
	killData data1, data2;
	array.GetArray(index1, data1);
	array.GetArray(index2, data2);

	switch (view_as<int>(hndl))
	{
		case SORT_DAMAGE:
		{
			if (data1.damage > data2.damage)
				return -1;
			if (data1.damage < data2.damage)
				return 1;
		}
		case SORT_FF:
		{
			if (data1.FF > data2.FF)
				return -1;
			if (data1.FF < data2.FF)
				return 1;
		}
		case SORT_WITCHDMG:
		{
			if (data1.WitchDmg > data2.WitchDmg)
				return -1;
			if (data1.WitchDmg < data2.WitchDmg)
				return 1;
		}
	}
	return 0;
}

bool IsValidEntityEx(int entity)
{
	if (entity > MaxClients)
	{
		return IsValidEntity(entity);
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

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

Action Cmd_ClearMvp(int client, int args)
{
	Event_RoundStart(null, "", true);
	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D2_GetKillData", Native_GetKillData);
	return APLRes_Success;
}

int Native_GetKillData(Handle plugin, int numParams)
{
	killData data;
	int player = GetNativeCell(1);
	
	data.player = player;
	data.damage = g_iTotalDmg[player];
	data.SI = g_iKillSI[player];
	data.CI = g_iKillCI[player];
	data.FF = g_iFriendlyFire[player];

	SetNativeArray(2, data, sizeof(data));
	return 0;
}

