#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <regex>

#define VERSION "0.2"
#define KV_PATH "data/l4d2_stats.txt"

Database g_Database;
bool g_bRoundEnd;

// 需要 l4d2_kill_mvp 插件
// sourcepawn不支持在native回调中直接中声明enum struct，使用any[]来接受enum struct
// https://github.com/alliedmodders/sourcepawn/issues/547
native void L4D2_GetKillData(int client, any[] SurKillData);
enum struct esKillData
{
	int iKillSI;
	int iKillCI;
	int iDmg;
}

enum QueryType
{
	UpdataKillData = 1,
	UpdataTimeData = 2,
	AddNewPlayerData = 3,
	QuerySteamID = 4,
	QueryPlayerData = 5,
	SaveTop10Data = 6,
	CreateTable = 7
};

enum
{
	FIELD_STEAMID = 0,
	FIELD_NAME = 1,
	FIELD_KILLSI = 2,
	FIELD_KILLCI = 3,
	FIELD_DMG = 4,
	FIELD_PLAYTIME = 5,
	FIELD_RANK = 6
};

public Plugin myinfo =
{
	name = "L4D2 Stats",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_stats_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	// 在configs/databases.cfg中设置mysql的连接信息
	Database.Connect(ConnectDatabase, "l4d2");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_stats", Cmd_PlayerStats);
}

public Action Cmd_PlayerStats(int client, int args)
{
	Menu menu = new Menu(MenuCallback);

	menu.SetTitle("选择查询类型:");
	menu.AddItem("", "前十名");
	menu.AddItem("", "自己");
	menu.Display(client, 20);
}

public int MenuCallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
				{
					char sDisplay[32];
					menu.GetItem(param2, "", 1, _, sDisplay, sizeof(sDisplay));

					Menu menuTop10 = new Menu(MenuTop10Callback);
					menuTop10.SetTitle("%s:", sDisplay);

					char sPath[PLATFORM_MAX_PATH], sName[MAX_NAME_LENGTH], sNum[4];
					BuildPath(Path_SM, sPath, sizeof(sPath), KV_PATH);
					KeyValues kv = new KeyValues("");

					if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
					{
						do
						{
							if (kv.GetSectionName(sNum, sizeof(sNum)))
							{
								kv.GetString("Name", sName, sizeof(sName));
								if (sName[0] != 0) menuTop10.AddItem(sNum, sName);
							}
						}
						while (kv.GotoNextKey());
						menuTop10.Display(param1, 20);
					}
					delete kv;
				}
				case 1: DatabaseQuery(QueryPlayerData, param1, DBPrio_High);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public int MenuTop10Callback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sNum[4], sName[MAX_NAME_LENGTH];
			char sPath[PLATFORM_MAX_PATH], sBuffer[64], sSteamID[64];

			menu.GetItem(param2, sNum, sizeof(sNum), _, sName, sizeof(sName));

			BuildPath(Path_SM, sPath, sizeof(sPath), KV_PATH);
			KeyValues kv = new KeyValues("");

			if (kv.ImportFromFile(sPath) && kv.JumpToKey(sNum))
			{
				Panel panel = new Panel();
				FormatEx(sBuffer, sizeof(sBuffer), "第 %s 名", sNum);
				panel.SetTitle(sBuffer);
				panel.DrawText("__________");

				FormatEx(sBuffer, sizeof(sBuffer), "名字: %s", sName);
				panel.DrawText(sBuffer);

				FormatEx(sBuffer, sizeof(sBuffer), "特感击杀数: %i 个", kv.GetNum("killsi"));
				panel.DrawText(sBuffer);

				FormatEx(sBuffer, sizeof(sBuffer), "丧失击杀数: %i 个", kv.GetNum("killci"));
				panel.DrawText(sBuffer);

				FormatEx(sBuffer, sizeof(sBuffer), "总伤害: %.2f 万", kv.GetNum("totaldamage")*0.0001);
				panel.DrawText(sBuffer);
				
				FormatEx(sBuffer, sizeof(sBuffer), "游戏时间: %.0f 小时 %i 分钟",  kv.GetFloat("playtime")/60/60, RoundToNearest(kv.GetFloat("playtime")/60) % 60);
				panel.DrawText(sBuffer);

				kv.GetString("steamid", sSteamID, sizeof(sSteamID));
				FormatEx(sBuffer, sizeof(sBuffer), "SteamID: %s", sSteamID);
				panel.DrawText(sBuffer);

				panel.DrawItem("返回");
				panel.Send(param1, PanelCallback, 20);
				delete panel;
			}
			delete kv;
		}

		case MenuAction_Cancel:
		{
			Cmd_PlayerStats(param1, 0);
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundEnd = false;
	CreateTimer(5.0, RoundStart_Timer);
}

public Action RoundStart_Timer(Handle timer)
{
	DatabaseQuery(SaveTop10Data, _, DBPrio_Low);
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		DatabaseQuery(QuerySteamID, client);
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			DatabaseQuery(UpdataKillData, i);
		}
	}
	g_bRoundEnd = true;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients && !IsFakeClient(client))
	{
		if (!g_bRoundEnd) DatabaseQuery(UpdataKillData, client);
		DatabaseQuery(UpdataTimeData, client);
	}
	return Plugin_Continue;
}

void DatabaseQuery(QueryType Type, int client = -1, DBPriority Priority = DBPrio_Normal)
{
	if (g_Database == null) ThrowError("g_Database == null");

	char sSteamID[64], sQuery[512];
	bool bGetSteamID;

	if (client > 0)
	{
		bGetSteamID = GetSteamID(client, sSteamID);
	}

	switch (Type)
	{
		case UpdataKillData:
		{
			if (bGetSteamID)
			{
				esKillData KillData;
				L4D2_GetKillData(client, KillData);
				g_Database.Format(sQuery, sizeof(sQuery), "UPDATE l4d2_stats SET name = '%N', killsi = killsi+%i, killci = killci+%i, totaldamage = totaldamage+%i WHERE steamid = '%s'", client, KillData.iKillSI, KillData.iKillCI, KillData.iDmg, sSteamID);
			}
		}

		case UpdataTimeData:
		{
			if (bGetSteamID)
			{
				g_Database.Format(sQuery, sizeof(sQuery), "UPDATE l4d2_stats SET name = '%N', playtime = playtime+%f WHERE steamid = '%s'", client, GetClientTime(client), sSteamID);
			}
		}

		case AddNewPlayerData:
		{
			if (bGetSteamID)
			{
				g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO l4d2_stats VALUES('%s', '%N', 0, 0, 0, 0.0, 0, 0, 0)", sSteamID, client);
			}
		}
		
		case QuerySteamID:
		{
			if (bGetSteamID)
			{
				g_Database.Format(sQuery, sizeof(sQuery), "SELECT steamid FROM l4d2_stats WHERE steamid = '%s'", sSteamID);
			}
		}

		case QueryPlayerData:
		{
			if (bGetSteamID)
			{
				g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM (SELECT steamid, name, killsi, killci, totaldamage, playtime, ROW_NUMBER() OVER(ORDER BY totaldamage DESC) AS rank_num FROM l4d2_stats) AS shit WHERE steamid = '%s'", sSteamID);
			}
		}

		case SaveTop10Data:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "SELECT steamid, name, killsi, killci, totaldamage, playtime FROM l4d2_stats ORDER BY totaldamage DESC LIMIT 0, 10");
		}

		case CreateTable:
		{
			g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS l4d2_stats(steamid VARCHAR(64), name TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, killsi INT, killci INT, totaldamage INT, playtime FLOAT, points INT, money INT, level INT, PRIMARY KEY (steamid))");
		}
	}

	if (sQuery[0] != '\0')
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(client);
		hPack.WriteCell(Type);
		g_Database.Query(QueryCallback, sQuery, hPack, Priority);
	}
}

public void QueryCallback(Database db, DBResultSet results, const char[] error, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	QueryType Type = hPack.ReadCell();
	delete hPack;

	if (db != null && results != null)
	{
		switch (Type)
		{
			case UpdataKillData, UpdataTimeData, AddNewPlayerData, CreateTable:
			{
			}

			case QuerySteamID:
			{
				if (results.RowCount == 0)
				{
					DatabaseQuery(AddNewPlayerData, client, DBPrio_High);
				}
			}

			case QueryPlayerData:
			{
				if (results.RowCount == 1 && results.FetchRow())
				{
					char sBuffer[64], sName[MAX_NAME_LENGTH];
					Panel panel = new Panel();

					panel.SetTitle("自己");
					panel.DrawText("__________");

					results.FetchString(FIELD_NAME, sName, sizeof(sName));
					FormatEx(sBuffer, sizeof(sBuffer), "名字: %s", sName);
					panel.DrawText(sBuffer);

					FormatEx(sBuffer, sizeof(sBuffer), "排名: 第 %i 名", results.FetchInt(FIELD_RANK));
					panel.DrawText(sBuffer);

					FormatEx(sBuffer, sizeof(sBuffer), "特感击杀数: %i 个", results.FetchInt(FIELD_KILLSI));
					panel.DrawText(sBuffer);

					FormatEx(sBuffer, sizeof(sBuffer), "丧失击杀数: %i 个", results.FetchInt(FIELD_KILLCI));
					panel.DrawText(sBuffer);

					FormatEx(sBuffer, sizeof(sBuffer), "总伤害: %.2f 万", results.FetchInt(FIELD_DMG)*0.0001);
					panel.DrawText(sBuffer);
					
					FormatEx(sBuffer, sizeof(sBuffer), "游戏时间: %.0f 小时 %i 分钟",  results.FetchFloat(FIELD_PLAYTIME)/60/60, RoundToNearest(results.FetchFloat(FIELD_PLAYTIME)/60) % 60);
					panel.DrawText(sBuffer);

					panel.DrawItem("返回");
					panel.Send(client, PanelCallback, 20);
					delete panel;
				}
			}

			case SaveTop10Data:
			{
				if (results.RowCount >= 1)
				{
					KeyValues kv = new KeyValues("Top10");
					char sSteamID[64], sName[MAX_NAME_LENGTH], sNum[4];
					int iNum;

					while (results.FetchRow())
					{
						kv.Rewind();
						IntToString(++iNum, sNum, sizeof(sNum));
						if (kv.JumpToKey(sNum, true))
						{
							results.FetchString(FIELD_STEAMID, sSteamID, sizeof(sSteamID));
							kv.SetString("steamid", sSteamID);
							results.FetchString(FIELD_NAME, sName, sizeof(sName));
							kv.SetString("Name", sName);
							kv.SetNum("killsi", results.FetchInt(FIELD_KILLSI));
							kv.SetNum("killci", results.FetchInt(FIELD_KILLCI));
							kv.SetNum("totaldamage", results.FetchInt(FIELD_DMG));
							kv.SetFloat("playtime", results.FetchFloat(FIELD_PLAYTIME));
						}
					}
					
					char sPath[PLATFORM_MAX_PATH];
					BuildPath(Path_SM, sPath, sizeof(sPath), KV_PATH);
					kv.Rewind();
					kv.ExportToFile(sPath);
					delete kv;
				}
			}
		}
	}
	else LogError("数据库错误: %s", error);
}

public int PanelCallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			Cmd_PlayerStats(param1, 0);
		}
	}
}

bool GetSteamID(int client, char sSteamID[64])
{
	if (GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
	{
		static Regex regex;

		if (regex == null)
			regex = new Regex("STEAM_\\d:\\d:\\d+");

		return regex.Match(sSteamID) == 1;
	}
	return false;
}

public void ConnectDatabase(Database db, const char[] error, any data)
{
	if (db == null) SetFailState("无法连接数据库: %s", error);
	db.SetCharset("utf8mb4");
	g_Database = db;
	DatabaseQuery(CreateTable, _, DBPrio_High);
}

