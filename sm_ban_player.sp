#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.2"

#include <sourcemod>
#include <adminmenu>
#include <regex>
#include <ripext>	// https://github.com/ErikMinekus/sm-ripext

#define MAX_STEAM2_LENGTH 21
#define MAX_STEAMID64_LENGTH 18

#define KICK_MSG "You have been permanently banned, Any questions contact the server owner"

#define UPDATE_TIME 60.0

#define FIELD_STEAMID	0
#define FIELD_NAME		1
#define FIELD_REASON	2

Database g_Database;
ConVar g_cvDatabaseName, g_cvkey;
StringMap g_smBanList;
TopMenu g_TopMenu;
char g_sKey[512];
char g_sLogPath[PLATFORM_MAX_PATH];
int g_iBanReason[MAXPLAYERS] = {1, ...};

enum QueryType
{
	Query_CreateTable	= 1,
	Query_UpdateBanList	= 2,
	Query_AddBan		= 3,
	Query_UpdateName	= 4,
	Query_UnBan			= 5,
};

enum struct QueryData
{
	int replyClient;
	ReplySource replySource; // Reply rcon doesn't work
	QueryType queryType;
	int banReason;
	char steamID2[MAX_STEAM2_LENGTH];
	char steamID64[MAX_STEAMID64_LENGTH];
	char playerName[MAX_NAME_LENGTH];
}

public Plugin myinfo =
{
	name = "SM Ban player",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("sm_ban_player_version", VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvDatabaseName = CreateConVar("sm_ban_player_cfg_name", "", "Database configuration name. (addons/sourcemod/configs/databases.cfg)");
	g_cvkey = CreateConVar("sm_ban_player_key", "", "The Steam API key used by get name.\nhttps://steamcommunity.com/dev/apikey");

	RegAdminCmd("sm_ban_player", Cmd_BanPlayer, ADMFLAG_ROOT);
	RegAdminCmd("sm_check_ban_player", Cmd_CheckBanPlayer, ADMFLAG_ROOT);
	RegAdminCmd("sm_unban_player", Cmd_UnBanPlayer, ADMFLAG_ROOT);

	AutoExecConfig(true, "sm_ban_player");
}

public void OnConfigsExecuted()
{
	FindConVar("sv_hibernate_when_empty").IntValue = 0;
	
	static bool shit;
	if (shit) return;
	shit = true;

	char sName[256];
	g_cvDatabaseName.GetString(sName, sizeof(sName));
	Database.Connect(ConnectCallback, sName);
}

void ConnectCallback(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("ConnectCallback: %s", error);

	char ident[8];
	db.Driver.GetIdentifier(ident, sizeof(ident));
	if (strcmp(ident, "mysql"))
		ThrowError("ConnectCallback: This plugin only supports MySQL!");

	g_cvkey.GetString(g_sKey, sizeof(g_sKey));
	if (!g_sKey[0])
		LogError("Steam API key not set!");

	db.SetCharset("utf8mb4");
	g_Database = db;
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/sm_ban_player.log");
	delete g_smBanList;
	g_smBanList = new StringMap();

	QueryData queryData[2];

	queryData[0].queryType = Query_CreateTable;
	DatabaseQuery(queryData[0], DBPrio_High);

	queryData[1].queryType = Query_UpdateBanList;
	DatabaseQuery(queryData[1], DBPrio_Low);

	if (LibraryExists("adminmenu") && ((g_TopMenu = GetAdminTopMenu()) != null))
	{
		TopMenuObject PlayerCmdCategory = FindTopMenuCategory(g_TopMenu, ADMINMENU_PLAYERCOMMANDS);
		if (PlayerCmdCategory != INVALID_TOPMENUOBJECT)
		{
			g_TopMenu.AddItem("l4d2_ban", BanPlayer_TopMenuHandler, PlayerCmdCategory, "l4d2_ban", ADMFLAG_ROOT, "BanPlayerEx");
		}
	}

	// For multiple servers share a database.
	CreateTimer(UPDATE_TIME, UpdateBan_Timer, _, TIMER_REPEAT);
}

Action UpdateBan_Timer(Handle timer)
{
	QueryData queryData;
	queryData.queryType = Query_UpdateBanList;
	DatabaseQuery(queryData, DBPrio_Low);

	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	static char steamID2[MAX_STEAM2_LENGTH];

	if (!IsFakeClient(client) && GetSteamID(client, steamID2, sizeof(steamID2)))
	{
		if (g_smBanList.ContainsKey(steamID2) && !IsClientInKickQueue(client))
		{
			KickClient(client, "%s", KICK_MSG);
			LogToFileEx(g_sLogPath, "[BlockEnterServer] %s (%N)", steamID2, client);
		}
	}
}

Action Cmd_BanPlayer(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "sm_ban_player <SteamID> <ReasonNum>");
		return Plugin_Handled;
	}

	char steamID2[MAX_STEAM2_LENGTH];
	GetCmdArg(1, steamID2, sizeof(steamID2));
	BanPlayer(client, GetCmdReplySource(), steamID2, GetCmdArgInt(2));

	return Plugin_Handled;
}

void BanPlayer(int client, ReplySource replySource, const char steamID2[MAX_STEAM2_LENGTH], int banReason, int target = 0)
{
	QueryData queryData;

	queryData.replyClient = client;
	queryData.replySource = replySource;
	queryData.queryType = Query_AddBan;
	queryData.banReason = banReason;
	queryData.steamID2 = steamID2;

	if (target > 0)
		FormatEx(queryData.playerName, sizeof(queryData.playerName), "%N", target);
	else if (!Steam2ToSteamID64(queryData.steamID64, sizeof(queryData.steamID64), steamID2))
	{
		ReplyToCommand(client, "[BanPlayer] Invalid SteamID: %s", steamID2);
		return;
	}

	DatabaseQuery(queryData);
}

Action Cmd_UnBanPlayer(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "sm_unban_player <SteamID>");
		return Plugin_Handled;
	}

	char steamID2[MAX_STEAM2_LENGTH];
	GetCmdArg(1, steamID2, sizeof(steamID2));
	
	QueryData queryData;

	queryData.replyClient = client;
	queryData.replySource = GetCmdReplySource();
	queryData.queryType = Query_UnBan;
	queryData.steamID2 = steamID2;

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

	char steamID2[MAX_STEAM2_LENGTH];
	GetCmdArg(1, steamID2, sizeof(steamID2));
	
	int banReason;
	if (g_smBanList.GetValue(steamID2, banReason))
		ReplyToCommand(client, "[CheckBan] %s has been banned for reasons: %i", steamID2, banReason);
	else
		ReplyToCommand(client, "[CheckBan] %s not found from ban list!", steamID2);

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

	static char sBanReason[64];
	switch (g_iBanReason[client])
	{
		case 1: FormatEx(sBanReason, sizeof(sBanReason), "Change Ban reason (Current: Cheat)");
		case 2: FormatEx(sBanReason, sizeof(sBanReason), "Change Ban reason (Current: MakeTrouble)");
		case 3: FormatEx(sBanReason, sizeof(sBanReason), "Change Ban reason (Current: Other)");
	}
	menu.AddItem("", sBanReason);

	char playerName[MAX_NAME_LENGTH], sUserid[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (/*i != client && */IsClientConnected(i) && !IsFakeClient(i))
		{
			FormatEx(playerName, sizeof(playerName), "%N", i);
			FormatEx(sUserid, sizeof(sUserid), "%i", GetClientUserId(i));
			menu.AddItem(sUserid, playerName);
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
					if (++i > 3) i = 1;
					g_iBanReason[client] = i;
					BanPlayer_MenuDrawing(client);
				}

				default:
				{
					char sUserid[16], steamID2[MAX_STEAM2_LENGTH];
					menu.GetItem(itemNum, sUserid, sizeof(sUserid));
					int target = GetClientOfUserId(StringToInt(sUserid));
					if (target > 0 && IsClientConnected(target) && !IsFakeClient(target))
					{
						if (GetSteamID(target, steamID2, sizeof(steamID2)))
							BanPlayer(client, SM_REPLY_TO_CHAT, steamID2, g_iBanReason[client], target);
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

void DatabaseQuery(const QueryData queryData, DBPriority Priority = DBPrio_Normal)
{
	if (g_Database == null)
		ThrowError("DatabaseQuery: g_Database == null");

	char sQuery[1024];

	switch (queryData.queryType)
	{
		case Query_CreateTable:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS l4d2_ban(steamid VARCHAR(64), name TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, banreason INT, time DATETIME, PRIMARY KEY (steamid))");
		}

		case Query_UpdateBanList:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM l4d2_ban");
		}

		case Query_AddBan:
		{
			Transaction txn = new Transaction();

			g_Database.Format(sQuery, sizeof(sQuery), "REPLACE INTO l4d2_ban VALUES('%s', '%s', %i, NOW())", queryData.steamID2, queryData.playerName, queryData.banReason);
			txn.AddQuery(sQuery); // 0

			g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM l4d2_ban WHERE steamid = '%s'", queryData.steamID2);
			txn.AddQuery(sQuery); // 1

			DataPack hPack = new DataPack();
			hPack.WriteCellArray(queryData, sizeof(queryData));
			g_Database.Execute(txn, TxnSuccessCallback, TxnFailureCallback, hPack, Priority);

			return;
		}

		case Query_UpdateName:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "UPDATE l4d2_ban SET name = '%s', time = NOW() WHERE steamid = '%s'", queryData.playerName, queryData.steamID2);
		}

		case Query_UnBan:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "DELETE FROM l4d2_ban WHERE steamid = '%s'", queryData.steamID2);
		}
	}

	if (sQuery[0])
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

	if (db == null || results == null)
		ThrowError("QueryCallback: %s", error);

	switch (queryData.queryType)
	{
		case Query_UpdateBanList:
		{
			if (g_smBanList.Size != results.RowCount)
			{
				LogToFileEx(g_sLogPath, "[UpdateBanList] BanListSize %i -> %i", g_smBanList.Size, results.RowCount);
				
				delete g_smBanList;
				g_smBanList = new StringMap();
				char steamID2[MAX_STEAM2_LENGTH];

				while (results.FetchRow())
				{
					results.FetchString(FIELD_STEAMID, steamID2, sizeof(steamID2));
					g_smBanList.SetValue(steamID2, results.FetchInt(FIELD_REASON));
				}

				if (results.MoreRows)
					ThrowError("UpdateBanList: %s", error);
				
				KickFromBanList();
			}
		}
		case Query_UpdateName:
		{
			if (results.AffectedRows != 1)
				return;
			
			LogToFileEx(g_sLogPath, "[UpdateName] successful: %s (%s)", queryData.steamID2, queryData.playerName);
			ReplyClient(queryData.replyClient, queryData.replySource, "[UpdateName] successful: %s (%s)", queryData.steamID2, queryData.playerName);
		}

		case Query_UnBan:
		{
			if (results.AffectedRows == 1 && g_smBanList.Remove(queryData.steamID2))
			{
				LogToFileEx(g_sLogPath, "[UnBan] successful: %s", queryData.steamID2);
				ReplyClient(queryData.replyClient, queryData.replySource, "[UnBan] successful: %s", queryData.steamID2);
			}
			else
				ReplyClient(queryData.replyClient, queryData.replySource, "[UnBan] failure: %s not found from ban list!", queryData.steamID2);
		}
	}
}


void TxnFailureCallback(Database db, DataPack hPack, int numQueries, const char[] error, int failIndex, any[] data)
{
	delete hPack;
	ThrowError("TxnFailureCallback: numQueries = %i, failIndex = %i, error = %s", numQueries, failIndex, error);
}

void TxnSuccessCallback(Database db, DataPack hPack, int numQueries, DBResultSet[] results, any[] data)
{
	hPack.Reset();
	QueryData queryData;
	hPack.ReadCellArray(queryData, sizeof(queryData));
	delete hPack;

	switch (queryData.queryType)
	{
		case Query_AddBan:
		{
			if (results[1].RowCount == 1)
			{
				g_smBanList.SetValue(queryData.steamID2, queryData.banReason);

				LogToFileEx(g_sLogPath, "[AddBan] successful: %s (%s), banReason = %i", queryData.steamID2, queryData.playerName, queryData.banReason);
				ReplyClient(queryData.replyClient, queryData.replySource, "[AddBan] successful: %s (%s), banReason = %i", queryData.steamID2, queryData.playerName, queryData.banReason);

				KickFromBanList();
				
				if (queryData.playerName[0] == 0)
				{
					LogToFileEx(g_sLogPath, "[AddBan] start updating name: %s", queryData.steamID2);
					ReplyClient(queryData.replyClient, queryData.replySource, "[AddBan] start updating name: %s", queryData.steamID2);

					char url[512];
					FormatEx(url, sizeof(url), "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s&format=json", g_sKey, queryData.steamID64);

					DataPack hPack1 = new DataPack();
					hPack1.WriteCellArray(queryData, sizeof(queryData));

					HTTPRequest http = new HTTPRequest(url);
					http.Get(HTTPRequestResult, hPack1);
				}
			}
		}
	}
}

// Retrieving value via JSON Path is not supported.
// https://github.com/ErikMinekus/sm-ripext/issues/74
void HTTPRequestResult(HTTPResponse response, DataPack hPack, const char[] error)
{
	hPack.Reset();
	QueryData queryData;
	hPack.ReadCellArray(queryData, sizeof(queryData));
	delete hPack;

	if (error[0] || response.Status != HTTPStatus_OK)
	{
		LogToFileEx(g_sLogPath, "[HTTPRequestResult]: %s (%s), HTTPStatus = %i, error = %s",  queryData.steamID2, queryData.steamID64, view_as<int>(response.Status), error);
		return;
	}

	char sBuffer[1024];
	JSONObject jsonRoot = view_as<JSONObject>(response.Data);
	jsonRoot.ToString(sBuffer, sizeof(sBuffer), JSON_COMPACT);
	if (StrContains(sBuffer, "personaname", false) == -1)
	{
		LogToFileEx(g_sLogPath, "[HTTPRequestResult]: %s (%s), personaname not found",  queryData.steamID2, queryData.steamID64);
		delete jsonRoot;
		return;
	}

	JSONObject jsonResponse = view_as<JSONObject>(jsonRoot.Get("response"));
	JSONArray jsonPlayers = view_as<JSONArray>(jsonResponse.Get("players"));
	JSONObject jsonPlayer0 = view_as<JSONObject>(jsonPlayers.Get(0));
	if (jsonPlayer0.GetString("personaname", queryData.playerName, sizeof(queryData.playerName)))
	{
		queryData.queryType = Query_UpdateName;
		DatabaseQuery(queryData);
	}

	delete jsonRoot;
	delete jsonResponse;
	delete jsonPlayers;
	delete jsonPlayer0;
}

bool GetSteamID(int client, char[] buffer, int maxlength)
{
	if (GetClientAuthId(client, AuthId_Steam2, buffer, maxlength))
	{
		static Regex regex;

		if (regex == null)
			regex = new Regex("STEAM_\\d:\\d:\\d+");

		return regex.Match(buffer) == 1;
	}
	return false;
}

void KickFromBanList()
{
	char steamID2[MAX_STEAM2_LENGTH];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i) && GetSteamID(i, steamID2, sizeof(steamID2)))
		{
			if (g_smBanList.ContainsKey(steamID2) && !IsClientInKickQueue(i))
				KickClient(i, "%s", KICK_MSG);
		}
	}
}

void ReplyClient(int client, ReplySource replySource, const char[] format, any ...)
{
	if (!client || IsClientInGame(client))
	{
		char sBuffer[256];
		VFormat(sBuffer, sizeof(sBuffer), format, 4);

		ReplySource oldSource = SetCmdReplySource(replySource);
		ReplyToCommand(client, "%s", sBuffer);
		SetCmdReplySource(oldSource);
	}
}

// https://forums.alliedmods.net/showthread.php?t=183443
// https://developer.valvesoftware.com/wiki/SteamID
bool Steam2ToSteamID64(char[] buffer, int maxlength, const char steamID2[MAX_STEAM2_LENGTH])
{
	char sParts[3][11];
	static const char identifier[] = "76561197960265728";
	
	if ((maxlength < 1) || (ExplodeString(steamID2, ":", sParts, sizeof(sParts), sizeof(sParts[])) != 3))
	{
		buffer[0] = '\0';
		return false;
	}

	int iCurrent;
	int iCarryOver = sParts[1][0] == '1' ? 1 : 0;

	for (int i = (maxlength - 2), j = (strlen(sParts[2]) - 1), k = (strlen(identifier) - 1); i >= 0; i--, j--, k--)
	{
		iCurrent = (j >= 0 ? (2 * (sParts[2][j] - '0')) : 0) + iCarryOver + (k >= 0 ? ((identifier[k] - '0') * 1) : 0);
		iCarryOver = iCurrent / 10;
		buffer[i] = (iCurrent % 10) + '0';
	}

	buffer[maxlength - 1] = '\0';
	return true;
}
