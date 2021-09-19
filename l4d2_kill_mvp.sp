#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>

#define VERSION "1.7"

#define SMOKER	1
#define BOOMER	2
#define HUNTER	3
#define SPITTER	4
#define JOCKEY	5
#define CHARGER	6
#define TANK	8

int g_iKillSICount[MAXPLAYERS+1];				//特感击杀数量
int g_iKillCICount[MAXPLAYERS+1];				//普通丧尸击杀数量
int g_iAttackerFFDamage[MAXPLAYERS+1];			//友伤
int g_iVictimFFDamage[MAXPLAYERS+1];			//被友伤
int g_iTotalDamage[MAXPLAYERS+1];				//特感和丧失总伤害
int g_iTankDamage[MAXPLAYERS+1][MAXPLAYERS+1];	//tank伤害[victim][attacker]
float g_fWitchDamage[2049][MAXPLAYERS+1];		//witch伤害[victim][attacker]

ConVar CvarTotalDamageWithTank, CvarTotalDamageWithWitch, CvarTotalDamageWithCI;
ConVar CvarTankDamageAnnounce, CvarWitchDamageAnnounce;

bool g_bTotalDamageWithTank, g_bTotalDamageWithWitch, g_bTotalDamageWithCI;
bool g_bTankDamageAnnounce, g_bWitchDamageAnnounce;
bool g_bTankAlive[MAXPLAYERS+1], g_bWitchAlive[2049];

public Plugin myinfo =
{
	name = "L4D2 Kill mvp",
	description = "",
	author = "fdxx",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_kill_mvp_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarTotalDamageWithTank = CreateConVar("l4d2_kill_mvp_add_tank_damage", "1", "总伤害包括Tank伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarTotalDamageWithWitch = CreateConVar("l4d2_kill_mvp_add_witch_damage", "1", "总伤害包括Witch伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarTotalDamageWithCI = CreateConVar("l4d2_kill_mvp_add_ci_damage", "1", "总伤害包括普通丧失伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarTankDamageAnnounce = CreateConVar("l4d2_kill_mvp_tank_death_damage_announce", "1", "Tank死后公布Tank伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarWitchDamageAnnounce = CreateConVar("l4d2_kill_mvp_witch_death_damage_announce", "1", "Witch死后公布Witch伤害", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	CvarTotalDamageWithTank.AddChangeHook(ConVarChanged);
	CvarTotalDamageWithWitch.AddChangeHook(ConVarChanged);
	CvarTotalDamageWithCI.AddChangeHook(ConVarChanged);
	CvarTankDamageAnnounce.AddChangeHook(ConVarChanged);
	CvarWitchDamageAnnounce.AddChangeHook(ConVarChanged);

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

	RegConsoleCmd("sm_mvp", Cmd_ShowTotalDamageRank);

	AutoExecConfig(true, "l4d2_kill_mvp");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bTotalDamageWithTank = CvarTotalDamageWithTank.BoolValue;
	g_bTotalDamageWithWitch = CvarTotalDamageWithWitch.BoolValue;
	g_bTotalDamageWithCI = CvarTotalDamageWithCI.BoolValue;
	g_bTankDamageAnnounce = CvarTankDamageAnnounce.BoolValue;
	g_bWitchDamageAnnounce = CvarWitchDamageAnnounce.BoolValue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		g_iKillSICount[i] = 0;
		g_iKillCICount[i] = 0;
		g_iAttackerFFDamage[i] = 0;
		g_iVictimFFDamage[i] = 0;
		g_iTotalDamage[i] = 0;

		g_bTankAlive[i] = false;

		for (int a = 0; a <= MAXPLAYERS; a++)
		{
			g_iTankDamage[i][a] = 0;
		}
	}

	for (int i = 0; i <= 2048; i++)
	{
		SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage_Witch);
		g_bWitchAlive[i] = false;

		for (int a = 0; a <= MAXPLAYERS; a++)
		{
			g_fWitchDamage[i][a] = 0.0;
		}
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ShowTotalDamageRank();
}

public Action Cmd_ShowTotalDamageRank(int client, int args)
{
	ShowTotalDamageRank();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsValidSI(client) && GetZombieClass(client) == TANK && IsPlayerAlive(client))
	{
		g_bTankAlive[client] = true;
		ClearTankDamage(client);
	}
}

//火的伤害统计不准确，只有站在火里才计算
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidSur(attacker) && IsPlayerAlive(attacker))
	{
		if (IsValidSI(victim) && IsPlayerAlive(victim))
		{
			static int iZombieClass, iVictimHealth;
			iZombieClass = GetZombieClass(victim);
			iVictimHealth = GetEntProp(victim, Prop_Data, "m_iHealth");
			
			switch (iZombieClass)
			{
				case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER:
				{
					if (damage >= float(iVictimHealth)) g_iTotalDamage[attacker] += iVictimHealth;
					else g_iTotalDamage[attacker] += RoundToFloor(damage);
				}

				case TANK:
				{
					if (g_bTankAlive[victim] && !GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
					{
						if (damage >= float(iVictimHealth))
						{
							g_bTankAlive[victim] = false;
							if (g_bTotalDamageWithTank) g_iTotalDamage[attacker] += iVictimHealth;
							if (g_bTankDamageAnnounce) g_iTankDamage[victim][attacker] += iVictimHealth;
						}
						else
						{
							if (g_bTotalDamageWithTank) g_iTotalDamage[attacker] += RoundToFloor(damage);
							if (g_bTankDamageAnnounce) g_iTankDamage[victim][attacker] += RoundToFloor(damage);
						}
					}
				}
			}
		}
		else if (IsValidSur(victim) && IsPlayerAlive(victim))
		{
			if (attacker != victim)
			{
				g_iAttackerFFDamage[attacker] += RoundToFloor(damage);
				g_iVictimFFDamage[victim] += RoundToFloor(damage);
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iVictim = GetClientOfUserId(event.GetInt("userid"));

	if (IsValidSI(iVictim))
	{
		if (GetZombieClass(iVictim) == TANK)
		{
			g_bTankAlive[iVictim] = false;
			if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker))
			{
				g_iKillSICount[iAttacker]++;
			}
			if (g_bTankDamageAnnounce)
			{
				ShowTankDamageRank(iVictim);
			}
			ClearTankDamage(iVictim);
		}
		else
		{
			if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker))
			{
				g_iKillSICount[iAttacker]++;
			}
		}
	}
	return Plugin_Continue;
}

void ShowTankDamageRank(int iTank)
{
	//1D=iPlayerCount, 2D[0]=client, 2D[1]=g_iTankDamage
	int[][] iTankDamageData = new int[MaxClients][2];
	int iPlayerCount, iTankTotalDamage;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSur(i))
		{
			iTankDamageData[iPlayerCount][0] = i;
			iTankDamageData[iPlayerCount][1] = g_iTankDamage[iTank][i];
			iTankTotalDamage += g_iTankDamage[iTank][i];
			iPlayerCount++;
		}
	}
	//PrintToChatAll("克总伤害: %i", iTankTotalDamage);
	if (iPlayerCount > 0 && iTankTotalDamage > 0)
	{
		int client, iTankDamage;
		CPrintToChatAll("{default}[{blue}Tank Damage{default}]:");
		SortCustom2D(iTankDamageData, iPlayerCount, SortByDamageDesc);
		for (int i; i < iPlayerCount; i++)
		{
			client = iTankDamageData[i][0];
			iTankDamage = iTankDamageData[i][1];
			if (iTankDamage > 0)
			{
				CPrintToChatAll("{blue}[{yellow}%i{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", iTankDamage, RoundToNearest((float(iTankDamage)/float(iTankTotalDamage))*100.0), client);
			}
		}
	}
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iWitch = event.GetInt("witchid");
	if (IsValidEntityIndex(iWitch))
	{
		g_bWitchAlive[iWitch] = true;
		ClearWitchDamage(iWitch);
		SDKHook(iWitch, SDKHook_OnTakeDamage, OnTakeDamage_Witch);
	}
}

public Action OnTakeDamage_Witch(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!g_bWitchAlive[victim]) return Plugin_Continue;

	if (IsValidEntityIndex(victim))
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			static float fVictimHealth;
			fVictimHealth = float(GetEntProp(victim, Prop_Data, "m_iHealth"));
			if (damage >= fVictimHealth)
			{
				g_bWitchAlive[victim] = false;
				if (g_bTotalDamageWithWitch) g_iTotalDamage[attacker] += RoundToNearest(fVictimHealth);
				if (g_bWitchDamageAnnounce) g_fWitchDamage[victim][attacker] += fVictimHealth;
			}
			else
			{
				if (g_bTotalDamageWithWitch) g_iTotalDamage[attacker] += RoundToNearest(damage);
				if (g_bWitchDamageAnnounce) g_fWitchDamage[victim][attacker] += damage;
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("userid"));
	int iWitch = event.GetInt("witchid");

	if (IsValidEntityIndex(iWitch))
	{
		SDKUnhook(iWitch, SDKHook_OnTakeDamage, OnTakeDamage_Witch);
		g_bWitchAlive[iWitch] = false;

		if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker))
		{
			if (g_bWitchDamageAnnounce) ShowWitchDamageRank(iWitch);
		}

		ClearWitchDamage(iWitch);
	}
	return Plugin_Continue;
}

void ShowWitchDamageRank(int iWitch)
{
	//1D=iPlayerCount, 2D[0]=client, 2D[1]=g_fWitchDamage
	float[][] fWitchDamageData = new float[MaxClients][2];
	float fWitchTotalDamage;
	int iPlayerCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSur(i))
		{
			fWitchDamageData[iPlayerCount][0] = float(i);
			fWitchDamageData[iPlayerCount][1] = g_fWitchDamage[iWitch][i];
			fWitchTotalDamage += g_fWitchDamage[iWitch][i];
			iPlayerCount++;
		}
	}
	//PrintToChatAll("witch总伤害: %.1f", fWitchTotalDamage);
	if (iPlayerCount > 0 && fWitchTotalDamage > 0.0)
	{
		int client;
		float fWitchDamage;
		CPrintToChatAll("{default}[{blue}Witch Damage{default}]:");
		SortCustom2D(fWitchDamageData, iPlayerCount, SortByDamageDesc); //2D数组排序浮点误差<=1?
		for (int i; i < iPlayerCount; i++)
		{
			client = RoundToNearest(fWitchDamageData[i][0]);
			fWitchDamage = fWitchDamageData[i][1];
			if (fWitchDamage > 0.0)
			{
				CPrintToChatAll("{blue}[{yellow}%.0f{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", fWitchDamage, RoundToNearest((fWitchDamage/fWitchTotalDamage)*100.0), client);
			}
		}
	}
}

public void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bTotalDamageWithCI)
	{
		static int iAttacker, iDamage, iVictim;
		
		iAttacker = GetClientOfUserId(event.GetInt("attacker"));
		iDamage  = event.GetInt("amount");
		iVictim = event.GetInt("entityid");

		if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker))
		{
			if (IsValidEntityIndex(iVictim))
			{
				char sClassName[256];
				if (GetEdictClassname(iVictim, sClassName, sizeof(sClassName)))
				{
					if (strcmp(sClassName, "witch") != 0) g_iTotalDamage[iAttacker] += iDamage;
				}
			}
		}
	}
}

public void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker))
	{
		g_iKillCICount[iAttacker]++;
	}
}

void ShowTotalDamageRank()
{
	//1D=iPlayerCount, 2D[0]=client, 2D[1]=g_iTotalDamage, 2D[2]=g_iKillSICount, 2D[3]=g_iKillCICount, 2D[4]=g_iAttackerFFDamage, 2D[5]=g_iVictimFFDamage
	int[][] iTotalKillData = new int[MaxClients][6];
	int iPlayerCount, iAllTotalDamage, iAllTotalFFDamage;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSur(i))
		{
			iTotalKillData[iPlayerCount][0] = i;
			iTotalKillData[iPlayerCount][1] = g_iTotalDamage[i];
			iTotalKillData[iPlayerCount][2] = g_iKillSICount[i];
			iTotalKillData[iPlayerCount][3] = g_iKillCICount[i];
			iTotalKillData[iPlayerCount][4] = g_iAttackerFFDamage[i];
			iTotalKillData[iPlayerCount][5] = g_iVictimFFDamage[i];

			iAllTotalDamage += g_iTotalDamage[i];
			iAllTotalFFDamage += g_iAttackerFFDamage[i];

			iPlayerCount++;
		}
	}

	if (iPlayerCount > 0)
	{
		int client, iTotalDamage, iKillSICount, iKillCICount, iAttackerFFDamage;
		//int iVictimFFDamage;
		CPrintToChatAll("{default}[{yellow}击杀排名{default}]:");
		SortCustom2D(iTotalKillData, iPlayerCount, SortByDamageDesc);
		for (int i; i < iPlayerCount; i++)
		{
			client = iTotalKillData[i][0];
			iTotalDamage = iTotalKillData[i][1];
			iKillSICount = iTotalKillData[i][2];
			iKillCICount = iTotalKillData[i][3];
			iAttackerFFDamage = iTotalKillData[i][4];
			//iVictimFFDamage = iTotalKillData[i][5];

			CPrintToChatAll("{blue}伤害{default}:  {yellow}%-6i  {blue}特感{default}:  {yellow}%-3i  {blue}丧尸{default}:  {yellow}%-4i  {blue}友伤{default}:  {yellow}%-5i  {blue}|{default}  {olive}%N", iTotalDamage, iKillSICount, iKillCICount, iAttackerFFDamage, client);
		}

		if (iAllTotalDamage  > 0)
		{
			client = iTotalKillData[0][0];
			CPrintToChatAll("{default}[{yellow}MVP{default}] {blue}击杀之王{default}:  {olive}%N   {blue}总伤害{default}:  {yellow}%i  {default}({yellow}%i{default}%%)", client, g_iTotalDamage[client], RoundToNearest((float(g_iTotalDamage[client])/float(iAllTotalDamage))*100.0));
		}
		
		if (iAllTotalFFDamage > 0)
		{
			SortCustom2D(iTotalKillData, iPlayerCount, SortByDamageDesc_FF);
			CPrintToChatAll("{default}[{yellow}LVP{default}] {blue}黑枪之王{default}:  {olive}%N   {blue}黑枪值{default}:  {yellow}%i  {default}({yellow}%i{default}%%)", iTotalKillData[0][0], iTotalKillData[0][4], RoundToNearest((float(iTotalKillData[0][4])/float(iAllTotalFFDamage))*100.0));
		}
	}
}

public int SortByDamageDesc(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

public int SortByDamageDesc_FF(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[4] > y[4]) return -1;
	else if (x[4] < y[4]) return 1;
	else return 0;
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}

void ClearWitchDamage(int iWitch)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_fWitchDamage[iWitch][i] = 0.0;
	}
}

void ClearTankDamage(int iTank)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iTankDamage[iTank][i] = 0;
	}
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

