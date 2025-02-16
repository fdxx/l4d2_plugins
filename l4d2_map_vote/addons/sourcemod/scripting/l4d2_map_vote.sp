#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.9"

#include <sourcemod>
#include <sdktools>
#include <l4d2_nativevote>			// https://github.com/fdxx/l4d2_nativevote
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues
#include <multicolors>  


#define TEAMFLAGS_SPEC	2
#define TEAMFLAGS_SUR	4
#define TEAMFLAGS_INF	8
#define TEAMFLAGS_DEFAULT (TEAMFLAGS_SPEC|TEAMFLAGS_SUR|TEAMFLAGS_INF)

#define MAP_OFFICIAL 0
#define MAP_CUSTOM 1

Address
	g_pMatchExtL4D,
	g_pTheDirector;

Handle
	g_hSDKGetAllMissions,
	g_hSDKChangeMission,
	g_hSDKClearTeamScores;

StringMap
	g_smExcludeMissions,
	g_smFirstMap;

ConVar
	mp_gamemode,
	g_cvClearScores,
	g_cvAdminTeamFlags;

int
	g_iType[MAXPLAYERS],
	g_iPos[MAXPLAYERS][2];

enum struct MvAttr
{
	int MenuTeamFlags;
	int VoteTeamFlags;
	bool bAdminOneVotePassed;
	bool bAdminOneVoteAgainst;
}

MvAttr g_MvAttr;
char g_sMode[128];

public Plugin myinfo = 
{
	name = "L4D2 Map vote",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_map_vote");
	return APLRes_Success;
}

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_map_vote_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvAdminTeamFlags = CreateConVar("l4d2_map_vote_adminteamflags", "1", "Admin bypass TeamFlags.");
	g_cvClearScores = CreateConVar("l4d2_map_vote_clearscores", "1", "Whether to clear the score when changing maps.");
	mp_gamemode = FindConVar("mp_gamemode");

	OnConVarChanged(null, "", "");
	mp_gamemode.AddChangeHook(OnConVarChanged);

	RegAdminCmdEx("sm_mapvote_attribute", Cmd_SetAttribute, ADMFLAG_ROOT);
	RegAdminCmdEx("sm_missions_export", Cmd_Export, ADMFLAG_ROOT);
	RegAdminCmdEx("sm_missions_reload", Cmd_Reload, ADMFLAG_ROOT);
	RegAdminCmdEx("sm_clear_scores", Cmd_ClearScores, ADMFLAG_ROOT);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	mp_gamemode.GetString(g_sMode, sizeof(g_sMode));
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	RegConsoleCmdEx("sm_mapvote", Cmd_VoteMap);
	RegConsoleCmdEx("sm_votemap", Cmd_VoteMap);
	RegConsoleCmdEx("sm_v3", Cmd_VoteMap);

	SetFirstMapString();
}

void SetFirstMapString()
{
	delete g_smFirstMap;
	g_smFirstMap = new StringMap();
	char sFirstMap[256], buffer[256];

	SourceKeyValues kvRoot = SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);
	for (SourceKeyValues kvSub = kvRoot.GetFirstTrueSubKey(); kvSub; kvSub = kvSub.GetNextTrueSubKey())
	{
		FormatEx(buffer, sizeof(buffer), "modes/%s/1/Map", g_sMode);
		SourceKeyValues kvFirstMap = kvSub.FindKey(buffer);
		if (!kvFirstMap)
			continue;

		kvSub.GetName(buffer, sizeof(buffer));
		kvFirstMap.GetString(NULL_STRING, sFirstMap, sizeof(sFirstMap));
		g_smFirstMap.SetString(sFirstMap, buffer);
	}
}

Action Cmd_SetAttribute(int client, int args)
{
	if (args != 2)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <MenuTeamFlags|VoteTeamFlags|AdminOneVotePassed|AdminOneVoteAgainst> <value>", cmd);
		return Plugin_Handled;
	}

	char attribute[32];
	GetCmdArg(1, attribute, sizeof(attribute));
	int value = GetCmdArgInt(2);

	if (StrContains(attribute, "MenuTeamFlags", false) != -1)
		g_MvAttr.MenuTeamFlags = value;
		
	else if (StrContains(attribute, "VoteTeamFlags", false) != -1)
		g_MvAttr.VoteTeamFlags = value;

	else if (StrContains(attribute, "AdminOneVotePassed", false) != -1)
		g_MvAttr.bAdminOneVotePassed = value > 0;

	else if (StrContains(attribute, "AdminOneVoteAgainst", false) != -1)
		g_MvAttr.bAdminOneVoteAgainst = value > 0;

	else
		ReplyToCommand(client, "Bad attribute name: %s ", attribute);
	
	return Plugin_Handled;
}

Action Cmd_Export(int client, int args)
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

	ReplyToCommand(client, "Update VPK File.");
	return Plugin_Handled;
}

Action Cmd_ClearScores(int client, int args)
{
	SDKCall(g_hSDKClearTeamScores, g_pTheDirector, true);
	ReplyToCommand(client, "ClearScores");
	return Plugin_Handled;
}

Action Cmd_VoteMap(int client, int args)
{
	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if (!IsValidTeamFlags(client, g_MvAttr.MenuTeamFlags))
		return Plugin_Handled;

	char buffer[256];
	Menu menu = new Menu(MapType_MenuHandler);

	Format(buffer, sizeof(buffer), "%T", "_SelectMapType", client);
	menu.SetTitle("%s", buffer);

	Format(buffer, sizeof(buffer), "%T", "_OfficialMap", client);
	menu.AddItem("", buffer);

	Format(buffer, sizeof(buffer), "%T", "_CustomMap", client);
	menu.AddItem("", buffer);

	menu.Display(client, 20);
	return Plugin_Handled;
}

int MapType_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iType[client] = itemNum;
			g_iPos[client][MAP_OFFICIAL] = 0;
			g_iPos[client][MAP_CUSTOM] = 0;

			ShowMissionsMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void ShowMissionsMenu(int client)
{
	char mission[256], buffer[256];
	Menu menu = new Menu(Missions_MenuHandler);

	Format(buffer, sizeof(buffer), "%T", "_SelectMap", client);
	menu.SetTitle("%s", buffer);

	SourceKeyValues kvRoot = SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);
	for (SourceKeyValues kvSub = kvRoot.GetFirstTrueSubKey(); kvSub; kvSub = kvSub.GetNextTrueSubKey())
	{
		kvSub.GetName(buffer, sizeof(buffer));
		if (g_smExcludeMissions.ContainsKey(buffer))
			continue;

		FormatEx(buffer, sizeof(buffer), "modes/%s", g_sMode);
		SourceKeyValues kvChapters = kvSub.FindKey(buffer);
		if (!kvChapters)
			continue;

		if (g_iType[client] == MAP_OFFICIAL && !kvSub.GetInt("builtin"))
			continue;

		if (g_iType[client] == MAP_CUSTOM && kvSub.GetInt("builtin"))
			continue;

		kvSub.GetString("DisplayTitle", mission, sizeof(mission), "N/A");
		if (TranslationPhraseExists(mission))
			Format(mission, sizeof(mission), "%T", mission, client);

		IntToString(view_as<int>(kvChapters), buffer, sizeof(buffer));
		menu.AddItem(buffer, mission);
	}
	
	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iPos[client][g_iType[client]], 30);
}

int Missions_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iPos[client][g_iType[client]] = menu.Selection;
			char mission[256], buffer[256];

			if (menu.GetItem(itemNum, buffer, sizeof(buffer), _, mission, sizeof(mission)))
				ShowChaptersMenu(client, view_as<SourceKeyValues>(StringToInt(buffer)), mission);
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

void ShowChaptersMenu(int client, SourceKeyValues kvChapters, const char[] mission)
{
	char chapter[256];
	Menu menu = new Menu(Chapters_MenuHandler);
	menu.SetTitle("%s:", mission);

	for (SourceKeyValues kvSub = kvChapters.GetFirstTrueSubKey(); kvSub; kvSub = kvSub.GetNextTrueSubKey())
	{
		kvSub.GetString("Map", chapter, sizeof(chapter), "N/A");
		menu.AddItem(chapter, chapter);
	}

	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

int Chapters_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char chapter[256];
			if (menu.GetItem(itemNum, chapter, sizeof(chapter)))
				StartVoteMap(client, chapter);
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				ShowMissionsMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void StartVoteMap(int client, const char[] chapter)
{
	if (!L4D2NativeVote_IsAllowNewVote())
	{
		CPrintToChat(client, "%t", "_NotAllowNewVote");
		return;
	}
	
	L4D2NativeVote vote = L4D2NativeVote(Vote_Handler);
	vote.SetDisplayText("%T", "_VoteDisplayTitle", client, chapter);
	vote.Initiator = client;
	vote.SetInfoString(chapter);

	int iPlayerCount = 0;
	int[] iClients = new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (!IsValidTeamFlags(i, g_MvAttr.VoteTeamFlags))
				continue;

			iClients[iPlayerCount++] = i;
		}
	}

	if (!vote.DisplayVote(iClients, iPlayerCount, 20))
		LogMessage("Failed to initiate voting.");
}

void Vote_Handler(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	switch (action)
	{
		case VoteAction_Start:
		{
			char sDisplay[256];
			vote.GetDisplayText(sDisplay, sizeof(sDisplay));
			CPrintToChatAll("%t", "_InitiatedVoting", param1, sDisplay);
		}
		case VoteAction_PlayerVoted:
		{
			CPrintToChatAll("%t", "_PlayerVoted");

			if (!CheckCommandAccess(param1, "sm_admin", ADMFLAG_ROOT))
				return;

			if (param2 == VOTE_YES && g_MvAttr.bAdminOneVotePassed)
			{
				vote.YesCount = vote.PlayerCount;
				vote.NoCount = 0;
			}
			else if (param2 == VOTE_NO &&g_MvAttr.bAdminOneVoteAgainst)
			{
				vote.YesCount = 0;
				vote.NoCount = vote.PlayerCount;
			}
		}
		case VoteAction_End:
		{
			if (vote.YesCount > vote.PlayerCount/2)
			{
				vote.SetPass("Loading...");

				char sMap[256], sMissionName[256];
				vote.GetInfoString(sMap, sizeof(sMap));

				if (g_cvClearScores.BoolValue)
					SDKCall(g_hSDKClearTeamScores, g_pTheDirector, true);

				if (g_smFirstMap.GetString(sMap, sMissionName, sizeof(sMissionName)))
					SDKCall(g_hSDKChangeMission, g_pTheDirector, sMissionName);
				else
					ServerCommand("changelevel %s", sMap);

				
			}
			else
				vote.SetFail();
		}
	}
}

bool IsValidTeamFlags(int client, int flags)
{
	if (g_cvAdminTeamFlags.BoolValue && CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
		return true;

	int team = GetClientTeam(client);
	return (flags & (1 << team)) != 0;
}

void RegAdminCmdEx(const char[] cmd, ConCmd callback, int adminflags, const char[] description="", const char[] group="", int flags=0)
{
	if (!CommandExists(cmd))
		RegAdminCmd(cmd, callback, adminflags, description, group, flags);
	else
	{
		char pluginName[PLATFORM_MAX_PATH];
		FindPluginNameByCmd(pluginName, sizeof(pluginName), cmd);
		LogError("The command \"%s\" already exists, plugin: \"%s\"", cmd, pluginName);
	}
}

void RegConsoleCmdEx(const char[] cmd, ConCmd callback, const char[] description="", int flags=0)
{
	if (!CommandExists(cmd))
		RegConsoleCmd(cmd, callback, description, flags);
	else
	{
		char pluginName[PLATFORM_MAX_PATH];
		FindPluginNameByCmd(pluginName, sizeof(pluginName), cmd);
		LogError("The command \"%s\" already exists, plugin: \"%s\"", cmd, pluginName);
	}
}

bool FindPluginNameByCmd(char[] buffer, int maxlength, const char[] cmd)
{
	char cmdBuffer[128];
	bool result = false;
	CommandIterator iter = new CommandIterator();

	while (iter.Next())
	{
		iter.GetName(cmdBuffer, sizeof(cmdBuffer));
		if (strcmp(cmdBuffer, cmd, false))
			continue;

		GetPluginFilename(iter.Plugin, buffer, maxlength);
		result = true;
		break;
	}

	if (!result)
	{
		ConVar cvar = FindConVar(cmd);
		if (cvar)
		{
			GetPluginFilename(cvar.Plugin, buffer, maxlength);
			result = true;
		}
	}

	delete iter;
	return result;
}

void Init()
{
	char buffer[256];

	strcopy(buffer, sizeof(buffer), "l4d2_map_vote");
	GameData hGameData = new GameData(buffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", buffer);

	strcopy(buffer, sizeof(buffer), "g_pMatchExtL4D");
	g_pMatchExtL4D = hGameData.GetAddress(buffer);
	if (g_pMatchExtL4D == Address_Null)
		SetFailState("Failed to GetAddress: %s", buffer);

	strcopy(buffer, sizeof(buffer), "TheDirector");
	g_pTheDirector = hGameData.GetAddress(buffer);
	if (g_pTheDirector == Address_Null)
		SetFailState("Failed to GetAddress: %s", buffer);

	strcopy(buffer, sizeof(buffer), "MatchExtL4D::GetAllMissions");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, buffer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetAllMissions = EndPrepSDKCall();
	if (g_hSDKGetAllMissions == null)
		SetFailState("Failed to create SDKCall: %s", buffer);
	
	strcopy(buffer, sizeof(buffer), "CDirector::OnChangeMissionVote");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDKChangeMission = EndPrepSDKCall();
	if (g_hSDKChangeMission == null)
		SetFailState("Failed to create SDKCall: %s", buffer);

	strcopy(buffer, sizeof(buffer), "CDirector::ClearTeamScores");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKClearTeamScores = EndPrepSDKCall();
	if (g_hSDKClearTeamScores == null)
		SetFailState("Failed to create SDKCall: %s", buffer);

	delete hGameData;

	LoadTranslations("l4d2_map_vote.phrases.txt");

	delete g_smExcludeMissions;
	g_smExcludeMissions = new StringMap();
	g_smExcludeMissions.SetValue("credits", 1);
	g_smExcludeMissions.SetValue("HoldoutChallenge", 1);
	g_smExcludeMissions.SetValue("HoldoutTraining", 1);
	g_smExcludeMissions.SetValue("parishdash", 1);
	g_smExcludeMissions.SetValue("shootzones", 1);

	// Out-of-the-box settings.
	g_MvAttr.MenuTeamFlags = TEAMFLAGS_SUR|TEAMFLAGS_INF;
	g_MvAttr.VoteTeamFlags = TEAMFLAGS_SUR|TEAMFLAGS_INF;
	g_MvAttr.bAdminOneVotePassed = true;
	g_MvAttr.bAdminOneVoteAgainst = true;
}
