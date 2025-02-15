#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "0.4"

ConVar
	fps_max,
	sv_minrate,
	sv_maxrate,
	sv_minupdaterate,
	sv_maxupdaterate,
	sv_mincmdrate,
	sv_maxcmdrate,
	sv_client_cmdrate_difference,
	sv_client_min_interp_ratio,
	sv_client_max_interp_ratio,
	nb_update_frequency,
	net_maxcleartime,
	net_splitpacket_maxrate,
	net_splitrate,
	sv_gravity,
	sv_clockcorrection_msecs,
	sv_forcepreload,
	sv_client_predict;

int g_iTickRate;
float g_fTickInterval;

public Plugin myinfo =
{
	name = "l4d2_tick_network_tweaks",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
};

public void OnPluginStart()
{
	g_iTickRate = GetCommandLineParamInt("-tickrate", 30);
	g_iTickRate = ClampInt(g_iTickRate, 30, 128);
	g_fTickInterval = 1.0 / g_iTickRate;

	CreateConVar("l4d2_tickrate", "", "", FCVAR_NOTIFY|FCVAR_DONTRECORD).IntValue = g_iTickRate; // Expose tickrate to A2S_RULES.
	CreateConVar("l4d2_tick_network_tweaks_version", VERSION, "version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	FindConVarEx("fps_max", fps_max);
	FindConVarEx("sv_minrate", sv_minrate);
	FindConVarEx("sv_maxrate", sv_maxrate);
	FindConVarEx("sv_minupdaterate", sv_minupdaterate);
	FindConVarEx("sv_maxupdaterate", sv_maxupdaterate);
	FindConVarEx("sv_mincmdrate", sv_mincmdrate);
	FindConVarEx("sv_maxcmdrate", sv_maxcmdrate);
	FindConVarEx("sv_client_cmdrate_difference", sv_client_cmdrate_difference);
	FindConVarEx("sv_client_min_interp_ratio", sv_client_min_interp_ratio);
	FindConVarEx("sv_client_max_interp_ratio", sv_client_max_interp_ratio);
	FindConVarEx("nb_update_frequency", nb_update_frequency);
	FindConVarEx("net_maxcleartime", net_maxcleartime);
	FindConVarEx("net_splitpacket_maxrate", net_splitpacket_maxrate);
	FindConVarEx("net_splitrate", net_splitrate);
	FindConVarEx("sv_gravity", sv_gravity);
	FindConVarEx("sv_clockcorrection_msecs", sv_clockcorrection_msecs);
	FindConVarEx("sv_forcepreload", sv_forcepreload);
	FindConVarEx("sv_client_predict", sv_client_predict);

	RegConsoleCmd("sm_tickcvar", Cmd_PrintCvar);
}

int ClampInt(int value, int min, int max)
{
	if (value < min)
		return min;
	if (value > max)
		return max;
	return value;
}

void FindConVarEx(const char[] name, ConVar &cvar)
{
	cvar = FindConVar(name);
	cvar.SetBounds(ConVarBound_Upper, false);
	cvar.SetBounds(ConVarBound_Lower, false);
}

// Does not trigger when maxplayers = 1.
public void OnConfigsExecuted()
{
	NetworkTweaks();
}

void NetworkTweaks()
{
	fps_max.IntValue = 0;

	sv_minrate.IntValue = g_iTickRate * 1000;
	sv_maxrate.IntValue = g_iTickRate * 1000;

	sv_minupdaterate.IntValue = g_iTickRate;
	sv_maxupdaterate.IntValue = g_iTickRate;

	sv_mincmdrate.IntValue = g_iTickRate;
	sv_maxcmdrate.IntValue = g_iTickRate;

	// cl_cmdrate = cl_updaterate, and clamped between sv_mincmdrate and sv_maxcmdrate.
	sv_client_cmdrate_difference.IntValue = 0; 

	sv_client_min_interp_ratio.IntValue = -1;
	sv_client_max_interp_ratio.IntValue = 2;

	if (g_iTickRate <= 60)
		nb_update_frequency.FloatValue = 0.024;
	else if (60 < g_iTickRate < 100)
		nb_update_frequency.FloatValue = 0.024-(0.00035*(g_iTickRate-60));
	else if (g_iTickRate >= 100)
		nb_update_frequency.FloatValue = 0.01;

	net_maxcleartime.FloatValue = 0.00001;
	net_splitpacket_maxrate.IntValue = g_iTickRate/2 * 1000;
	net_splitrate.IntValue = 2;

	// https://github.com/Derpduck/L4D2-Comp-Stripper-Rework/issues/35
	sv_gravity.IntValue = 750;

	sv_clockcorrection_msecs.IntValue = 30;
	sv_forcepreload.IntValue = 1;
	sv_client_predict.IntValue = 1;
}

Action Cmd_PrintCvar(int client, int args)
{
	ReplyToCommand(client, "---------- %s ----------", VERSION);

	ReplyToCommand(client, "%-28s = %i",	"tickrate",						g_iTickRate);
	ReplyToCommand(client, "%-28s = %.4f",	"tickinterval",					g_fTickInterval);
	ReplyToCommand(client, "%-28s = %i",	"fps_max",						fps_max.IntValue);	
	ReplyToCommand(client, "%-28s = %i",	"sv_minrate",					sv_minrate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_maxrate",					sv_maxrate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_minupdaterate",				sv_minupdaterate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_maxupdaterate",				sv_maxupdaterate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_mincmdrate",				sv_mincmdrate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_maxcmdrate",				sv_maxcmdrate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_client_cmdrate_difference",	sv_client_cmdrate_difference.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_client_min_interp_ratio",	sv_client_min_interp_ratio.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_client_max_interp_ratio",	sv_client_max_interp_ratio.IntValue);
	ReplyToCommand(client, "%-28s = %.5f",	"nb_update_frequency",			nb_update_frequency.FloatValue);
	ReplyToCommand(client, "%-28s = %.6f",	"net_maxcleartime",				net_maxcleartime.FloatValue);
	ReplyToCommand(client, "%-28s = %i",	"net_splitpacket_maxrate",		net_splitpacket_maxrate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"net_splitrate",				net_splitrate.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_gravity",					sv_gravity.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_clockcorrection_msecs",		sv_clockcorrection_msecs.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_forcepreload",				sv_forcepreload.IntValue);
	ReplyToCommand(client, "%-28s = %i",	"sv_client_predict",			sv_client_predict.IntValue);

	return Plugin_Handled;
}

