#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>

#define VERSION "3.0"

ConVar g_cvAfkDelay, g_cvBlockIdle;
float g_fAfkDelay;
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

	g_cvAfkDelay = CreateConVar("l4d2_afk_commands_afk_delay", "3.0", "切换到旁观之前的延迟, 0.0=禁用延迟加入旁观", FCVAR_NONE);
	g_cvBlockIdle = CreateConVar("l4d2_afk_commands_block_idle", "1", "是否阻止 go_away_from_keyboard 命令", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	g_cvAfkDelay.AddChangeHook(ConVarChanged);
	g_cvBlockIdle.AddChangeHook(ConVarChanged);
	
	AddCommandListener(GoAfk_CmdListener, "go_away_from_keyboard");
	
	RegConsoleCmd("sm_afk", Cmd_JoinSpectate);
	RegConsoleCmd("sm_away", Cmd_JoinSpectate);
	RegConsoleCmd("sm_idle", Cmd_JoinSpectate);
	RegConsoleCmd("sm_spectate", Cmd_JoinSpectate);
	RegConsoleCmd("sm_spectators", Cmd_JoinSpectate);
	RegConsoleCmd("sm_joinspectators", Cmd_JoinSpectate);
	RegConsoleCmd("sm_jointeam1", Cmd_JoinSpectate);

	RegConsoleCmd("sm_survivors", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_join", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jg", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jiaru", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jointeam2", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jr", Cmd_JoinSurvivor);

	RegConsoleCmd("sm_kill", Cmd_KillSelf);
	RegConsoleCmd("sm_zs", Cmd_KillSelf);

	AutoExecConfig(true, "l4d2_afk_commands");
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fAfkDelay = g_cvAfkDelay.FloatValue;
	g_bBlockIdle = g_cvBlockIdle.BoolValue;
}

// Block Idle
Action GoAfk_CmdListener(int client, const char[] command, int argc)
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
Action Cmd_JoinSpectate(int client, int args)
{
	if (IsRealClient(client) && GetClientTeam(client) != 1)
	{
		if (g_fAfkDelay >= 0.1)
		{
			CreateTimer(g_fAfkDelay, JoinSpectate_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			PrintHintText(client, "%.1f 秒后进入旁观状态", g_fAfkDelay);
		}
		else
		{
			ChangeClientTeam(client, 1);
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}进入了旁观状态.", client);
		}
	}
	return Plugin_Handled;
}

Action JoinSpectate_Timer(Handle timer, int userid)
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
Action Cmd_JoinSurvivor(int client, int args)
{
	if (IsRealClient(client) && GetClientTeam(client) != 2)
	{
		if (L4D_GetBotOfIdlePlayer(client) > 0)
		{
			L4D_TakeOverBot(client);
			return Plugin_Handled;
		}
		
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
Action Cmd_KillSelf(int client, int args)
{
	if (IsRealClient(client))
	{
		switch (GetClientTeam(client))
		{
			case 2, 3:
			{
				if (IsPlayerAlive(client))
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
			if (L4D_GetIdlePlayerOfBot(i) <= 0)
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
