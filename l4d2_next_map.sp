#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>  
#include <left4dhooks>

#define VERSION "1.6"

enum
{
	FIRST,
	FINAL,
	TRANSLATE,
}

char g_sMapsInfo[][][] =
{
	{"c1m1_hotel",			"c1m4_atrium",			"C1 死亡中心"},
	{"c2m1_highway",		"c2m5_concert",			"C2 黑色嘉年华"},
	{"c3m1_plankcountry",	"c3m4_plantation",		"C3 沼泽激战"},
	{"c4m1_milltown_a",		"c4m5_milltown_escape",	"C4 暴风骤雨"},
	{"c5m1_waterfront",		"c5m5_bridge",			"C5 教区"},
	{"c6m1_riverbank",		"c6m3_port",			"C6 短暂时刻"},
	{"c7m1_docks",			"c7m3_port",			"C7 牺牲"},
	{"c8m1_apartment",		"c8m5_rooftop",			"C8 毫不留情"},
	{"c9m1_alleys",			"c9m2_lots",			"C9 坠机险途"},
	{"c10m1_caves",			"c10m5_houseboat",		"C10 死亡丧钟"},
	{"c11m1_greenhouse",	"c11m5_runway",			"C11 寂静时分"},
	{"c12m1_hilltop",		"c12m5_cornfield",		"C12 血腥收获"},
	{"c13m1_alpinecreek",	"c13m4_cutthroatcreek",	"C13 刺骨寒溪"},
	{"c14m1_junkyard",		"c14m2_lighthouse",		"C14 临死一搏"},
};

ArrayList g_aRawMaps, g_aMaps;
StringMap g_smTranslate, g_smFinalToFirst;
char g_sNextMap[128], g_sNextMapTranslate[128];
bool g_bFinalMap;

public Plugin myinfo =
{
	name = "L4D2 Next Map",
	description = "When the end of finale chapter, map will be changed automatically. (Random)",
	author = "pan0s, fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_next_map_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_view_nextmap", Cmd_ViewNextMap);
	RegAdminCmd("sm_set_nextmap", Cmd_SetNextMap, ADMFLAG_ROOT);
}

void Init()
{
	g_aRawMaps = new ArrayList(ByteCountToCells(128));
	g_smTranslate = new StringMap();
	g_smFinalToFirst = new StringMap();

	for (int i; i < sizeof(g_sMapsInfo); i++)
	{
		g_aRawMaps.PushString(g_sMapsInfo[i][FIRST]);
		g_smTranslate.SetString(g_sMapsInfo[i][FIRST], g_sMapsInfo[i][TRANSLATE]);
		g_smFinalToFirst.SetString(g_sMapsInfo[i][FINAL], g_sMapsInfo[i][FIRST]);
	}

	g_aMaps = g_aRawMaps.Clone();
}

Action Cmd_ViewNextMap(int client, int args)
{
	if (g_bFinalMap)
		CPrintToChatAll("{blue}[提示] {olive}下一张图: {yellow}%s", g_sNextMapTranslate);
	return Plugin_Handled;
}

Action Cmd_SetNextMap(int client, int args)
{
	if (!g_bFinalMap || args != 1)
		return Plugin_Handled;

	char sBuffer[128];
	GetCmdArg(1, sBuffer, sizeof(sBuffer));
	if (!IsMapValid(sBuffer))
		return Plugin_Handled;

	strcopy(g_sNextMap, sizeof(g_sNextMap), sBuffer);
	strcopy(g_sNextMapTranslate, sizeof(g_sNextMapTranslate), g_sNextMap);
	g_smTranslate.GetString(g_sNextMap, g_sNextMapTranslate, sizeof(g_sNextMapTranslate));
	ReplyToCommand(client, "设置下一张地图: %s (%s)", g_sNextMap, g_sNextMapTranslate);
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	if (!L4D2_IsGenericCooperativeMode())
		LogError("不支持的游戏模式");
}

public void OnMapStart()
{
	CreateTimer(0.1, OnMapStart_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action OnMapStart_Timer(Handle timer)
{
	g_bFinalMap = L4D_IsMissionFinalMap();

	if (L4D_IsFirstMapInScenario())
	{
		RemovePlayedMap(CurrentMap());
	}
	
	if (g_bFinalMap)
	{
		SetupNextMap(CurrentMap());
		CreateTimer(20.0, Notify_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

void RemovePlayedMap(const char[] sMap)
{
	int index = g_aMaps.FindString(sMap);
	if (index != -1)
		g_aMaps.Erase(index);
}

void SetupNextMap(const char[] sMap)
{
	char sFirstMap[128];
	g_smFinalToFirst.GetString(sMap, sFirstMap, sizeof(sFirstMap));
	RemovePlayedMap(sFirstMap);

	if (!g_aMaps.Length)
	{
		delete g_aMaps;
		g_aMaps = g_aRawMaps.Clone();
		RemovePlayedMap(sFirstMap);
	}

	g_aMaps.Sort(Sort_Random, Sort_String);
	int index = GetRandomIntEx(0, g_aMaps.Length-1);
	g_aMaps.GetString(index, g_sNextMap, sizeof(g_sNextMap));
	g_smTranslate.GetString(g_sNextMap, g_sNextMapTranslate, sizeof(g_sNextMapTranslate));
}

Action Notify_Timer(Handle timer)
{
	if (g_bFinalMap)
		CPrintToChatAll("{blue}[提示] {olive}下一张图: {yellow}%s", g_sNextMapTranslate);	
	return Plugin_Continue;
}

void Event_FinaleWin(Event event, char[] name, bool dontBroadcast)
{
	ServerCommand("changelevel %s", g_sNextMap);
}

char[] CurrentMap()
{
	static char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	return sMapName;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
int GetRandomIntEx(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}
