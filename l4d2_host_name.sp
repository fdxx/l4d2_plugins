#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "1.3"

ConVar
	g_cvHostName,
	g_cvDynamicName,
	g_cvMaxSpecial,
	g_cvSpawnTime;

char
	g_sHostName[256];

bool
	g_bDynamicName;

public Plugin myinfo = 
{
	name = "L4D2 host name",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	GetCustomHostName();

	CreateConVar("l4d2_host_name_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvHostName = FindConVar("hostname");
	g_cvDynamicName = CreateConVar("l4d2_dynamic_host_name", "1", "Add special infected configure to host name.", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_bDynamicName = g_cvDynamicName.BoolValue;
	g_cvDynamicName.AddChangeHook(OnConVarChanged);

	RegConsoleCmd("sm_curhostname", Cmd_GetCurHostName);

	AutoExecConfig(true, "l4d2_host_name");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bDynamicName = g_cvDynamicName.BoolValue;
}

void GetCustomHostName()
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "data/hostname.txt");

	if (!FileExists(sFilePath))
		SetFailState("Failed to read hostname.txt");

	File hFile = OpenFile(sFilePath, "r");
	if (hFile == null)
		SetFailState("Failed to read hostname.txt");

	if (!hFile.ReadLine(g_sHostName, sizeof(g_sHostName)))
		SetFailState("Failed to read hostname.txt");
	
	delete hFile;
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	if (g_bDynamicName)
	{
		g_cvMaxSpecial = FindConVar("l4d2_si_spawn_control_max_specials");
		g_cvSpawnTime = FindConVar("l4d2_si_spawn_control_spawn_time");

		if (g_cvMaxSpecial == null)
			SetFailState("l4d2_si_spawn_control plugin not loaded?");
		
		g_cvMaxSpecial.AddChangeHook(OnSpecialsChanged);
		g_cvSpawnTime.AddChangeHook(OnSpecialsChanged);
	}

	SetHostName();
}

void OnSpecialsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetHostName();
}

void SetHostName()
{
	if (g_bDynamicName)
	{
		static char sName[256];
		FormatEx(sName, sizeof(sName), "%s[%i特%.0f秒]", g_sHostName, g_cvMaxSpecial.IntValue, g_cvSpawnTime.FloatValue);
		g_cvHostName.SetString(sName);
	}
	else g_cvHostName.SetString(g_sHostName);
}

Action Cmd_GetCurHostName(int client, int args)
{
	char sName[256];
	g_cvHostName.GetString(sName, sizeof(sName));
	ReplyToCommand(client, "Name: %s", sName);
	return Plugin_Handled;
}
