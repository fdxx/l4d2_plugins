#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_nativevote> // https://github.com/fdxx/l4d2_nativevote
#include <multicolors>

KeyValues g_kv;

public Plugin myinfo = 
{
	name = "L4D2 Config vote",
	author = "vintik, Sir, fdxx",
	description = "自定义配置投票",
	version = "0.3",
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/l4d2_config_vote.cfg");

	g_kv = new KeyValues("Config");
	if (!g_kv.ImportFromFile(sPath))
		SetFailState("Couldn't load l4d2_config_vote.cfg!");

	RegConsoleCmd("sm_sivote", Cmd_Vote);
	RegConsoleCmd("sm_votesi", Cmd_Vote);
}

Action Cmd_Vote(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != 1)
	{
		Menu menu = new Menu(Category_MenuHandler);
		menu.SetTitle("选择投票类型");

		g_kv.Rewind();
		char sCategory[64];
		if (g_kv.GotoFirstSubKey())
		{
			do
			{
				g_kv.GetSectionName(sCategory, sizeof(sCategory));
				menu.AddItem(sCategory, sCategory);
			}
			while (g_kv.GotoNextKey());
		}
		menu.Display(client, 20);
		return Plugin_Handled;
	}

	CPrintToChat(client, "{default}[{yellow}提示{default}] 旁观无法进行投票");
	return Plugin_Handled;
}

int Category_MenuHandler(Menu hCategoryMenu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sCategory[64], sCfgPath[256], sDisplay[64];
			hCategoryMenu.GetItem(param2, sCategory, sizeof(sCategory));
			g_kv.Rewind();
			if (g_kv.JumpToKey(sCategory) && g_kv.GotoFirstSubKey())
			{
				Menu menu = new Menu(Item_MenuHandler);
				menu.SetTitle(sCategory);
				do
				{
					g_kv.GetSectionName(sCfgPath, sizeof(sCfgPath));
					g_kv.GetString("name", sDisplay, sizeof(sDisplay));
					menu.AddItem(sCfgPath, sDisplay);
				}
				while (g_kv.GotoNextKey());
				menu.ExitBackButton = true;
				menu.Display(param1, 20);
			}
		}
		case MenuAction_End:
		{
			delete hCategoryMenu;
		}
	}
	return 0;
}

int Item_MenuHandler(Menu hItemMenu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sCfgPath[256], sDisplay[64];
			hItemMenu.GetItem(param2, sCfgPath, sizeof(sCfgPath), _, sDisplay, sizeof(sDisplay));
			StartVote(param1, sDisplay, sCfgPath);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Cmd_Vote(param1, 0);
		}
		case MenuAction_End:
		{
			delete hItemMenu;
		}
	}
	return 0;
}

void StartVote(int client, const char[] sDisplay, const char[] sCfgPath)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "{default}[{yellow}提示{default}] 投票正在进行中，暂不能发起新的投票");
		return;
	}
	
	L4D2NativeVote vote = L4D2NativeVote(VoteHandler);
	vote.SetDisplayText("将配置更改为: %s ?", sDisplay);
	vote.Initiator = client;
	vote.SetInfoString(sCfgPath);

	int iPlayerCount = 0;
	int[] iClients = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
			{
				iClients[iPlayerCount++] = i;
			}
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

				char sCfgPath[256], sMsg[128];
				vote.GetInfoString(sCfgPath, sizeof(sCfgPath));
				ServerCommandEx(sMsg, sizeof(sMsg), "exec %s", sCfgPath);
				if (sMsg[0] != '\0')
				{
					CPrintToChatAll("{default}[{red}提示{default}] 加载配置失败");
					LogError("加载 %s 失败: %s", sCfgPath, sMsg);
				}
			}
			else vote.SetFail();
		}
	}
}
