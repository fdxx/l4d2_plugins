#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <multicolors>
#include <left4dhooks>

#define VERSION "2.3"

enum
{
	SMOKER	= 1,
	BOOMER	= 2,
	HUNTER	= 3,
	SPITTER	= 4,
	JOCKEY	= 5,
	CHARGER	= 6,
	TANK	= 8,
}

int
	g_iWitchMaxHealth,
	g_iKillSICount[MAXPLAYERS+1],				//特感击杀数量
	g_iKillCICount[MAXPLAYERS+1],				//普通丧尸击杀数量
	g_iAttackerFFDamage[MAXPLAYERS+1],			//友伤
	g_iTotalDamage[MAXPLAYERS+1],				//特感和丧失总伤害
	g_iTankDamage[MAXPLAYERS+1][MAXPLAYERS+1];	//tank伤害[victim][attacker]

float
	g_fWitchHealth[2049],
	g_fWitchDamage[2049][MAXPLAYERS+1];			//witch伤害[victim][attacker]

ConVar
	g_cvWitchMaxHealth,
	g_cvTotalDamageWithTank,
	g_cvTotalDamageWithWitch,
	g_cvTotalDamageWithCI,
	g_cvTankDamageAnnounce,
	g_cvWitchDamageAnnounce;

bool
	g_bTotalDamageWithTank,
	g_bTotalDamageWithWitch,
	g_bTotalDamageWithCI,
	g_bTankDamageAnnounce,
	g_bWitchDamageAnnounce,
	g_bTankAlive[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "L4D2 Kill mvp",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_kill_mvp_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	
	g_cvWitchMaxHealth = FindConVar("z_witch_health");
	g_cvTotalDamageWithTank = CreateConVar("l4d2_kill_mvp_add_tank_damage", "1", "总伤害包括Tank伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvTotalDamageWithWitch = CreateConVar("l4d2_kill_mvp_add_witch_damage", "1", "总伤害包括Witch伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvTotalDamageWithCI = CreateConVar("l4d2_kill_mvp_add_ci_damage", "1", "总伤害包括普通丧失伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvTankDamageAnnounce = CreateConVar("l4d2_kill_mvp_tank_death_damage_announce", "1", "Tank死后公布Tank伤害", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvWitchDamageAnnounce = CreateConVar("l4d2_kill_mvp_witch_death_damage_announce", "1", "Witch死后公布Witch伤害", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	g_cvWitchMaxHealth.AddChangeHook(ConVarChanged);
	g_cvTotalDamageWithTank.AddChangeHook(ConVarChanged);
	g_cvTotalDamageWithWitch.AddChangeHook(ConVarChanged);
	g_cvTotalDamageWithCI.AddChangeHook(ConVarChanged);
	g_cvTankDamageAnnounce.AddChangeHook(ConVarChanged);
	g_cvWitchDamageAnnounce.AddChangeHook(ConVarChanged);

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

	RegConsoleCmd("sm_mvp", Cmd_ShowTotalDamageRank);
	RegAdminCmd("sm_clear_mvp", Cmd_ClearMvp, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d2_kill_mvp");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iWitchMaxHealth = g_cvWitchMaxHealth.IntValue;
	g_bTotalDamageWithTank = g_cvTotalDamageWithTank.BoolValue;
	g_bTotalDamageWithWitch = g_cvTotalDamageWithWitch.BoolValue;
	g_bTotalDamageWithCI = g_cvTotalDamageWithCI.BoolValue;
	g_bTankDamageAnnounce = g_cvTankDamageAnnounce.BoolValue;
	g_bWitchDamageAnnounce = g_cvWitchDamageAnnounce.BoolValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	static int i;

	for (i = 0; i <= MaxClients; i++)
	{
		g_iKillSICount[i] = 0;
		g_iKillCICount[i] = 0;
		g_iAttackerFFDamage[i] = 0;
		g_iTotalDamage[i] = 0;

		g_bTankAlive[i] = false;
		ClearTankDamage(i);
	}

	for (i = 0; i <= 2048; i++)
	{
		g_fWitchHealth[i] = 0.0;
		ClearWitchDamage(i);
	}
}

void ClearTankDamage(int iTank)
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		g_iTankDamage[iTank][i] = 0;
	}
}

void ClearWitchDamage(int iWitch)
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		g_fWitchDamage[iWitch][i] = 0.0;
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
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0)
	{
		g_bTankAlive[client] = true;
		ClearTankDamage(client);
	}
}

Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0) return Plugin_Continue;

	if (IsValidSur(attacker) && IsPlayerAlive(attacker))
	{
		if (IsValidSI(victim) && IsPlayerAlive(victim))
		{
			static int iVictimHealth;
			iVictimHealth = GetEntProp(victim, Prop_Data, "m_iHealth");

			switch (GetZombieClass(victim))
			{
				case SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER:
				{
					if (damage >= float(iVictimHealth)) g_iTotalDamage[attacker] += iVictimHealth;
					else g_iTotalDamage[attacker] += RoundToFloor(damage);
				}
				case TANK:
				{
					static int iLastAttacker[MAXPLAYERS];
					static int iVictimHealthPost[MAXPLAYERS];

					if (!g_bTankAlive[victim]) return Plugin_Continue;

					if (!GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
					{
						iLastAttacker[victim] = attacker;
						iVictimHealthPost[victim] = iVictimHealth - RoundToFloor(damage);
						
						if (g_bTotalDamageWithTank) g_iTotalDamage[attacker] += RoundToFloor(damage);
						if (g_bTankDamageAnnounce) g_iTankDamage[victim][attacker] += RoundToFloor(damage);
					}
					else
					{
						g_bTankAlive[victim] = false;
						if (g_bTotalDamageWithTank) g_iTotalDamage[iLastAttacker[victim]] += iVictimHealthPost[victim];
						if (g_bTankDamageAnnounce) g_iTankDamage[victim][iLastAttacker[victim]] += iVictimHealthPost[victim];
					}
				}
			}
		}
		else if (IsValidSur(victim) && IsPlayerAlive(victim))
		{
			if (attacker != victim)
			{
				g_iAttackerFFDamage[attacker] += RoundToFloor(damage);
			}
		}
	}
	return Plugin_Continue;
}

void Event_BotReplacedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));

	if (IsValidSI(player) && GetZombieClass(player) == TANK && !IsFakeClient(player))
	{
		if (IsValidSI(bot) && GetZombieClass(bot) == TANK && IsFakeClient(bot) && IsPlayerAlive(bot) && !GetEntProp(bot, Prop_Send, "m_isIncapacitated"))
		{
			//LogMessage("[DeBug] AddTankDamage %N -> %N", player, bot);
			AddTankDamage(player, bot);
			ClearTankDamage(player);
		}
	}
}

void AddTankDamage(int iTankPlayer, int iTankBot)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iTankDamage[iTankBot][i] += g_iTankDamage[iTankPlayer][i];
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int iAttacker, iVictim;

	iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	iVictim = GetClientOfUserId(event.GetInt("userid"));

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
}

void ShowTankDamageRank(int iTank)
{
	//1D=iPlayerCount, 2D[0]=client, 2D[1]=g_iTankDamage
	int[][] iTankDamageData = new int[MaxClients][2];
	int iPlayerCount, iTankTotalDamage;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iTankDamage[iTank][i] > 0)
		{
			iTankDamageData[iPlayerCount][0] = i;
			iTankDamageData[iPlayerCount][1] = g_iTankDamage[iTank][i];
			iTankTotalDamage += g_iTankDamage[iTank][i];
			iPlayerCount++;
		}
	}
	//LogMessage("[DeBug] 克总伤害: %i", iTankTotalDamage);
	if (iPlayerCount > 0 && iTankTotalDamage > 0)
	{
		int client, iTankDamage;

		if (!IsFakeClient(iTank))
			CPrintToChatAll("{default}[{olive}Tank {default}({red}%N{default}) Damage]:", iTank);
		else CPrintToChatAll("{default}[{olive}%N {default}Damage]:", iTank);

		SortCustom2D(iTankDamageData, iPlayerCount, SortByDamageDesc);
		for (int i; i < iPlayerCount; i++)
		{
			client = iTankDamageData[i][0];
			iTankDamage = iTankDamageData[i][1];

			if (IsClientInGame(client) && GetClientTeam(client) == 2)
				CPrintToChatAll("{blue}[{yellow}%i{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", iTankDamage, RoundToNearest((float(iTankDamage)/float(iTankTotalDamage))*100.0), client);
		}
	}
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iWitch = event.GetInt("witchid");
	if (IsValidEntityEx(iWitch))
	{
		g_fWitchHealth[iWitch] = float(g_iWitchMaxHealth);
		ClearWitchDamage(iWitch);
		SDKUnhook(iWitch, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive_Witch);
		SDKHook(iWitch, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive_Witch);
	}
}

Action OnTakeDamageAlive_Witch(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0 || g_fWitchHealth[victim] <= 0.0) return Plugin_Continue;

	if (IsValidEntityEx(victim))
	{
		if (IsValidSur(attacker) && IsPlayerAlive(attacker))
		{
			if (damage >= g_fWitchHealth[victim])
			{
				if (g_bTotalDamageWithWitch) g_iTotalDamage[attacker] += RoundToNearest(g_fWitchHealth[victim]);
				if (g_bWitchDamageAnnounce) g_fWitchDamage[victim][attacker] += g_fWitchHealth[victim];

				g_fWitchHealth[victim] = 0.0;
			}
			else
			{
				g_fWitchHealth[victim] -= damage;
				if (g_bTotalDamageWithWitch) g_iTotalDamage[attacker] += RoundToNearest(damage);
				if (g_bWitchDamageAnnounce) g_fWitchDamage[victim][attacker] += damage;
			}
		}
	}
	return Plugin_Continue;
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(event.GetInt("userid"));
	int iWitch = event.GetInt("witchid");

	g_fWitchHealth[iWitch] = 0.0;

	if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker))
	{
		if (g_bWitchDamageAnnounce) ShowWitchDamageRank(iWitch);
	}

	ClearWitchDamage(iWitch);
}

void ShowWitchDamageRank(int iWitch)
{
	//1D=iPlayerCount, 2D[0]=client, 2D[1]=g_fWitchDamage
	float[][] fWitchDamageData = new float[MaxClients][2];
	float fWitchTotalDamage;
	int iPlayerCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_fWitchDamage[iWitch][i] > 0.0)
		{
			fWitchDamageData[iPlayerCount][0] = float(i);
			fWitchDamageData[iPlayerCount][1] = g_fWitchDamage[iWitch][i];
			fWitchTotalDamage += g_fWitchDamage[iWitch][i];
			iPlayerCount++;
		}
	}
	//LogMessage("[DeBug] witch总伤害: %.3f", fWitchTotalDamage);
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

			if (IsClientInGame(client) && GetClientTeam(client) == 2)
				CPrintToChatAll("{blue}[{yellow}%i{blue}] ({yellow}%i{default}%%{blue})  {olive}%N", RoundToNearest(fWitchDamage), RoundToNearest((fWitchDamage/fWitchTotalDamage)*100.0), client);
		}
	}
}

void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bTotalDamageWithCI)
	{
		static int iAttacker, iDamage, iVictim;
		
		iAttacker = GetClientOfUserId(event.GetInt("attacker"));
		iDamage  = event.GetInt("amount");
		iVictim = event.GetInt("entityid");

		if (IsValidEntityEx(iVictim))
		{
			if (IsValidSur(iAttacker) && IsPlayerAlive(iAttacker))
			{
				static char sClassName[6];
				if (GetEdictClassname(iVictim, sClassName, sizeof(sClassName)))
				{
					if (strcmp(sClassName, "witch") != 0) g_iTotalDamage[iAttacker] += iDamage;
				}
			}
		}
	}
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int iAttacker;
	iAttacker = GetClientOfUserId(event.GetInt("attacker"));

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

			iAllTotalDamage += g_iTotalDamage[i];
			iAllTotalFFDamage += g_iAttackerFFDamage[i];

			iPlayerCount++;
		}
	}

	if (iPlayerCount > 0)
	{
		int client, iTotalDamage, iKillSICount, iKillCICount, iAttackerFFDamage;

		CPrintToChatAll("{default}[{yellow}击杀排名{default}]:");
		SortCustom2D(iTotalKillData, iPlayerCount, SortByDamageDesc);
		for (int i; i < iPlayerCount; i++)
		{
			client = iTotalKillData[i][0];
			iTotalDamage = iTotalKillData[i][1];
			iKillSICount = iTotalKillData[i][2];
			iKillCICount = iTotalKillData[i][3];
			iAttackerFFDamage = iTotalKillData[i][4];

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

int SortByDamageDesc(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

int SortByDamageDesc_FF(int[] x, int[] y, const int[][] array, Handle hndl)
{
	if (x[4] > y[4]) return -1;
	else if (x[4] < y[4]) return 1;
	else return 0;
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
	Event_RoundStart(view_as<Event>(0), "", true);
	return Plugin_Handled;
}

enum struct SurKillData
{
	int iKillSI;
	int iKillCI;
	int iDmg;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("L4D2_GetKillData", Native_GetKillData);
	return APLRes_Success;
}

int Native_GetKillData(Handle plugin, int numParams)
{
	int client =  GetNativeCell(1);
	SurKillData KillData;
	KillData.iKillSI = g_iKillSICount[client];
	KillData.iKillCI = g_iKillCICount[client];
	KillData.iDmg = g_iTotalDamage[client];
	SetNativeArray(2, KillData, sizeof(KillData));
	return 0;
}

