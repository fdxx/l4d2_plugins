#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "1.2"

ConVar CvarDynamicName;
ConVar HostNameCvar, CvarMaxSpecial, CvarSpecialSpawnTime;
char g_sHostName[256];
bool g_bDynamicName;

public Plugin myinfo = 
{
	name = "L4D2 host name",
	author = "fdxx",
	description = "",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	CreateConVar("l4d2_host_name_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	CvarDynamicName = CreateConVar("l4d2_dynamic_host_name", "1", "将特感配置添加到服务器名字", FCVAR_NONE, true, 0.0, true, 1.0);
	g_bDynamicName = CvarDynamicName.BoolValue;
	CvarDynamicName.AddChangeHook(ConVarChanged);

	RegConsoleCmd("sm_curhostname", curhostname);
	GetCustomHostName();

	AutoExecConfig(true, "l4d2_host_name");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bDynamicName = CvarDynamicName.BoolValue;
}

void GetCustomHostName()
{
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "data/hostname.txt");

	if (FileExists(sFilePath))
	{
		File file = OpenFile(sFilePath, "r");

		if (file != null)
		{
			if (!file.ReadLine(g_sHostName, sizeof(g_sHostName)))
				SetFailState("读取 hostname.txt 失败");
		}
		else SetFailState("读取 hostname.txt 失败");
		
		delete file;
	}
	else SetFailState("读取 hostname.txt 失败");
}

public void OnConfigsExecuted()
{
	static bool bProcessed;

	if (!bProcessed)
	{
		HostNameCvar = FindConVar("hostname");

		if (HostNameCvar != null)
		{
			if (g_bDynamicName)
			{
				CvarMaxSpecial = FindConVar("l4d2_si_spawn_control_max_specials");
				CvarSpecialSpawnTime = FindConVar("l4d2_si_spawn_control_spawn_time");

				if (CvarMaxSpecial != null)
				{
					CvarMaxSpecial.AddChangeHook(SpecialsChanged);
					CvarSpecialSpawnTime.AddChangeHook(SpecialsChanged);
					SetHostName();
				}
				else SetFailState("l4d2_si_spawn_control plugin not loaded?"); 
			}
			else SetHostName();
		}
		else SetFailState("Not find hostname ConVar");

		bProcessed = true;
	}
}

public void SpecialsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetHostName();
}

void SetHostName()
{
	if (g_bDynamicName)
	{
		char sName[256];
		Format(sName, sizeof(sName), "%s[%i特%.0f秒]", g_sHostName, CvarMaxSpecial.IntValue, CvarSpecialSpawnTime.FloatValue);
		HostNameCvar.SetString(sName);
	}
	else HostNameCvar.SetString(g_sHostName);
}

public Action curhostname(int client, int args)
{
	char sName[256];
	HostNameCvar.GetString(sName, sizeof(sName));
	ReplyToCommand(client, "Name: %s", sName);
}

