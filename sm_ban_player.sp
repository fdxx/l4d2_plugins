#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.1"

#include <sourcemod>
#include <adminmenu>
#include <regex>
#include <ripext>	// https://github.com/ErikMinekus/sm-ripext

#define MAX_STEAM2_LENGTH 21
#define MAX_STEAMID64_LENGTH 18

static const char g_sKickMsg[] = "You have been permanently banned, Any questions contact the server owner.";

Database g_Database;
ConVar g_cvCfgName, g_cvkey;
StringMap g_smBanList;
char g_sKey[512];
char g_sLogPath[PLATFORM_MAX_PATH];
TopMenu g_TopMenu;
int g_iBanReason[MAXPLAYERS] = {1, ...};

enum
{
	BAN_NONE		= 0,
	BAN_CHEAT		= 1,
	BAN_MAKETROUBLE = 2,
	BAN_OTHER		= 3,
};

enum
{
	FIELD_STEAMID	= 0,
	FIELD_NAME		= 1,
	FIELD_REASON	= 2,
};

enum QueryType
{
	Query_CreateTable	= 1,
	Query_CreateBanList	= 2,
	Query_AddBan		= 3,
	Query_UpdateName	= 4,
	Query_UnBan			= 5,
};

enum struct QueryData
{
	int iCmdClient;
	ReplySource reply; // Reply rcon doesn't work
	QueryType type;
	int iBanReason;
	//int iTargetClient;
	char sSteamID[MAX_STEAM2_LENGTH];
	char sSteamID64[MAX_STEAMID64_LENGTH];
	char sName[MAX_NAME_LENGTH];
}

public Plugin myinfo =
{
	name = "SM Ban player",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	delete g_smBanList;
	g_smBanList = new StringMap();

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/sm_ban_player.log");

	CreateConVar("sm_ban_player_version", VERSION, "Plugin version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvCfgName = CreateConVar("sm_ban_player_cfg_name", "", "Database configuration name. (addons/sourcemod/configs/databases.cfg)");
	g_cvkey = CreateConVar("sm_ban_player_key", "", "The Steam API key used by get name.\nhttps://steamcommunity.com/dev/apikey");

	RegAdminCmd("sm_ban_player", Cmd_BanPlayer, ADMFLAG_ROOT);
	RegAdminCmd("sm_check_ban_player", Cmd_CheckBanPlayer, ADMFLAG_ROOT);
	RegAdminCmd("sm_unban_player", Cmd_UnBanPlayer, ADMFLAG_ROOT);

	AutoExecConfig(true, "sm_ban_player");
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	g_cvkey.GetString(g_sKey, sizeof(g_sKey));

	char sName[256];
	g_cvCfgName.GetString(sName, sizeof(sName));
	Database.Connect(ConnectDatabase, sName);

	if (LibraryExists("adminmenu") && ((g_TopMenu = GetAdminTopMenu()) != null))
	{
		TopMenuObject PlayerCmdCategory = FindTopMenuCategory(g_TopMenu, ADMINMENU_PLAYERCOMMANDS);
		if (PlayerCmdCategory != INVALID_TOPMENUOBJECT)
		{
			g_TopMenu.AddItem("l4d2_ban", BanPlayer_TopMenuHandler, PlayerCmdCategory, "l4d2_ban", ADMFLAG_ROOT, "BanPlayerEx");
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		char sSteamID[MAX_STEAM2_LENGTH];
		if (GetSteamID(client, sSteamID, sizeof(sSteamID)))
		{
			int iBanReason;
			if (g_smBanList.GetValue(sSteamID, iBanReason))
			{
				KickClient(client, "%s", g_sKickMsg);
				LogToFileEx(g_sLogPath, "%N (%s) has been banned from enter the server, reason: %i", client, sSteamID, iBanReason);
			}
		}
	}
}

void ConnectDatabase(Database db, const char[] error, any data)
{
	if (db == null) SetFailState("Unable to connect to database: %s", error);
	db.SetCharset("utf8mb4");
	g_Database = db;

	QueryData queryData[2];

	queryData[0].type = Query_CreateTable;
	DatabaseQuery(queryData[0], DBPrio_High);

	queryData[1].type = Query_CreateBanList;
	DatabaseQuery(queryData[1], DBPrio_Low);
}

// enum struct ignore const https://github.com/alliedmodders/sourcepawn/issues/758
void DatabaseQuery(QueryData queryData, DBPriority Priority = DBPrio_Normal)
{
	if (g_Database == null) ThrowError("g_Database == null");

	char sQuery[512];

	switch (queryData.type)
	{
		case Query_CreateTable:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS l4d2_ban(steamid VARCHAR(64), name TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, banreason INT, time DATETIME, PRIMARY KEY (steamid))");
		}

		case Query_CreateBanList:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM l4d2_ban");
		}

		case Query_AddBan:
		{
			Transaction hMultiQuery = new Transaction();

			g_Database.Format(sQuery, sizeof(sQuery), "REPLACE INTO l4d2_ban VALUES('%s', '%s', %i, NOW())", queryData.sSteamID, queryData.sName, queryData.iBanReason);
			hMultiQuery.AddQuery(sQuery); // 0

			g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM l4d2_ban WHERE steamid = '%s'", queryData.sSteamID);
			hMultiQuery.AddQuery(sQuery); // 1

			DataPack hPack = new DataPack();
			hPack.WriteCellArray(queryData, sizeof(queryData));
			g_Database.Execute(hMultiQuery, MultiQuerySuccessCallback, MultiQueryFailureCallback, hPack, Priority);

			return;
		}

		case Query_UpdateName:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "UPDATE l4d2_ban SET name = '%s', time = NOW() WHERE steamid = '%s'", queryData.sName, queryData.sSteamID);
		}

		case Query_UnBan:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM l4d2_ban WHERE steamid = '%s'", queryData.sSteamID);
		}
	}

	if (sQuery[0] != '\0')
	{
		DataPack hPack = new DataPack();
		hPack.WriteCellArray(queryData, sizeof(queryData));
		g_Database.Query(QueryCallback, sQuery, hPack, Priority);
	}
}

void QueryCallback(Database db, DBResultSet results, const char[] error, DataPack hPack)
{
	hPack.Reset();
	QueryData queryData;
	hPack.ReadCellArray(queryData, sizeof(queryData));
	delete hPack;

	if (db != null && results != null)
	{
		switch (queryData.type)
		{
			case Query_CreateBanList:
			{
				if (results.RowCount >= 1)
				{
					char sSteamID[MAX_STEAM2_LENGTH];
					while (results.FetchRow())
					{
						results.FetchString(FIELD_STEAMID, sSteamID, sizeof(sSteamID));
						g_smBanList.SetValue(sSteamID, results.FetchInt(FIELD_REASON));
					}
				}
			}
			case Query_UpdateName:
			{
				ReplySource OldReply = SetCmdReplySource(queryData.reply);
				ReplyToCommand(queryData.iCmdClient, "Update %s name %s successful", queryData.sSteamID, queryData.sName);
				SetCmdReplySource(OldReply);

				LogToFileEx(g_sLogPath, "Update %s name %s successful", queryData.sSteamID, queryData.sName);
			}

			case Query_UnBan:
			{
				ReplySource OldReply = SetCmdReplySource(queryData.reply);

				if (g_smBanList.Remove(queryData.sSteamID))
				{
					ReplyToCommand(queryData.iCmdClient, "UnBan %s successful", queryData.sSteamID);
					LogToFileEx(g_sLogPath, "UnBan %s successful", queryData.sSteamID);
				}
				else ReplyToCommand(queryData.iCmdClient, "Steamid not found from ban list!");

				SetCmdReplySource(OldReply);
			}
		}
	}
	else LogError("Database error: %s", error);
}

void MultiQueryFailureCallback(Database db, DataPack hPack, int numQueries, const char[] error, int failIndex, any[] data)
{
	delete hPack;
	LogError("numQueries = %i, failIndex = %i, error = %s", numQueries, failIndex, error);
}

void MultiQuerySuccessCallback(Database db, DataPack hPack, int numQueries, DBResultSet[] results, any[] data)
{
	hPack.Reset();
	QueryData queryData;
	hPack.ReadCellArray(queryData, sizeof(queryData));
	delete hPack;

	for (int i = 0; i < numQueries; i++)
	{
		if (results[i] == null)
		{
			LogError("results[%i] == null", i);
			return;
		}
	}

	switch (queryData.type)
	{
		case Query_AddBan:
		{
			if (results[1].RowCount == 1 && results[1].FetchRow())
			{
				g_smBanList.SetValue(queryData.sSteamID, queryData.iBanReason);

				ReplySource OldReply = SetCmdReplySource(queryData.reply);
				ReplyToCommand(queryData.iCmdClient, "AddBan %s (%s) successful, reason = %i",  queryData.sSteamID, queryData.sName, queryData.iBanReason);
				SetCmdReplySource(OldReply);

				LogToFileEx(g_sLogPath, "AddBan %s (%s) successful, reason = %i",  queryData.sSteamID, queryData.sName, queryData.iBanReason);

				char sName[MAX_NAME_LENGTH];
				results[1].FetchString(FIELD_NAME, sName, sizeof(sName));
				
				if (sName[0] == '\0')
				{
					char sUrl[512];
					FormatEx(sUrl, sizeof(sUrl), "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s&format=json", g_sKey, queryData.sSteamID64);

					DataPack hPack1 = new DataPack();
					hPack1.WriteCellArray(queryData, sizeof(queryData));

					HTTPRequest http = new HTTPRequest(sUrl);
					http.Get(HTTPRequestResult, hPack1);
				}
			}
		}
	}
}

void HTTPRequestResult(HTTPResponse response, DataPack hPack, const char[] error)
{
	hPack.Reset();
	QueryData queryData;
	hPack.ReadCellArray(queryData, sizeof(queryData));
	delete hPack;

	if (error[0] == '\0' && response.Status == HTTPStatus_OK)
	{
		JSONObject ObjectRoot = view_as<JSONObject>(response.Data);
		if (ObjectRoot != null && ObjectRoot.HasKey("response"))
		{
			JSONObject ObjectResponse = view_as<JSONObject>(ObjectRoot.Get("response"));
			if (ObjectResponse != null && ObjectResponse.HasKey("players"))
			{
				JSONArray ArrayPlayers = view_as<JSONArray>(ObjectResponse.Get("players"));
				if (ArrayPlayers != null && ArrayPlayers.Length == 1)
				{
					JSONObject ObjectPlayers = view_as<JSONObject>(ArrayPlayers.Get(0));
					if (ObjectPlayers != null && ObjectPlayers.HasKey("personaname"))
					{
						if (ObjectPlayers.GetString("personaname", queryData.sName, sizeof(queryData.sName)))
						{
							queryData.type = Query_UpdateName;
							DatabaseQuery(queryData);
						}
					}
					delete ObjectPlayers;
				}
				delete ArrayPlayers;
			}
			delete ObjectResponse;
		}
		delete ObjectRoot;
	}
	else LogMessage("error = %s, HTTPStatus = %i", error, view_as<int>(response.Status));
}

Action Cmd_BanPlayer(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "sm_ban_player <SteamID> <ReasonNum>");
		return Plugin_Handled;
	}

	char sSteamID[MAX_STEAM2_LENGTH];
	GetCmdArg(1, sSteamID, sizeof(sSteamID));
	BanPlayer(client, GetCmdReplySource(), sSteamID, GetCmdArgInt(2));

	return Plugin_Handled;
}

void BanPlayer(int client, ReplySource reply, const char[] sSteamID, int iBanReason)
{
	QueryData queryData;

	queryData.iCmdClient = client;
	queryData.reply = reply;
	queryData.type = Query_AddBan;
	queryData.iBanReason = iBanReason;
	strcopy(queryData.sSteamID, sizeof(queryData.sSteamID), sSteamID);

	int iTarget = GetClientOfSteamID(sSteamID);
	//queryData.iTargetClient = iTarget;

	if (iTarget > 0)
	{
		int id = GetSteamAccountID(iTarget);
		IntToString(id, queryData.sSteamID64, sizeof(queryData.sSteamID64));
		FormatEx(queryData.sName, sizeof(queryData.sName), "%N", iTarget);
		if (!IsClientInKickQueue(iTarget)) KickClient(iTarget, "Kick by admin");
	}
	else Steam2ToSteamID64(queryData.sSteamID64, sizeof(queryData.sSteamID64), sSteamID);

	DatabaseQuery(queryData);
}

Action Cmd_UnBanPlayer(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_unban_player <SteamID>");
		return Plugin_Handled;
	}

	char sSteamID[MAX_STEAM2_LENGTH];
	GetCmdArg(1, sSteamID, sizeof(sSteamID));
	
	QueryData queryData;

	queryData.iCmdClient = client;
	queryData.reply = GetCmdReplySource();
	queryData.type = Query_UnBan;
	strcopy(queryData.sSteamID, sizeof(queryData.sSteamID), sSteamID);
	DatabaseQuery(queryData);

	return Plugin_Handled;
}

Action Cmd_CheckBanPlayer(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_check_ban_player <SteamID>");
		return Plugin_Handled;
	}

	char sSteamID[MAX_STEAM2_LENGTH];
	GetCmdArg(1, sSteamID, sizeof(sSteamID));
	
	int iBanReason;
	if (g_smBanList.GetValue(sSteamID, iBanReason))
	{
		ReplyToCommand(client, "%s has been banned for reasons: %i", sSteamID, iBanReason);
	}
	else ReplyToCommand(client, "Steamid not found from ban list!");

	return Plugin_Handled;
}

void BanPlayer_TopMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: topmenu.GetInfoString(topobj_id, buffer, maxlength);
		case TopMenuAction_SelectOption: BanPlayer_MenuDrawing(client);
	}
}

void BanPlayer_MenuDrawing(int client)
{
	Menu menu = new Menu(BanPlayer_MenuHandler);
	menu.SetTitle("Select Ban Target:");

	static char sBanReason[128];
	switch (g_iBanReason[client])
	{
		case 0: FormatEx(sBanReason, sizeof(sBanReason), "Change Ban reason (Current: None)");
		case 1: FormatEx(sBanReason, sizeof(sBanReason), "Change Ban reason (Current: Cheat)");
		case 2: FormatEx(sBanReason, sizeof(sBanReason), "Change Ban reason (Current: MakeTrouble)");
		case 3: FormatEx(sBanReason, sizeof(sBanReason), "Change Ban reason (Current: Other)");
	}
	menu.AddItem("", sBanReason);

	char sName[MAX_NAME_LENGTH], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientConnected(i) && !IsFakeClient(i))
		{
			FormatEx(sName, sizeof(sName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, sName);
		}
	}
	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

int BanPlayer_MenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 0:
				{
					static int i = 1;
					g_iBanReason[client] = (++i) % 4; // 0-3 loop, start at 1
					BanPlayer_MenuDrawing(client);
				}

				default:
				{
					char sUserid[16], sSteamID[MAX_STEAM2_LENGTH];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int iTarget = GetClientOfUserId(StringToInt(sUserid));
					if (iTarget > 0 && iTarget <= MaxClients && IsClientConnected(iTarget) && !IsFakeClient(iTarget))
					{
						if (GetSteamID(iTarget, sSteamID, sizeof(sSteamID)))
						{
							BanPlayer(client, SM_REPLY_TO_CHAT, sSteamID, g_iBanReason[client]);
						}
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (itemNum == MenuCancel_ExitBack)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

int GetClientOfSteamID(const char[] sSteamID)
{
	static int i;
	static char sBuffer[MAX_STEAM2_LENGTH];

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			if (GetSteamID(i, sBuffer, sizeof(sBuffer)))
			{
				if (strcmp(sSteamID, sBuffer) == 0)
				{
					return i;
				}
			}
		}
	}
	return -1;
}

bool GetSteamID(int client, char[] sSteamID, int iMaxLength)
{
	if (GetClientAuthId(client, AuthId_Steam2, sSteamID, iMaxLength))
	{
		static Regex regex;

		if (regex == null)
			regex = new Regex("STEAM_\\d:\\d:\\d+");

		return regex.Match(sSteamID) == 1;
	}
	return false;
}

// https://forums.alliedmods.net/showthread.php?t=183443
bool Steam2ToSteamID64(char[] sSteamID64, int iMaxLength, const char[] sSteam2)
{
	char sSteamIDParts[3][11];
	static const char Identifier[] = "76561197960265728";
	
	if ((iMaxLength < 1) || (ExplodeString(sSteam2, ":", sSteamIDParts, sizeof(sSteamIDParts), sizeof(sSteamIDParts[])) != 3))
	{
		sSteamID64[0] = '\0';
		return false;
	}

	int iCurrent;
	int iCarryOver = sSteamIDParts[1][0] == '1' ? 1 : 0;

	for (int i = (iMaxLength - 2), j = (strlen(sSteamIDParts[2]) - 1), k = (strlen(Identifier) - 1); i >= 0; i--, j--, k--)
	{
		iCurrent = (j >= 0 ? (2 * (sSteamIDParts[2][j] - '0')) : 0) + iCarryOver + (k >= 0 ? ((Identifier[k] - '0') * 1) : 0);
		iCarryOver = iCurrent / 10;
		sSteamID64[i] = (iCurrent % 10) + '0';
	}

	sSteamID64[iMaxLength - 1] = '\0';
	return true;
} 
