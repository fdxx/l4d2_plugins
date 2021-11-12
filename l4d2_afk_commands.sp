#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>

#define VERSION "2.7"

ConVar CvarAFKDelay, CvarBlockIdle;
float g_fAFKDelay;
bool g_bBlockIdle;

public Plugin myinfo =
{
	name = "L4D2 AFK Commands",
	author = "MasterMe, fdxx",
	description = "Adds commands to let the player spectate and join team. (!join, !afk, !zs)",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_afk_commands_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarAFKDelay = CreateConVar("l4d2_afk_commands_afk_delay", "3.0", "切换到旁观之前的延迟, 0.0=禁用延迟加入旁观", FCVAR_NONE);
	CvarBlockIdle = CreateConVar("l4d2_afk_commands_block_idle", "1", "是否阻止 go_away_from_keyboard 命令", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	CvarAFKDelay.AddChangeHook(ConVarChanged);
	CvarBlockIdle.AddChangeHook(ConVarChanged);
	
	AddCommandListener(BlockIdle, "go_away_from_keyboard");
	
	RegConsoleCmd("sm_afk", JoinSpectate);
	RegConsoleCmd("sm_away", JoinSpectate);
	RegConsoleCmd("sm_idle", JoinSpectate);
	RegConsoleCmd("sm_spectate", JoinSpectate);
	RegConsoleCmd("sm_spectators", JoinSpectate);
	RegConsoleCmd("sm_joinspectators", JoinSpectate);
	RegConsoleCmd("sm_jointeam1", JoinSpectate);

	RegConsoleCmd("sm_survivors", JoinSurvivor);
	RegConsoleCmd("sm_join", JoinSurvivor);
	RegConsoleCmd("sm_jg", JoinSurvivor);
	RegConsoleCmd("sm_jiaru", JoinSurvivor);
	RegConsoleCmd("sm_jointeam2", JoinSurvivor);
	RegConsoleCmd("sm_jr", JoinSurvivor);

	RegConsoleCmd("sm_kill", KillSelf);
	RegConsoleCmd("sm_zs", KillSelf);

	AutoExecConfig(true, "l4d2_afk_commands");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fAFKDelay = CvarAFKDelay.FloatValue;
	g_bBlockIdle = CvarBlockIdle.BoolValue;
}

// Block Idle
public Action BlockIdle(int client, const char[] command, int argc)
{
	if (g_bBlockIdle)
	{
		if (IsRealClient(client) && GetClientTeam(client) != 1)
		{
			PrintHintText(client, "闲置请用 !away 命令");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

// To Spectate
public Action JoinSpectate(int client, int args)
{
	if (IsRealClient(client) && GetClientTeam(client) != 1)
	{
		if (g_fAFKDelay >= 0.1)
		{
			CreateTimer(g_fAFKDelay, JoinSpectate_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			PrintHintText(client, "%.1f 秒后进入旁观状态", g_fAFKDelay);
		}
		else
		{
			ChangeClientTeam(client, 1);
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}进入了旁观状态.", client);
		}
	}
	return Plugin_Handled;
}

public Action JoinSpectate_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsRealClient(client) && GetClientTeam(client) != 1)
	{
		ChangeClientTeam(client, 1);
		CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}进入了旁观状态.", client);
	}
	return Plugin_Continue;
}

// To Survivor
public Action JoinSurvivor(int client, int args)
{
	if (IsRealClient(client) && GetClientTeam(client) != 2)
	{
		int bot = GetSurBot();
		if (bot >= 1)
		{
			ChangeClientTeam(client, 0);
			L4D_SetHumanSpec(bot, client);
			L4D_TakeOverBot(client);
			//if (GetClientTeam(client) != 2) LogError("切换到幸存者失败");
		}
		else PrintHintText(client, "暂无幸存者BOT供接管");
	}
	return Plugin_Handled;
}

// Suicide
public Action KillSelf(int client, int args)
{
	if (IsRealClient(client))
	{
		switch (GetClientTeam(client))
		{
			case 2:
			{
				if (IsPlayerAlive(client))
				{
					ForcePlayerSuicide(client);
				}
			}
			case 3:
			{
				if (IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
				{
					ForcePlayerSuicide(client);
				}
			}
		}
	}
	return Plugin_Handled;
}

// other
bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

int GetSurBot()
{
	int bot;

	ArrayList aAliveBots = new ArrayList();
	ArrayList aDeadBots = new ArrayList();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i))
		{
			if (!HasIdlePlayer(i))
			{
				if (IsPlayerAlive(i)) aAliveBots.Push(i);
				else aDeadBots.Push(i);
			}
		}
	}

	// 活着的Bot优先
	if (aAliveBots.Length > 0)
	{
		bot = aAliveBots.Get(GetRandomInt(0, aAliveBots.Length - 1));
	}
	else if (aDeadBots.Length > 0)
	{
		bot = aDeadBots.Get(GetRandomInt(0, aDeadBots.Length - 1));
	}
	
	delete aAliveBots;
	delete aDeadBots;

	return bot;
}

bool HasIdlePlayer(int iBot)
{
	if (IsClientInGame(iBot) && GetClientTeam(iBot) == 2 && IsPlayerAlive(iBot))
	{
		static char sNetClass[12];
		GetEntityNetClass(iBot, sNetClass, sizeof(sNetClass));

		if (IsFakeClient(iBot) && strcmp(sNetClass, "SurvivorBot") == 0)
		{
			static int iClient;
			iClient = GetClientOfUserId(GetEntProp(iBot, Prop_Send, "m_humanSpectatorUserID"));
			if (iClient > 0 && iClient <= MaxClients && IsClientConnected(iClient))
			{
				if (!IsClientInGame(iClient)) //过图加载中的玩家
				{
					return true;
				}
				else if (IsClientInGame(iClient) && GetClientTeam(iClient) == 1)
				{
					return true;
				}
			}
		}
	}
	return false;
}