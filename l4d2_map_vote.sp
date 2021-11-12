#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <nativevotes> //https://github.com/sapphonie/sourcemod-nativevotes-updated
#include <multicolors>

ArrayList g_aExcludeFile, g_aMapInfo;
KeyValues g_kvMapList, g_kvMissionFile;
char g_sMapListPath[PLATFORM_MAX_PATH];
char g_sMapName[128];

public Plugin myinfo = 
{
	name = "L4D2 Map vote",
	author = "Alex Dragokas, fdxx",
	description = "第三方地图投票，自动解析地图文件",
	version = "0.1",
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vote3", Cmd_VoteMap);
	RegConsoleCmd("sm_v3", Cmd_VoteMap);
	
	Initialization();
}

public Action Cmd_VoteMap(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != 1)
	{
		ShowVoteMenu(client);
	}
	else CPrintToChat(client, "{default}[{yellow}提示{default}] 旁观无法进行投票");
	return Plugin_Handled;
}

void ShowVoteMenu(int client)
{
	Menu MenuMapTitle = new Menu(Callback_MenuMapTitle);
	MenuMapTitle.SetTitle("选择地图:");

	g_kvMapList.Rewind();
	char sMapTitle[128];
	if (g_kvMapList.GotoFirstSubKey())
	{
		do
		{
			g_kvMapList.GetSectionName(sMapTitle, sizeof(sMapTitle));
			MenuMapTitle.AddItem(sMapTitle, sMapTitle);
		}
		while (g_kvMapList.GotoNextKey());
	}
	MenuMapTitle.Display(client, 20);
}


public int Callback_MenuMapTitle(Menu MenuMapTitle, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMapTitle[128], sMapName[128], sMapFullInfo[128];
			MenuMapTitle.GetItem(param2, sMapTitle, sizeof(sMapTitle));
			g_kvMapList.Rewind();
			if (g_kvMapList.JumpToKey(sMapTitle) && g_kvMapList.GotoFirstSubKey(false))
			{
				Menu MenuMapName = new Menu(Callback_MenuMapName);
				MenuMapName.SetTitle("选择 %s 的章节:", sMapTitle);
				do
				{
					g_kvMapList.GetString(NULL_STRING, sMapName, sizeof(sMapName));
					FormatEx(sMapFullInfo, sizeof(sMapFullInfo), "%s (%s)", sMapTitle, sMapName);
					MenuMapName.AddItem(sMapFullInfo, sMapName);
				}
				while (g_kvMapList.GotoNextKey(false));
				MenuMapName.Display(param1, 20);
			}
		}
		case MenuAction_End:
		{
			delete MenuMapTitle;
		}
	}
	return 0;
}

public int Callback_MenuMapName(Menu MenuMapName, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMapName[128], sMapFullInfo[128];
			MenuMapName.GetItem(param2, sMapFullInfo, sizeof(sMapFullInfo), _, sMapName, sizeof(sMapName));
			strcopy(g_sMapName, sizeof(g_sMapName), sMapName);
			StartVote(param1, sMapFullInfo);
		}
		case MenuAction_Cancel:
		{
			ShowVoteMenu(param1);
		}
		case MenuAction_End:
		{
			delete MenuMapName;
		}
	}
	return 0;
}

void StartVote(int client, const char[] sMapFullInfo)
{
	if (NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		if (NativeVotes_IsNewVoteAllowed())
		{
			NativeVote vote = new NativeVote(Callback_NativeVote, NativeVotesType_Custom_YesNo, MenuAction_Select|NATIVEVOTES_ACTIONS_DEFAULT);
			vote.Initiator = client;
			vote.SetDetails("将地图更改为: %s ?", sMapFullInfo);
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
				vote.DisplayPass("5秒后更换地图到 %s", g_sMapName);
				CreateTimer(5.0, ChangeMap_Timer);
			}
		}

		case MenuAction_End:
		{
			vote.Close();
		}
	}
	return 0;
}

public Action ChangeMap_Timer(Handle timer)
{
	char sMsg[128];
	ServerCommandEx(sMsg, sizeof(sMsg), "changelevel %s", g_sMapName);
	if (sMsg[0] != 0)
	{
		CPrintToChatAll("{default}[{red}提示{default}] 换图失败");
		LogError("更换 %s 地图失败: %s", g_sMapName, sMsg);
	}
	return Plugin_Continue;
}

void Initialization()
{
	g_aExcludeFile = new ArrayList(128);
	g_aMapInfo = new ArrayList(128);

	char sFile[128];
	for (int i = 1; i <= 14; i++)
	{
		FormatEx(sFile, sizeof(sFile), "campaign%i.txt", i);
		g_aExcludeFile.PushString(sFile);
	}
	g_aExcludeFile.PushString("credits.txt");
	g_aExcludeFile.PushString("holdoutchallenge.txt");
	g_aExcludeFile.PushString("holdouttraining.txt");
	g_aExcludeFile.PushString("parishdash.txt");
	g_aExcludeFile.PushString("shootzones.txt");
	
	BuildPath(Path_SM, g_sMapListPath, sizeof(g_sMapListPath), "data/l4d2_map_vote.txt");
}

public void OnMapStart()
{
	CreateTimer(1.0, MapStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action MapStart_Timer(Handle timer)
{
	delete g_kvMapList;
	g_kvMapList = new KeyValues("map");

	char sMissionFile[128];
	FileType fileType;
	DirectoryListing hDir = OpenDirectory("missions", true, ".");

	if (hDir != null)
	{
		while (hDir.GetNext(sMissionFile, sizeof(sMissionFile), fileType))
		{
			if (fileType == FileType_File)
			{
				if (g_aExcludeFile.FindString(sMissionFile) == -1)
				{
					Format(sMissionFile, sizeof(sMissionFile), "missions/%s", sMissionFile);
					ParseMissionFile(sMissionFile);
				}
			}
		}
	}

	delete hDir;
	g_kvMapList.Rewind();
	g_kvMapList.ExportToFile(g_sMapListPath);

	return Plugin_Continue;
}

void ParseMissionFile(const char[] sMissionFile)
{
	g_aMapInfo.Clear();
	delete g_kvMissionFile;
	g_kvMissionFile = new KeyValues("");

	static char sDisplayTitle[128], sMapName[128];

	if (g_kvMissionFile.ImportFromFile(sMissionFile))
	{
		g_kvMissionFile.GetString("DisplayTitle", sDisplayTitle, sizeof(sDisplayTitle), "INVALID_TITLE");
		if (strcmp(sDisplayTitle, "INVALID_TITLE") == 0)
			LogError("(%s) Get DisplayTitle failed", sMissionFile);
		g_aMapInfo.PushString(sDisplayTitle);

		if (g_kvMissionFile.JumpToKey("modes") && g_kvMissionFile.JumpToKey("coop"))
		{
			if (g_kvMissionFile.GotoFirstSubKey())
			{
				do
				{
					g_kvMissionFile.GetString("Map", sMapName, sizeof(sMapName), "INVALID_NAME");
					if (strcmp(sMapName, "INVALID_NAME") == 0)
						LogError("(%s) Get MapName failed", sMissionFile);
					g_aMapInfo.PushString(sMapName);
				}
				while (g_kvMissionFile.GotoNextKey());
			}
		}

		SetMapList(g_aMapInfo);
	}
}

void SetMapList(ArrayList aMapInfo)
{
	g_kvMapList.Rewind();
	
	if (aMapInfo.Length > 0)
	{
		static char sDisplayTitle[128], sMapName[128], sNum[4];
		aMapInfo.GetString(0, sDisplayTitle, sizeof(sDisplayTitle));
		if (g_kvMapList.JumpToKey(sDisplayTitle, true))
		{
			for (int i = 1; i < aMapInfo.Length; i++)
			{
				IntToString(i, sNum, sizeof(sNum));
				aMapInfo.GetString(i, sMapName, sizeof(sMapName));
				g_kvMapList.SetString(sNum, sMapName);
			}
		}
	}
}
