#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2_nativevote> // https://github.com/fdxx/l4d2_nativevote
#include <multicolors>

#define VERSION "0.2"

ArrayList g_aExcludeFile, g_aMapInfo;
KeyValues g_kvMapList, g_kvMissionFile;
char g_sMapListPath[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "L4D2 Map vote",
	author = "Alex Dragokas, fdxx",
	description = "第三方地图投票，自动解析地图文件",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_map_vote_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	RegConsoleCmd("sm_vote3", Cmd_VoteMap);
	RegConsoleCmd("sm_v3", Cmd_VoteMap);
	
	Initialization();
}

Action Cmd_VoteMap(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != 1)
	{
		Menu menu = new Menu(MapTitle_MenuHandler);
		menu.SetTitle("选择地图:");

		g_kvMapList.Rewind();
		char sMapTitle[128];
		if (g_kvMapList.GotoFirstSubKey())
		{
			do
			{
				g_kvMapList.GetSectionName(sMapTitle, sizeof(sMapTitle));
				menu.AddItem(sMapTitle, sMapTitle);
			}
			while (g_kvMapList.GotoNextKey());
		}
		menu.Display(client, 20);
		return Plugin_Handled;
	}

	CPrintToChat(client, "{default}[{yellow}提示{default}] 旁观无法进行投票");
	return Plugin_Handled;
}

int MapTitle_MenuHandler(Menu hTitleMenu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMapTitle[128], sMapName[128], sMapFullInfo[128];
			hTitleMenu.GetItem(param2, sMapTitle, sizeof(sMapTitle));
			g_kvMapList.Rewind();
			if (g_kvMapList.JumpToKey(sMapTitle) && g_kvMapList.GotoFirstSubKey(false))
			{
				Menu menu = new Menu(MapName_MenuHandler);
				menu.SetTitle("选择 %s 的章节:", sMapTitle);
				do
				{
					g_kvMapList.GetString(NULL_STRING, sMapName, sizeof(sMapName));
					FormatEx(sMapFullInfo, sizeof(sMapFullInfo), "%s (%s)", sMapTitle, sMapName);
					menu.AddItem(sMapFullInfo, sMapName);
				}
				while (g_kvMapList.GotoNextKey(false));
				menu.ExitBackButton = true;
				menu.Display(param1, 20);
			}
		}
		case MenuAction_End:
		{
			delete hTitleMenu;
		}
	}
	return 0;
}

int MapName_MenuHandler(Menu hMapNameMenu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sMapName[128], sMapFullInfo[128];
			hMapNameMenu.GetItem(param2, sMapFullInfo, sizeof(sMapFullInfo), _, sMapName, sizeof(sMapName));
			StartVote(param1, sMapFullInfo, sMapName);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Cmd_VoteMap(param1, 0);
		}
		case MenuAction_End:
		{
			delete hMapNameMenu;
		}
	}
	return 0;
}

void StartVote(int client, const char[] sMapFullInfo, const char[] sMapName)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "{default}[{yellow}提示{default}] 投票正在进行中，暂不能发起新的投票");
		return;
	}
	
	L4D2NativeVote vote = L4D2NativeVote(VoteHandler);
	vote.SetDisplayText("将地图更改为: %s ?", sMapFullInfo);
	vote.Initiator = client;
	vote.SetInfoString(sMapName);

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

				char sMapName[256], sMsg[128];
				vote.GetInfoString(sMapName, sizeof(sMapName));
				ServerCommandEx(sMsg, sizeof(sMsg), "changelevel %s", sMapName);
				if (sMsg[0] != '\0')
				{
					CPrintToChatAll("{default}[{red}提示{default}] 换图失败");
					LogError("更换 %s 地图失败: %s", sMapName, sMsg);
				}
			}
			else vote.SetFail();
		}
	}
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

Action MapStart_Timer(Handle timer)
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
