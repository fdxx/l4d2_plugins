#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

char g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "Server restart notif",
	author = "fdxx",
	description = "",
	version = "0.2",
	url = ""
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/server_restart_notif.log");
	RegConsoleCmd("sm_curtime", Cmd_CurTime);
	CreateTimer(50.0, Notif_Timer, _, TIMER_REPEAT);
}

public Action Notif_Timer(Handle timer)
{
	if (GetCurHour() == 4)
	{
		if (57 <= GetCurMinute() <= 59)
		{
			if (IsHavePlayer())
			{
				CPrintToChatAll("{default}[{red}警告{default}] 服务器将在: 05:01:00 自动重启, 当前时间: %s", GetCurTime());
				CPrintToChatAll("{default}[{red}警告{default}] 服务器将在: 05:01:00 自动重启, 当前时间: %s", GetCurTime());
				CPrintToChatAll("{default}[{red}警告{default}] 服务器将在: 05:01:00 自动重启, 当前时间: %s", GetCurTime());

				LogToFileEx(g_sLogPath, "已通知服务器即将重启，当前时间: %s", GetCurTime());

				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}

bool IsHavePlayer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			return true;
		}
	}
	return false;
}

public Action Cmd_CurTime(int client, int args)
{
	ReplyToCommand(client, "当前时间: %s, 小时: %i, 分钟: %i, 秒: %i", GetCurTime(), GetCurHour(), GetCurMinute(), GetCurSecond());
}

int GetCurHour()
{
	static char sHour[32];
	FormatTime(sHour, sizeof(sHour), "%H");
	return StringToInt(sHour);
}

int GetCurMinute()
{
	static char sMinute[32];
	FormatTime(sMinute, sizeof(sMinute), "%M");
	return StringToInt(sMinute);
}

int GetCurSecond()
{
	static char sSecond[32];
	FormatTime(sSecond, sizeof(sSecond), "%S");
	return StringToInt(sSecond);
}

char GetCurTime()
{
	static char sTime[32];
	FormatTime(sTime, sizeof(sTime), "%T");
	return sTime;
}
