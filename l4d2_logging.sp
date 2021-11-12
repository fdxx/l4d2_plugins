#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "2.0.5"

// 忽略的命令
static const char g_sIgnoredCmds[][] =
{
	"+lookatweapon",
	"-lookatweapon",
	"snd_setsoundparam",
	"vmodenable",
	"vban",
	"menuopen",
	"menuclosed",
	"menuselect",
	"voicemenu",
	"unpause",
	"spec_next",
	"z_spawn_old",
	"setpause",
	"vocalize",
	"choose_closedoor",
	"choose_opendoor",
	"spec_prev",
	"spec_mode",
	"setupslot",
	"nb_assault",
	"give",
	"wait",
};

public Plugin myinfo =
{
	name = "L4D2 Logging",
	author = "Franc1sco franug, fdxx", 
	description = "", 
	version = VERSION, 
	url = "https://github.com/Franc1sco/Commands-Logger/blob/master/logcommands.sp"
};

public void OnPluginStart()
{
	CreateConVar("l4d2_logging_version", VERSION, "插件版本", FCVAR_NONE | FCVAR_DONTRECORD);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);

	AddCommandListener(CommandListener);

	LogToFilePlus("====================   OnPluginStart   ====================");
}

public void OnPluginEnd()
{
	LogToFilePlus("====================   OnPluginEnd   ====================");
}

public Action CommandListener(int client, const char[] command, int argc)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (!IsIgnoredCmd(command))
		{
			static char sCmdArgs[256];
			if (argc > 0) GetCmdArgString(sCmdArgs, sizeof(sCmdArgs));
			LogToFilePlus("%L used: %s %s", client, command, (argc > 0 ? sCmdArgs : ""));
		}
	}
	return Plugin_Continue;
}

bool IsIgnoredCmd(const char[] sCommand)
{
	for (int i = 0; i < sizeof(g_sIgnoredCmds); i++)
	{
		if (strcmp(g_sIgnoredCmds[i], sCommand, false) == 0)
		{
			return true;
		}
	}
	return false;
}

public void OnClientConnected(int client)
{
	if (!IsFakeClient(client))
	{
		LogToFilePlus("%L 正在加入游戏..", client);
	}
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients && !IsFakeClient(client))
	{
		static char sReason[128];
		event.GetString("reason", sReason, sizeof(sReason));
		LogToFilePlus("%L 已离开游戏(%s)", client, sReason);
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	static char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	LogToFilePlus("---> %s MapStart <---", sMapName);
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	LogToFilePlus("---> MapTransition <---");
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
	LogToFilePlus("---> MissionLost <---");
}

public void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	LogToFilePlus("---> FinaleWin <---");
}

void LogToFilePlus(const char[] sMsg, any ...)
{
	static char sDate[32], sLogPath[PLATFORM_MAX_PATH];
	static char sBuffer[256];

	FormatTime(sDate, sizeof(sDate), "%Y%m%d");
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), "logs/%s_logging.log", sDate);
	VFormat(sBuffer, sizeof(sBuffer), sMsg, 2);

	LogToFileEx(sLogPath, sBuffer);
}
