#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "0.5"

#define RM_CRASH_CMD 1
#define RM_EXIT 2

ConVar
	sv_hibernate_when_empty,
	sb_all_bot_game,
	g_cvDelayTime,
	g_cvMethod,
	g_cvExitCode;

Handle g_hExitProcess;

public Plugin myinfo =
{
	name = "L4D2 Auto restart",
	author = "Dragokas, Harry Potter, fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	Init();

	sv_hibernate_when_empty = FindConVar("sv_hibernate_when_empty");
	sb_all_bot_game = FindConVar("sb_all_bot_game");

	CreateConVar("l4d2_auto_restart_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvDelayTime = CreateConVar("l4d2_auto_restart_delay", "30.0", "Restart grace period (in sec.)");
	g_cvMethod = CreateConVar("l4d2_auto_restart_method", "1", "Restart method. 1=crash command, 2=Exit");
	g_cvExitCode = CreateConVar("l4d2_auto_restart_exitcode", "60", "if method is Exit, what is the exitcode?");

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	RegAdminCmd("sm_restart_server", Cmd_RestartServer, ADMFLAG_ROOT);

	// AutoExecConfig(true, "l4d2_auto_restart");
}

Action Cmd_RestartServer(int client, int args)
{
	RestartServer();
	return Plugin_Handled;
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == 0 || !IsFakeClient(client))
	{
		char sNetworkid[4];
		event.GetString("networkid", sNetworkid, sizeof(sNetworkid));
		if (!strcmp(sNetworkid, "BOT", false)) 
			return;
			
		if (!HaveRealPlayer(client))
		{
			sv_hibernate_when_empty.IntValue = 0;
			sb_all_bot_game.IntValue = 1;
			CreateTimer(g_cvDelayTime.FloatValue, RestServer_Timer);
			LogToFilePlus("Server has no more real players, restart the server after %.1f seconds.", g_cvDelayTime.FloatValue);
		}
	}
}

Action RestServer_Timer(Handle timer)
{
	if (!HaveRealPlayer())
	{
		LogToFilePlus("Auto restart the server...");
		RestartServer();
	}
	else
		LogToFilePlus("Server restart failed, there are still real players.");

	return Plugin_Continue;
}

void RestartServer()
{
	UnloadAccelerator();

	if (g_cvMethod.IntValue == RM_CRASH_CMD)
	{
		SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
		ServerCommand("crash");
	}
	else if (g_cvMethod.IntValue == RM_EXIT)
	{
		SDKCall(g_hExitProcess, g_cvExitCode.IntValue);
	}
}

bool HaveRealPlayer(int iExclude = 0)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != iExclude && IsClientConnected(i) && !IsFakeClient(i))
		{
			return true;
		}
	}
	return false;
}

void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();
	}
}

//by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}

void LogToFilePlus(const char[] sMsg, any ...)
{
	static char sDate[32], sLogPath[PLATFORM_MAX_PATH];
	static char sBuffer[256];

	FormatTime(sDate, sizeof(sDate), "%Y%m%d");
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), "logs/%s_logging.log", sDate);
	VFormat(sBuffer, sizeof(sBuffer), sMsg, 2);

	LogToFileEx(sLogPath, "%s", sBuffer);
}

void Init()
{
	char buffer[128];

	strcopy(buffer, sizeof(buffer), "l4d2_auto_restart");
	GameData hGameData = new GameData(buffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", buffer);

	strcopy(buffer, sizeof(buffer), "Sys_Error_Internal::Plat_ExitProcess");
	Address	addr = hGameData.GetAddress(buffer);
	if (addr == Address_Null || LoadFromAddress(addr, NumberType_Int8) != 0xE8)
		SetFailState("Failed to GetAddress: %s", buffer);

	Address pRelativeOffset = LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32);
	addr = addr + view_as<Address>(5) + pRelativeOffset;

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetAddress(addr);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hExitProcess = EndPrepSDKCall();
	if(g_hExitProcess == null)
		SetFailState("Failed to create SDKCall: %s", buffer);

	delete hGameData;
}
