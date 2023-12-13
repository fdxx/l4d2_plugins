#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>  

#define VERSION "3.1"

#define IDLE_DEFAULT	0
#define IDLE_BLOCK		1
#define IDLE_NO_LIMIT	2

ConVar g_cvAfkDelay, g_cvIdleType;
Handle g_hSDK_GoAwayFromKeyboard;
float g_fAfkDelay;
int g_iIdleType;

public Plugin myinfo =
{
	name = "L4D2 AFK Commands",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_afk_commands_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvAfkDelay = CreateConVar("l4d2_afk_commands_afk_delay", "3.0", "How long to delay change to spectator. 0.0=Disabled.", FCVAR_NONE);
	g_cvIdleType = CreateConVar("l4d2_afk_commands_idle_type", "1", "0=Default, 1=Block, 2=No limit.");

	OnConVarChanged(null, "", "");

	g_cvAfkDelay.AddChangeHook(OnConVarChanged);
	g_cvIdleType.AddChangeHook(OnConVarChanged);
	
	AddCommandListener(GoAfk_CmdListener, "go_away_from_keyboard");
	
	RegConsoleCmd("sm_afk", Cmd_JoinSpectate);
	RegConsoleCmd("sm_away", Cmd_JoinSpectate);
	RegConsoleCmd("sm_idle", Cmd_JoinSpectate);
	RegConsoleCmd("sm_spectate", Cmd_JoinSpectate);
	RegConsoleCmd("sm_spectators", Cmd_JoinSpectate);
	RegConsoleCmd("sm_joinspectators", Cmd_JoinSpectate);
	RegConsoleCmd("sm_jointeam1", Cmd_JoinSpectate);

	RegConsoleCmd("sm_survivors", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_sur", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_join", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jg", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jiaru", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jointeam2", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jr", Cmd_JoinSurvivor);

	RegConsoleCmd("sm_kill", Cmd_KillSelf);
	RegConsoleCmd("sm_zs", Cmd_KillSelf);

	//AutoExecConfig(true, "l4d2_afk_commands");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fAfkDelay = g_cvAfkDelay.FloatValue;
	g_iIdleType = g_cvIdleType.IntValue;
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_afk_commands");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", sBuffer);

	// void CTerrorPlayer::GoAwayFromKeyboard(void)
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorPlayer::GoAwayFromKeyboard");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	g_hSDK_GoAwayFromKeyboard = EndPrepSDKCall();
	if(g_hSDK_GoAwayFromKeyboard == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	delete hGameData;
}

Action GoAfk_CmdListener(int client, const char[] command, int argc)
{
	switch (g_iIdleType)
	{
		case IDLE_BLOCK:
		{
			if (IsRealClient(client) && GetClientTeam(client) != 1)
			{
				PrintHintText(client, "闲置请用 !away 命令");
				return Plugin_Handled;
			}
		}

		case IDLE_NO_LIMIT:
		{
			if (IsRealClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
			{
				// By default, it cannot be idle when there is only 1 person.
				SDKCall(g_hSDK_GoAwayFromKeyboard, client);
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

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
			CPrintToChatAll("{blue}[提示] {olive}%N {default}进入了旁观状态.", client);
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
		CPrintToChatAll("{blue}[提示] {olive}%N {default}进入了旁观状态.", client);
	}
	return Plugin_Continue;
}


Action Cmd_JoinSurvivor(int client, int args)
{
	if (IsRealClient(client) && GetClientTeam(client) != 2)
	{
		if (IsPlayerIdle(client))
		{
			L4D_TakeOverBot(client);
			return Plugin_Handled;
		}
		
		int bot = GetSurBot();
		if (bot > 0)
		{
			ChangeClientTeam(client, 0);
			L4D_SetHumanSpec(bot, client);
			L4D_TakeOverBot(client);
		}
		else PrintHintText(client, "暂无幸存者BOT供接管");
	}
	return Plugin_Handled;
}


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
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && !HasIdlePlayer(i))
		{
			if (IsPlayerAlive(i))
				aAliveBots.Push(i);
			else
				aDeadBots.Push(i);
		}
	}

	if (aAliveBots.Length > 0)
	{
		bot = aAliveBots.Get(GetRandomIntEx(0, aAliveBots.Length - 1));
	}
	else if (aDeadBots.Length > 0)
	{
		bot = aDeadBots.Get(GetRandomIntEx(0, aDeadBots.Length - 1));
	}
	
	delete aAliveBots;
	delete aDeadBots;

	return bot;
}

int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

bool IsPlayerIdle(int player)
{
	int offset;
	char sNetClass[12];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i) && IsPlayerAlive(i))
		{
			if (!GetEntityNetClass(i, sNetClass, sizeof(sNetClass)))
				continue;

			offset = FindSendPropInfo(sNetClass, "m_humanSpectatorUserID");
			if (offset > 0 && GetClientOfUserId(GetEntData(i, offset)) == player)
				return true;
		}
	}
	return false;
}

bool HasIdlePlayer(int bot) 
{
	char sNetClass[12];
	int offset, player;

	GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));
	offset = FindSendPropInfo(sNetClass, "m_humanSpectatorUserID");

	if (offset > 0)
	{
		player = GetClientOfUserId(GetEntData(bot, offset));
		if (player > 0 && IsClientConnected(player) && !IsFakeClient(player))
			return true;
	}

	return false;
}
