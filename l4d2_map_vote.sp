#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.7"

#include <sourcemod>
#include <sdktools>
#include <l4d2_nativevote>			// https://github.com/fdxx/l4d2_nativevote
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues
#include <multicolors>  

Address
	g_pMatchExtL4D,
	g_pTheDirector;

Handle
	g_hSDKGetAllMissions,
	g_hSDKChangeMission,
	g_hSDKClearTeamScores;

StringMap
	g_smTranslate,
	g_smExcludeMissions,
	g_smFirstMap;

ConVar
	mp_gamemode,
	g_cvAdminChangeDirectly;

int
	g_iType[MAXPLAYERS],
	g_iPos[MAXPLAYERS][2];

bool g_bAdminChangeDirectly;
char g_sMode[128];

char g_sValveMaps[][][] = 
{
	{"C1",	"C1 死亡中心"},
	{"C2",	"C2 黑色嘉年华"},
	{"C3",	"C3 沼泽激战"},
	{"C4",	"C4 暴风骤雨"},
	{"C5",	"C5 教区"},
	{"C6",	"C6 短暂时刻"},
	{"C7",	"C7 牺牲"},
	{"C8",	"C8 毫不留情"},
	{"C9",	"C9 坠机险途"},
	{"C10",	"C10 死亡丧钟"},
	{"C11",	"C11 寂静时分"},
	{"C12",	"C12 血腥收获"},
	{"C13",	"C13 刺骨寒溪"},
	{"C14",	"C14 临死一搏"},
};

public Plugin myinfo = 
{
	name = "L4D2 Map vote",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_map_vote_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvAdminChangeDirectly = CreateConVar("l4d2_map_vote_admin_change_directly", "1", "Admin change directly, no votes required.");
	mp_gamemode = FindConVar("mp_gamemode");

	OnConVarChanged(null, "", "");

	g_cvAdminChangeDirectly.AddChangeHook(OnConVarChanged);
	mp_gamemode.AddChangeHook(OnConVarChanged);

	RegConsoleCmd("sm_mapvote", Cmd_VoteMap);
	RegConsoleCmd("sm_votemap", Cmd_VoteMap);
	RegConsoleCmd("sm_v3", Cmd_VoteMap);

	RegAdminCmd("sm_missions_export", Cmd_Rxport, ADMFLAG_ROOT);
	RegAdminCmd("sm_missions_reload", Cmd_Reload, ADMFLAG_ROOT);
	RegAdminCmd("sm_clear_scores", Cmd_ClearScores, ADMFLAG_ROOT);

	RegPluginLibrary("l4d2_map_vote");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	mp_gamemode.GetString(g_sMode, sizeof(g_sMode));
	g_bAdminChangeDirectly = g_cvAdminChangeDirectly.BoolValue;
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	SetFirstMapString();
}

void SetFirstMapString()
{
	delete g_smFirstMap;
	g_smFirstMap = new StringMap();

	char sKey[64], sMissionName[256], sFirstMap[256];

	SourceKeyValues kvMissions = SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);
	for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey())
	{
		FormatEx(sKey, sizeof(sKey), "modes/%s/1/Map", g_sMode);
		SourceKeyValues kvFirstMap = kvSub.FindKey(sKey);
		if (!kvFirstMap.IsNull())
		{
			kvSub.GetName(sMissionName, sizeof(sMissionName));
			kvFirstMap.GetString(NULL_STRING, sFirstMap, sizeof(sFirstMap));
			g_smFirstMap.SetString(sFirstMap, sMissionName);
		}
	}
}

Action Cmd_Rxport(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_missions_export <sFileName>");
		return Plugin_Handled;
	}

	char sFile[256];
	GetCmdArg(1, sFile, sizeof(sFile));
	SourceKeyValues kv = SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);

	if (kv.SaveToFile(sFile))
		ReplyToCommand(client, "Save to file succeeded: %s", sFile);
	
	return Plugin_Handled;
}

Action Cmd_Reload(int client, int args)
{
	ServerCommand("update_addon_paths");
	ServerCommand("mission_reload");
	ServerExecute();
	SetFirstMapString();

	ReplyToCommand(client, "更新VPK文件");
	return Plugin_Handled;
}

Action Cmd_ClearScores(int client, int args)
{
	SDKCall(g_hSDKClearTeamScores, g_pTheDirector, true);
	ReplyToCommand(client, "清除分数");
	return Plugin_Handled;
}

Action Cmd_VoteMap(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) != 1 || CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
		{
			Menu menu = new Menu(MapType_MenuHandler);
			menu.SetTitle("选择地图类型:");
			menu.AddItem("", "官方地图");
			menu.AddItem("", "第三方地图");
			menu.Display(client, 20);
			return Plugin_Handled;
		}
	}

	CPrintToChat(client, "{lightgreen}旁观无法进行投票.");
	return Plugin_Handled;
}

int MapType_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iType[client] = itemNum;
			g_iPos[client][0] = 0;
			g_iPos[client][1] = 0;

			ShowMapMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void ShowMapMenu(int client)
{
	static char sSubName[256], sTitle[256], sKey[256];

	Menu menu = new Menu(Title_MenuHandler);
	menu.SetTitle("选择地图:");

	SourceKeyValues kvMissions = SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);
	for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey())
	{
		kvSub.GetName(sSubName, sizeof(sSubName));
		if (g_smExcludeMissions.ContainsKey(sSubName))
			continue;

		FormatEx(sKey, sizeof(sKey), "modes/%s", g_sMode);
		if (kvSub.FindKey(sKey).IsNull())
			continue;

		if (g_iType[client] == 0 && kvSub.GetInt("builtin"))
		{
			kvSub.GetString("DisplayTitle", sTitle, sizeof(sTitle), "N/A");
			g_smTranslate.GetString(sTitle[23], sTitle, sizeof(sTitle));
			menu.AddItem(sSubName, sTitle);
		}
		else if (g_iType[client] == 1 && !kvSub.GetInt("builtin"))
		{
			kvSub.GetString("DisplayTitle", sTitle, sizeof(sTitle), "N/A");
			menu.AddItem(sSubName, sTitle);
		}
	}
	
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iPos[client][g_iType[client]], 30);
}

int Title_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iPos[client][g_iType[client]] = menu.Selection;

			static char sTitle[256], sSubName[256];

			if (menu.GetItem(itemNum, sSubName, sizeof(sSubName), _, sTitle, sizeof(sTitle)))
			{
				ShowChaptersMenu(client, sSubName, sTitle);
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				Cmd_VoteMap(client, 0);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void ShowChaptersMenu(int client, const char[] sSubName, const char[] sTitle)
{
	static char sMap[256], sKey[256];
	
	FormatEx(sKey, sizeof(sKey), "%s/modes/%s", sSubName, g_sMode);
	SourceKeyValues kvMissions = SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);
	SourceKeyValues kvChapters = kvMissions.FindKey(sKey);

	if (!kvChapters.IsNull())
	{
		Menu menu = new Menu(Chapters_MenuHandler);
		menu.SetTitle("选择章节:");

		for (SourceKeyValues kvSub = kvChapters.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey())
		{
			kvSub.GetString("Map", sMap, sizeof(sMap), "N/A");
			menu.AddItem(sTitle, sMap);
		}

		menu.ExitBackButton = true;
		menu.Display(client, 30);
	}
}

int Chapters_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			static char sTitle[256], sMap[256];

			if (menu.GetItem(itemNum, sTitle, sizeof(sTitle), _, sMap, sizeof(sMap)))
			{
				StartVoteMap(client, sTitle, sMap);
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				ShowMapMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void StartVoteMap(int client, const char[] sTitle, const char[] sMap)
{
	if (g_bAdminChangeDirectly && CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
	{
		char sMissionName[256];
		if (g_smFirstMap.GetString(sMap, sMissionName, sizeof(sMissionName)))
			SDKCall(g_hSDKChangeMission, g_pTheDirector, sMissionName);
		else
			ServerCommand("changelevel %s", sMap);
			
		return;
	}

	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "{lightgreen}投票正在进行中, 暂不能发起新的投票.");
		return;
	}
	
	L4D2NativeVote vote = L4D2NativeVote(Vote_Handler);
	vote.SetDisplayText("更换地图: %s (%s)", sTitle, sMap);
	vote.Initiator = client;
	vote.SetInfoString(sMap);

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
			char sDisplay[256];
			vote.GetDisplayText(sDisplay, sizeof(sDisplay));
			CPrintToChatAll("{blue}[Vote] {olive}%N {default}发起投票%s", param1, sDisplay);
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

				char sMap[256], sMissionName[256];
				vote.GetInfoString(sMap, sizeof(sMap));

				if (g_smFirstMap.GetString(sMap, sMissionName, sizeof(sMissionName)))
					SDKCall(g_hSDKChangeMission, g_pTheDirector, sMissionName);
				else
					ServerCommand("changelevel %s", sMap);

			}
			else vote.SetFail();
		}
	}
}

void Init()
{
	GameData hGameData = new GameData("l4d2_map_vote");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_map_vote.txt\" file");
	
	g_pMatchExtL4D = hGameData.GetAddress("g_pMatchExtL4D");
	if (g_pMatchExtL4D == Address_Null)
		SetFailState("Failed to get address: \"g_pMatchExtL4D\"");

	g_pTheDirector = hGameData.GetAddress("TheDirector");
	if (g_pTheDirector == Address_Null)
		SetFailState("Failed to get address: \"TheDirector\"");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(0);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetAllMissions = EndPrepSDKCall();
	if (g_hSDKGetAllMissions == null)
		SetFailState("Failed to create SDKCall: MatchExtL4D::GetAllMissions");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::OnChangeMissionVote");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDKChangeMission = EndPrepSDKCall();
	if (g_hSDKChangeMission == null)
		SetFailState("Failed to create SDKCall: CDirector::OnChangeMissionVote");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::ClearTeamScores");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKClearTeamScores = EndPrepSDKCall();
	if (g_hSDKClearTeamScores == null)
		SetFailState("Failed to create SDKCall: CDirector::ClearTeamScores");

	delete hGameData;

	g_smTranslate = new StringMap();
	for (int i; i < sizeof(g_sValveMaps); i++)
		g_smTranslate.SetString(g_sValveMaps[i][0], g_sValveMaps[i][1]);

	g_smExcludeMissions = new StringMap();
	g_smExcludeMissions.SetValue("credits", 1);
	g_smExcludeMissions.SetValue("HoldoutChallenge", 1);
	g_smExcludeMissions.SetValue("HoldoutTraining", 1);
	g_smExcludeMissions.SetValue("parishdash", 1);
	g_smExcludeMissions.SetValue("shootzones", 1);
}
