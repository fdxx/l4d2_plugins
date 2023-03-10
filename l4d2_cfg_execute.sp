#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.5"
#define FILE_PATH "sourcemod/l4d2_cfg_execute_once.cfg" // Relative to the cfg folder.

public Plugin myinfo = 
{
	name = "L4D2 Config execute",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_cfg_execute_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
}

public void OnAutoConfigsBuffered()
{
	static bool shit;
	if (shit) return;
	shit = true;

	char sBuffer[PLATFORM_MAX_PATH];
	FormatEx(sBuffer, PLATFORM_MAX_PATH, "cfg/%s", FILE_PATH);

	if (FileExists(sBuffer))
	{
		ServerCommand("exec %s", FILE_PATH);
		ServerExecute();
	}
	else
		LogError("%s file does not exist", FILE_PATH);
}
