#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

ConVar CvarChangedAnnounce, CvarJoinAnnounce;
ConVar CvarMaxSpecials, CvarSpecialSpawnTime;
bool g_bChangedAnnounce, g_bJoinAnnounce;

public Plugin myinfo = 
{
	name = "L4D2 Mode announce",
	author = "fdxx",
	description = "宣布当前特感配置",
	version = "0.2",
	url = ""
}

public void OnPluginStart()
{
	CvarChangedAnnounce = CreateConVar("l4d2_mode_changed_announce", "1", "当特感配置发生变化的时候通知玩家", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarJoinAnnounce = CreateConVar("l4d2_mode_join_announce", "0", "玩家进入游戏后通知当前特感配置 (换图后也会通知)", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_bChangedAnnounce = CvarChangedAnnounce.BoolValue;
	g_bJoinAnnounce = CvarJoinAnnounce.BoolValue;

	CvarChangedAnnounce.AddChangeHook(ConVarChanged);
	CvarJoinAnnounce.AddChangeHook(ConVarChanged);

	RegConsoleCmd("sm_mode", ShowCurSIMode);
	RegConsoleCmd("sm_mod", ShowCurSIMode);

	AutoExecConfig(true, "l4d2_mode_announce");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bChangedAnnounce = CvarChangedAnnounce.BoolValue;
	g_bJoinAnnounce = CvarJoinAnnounce.BoolValue;
}

public void OnConfigsExecuted()
{
	static bool bProcessed;

	if (!bProcessed)
	{
		CvarMaxSpecials = FindConVar("l4d2_si_spawn_control_max_specials");
		CvarSpecialSpawnTime = FindConVar("l4d2_si_spawn_control_spawn_time");

		if (CvarMaxSpecials != null)
		{
			CvarMaxSpecials.AddChangeHook(SpecialsChanged);
			CvarSpecialSpawnTime.AddChangeHook(SpecialsChanged);
		}
		else SetFailState("l4d2_si_spawn_control plugin not loaded?");

		bProcessed = true;
	}
}

public void SpecialsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{	
	if (g_bChangedAnnounce)
	{
		CreateTimer(0.2, bAnnounce_Timer);
	}
}

public Action bAnnounce_Timer(Handle timer)
{
	AnnounceCurSIMode_All();
	return Plugin_Continue;
}

public Action ShowCurSIMode(int client, int args)
{
	if (IsRealClient(client)) AnnounceCurSIMode_All();
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if (g_bJoinAnnounce && IsRealClient(client))
	{
		CreateTimer(5.0, ShowCurSIMode_Timer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ShowCurSIMode_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsRealClient(client)) AnnounceCurSIMode(client);
	return Plugin_Continue;
}

void AnnounceCurSIMode_All()
{
	CPrintToChatAll("{default}[{yellow}提示{default}] 当前模式: {yellow}%i {default}特 {yellow}%.0f {default}秒", CvarMaxSpecials.IntValue, CvarSpecialSpawnTime.FloatValue);
}

void AnnounceCurSIMode(int client)
{
	CPrintToChat(client, "{default}[{yellow}提示{default}] 当前模式: {yellow}%i {default}特 {yellow}%.0f {default}秒", CvarMaxSpecials.IntValue, CvarSpecialSpawnTime.FloatValue);
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}
