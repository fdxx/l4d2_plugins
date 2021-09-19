#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <nativevotes>
#include <multicolors>

#define VERSION "0.4"

ConVar sv_maxplayers;
ConVar CvarSlotsDefault, CvarSlotsVoteMin, CvarSlotsVoteMax;
int g_iSlotsDef, g_iSlotsVoteMin, g_iSlotsVoteMax;
int g_iVoteNumber;

public Plugin myinfo =
{
	name = "L4D2 Slots",
	author = "Sir, fdxx",
	description = "",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_slots_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarSlotsDefault = CreateConVar("l4d2_slots_default", "5", "默认slots设置(服务器启动时设置)", FCVAR_NONE, true, -1.0, true, 31.0);
	CvarSlotsVoteMin = CreateConVar("l4d2_slots_vote_min", "5", "slots投票最小限制", FCVAR_NONE, true, -1.0, true, 31.0);
	CvarSlotsVoteMax = CreateConVar("l4d2_slots_vote_max", "6", "slots投票最大限制", FCVAR_NONE, true, -1.0, true, 31.0);

	GetCvars();

	CvarSlotsDefault.AddChangeHook(ConVarChanged);
	CvarSlotsVoteMin.AddChangeHook(ConVarChanged);
	CvarSlotsVoteMax.AddChangeHook(ConVarChanged);

	RegConsoleCmd("sm_slots", SlotsVote);
	RegConsoleCmd("sm_slot", SlotsVote);
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iSlotsDef = CvarSlotsDefault.IntValue;
	g_iSlotsVoteMin = CvarSlotsVoteMin.IntValue;
	g_iSlotsVoteMax = CvarSlotsVoteMax.IntValue;
}

public void OnConfigsExecuted()
{
	FindConVar("sv_allow_lobby_connect_only").SetBool(false);
	L4D_LobbyUnreserve();

	sv_maxplayers = FindConVar("sv_maxplayers");

	if (sv_maxplayers != null)
	{
		static bool bAlreadySet;
		if (!bAlreadySet)
		{
			bAlreadySet = true;
			sv_maxplayers.SetInt(g_iSlotsDef);
		}
	}
	else SetFailState("l4dtoolz plugin not loaded?");
}

public Action SlotsVote(int client, int args)
{
	if (IsRealClient(client))
	{
		if (args == 1)
		{
			char sArg[2];
			GetCmdArg(1, sArg, sizeof(sArg));
			g_iVoteNumber = StringToInt(sArg);
			if (g_iSlotsVoteMin <= g_iVoteNumber <= g_iSlotsVoteMax)
			{
				StartVote(client, g_iVoteNumber);
			}
			else PrintToChat(client, "%i <= number <= %i", g_iSlotsVoteMin, g_iSlotsVoteMax);
		}
		else PrintToChat(client, "Use: !slots <number>");
	}
}

void StartVote(int client, int iNumber)
{
	if (NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		if (NativeVotes_IsNewVoteAllowed())
		{
			NativeVote vote = new NativeVote(Callback_NativeVote, NativeVotesType_Custom_YesNo, MenuAction_Select|NATIVEVOTES_ACTIONS_DEFAULT);
			vote.Initiator = client;
			vote.SetDetails("将 Slots 更改为 %i ?", iNumber);
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}发起了一个投票", client);

			int iTotal = 0;
			int[] Clients = new int[MaxClients];
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsRealClient(i))
				{
					Clients[iTotal++] = i;
				}
			}
			vote.DisplayVote(Clients, iTotal, 20);
		}
		else CPrintToChat(client, "{default}[{yellow}提示{default}] 请等待 {yellow}%i {default}秒后再进行投票", NativeVotes_CheckVoteDelay());
	}
	else LogError("游戏不支持 NativeVote 插件");
}

public int Callback_NativeVote(NativeVote vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			CPrintToChatAll("{olive}%N {default}已投票", param1);
		}

		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				vote.DisplayFail(NativeVotesFail_Generic);
			}
		}

		case MenuAction_VoteEnd:
		{
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				vote.DisplayFail(NativeVotesFail_Loses);
			}
			else
			{
				vote.DisplayPass("加载中...");
				sv_maxplayers.SetInt(g_iVoteNumber);
			}
		}

		case MenuAction_End:
		{
			vote.Close();
		}
	}
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

