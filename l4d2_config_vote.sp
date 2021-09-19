
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <nativevotes>
#include <multicolors>

KeyValues g_Kv;
char g_sCfg[128];

public Plugin myinfo = 
{
	name = "L4D2 Config vote",
	author = "vintik, Sir, fdxx",
	description = "自定义配置投票",
	version = "0.2",
	url = ""
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/l4d2_config_vote.cfg");

	g_Kv = new KeyValues("Config");
	if (!g_Kv.ImportFromFile(sPath))
		SetFailState("Couldn't load l4d2_config_vote.cfg!");

	RegConsoleCmd("sm_sivote", CmdVote);
	RegConsoleCmd("sm_votesi", CmdVote);
}

public Action CmdVote(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != 1)
	{
		ShowVoteMenu(client);
	}
	else CPrintToChat(client, "{default}[{yellow}提示{default}] 旁观无法进行投票");
}

void ShowVoteMenu(int client)
{
	Menu hMenuLevel1 = new Menu(Callback_MenuLevel1);
	hMenuLevel1.SetTitle("选择投票类型");

	g_Kv.Rewind();
	char sType[128];
	if (g_Kv.GotoFirstSubKey())
	{
		do
		{
			g_Kv.GetSectionName(sType, sizeof(sType));
			hMenuLevel1.AddItem(sType, sType);
		}
		while (g_Kv.GotoNextKey());
	}
	hMenuLevel1.Display(client, 20);
}

public int Callback_MenuLevel1(Menu hMenuLevel1, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sType[128], sCfg[128], sDisplay[128];
			hMenuLevel1.GetItem(param2, sType, sizeof(sType));
			g_Kv.Rewind();
			if (g_Kv.JumpToKey(sType) && g_Kv.GotoFirstSubKey())
			{
				Menu hMenuLevel2 = new Menu(Callback_MenuLevel2);
				hMenuLevel2.SetTitle(sType);
				do
				{
					g_Kv.GetSectionName(sCfg, sizeof(sCfg));
					g_Kv.GetString("name", sDisplay, sizeof(sDisplay));
					hMenuLevel2.AddItem(sCfg, sDisplay);
				}
				while (g_Kv.GotoNextKey());
				hMenuLevel2.Display(param1, 20);
			}
		}
		case MenuAction_End:
		{
			delete hMenuLevel1;
		}
	}
}

public int Callback_MenuLevel2(Menu hMenuLevel2, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sCfg[128], sDisplay[128];
			hMenuLevel2.GetItem(param2, sCfg, sizeof(sCfg), _, sDisplay, sizeof(sDisplay));
			strcopy(g_sCfg, sizeof(g_sCfg), sCfg);
			StartVote(param1, sDisplay);
		}
		case MenuAction_Cancel:
		{
			ShowVoteMenu(param1);
		}
		case MenuAction_End:
		{
			delete hMenuLevel2;
		}
	}
}

void StartVote(int client, const char[] sDisplay)
{
	if (NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		if (NativeVotes_IsNewVoteAllowed())
		{
			NativeVote vote = new NativeVote(Callback_NativeVote, NativeVotesType_Custom_YesNo, MenuAction_Select|NATIVEVOTES_ACTIONS_DEFAULT);
			vote.Initiator = client;
			vote.SetDetails("将配置更改为: %s ?", sDisplay);
			CPrintToChatAll("{default}[{yellow}提示{default}] {olive}%N {default}发起了一个投票", client);

			int iTotal = 0;
			int[] Clients = new int[MaxClients];
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					if (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
					{
						Clients[iTotal++] = i;
					}
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
				char sMsg[128];
				ServerCommandEx(sMsg, sizeof(sMsg), "exec %s", g_sCfg);
				if (sMsg[0] != '\0')
				{
					CPrintToChatAll("{default}[{red}提示{default}] 加载配置失败");
					LogError("加载 %s 失败: %s", g_sCfg, sMsg);
				}
			}
		}

		case MenuAction_End:
		{
			vote.Close();
		}
	}
}
