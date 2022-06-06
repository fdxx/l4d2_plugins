#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.1"

#include <sourcemod>

ConVar
	fps_max,
	sv_minrate,
	sv_maxrate,
	sv_minupdaterate,
	sv_maxupdaterate,
	sv_mincmdrate,
	sv_maxcmdrate,
	sv_client_min_interp_ratio,
	sv_client_max_interp_ratio,
	nb_update_frequency,
	net_maxcleartime,
	net_splitpacket_maxrate,
	net_splitrate,
	sv_gravity;

int
	g_iTick;

public Plugin myinfo = 
{
	name = "L4D2 tick settings",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	g_iTick = GetCommandLineParamInt("-tickrate");
	if (g_iTick == 0)
		SetFailState("tickrate parameter not found!");

	CreateConVar("l4d2_tick_settings_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);

	fps_max = FindConVar("fps_max");
	sv_minrate = FindConVar("sv_minrate");
	sv_maxrate = FindConVar("sv_maxrate");
	sv_minupdaterate = FindConVar("sv_minupdaterate");
	sv_maxupdaterate = FindConVar("sv_maxupdaterate");
	sv_mincmdrate = FindConVar("sv_mincmdrate");
	sv_maxcmdrate = FindConVar("sv_maxcmdrate");
	sv_client_min_interp_ratio = FindConVar("sv_client_min_interp_ratio");
	sv_client_max_interp_ratio = FindConVar("sv_client_max_interp_ratio");
	nb_update_frequency = FindConVar("nb_update_frequency");
	net_maxcleartime = FindConVar("net_maxcleartime");
	net_splitpacket_maxrate = FindConVar("net_splitpacket_maxrate");
	net_splitrate = FindConVar("net_splitrate");
	sv_gravity = FindConVar("sv_gravity");

	RegConsoleCmd("sm_tick_cvar", Cmd_PrintCvar);
	RegConsoleCmd("sm_tickcvar", Cmd_PrintCvar);
	RegConsoleCmd("sm_cvar_tick", Cmd_PrintCvar);
}

public void OnConfigsExecuted()
{
	CreateTimer(0.1, Timer);
}

// https://forums.alliedmods.net/showthread.php?p=2643551
Action Timer(Handle timer)
{
	fps_max.IntValue = 0;

	sv_minrate.IntValue = g_iTick * 1000;
	sv_maxrate.IntValue = g_iTick * 1000;

	sv_minupdaterate.IntValue = g_iTick;
	sv_maxupdaterate.IntValue = g_iTick;

	sv_mincmdrate.IntValue = g_iTick;
	sv_maxcmdrate.IntValue = g_iTick;

	sv_client_min_interp_ratio.IntValue = -1;
	sv_client_max_interp_ratio.IntValue = 2;

	nb_update_frequency.FloatValue = 0.024;
	net_maxcleartime.FloatValue = 0.00001;
	net_splitpacket_maxrate.IntValue = g_iTick/2 * 1000;
	net_splitrate.IntValue = 2;

	// https://github.com/Derpduck/L4D2-Comp-Stripper-Rework/issues/35
	sv_gravity.IntValue = 750;
	
	return Plugin_Continue;
}

Action Cmd_PrintCvar(int client, int args)
{
	ReplyToCommand(client, "tickrate = %i", g_iTick);
	ReplyToCommand(client, "fps_max = %i", fps_max.IntValue);
	ReplyToCommand(client, "sv_minrate = %i", sv_minrate.IntValue);
	ReplyToCommand(client, "sv_maxrate = %i", sv_maxrate.IntValue);
	ReplyToCommand(client, "sv_minupdaterate = %i", sv_minupdaterate.IntValue);
	ReplyToCommand(client, "sv_maxupdaterate = %i", sv_maxupdaterate.IntValue);
	ReplyToCommand(client, "sv_mincmdrate = %i", sv_mincmdrate.IntValue);
	ReplyToCommand(client, "sv_maxcmdrate = %i", sv_maxcmdrate.IntValue);
	ReplyToCommand(client, "sv_client_min_interp_ratio = %i", sv_client_min_interp_ratio.IntValue);
	ReplyToCommand(client, "sv_client_max_interp_ratio = %i", sv_client_max_interp_ratio.IntValue);
	ReplyToCommand(client, "nb_update_frequency = %f", nb_update_frequency.FloatValue);
	ReplyToCommand(client, "net_maxcleartime = %f", net_maxcleartime.FloatValue);
	ReplyToCommand(client, "net_splitpacket_maxrate = %i", net_splitpacket_maxrate.IntValue);
	ReplyToCommand(client, "net_splitrate = %i", net_splitrate.IntValue);
	ReplyToCommand(client, "sv_gravity = %i", sv_gravity.IntValue);

	return Plugin_Handled;
}