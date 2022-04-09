#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.4"

#include <sourcemod>
#include <multicolors>

ConVar
	g_cvChangedNotify,
	g_cvJoinNotify,
	g_cvMaxSpecials,
	g_cvSpawnTime;

bool
	g_bChangedNotify,
	g_bJoinNotify;

public Plugin myinfo = 
{
	name = "L4D2 Mode announce",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	g_cvChangedNotify = CreateConVar("l4d2_mode_changed_announce", "1", "当特感配置发生变化的时候通知玩家", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvJoinNotify = CreateConVar("l4d2_mode_join_announce", "0", "玩家进入游戏后通知当前特感配置 (换图后也会通知)", FCVAR_NONE, true, 0.0, true, 1.0);
	
	GetCvars();

	g_cvChangedNotify.AddChangeHook(OnConVarChanged);
	g_cvJoinNotify.AddChangeHook(OnConVarChanged);

	RegConsoleCmd("sm_mode", Cmd_ShowCurMode);
	RegConsoleCmd("sm_mod", Cmd_ShowCurMode);

	AutoExecConfig(true, "l4d2_mode_announce");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bChangedNotify = g_cvChangedNotify.BoolValue;
	g_bJoinNotify = g_cvJoinNotify.BoolValue;
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	g_cvMaxSpecials = FindConVar("l4d2_si_spawn_control_max_specials");
	g_cvSpawnTime = FindConVar("l4d2_si_spawn_control_spawn_time");

	if (g_cvMaxSpecials == null)
		SetFailState("l4d2_si_spawn_control plugin not loaded?");

	g_cvMaxSpecials.AddChangeHook(OnSpecialsChanged);
	g_cvSpawnTime.AddChangeHook(OnSpecialsChanged);
}

void OnSpecialsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{	
	if (g_bChangedNotify)
	{
		CreateTimer(0.2, Notify_Timer, -1, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Cmd_ShowCurMode(int client, int args)
{
	if (IsRealClient(client)) Notify();
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if (g_bJoinNotify && IsRealClient(client))
	{
		CreateTimer(5.0, Notify_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Notify_Timer(Handle timer, int userid)
{
	if (userid == -1)
	{
		Notify();
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(userid);
	if (IsRealClient(client)) Notify(client);

	return Plugin_Continue;
}

void Notify(int client = -1)
{
	if (client > 0)
		CPrintToChat(client, "{default}[{yellow}提示{default}] 当前模式: {yellow}%i {default}特 {yellow}%.0f {default}秒", g_cvMaxSpecials.IntValue, g_cvSpawnTime.FloatValue);
	else CPrintToChatAll("{default}[{yellow}提示{default}] 当前模式: {yellow}%i {default}特 {yellow}%.0f {default}秒", g_cvMaxSpecials.IntValue, g_cvSpawnTime.FloatValue);
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}
