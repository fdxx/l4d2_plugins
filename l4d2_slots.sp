#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2_nativevote> // https://github.com/fdxx/l4d2_nativevote
#include <multicolors>

#define VERSION "0.6"

ConVar
	sv_allow_lobby_connect_only,
	sv_maxplayers,
	g_cvSlotsDefault,
	g_cvSlotsVoteMin,
	g_cvSlotsVoteMax;

int
	g_iSlotsDef,
	g_iSlotsVoteMin,
	g_iSlotsVoteMax;

public Plugin myinfo =
{
	name = "L4D2 Slots",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_slots_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	sv_allow_lobby_connect_only = FindConVar("sv_allow_lobby_connect_only");

	g_cvSlotsDefault = CreateConVar("l4d2_slots_default", "6", "默认slots设置(服务器启动时设置)", FCVAR_NONE, true, -1.0, true, 31.0);
	g_cvSlotsVoteMin = CreateConVar("l4d2_slots_vote_min", "6", "slots投票最小限制", FCVAR_NONE, true, -1.0, true, 31.0);
	g_cvSlotsVoteMax = CreateConVar("l4d2_slots_vote_max", "7", "slots投票最大限制", FCVAR_NONE, true, -1.0, true, 31.0);

	GetCvars();

	g_cvSlotsDefault.AddChangeHook(ConVarChanged);
	g_cvSlotsVoteMin.AddChangeHook(ConVarChanged);
	g_cvSlotsVoteMax.AddChangeHook(ConVarChanged);

	RegConsoleCmd("sm_slots", Cmd_SlotsVote);
	RegConsoleCmd("sm_slot", Cmd_SlotsVote);

	AutoExecConfig(true, "l4d2_slots");
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iSlotsDef = g_cvSlotsDefault.IntValue;
	g_iSlotsVoteMin = g_cvSlotsVoteMin.IntValue;
	g_iSlotsVoteMax = g_cvSlotsVoteMax.IntValue;
}

public void OnConfigsExecuted()
{
	sv_allow_lobby_connect_only.IntValue = 0;
	L4D_LobbyUnreserve();

	static bool shit;
	if (shit) return;
	shit = true;

	sv_maxplayers = FindConVar("sv_maxplayers");
	if (sv_maxplayers == null)
		SetFailState("l4dtoolz plugin not loaded?");
	sv_maxplayers.IntValue = g_iSlotsDef;
}

Action Cmd_SlotsVote(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (args != 1)
		{
			PrintToChat(client, "Use: !slots <number>");
			return Plugin_Handled;
		}

		int iSlotNum = GetCmdArgInt(1);
		if (iSlotNum == sv_maxplayers.IntValue)
		{
			PrintToChat(client, "当前slots已经是%i", iSlotNum);
			return Plugin_Handled;
		}

		if (iSlotNum < g_iSlotsVoteMin || iSlotNum > g_iSlotsVoteMax)
		{
			PrintToChat(client, "%i <= number <= %i", g_iSlotsVoteMin, g_iSlotsVoteMax);
			return Plugin_Handled;
		}

		StartVote(client, iSlotNum);
	}
	return Plugin_Handled;
}

void StartVote(int client, int iSlotNum)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "{default}[{yellow}提示{default}] 投票正在进行中，暂不能发起新的投票");
		return;
	}
	
	L4D2NativeVote vote = L4D2NativeVote(VoteHandler);
	vote.SetDisplayText("将 Slots 更改为 %i ?", iSlotNum);
	vote.Initiator = client;
	vote.Value = iSlotNum;

	int iPlayerCount = 0;
	int[] iClients = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			iClients[iPlayerCount++] = i;
		}
	}

	if (!vote.DisplayVote(iClients, iPlayerCount, 20))
		LogError("发起投票失败");
}

void VoteHandler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}发起了一个投票", param1);
		}
		case VoteAction_PlayerVoted:
		{
			CPrintToChatAll("{olive}%N {default}已投票", param1);
		}
		case VoteAction_End:
		{
			if (vote.YesCount > vote.PlayerCount/2)
			{
				vote.SetPass("加载中...");
				sv_maxplayers.IntValue = vote.Value;
			}
			else vote.SetFail();
		}
	}
}
