#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>  

#define VERSION "0.3"
#define CFG_PATH "data/server_info.cfg"

#define AD_SEQUENTIAL	0
#define AD_RANDOM		1

ConVar g_cvPrintType, g_cvTime;
ArrayList g_aAdList;
Handle g_hTimer;
int g_iPrintType;
float g_fTime;

public Plugin myinfo = 
{
	name = "L4D2 Advertisements",
	author = "Tsunami, fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	LoadAdvertisements();

	CreateConVar("l4d2_advertisements_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvPrintType = CreateConVar("l4d2_advertisements_type", "0", "Print type. 0=Sequential，1=Random");
	g_cvTime = CreateConVar("l4d2_advertisements_time", "360.0", "Print interval time");

	OnConVarChanged(null, "", "");

	g_cvPrintType.AddChangeHook(OnConVarChanged);
	g_cvTime.AddChangeHook(OnConVarChanged);

	RegConsoleCmd("sm_adlist", Cmd_CheckAdList);
	RegAdminCmd("sm_adreload", Cmd_AdReload, ADMFLAG_ROOT);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iPrintType = g_cvPrintType.IntValue;
	g_fTime = g_cvTime.FloatValue;

	delete g_hTimer;
	if (g_fTime >= 0.1)
		g_hTimer = CreateTimer(g_fTime, PrintAd_Timer, _, TIMER_REPEAT);
}

void LoadAdvertisements()
{
	char sBuffer[MAX_MESSAGE_LENGTH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), CFG_PATH);

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

	static char sBuffer[MAX_MESSAGE_LENGTH];
	g_aAdList.GetString(GetIndex(), sBuffer, sizeof(sBuffer));
	ReplaceString(sBuffer, sizeof(sBuffer), "{time}", GetCurTime());
	CPrintToChatAll("%s", sBuffer);

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

char[] GetCurTime()
{
	static char sTime[64];
	FormatTime(sTime, sizeof(sTime), "%F %T");
	return sTime;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
int GetRandomIntEx(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

Action Cmd_CheckAdList(int client, int args)
{
	if (!g_aAdList || !g_aAdList.Length)
		return Plugin_Handled;

	static char sBuffer[MAX_MESSAGE_LENGTH];
	for (int i = 0; i < g_aAdList.Length; i++)
	{
		g_aAdList.GetString(i, sBuffer, sizeof(sBuffer));
		ReplaceString(sBuffer, sizeof(sBuffer), "{time}", GetCurTime());
		CPrintToChatAll("%s", sBuffer);
	}

	return Plugin_Handled;
}

Action Cmd_AdReload(int client, int args)
{
	LoadAdvertisements();
	Cmd_CheckAdList(0,0);
	return Plugin_Handled;
}
