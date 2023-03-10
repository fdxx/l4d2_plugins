#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2_nativevote>	// https://github.com/fdxx/l4d2_nativevote
#include <multicolors>  

#define VERSION "0.7"

ConVar
	sv_maxplayers,
	g_cvDefSlots,
	g_cvVoteMin,
	g_cvVoteMax;

int
	g_iDefSlots,
	g_iVoteMin,
	g_iVoteMax;

public Plugin myinfo =
{
	name = "L4D2 Slots",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_slots_version", VERSION, "Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	g_cvDefSlots = CreateConVar("l4d2_slots_default", "8", "Default slots (set at server startup)", FCVAR_NONE, true, -1.0, true, 31.0);
	g_cvVoteMin = CreateConVar("l4d2_slots_vote_min", "8", "Min limit for slots voting", FCVAR_NONE, true, -1.0, true, 31.0);
	g_cvVoteMax = CreateConVar("l4d2_slots_vote_max", "10", "Max limit for slots voting", FCVAR_NONE, true, -1.0, true, 31.0);

	GetCvars();

	g_cvDefSlots.AddChangeHook(ConVarChanged);
	g_cvVoteMin.AddChangeHook(ConVarChanged);
	g_cvVoteMax.AddChangeHook(ConVarChanged);

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
	g_iDefSlots = g_cvDefSlots.IntValue;
	g_iVoteMin = g_cvVoteMin.IntValue;
	g_iVoteMax = g_cvVoteMax.IntValue;
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	sv_maxplayers = FindConVar("sv_maxplayers");
	if (sv_maxplayers == null)
		SetFailState("l4dtoolz plugin not loaded?");
	sv_maxplayers.IntValue = g_iDefSlots;
}

Action Cmd_SlotsVote(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (args != 1)
		{
			CPrintToChat(client, "{lightgreen}Use: !slots <number>");
			return Plugin_Handled;
		}

		int slots = GetCmdArgInt(1);
		if (slots == sv_maxplayers.IntValue)
		{
			CPrintToChat(client, "{lightgreen}当前slots已经是%i", slots);
			return Plugin_Handled;
		}

		if (slots < g_iVoteMin || slots > g_iVoteMax)
		{
			CPrintToChat(client, "{lightgreen}%i <= number <= %i", g_iVoteMin, g_iVoteMax);
			return Plugin_Handled;
		}

		StartVote(client, slots);
	}
	return Plugin_Handled;
}

void StartVote(int client, int slots)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "{lightgreen}投票正在进行中, 暂不能发起新的投票.");
		return;
	}
	
	L4D2NativeVote vote = L4D2NativeVote(Vote_Handler);
	vote.SetDisplayText("将 Slots 更改为 %i ?", slots);
	vote.Initiator = client;
	vote.Value = slots;

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

void Vote_Handler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			CPrintToChatAll("{blue}[Vote] {olive}%N {default}发起了一个投票.", param1);
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
			else
				vote.SetFail();
		}
	}
}
