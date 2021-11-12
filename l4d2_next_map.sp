#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <sdktools>
#include <left4dhooks>

#define VERSION "1.5"

enum
{
	FINAL_MAP,
	FIRST_MAP,
	MAP_TRANSLATE,
}

char g_sMapsInfo[][][] =
{
	//FINAL_MAP,				FIRST_MAP,				MAP_TRANSLATE
	{"c14m2_lighthouse",		"c1m1_hotel",			"C1M1 死亡中心"},	//0
	{"c1m4_atrium",				"c2m1_highway",			"C2M1 黑色嘉年华"},	//1
	{"c2m5_concert",			"c3m1_plankcountry",	"C3M1 沼泽激战"},	//2
	{"c3m4_plantation",			"c4m1_milltown_a",		"C4M1 暴风骤雨"},	//3
	{"c4m5_milltown_escape",	"c5m1_waterfront",		"C5M1 教区"}, 		//4
	{"c5m5_bridge",				"c6m1_riverbank",		"C6M1 短暂时刻"},	//5
	{"c6m3_port",				"c7m1_docks",			"C7M1 牺牲"},		//6
	{"c7m3_port",				"c8m1_apartment",		"C8M1 毫不留情"},	//7
	{"c8m5_rooftop",			"c9m1_alleys",			"C9M1 坠机险途"},	//8
	{"c9m2_lots",				"c10m1_caves",			"C10M1 死亡丧钟"},	//9
	{"c10m5_houseboat",			"c11m1_greenhouse",		"C11M1 寂静时分"},	//10
	{"c11m5_runway",			"c12m1_hilltop",		"C12M1 血腥收获"},	//11
	{"c12m5_cornfield",			"c13m1_alpinecreek",	"C13M1 刺骨寒溪"},	//12
	{"c13m4_cutthroatcreek",	"c14m1_junkyard",		"C14M1 临死一搏"},	//13
};

ConVar CvarRandomNextMap, CvarDefaultNextMap, CvarAnnounceNextMap;
bool g_bRandomNextMap, g_bAnnounceNextMap;
char g_sDefNextMap[128];
ArrayList g_aPlayedMap;
bool g_bFirstMap, g_bFinalMap;
int g_iMapID = -1;

//Handle g_hChangeLevel;
//Address g_pTheDirector;

public Plugin myinfo =
{
	name = "L4D2 Next Map",
	description = "When the end of finale chapter, map will be changed automatically.",
	author = "pan0s, fdxx",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_next_map_version", VERSION, "L4D2 auto change next map version", FCVAR_NONE | FCVAR_DONTRECORD);
	
	CvarRandomNextMap = CreateConVar("l4d2_next_map_random", "1", "Next map is random? 0=Order, 1=Random", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarAnnounceNextMap = CreateConVar("l4d2_next_map_announce", "1", "Announce next map to players after the final map start", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarDefaultNextMap = CreateConVar("l4d2_next_map_default", "c2m1_highway", "Default map when the change map fails", FCVAR_NONE, true, 0.0, true, 1.0);

	GetCvars();

	CvarRandomNextMap.AddChangeHook(ConVarChanged);
	CvarAnnounceNextMap.AddChangeHook(ConVarChanged);
	CvarDefaultNextMap.AddChangeHook(ConVarChanged);

	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_next_map", CmdNextMap);
	RegConsoleCmd("sm_set_next_map", CmdSetNextMap);

	g_aPlayedMap = new ArrayList();
	//GetGameData();

	AutoExecConfig(true, "l4d2_next_map");
}
/*
void GetGameData()
{
	// https://forums.alliedmods.net/showthread.php?t=319156
	GameData hGamedata = new GameData("l4d2_next_map");
	if(hGamedata == null) 
		SetFailState("Failed to load \"l4d2_next_map\" gamedata.");
	
	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CDirector::OnChangeChapterVote"))
		SetFailState("Error finding the 'CDirector::OnChangeChapterVote' signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hChangeLevel = EndPrepSDKCall();
	if(g_hChangeLevel == null)
		SetFailState("Unable to prep SDKCall 'CDirector::OnChangeChapterVote'");
	
	g_pTheDirector = GameConfGetAddress(hGamedata, "CDirector");
	if(g_pTheDirector == Address_Null)
		SetFailState("Unable to get 'CDirector' Address");

	delete hGamedata;
}
*/
public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bRandomNextMap = CvarRandomNextMap.BoolValue;
	g_bAnnounceNextMap = CvarAnnounceNextMap.BoolValue;
	CvarDefaultNextMap.GetString(g_sDefNextMap, sizeof(g_sDefNextMap));
}

public void OnConfigsExecuted()
{
	if (!L4D2_IsGenericCooperativeMode())
	{
		LogError("不支持的游戏模式");
	}
}

public void OnMapStart()
{
	CreateTimer(1.0, OnMapStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnMapStart_Timer(Handle timer)
{
	g_bFirstMap = L4D_IsFirstMapInScenario();
	g_bFinalMap = L4D_IsMissionFinalMap();

	SavePlayedMap();
	SetNextMapID();

	return Plugin_Continue;
}

void SavePlayedMap()
{
	if (g_bFirstMap && g_bRandomNextMap)
	{
		int iMapID = FindMapId(CurrentMap(), FIRST_MAP);
		if (iMapID != -1)
		{
			if(g_aPlayedMap.Length + 1 >= sizeof(g_sMapsInfo)) g_aPlayedMap.Clear();
			g_aPlayedMap.Push(iMapID);
		}
		else LogMessage("[l4d2_next_map] SavePlayedMap 无法从 g_sMapsInfo 中找到 MapID");
	}
}

void SetNextMapID()
{
	if (g_bFinalMap)
	{
		int iMapID = FindMapId(CurrentMap(), FINAL_MAP);
		if (iMapID != -1 && g_bRandomNextMap)
		{
			iMapID = GetRandomInt(0, (sizeof(g_sMapsInfo) - 1));
			bool bValidMapID = CheckMapID(iMapID);
			while (!bValidMapID) //随机地图不重复
			{
				iMapID = GetRandomInt(0, (sizeof(g_sMapsInfo) - 1));
				bValidMapID = CheckMapID(iMapID);
			}
		}
		else LogMessage("[l4d2_next_map] SetNextMapID 无法从 g_sMapsInfo 中找到 MapID");
		g_iMapID = iMapID;
	}
}

bool CheckMapID(int iMapID)
{
	for (int i = 0; i < g_aPlayedMap.Length; i++)
	{
		if (iMapID == g_aPlayedMap.Get(i))
		{
			return false;
		}
	}
	return true;
}

public void OnClientPutInServer(int client)
{
	if (g_bFinalMap)
	{
		if (g_bAnnounceNextMap && !IsFakeClient(client))
		{
			CreateTimer(15.0, Announce_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Announce_Timer(Handle timer, int userid)
{
	if (g_bFinalMap && (g_iMapID != -1))
	{
		int client = GetClientOfUserId(userid);
		if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
		{
			CPrintToChat(client, "{default}[{yellow}提示{default}] 下一张图%s: {blue}%s", (g_bRandomNextMap ? "(随机)" : ""), g_sMapsInfo[g_iMapID][MAP_TRANSLATE]);
		}
	}
	return Plugin_Continue;
}

public void Event_FinaleWin(Event event, char[] name, bool dontBroadcast)
{
	if (g_iMapID == -1)
	{
		LogMessage("获取下一张换图失败，更换到默认地图");
		//SDKCall(g_hChangeLevel, g_pTheDirector, g_sDefNextMap);
		ServerCommand("changelevel %s", g_sDefNextMap);
	}
	else
	{
		//SDKCall(g_hChangeLevel, g_pTheDirector, g_sMapsInfo[g_iMapID][FIRST_MAP]);
		ServerCommand("changelevel %s", g_sMapsInfo[g_iMapID][FIRST_MAP]);
		g_iMapID = -1;
	}
}

public Action CmdNextMap(int client, int args)
{
	if (g_bFinalMap && (g_iMapID != -1))
	{
		CPrintToChatAll("{default}[{yellow}提示{default}] 下一张图%s: {blue}%s", (g_bRandomNextMap ? "(随机)" : ""), g_sMapsInfo[g_iMapID][MAP_TRANSLATE]);
	}
	return Plugin_Handled;
}

public Action CmdSetNextMap(int client, int args)
{
	if (g_bFinalMap)
	{
		SetNextMapID();
		if (g_iMapID != -1)
		{
			CPrintToChatAll("{default}[{yellow}提示{default}] 下一张图%s: {blue}%s", (g_bRandomNextMap ? "(随机)" : ""), g_sMapsInfo[g_iMapID][MAP_TRANSLATE]);
		}
		else PrintToChat(client, "设置下一张地图失败");
	}
	else PrintToChat(client, "不是结局地图，无法设置");
	return Plugin_Handled;
}

int FindMapId(const char[] sMapName, const int type)
{
	for (int i = 0; i < sizeof(g_sMapsInfo); i++)
	{
		if (strcmp(sMapName, g_sMapsInfo[i][type], false) == 0)
		{
			return i;
		}
	}
	return -1;
}

char[] CurrentMap()
{
	static char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return sMapName;
}
