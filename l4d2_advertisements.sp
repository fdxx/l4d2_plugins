#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>  

#define VERSION "0.4"
#define CFG_PATH "data/server_info.cfg"

#define AD_SEQUENTIAL	0
#define AD_RANDOM		1

ConVar g_cvPrintType, g_cvTime, g_cvCfgPath;
ArrayList g_aAdList;
Handle g_hTimer;
int g_iPrintType;
float g_fTime;
char g_sCfgPath[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "L4D2 Advertisements",
	author = "Tsunami, fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_advertisements_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvPrintType = CreateConVar("l4d2_advertisements_type", "0", "Print type. 0=Sequential, 1=Random");
	g_cvTime = CreateConVar("l4d2_advertisements_time", "360.0", "Print interval time");
	g_cvCfgPath = CreateConVar("l4d2_advertisements_cfg", CFG_PATH, "config file path");

	OnConVarChanged(null, "", "");

	g_cvPrintType.AddChangeHook(OnConVarChanged);
	g_cvTime.AddChangeHook(OnConVarChanged);
	g_cvCfgPath.AddChangeHook(OnConVarChanged);

	RegConsoleCmd("sm_adlist", Cmd_CheckAdList);
	RegAdminCmd("sm_adreload", Cmd_AdReload, ADMFLAG_ROOT);

	CreateTimer(2.0, Init_Timer);
}

Action Init_Timer(Handle timer)
{
	LoadAdvertisements();
	return Plugin_Continue;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iPrintType = g_cvPrintType.IntValue;
	g_fTime = g_cvTime.FloatValue;
	g_cvCfgPath.GetString(g_sCfgPath, sizeof(g_sCfgPath));

	if (convar == g_cvCfgPath)
		LoadAdvertisements();

	delete g_hTimer;
	if (g_fTime >= 0.1)
		g_hTimer = CreateTimer(g_fTime, PrintAd_Timer, _, TIMER_REPEAT);
}

void LoadAdvertisements()
{
	char sBuffer[MAX_MESSAGE_LENGTH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "%s", g_sCfgPath);

	KeyValues kv = new KeyValues("");
	kv.SetEscapeSequences(true); // Allow newline characters to be read.

	if (!kv.ImportFromFile(sBuffer))
		SetFailState("Failed to load: %s", sBuffer);

	FindConVar("hostport").GetString(sBuffer, sizeof(sBuffer)); // Get config by port
	Format(sBuffer, sizeof(sBuffer), "%s/advertisements", sBuffer);

	if (kv.JumpToKey(sBuffer) && kv.GotoFirstSubKey(false))
	{
		delete g_aAdList;
		g_aAdList = new ArrayList(ByteCountToCells(MAX_MESSAGE_LENGTH));

		do
		{
			kv.GetString(NULL_STRING, sBuffer, sizeof(sBuffer));
			g_aAdList.PushString(sBuffer);
		}
		while (kv.GotoNextKey(false));
	}

	delete kv;
}

Action PrintAd_Timer(Handle timer)
{	
	if (!g_aAdList || !g_aAdList.Length)
		return Plugin_Continue;

	char buffer[MAX_MESSAGE_LENGTH];
	char time[128];
	FormatTime(time, sizeof(time), "%F %T");

	g_aAdList.GetString(GetIndex(), buffer, sizeof(buffer));
	ReplaceString(buffer, sizeof(buffer), "{time}", time);
	CPrintToChatAll("%s", buffer);

	return Plugin_Continue;
}

int GetIndex()
{
	if (g_iPrintType == AD_RANDOM)
		return GetRandomIntEx(0, g_aAdList.Length-1);

	if (g_iPrintType == AD_SEQUENTIAL)
	{
		static int index = -1;
		if (++index >= g_aAdList.Length)
			index = 0;
		return index;
	}

	return -1;
}

int GetRandomIntEx(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

Action Cmd_CheckAdList(int client, int args)
{
	if (!g_aAdList || !g_aAdList.Length)
		return Plugin_Handled;

	char buffer[MAX_MESSAGE_LENGTH];
	char time[128];
	FormatTime(time, sizeof(time), "%F %T");

	for (int i = 0; i < g_aAdList.Length; i++)
	{
		g_aAdList.GetString(i, buffer, sizeof(buffer));
		ReplaceString(buffer, sizeof(buffer), "{time}", time);
		CPrintToChatAll("%s", buffer);
	}

	return Plugin_Handled;
}

Action Cmd_AdReload(int client, int args)
{
	LoadAdvertisements();
	Cmd_CheckAdList(0,0);
	return Plugin_Handled;
}
