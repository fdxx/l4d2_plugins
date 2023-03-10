#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_nativevote>	// https://github.com/fdxx/l4d2_nativevote
#include <multicolors> 		

#define VERSION "0.4"

char g_sConfig[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "L4D2 Config vote",
	author = "vintik, Sir, fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_config_vote_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	BuildPath(Path_SM, g_sConfig, sizeof(g_sConfig), "data/l4d2_config_vote.cfg");
	if (!FileExists(g_sConfig))
		SetFailState("%s file does not exist!", g_sConfig);

	RegConsoleCmd("sm_sivote", Cmd_Vote);
	RegConsoleCmd("sm_votesi", Cmd_Vote);

	RegPluginLibrary("l4d2_config_vote");
}

Action Cmd_Vote(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) != 1 || CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
		{
			KeyValues kv = new KeyValues("");
			if (!kv.ImportFromFile(g_sConfig))
				ThrowError("Failed to import %s file into KeyValues", g_sConfig);

			Menu menu1 = new Menu(Level1_MenuHandler);
			menu1.SetTitle("选择投票类型");
			
			if (kv.GotoFirstSubKey())
			{
				char sName[64];

				do
				{
					kv.GetSectionName(sName, sizeof(sName));
					menu1.AddItem(sName, sName);
				}
				while (kv.GotoNextKey());
			}

			menu1.Display(client, 20);

			delete kv;
			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{lightgreen}旁观无法进行投票.");
	return Plugin_Handled;
}

int Level1_MenuHandler(Menu menu1, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			KeyValues kv = new KeyValues("");
			if (!kv.ImportFromFile(g_sConfig))
				ThrowError("Failed to import %s file into KeyValues", g_sConfig);

			char sName[64], sCfgPath[PLATFORM_MAX_PATH];
			menu1.GetItem(param2, sName, sizeof(sName));

			if (kv.JumpToKey(sName) && kv.GotoFirstSubKey())
			{
				Menu menu2 = new Menu(Level2_MenuHandler);
				menu2.SetTitle(sName);

				do
				{
					kv.GetSectionName(sCfgPath, sizeof(sCfgPath));
					kv.GetString("name", sName, sizeof(sName));
					menu2.AddItem(sCfgPath, sName);
				}
				while (kv.GotoNextKey());

				menu2.ExitBackButton = true;
				menu2.Display(param1, 20);
			}

			delete kv;
		}
		case MenuAction_End:
		{
			delete menu1;
		}
	}
	return 0;
}

int Level2_MenuHandler(Menu menu2, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sName[64], sCfgPath[PLATFORM_MAX_PATH];
			menu2.GetItem(param2, sCfgPath, sizeof(sCfgPath), _, sName, sizeof(sName));
			StartVote(param1, sName, sCfgPath);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Cmd_Vote(param1, 0);
		}
		case MenuAction_End:
		{
			delete menu2;
		}
	}
	return 0;
}

void StartVote(int client, const char[] sDisplay, const char[] sCfgPath)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "{lightgreen}投票正在进行中, 暂不能发起新的投票.");
		return;
	}
	
	L4D2NativeVote vote = L4D2NativeVote(Vote_Handler);
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

				char sCfgPath[PLATFORM_MAX_PATH], sBuffer[PLATFORM_MAX_PATH];
				vote.GetInfoString(sCfgPath, sizeof(sCfgPath));
				FormatEx(sBuffer, PLATFORM_MAX_PATH, "cfg/%s", sCfgPath);

				if (FileExists(sBuffer))
					ServerCommand("exec %s", sCfgPath);
				else
				{
					CPrintToChatAll("{blue}[Vote] {default}加载配置失败.");
					LogError("%s file does not exist", sCfgPath);
				}
			}
			else
				vote.SetFail();
		}
	}
}
