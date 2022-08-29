#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.3"

#include <sourcemod>

#define ONCE 1
#define MANY_TIMES 2

ConVar
	g_cvExecOnce,
	g_cvExecManyTimes;

public Plugin myinfo = 
{
	name = "L4D2 Config execute",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_cfg_execute_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvExecOnce = CreateConVar("l4d2_cfg_execute_once", "", "CFG file to be executed once after server startup. \nUse semicolons to separate multiple files. (search path: left4dead2/cfg)", FCVAR_NONE);
	g_cvExecManyTimes = CreateConVar("l4d2_cfg_execute_manytimes", "", "CFG file executed after each map start.", FCVAR_NONE);

	RegAdminCmd("sm_cfg_exec", Cmd_cfgExec, ADMFLAG_ROOT, "Manually execute");
	AutoExecConfig(true, "l4d2_cfg_execute");
}

Action Cmd_cfgExec(int client, int args)
{
	char sFile[256], sResult[256];
	
	GetCmdArg(1, sFile, sizeof(sFile));
	ServerCommandEx(sResult, sizeof(sResult), "exec %s", sFile);
	if (sResult[0] != '\0')
		LogError("%s", sResult);
	
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	RequestFrame(NextFrame, MANY_TIMES);

	static bool shit;
	if (shit) return;
	shit = true;

	RequestFrame(NextFrame, ONCE);
}

void NextFrame(int iType)
{
	char sBuffer[1024];

	if (iType == MANY_TIMES)
		g_cvExecManyTimes.GetString(sBuffer, sizeof(sBuffer));
	else g_cvExecOnce.GetString(sBuffer, sizeof(sBuffer));

	if (sBuffer[0] == '\0')
		return;

	char sFiles[32][256], sResult[256];
	int pieces = ExplodeString(sBuffer, ";", sFiles, sizeof(sFiles), sizeof(sFiles[]));
	
	for (int i = 0; i < pieces; i++)
	{
		sResult[0] = '\0';
		ServerCommandEx(sResult, sizeof(sResult), "exec %s", sFiles[i]);
		if (sResult[0] != '\0')
			LogError("%s", sResult);
	}
}
