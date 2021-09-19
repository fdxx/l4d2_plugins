#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.3"

ConVar CvarDelayTime;
char g_LogPath[PLATFORM_MAX_PATH];
float g_fDelayTime;

public Plugin myinfo =
{
	name = "L4D2 Auto restart",
	author = "Dragokas, Harry Potter, fdxx",
	description = "Auto restart server when the last player disconnects from the server. Only support Linux system",
	version = VERSION,
	url	= ""
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_LogPath, sizeof(g_LogPath), "logs/Restart.log");

	CreateConVar("l4d2_auto_restart_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);
	CvarDelayTime = CreateConVar("l4d2_auto_restart_delay", "30.0", "Restart grace period (in sec.)", FCVAR_NOTIFY);
	g_fDelayTime = CvarDelayTime.FloatValue;
	CvarDelayTime.AddChangeHook(ConVarChanged);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	AutoExecConfig(true, "l4d2_auto_restart");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fDelayTime = CvarDelayTime.FloatValue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client == 0 || !IsFakeClient(client))
	{
		if (!HaveRealPlayer(client))
		{
			ServerCommand("sm_cvar sb_all_bot_game 1");
			ServerCommand("sm_cvar sv_hibernate_when_empty 0");
			CreateTimer(g_fDelayTime, RestServer_Timer);
			LogToFileEx(g_LogPath, "服务器即将重启");
		}
	}
	return Plugin_Continue;
}

public Action RestServer_Timer(Handle timer)
{
	if (!HaveRealPlayer())
	{
		UnloadAccelerator();
		LogToFileEx(g_LogPath, "空服后重启成功");
		SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
		ServerCommand("crash");
	}
	else LogToFileEx(g_LogPath, "服务器重启失败，还有真实玩家");
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

