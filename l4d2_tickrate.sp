#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sourcescramble>

#define VERSION "0.1"

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
	sv_gravity;

MemoryBlock gGlobals, gpGlobals;
MemoryPatch g_mPatch[6];
int g_iTickRate;
float g_fTickInterval;

public Plugin myinfo =
{
    name = "[L4D2] Tickrate Enabler",
    author = "BHaType & Satanic Spirit, fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	g_iTickRate = GetCommandLineParamInt("-tickrate", 30);
	g_fTickInterval = 1.0 / g_iTickRate;
	SetTickRate();

	CreateConVar("l4d2_tickrate", "", "", FCVAR_NOTIFY|FCVAR_DONTRECORD).IntValue = g_iTickRate; // Expose tickrate to A2S_RULES.
	CreateConVar("l4d2_tickrate_version", VERSION, "version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
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

	RegConsoleCmd("sm_tickcvar", Cmd_PrintCvar);
}

void SetTickRate()
{
	GameData hGameData = new GameData("l4d2_tickrate");
	Address addr;

	int windows = hGameData.GetOffset("os");

	GetAddress(hGameData, "CCommonHostState::interval_per_tick", addr);
	StoreToAddress(addr, view_as<int>(g_fTickInterval), NumberType_Int32);

	GetAddress(hGameData, "CBaseServer::m_flTickInterval", addr);
	StoreToAddress(addr, view_as<int>(g_fTickInterval), NumberType_Int32);

	GetAddress(hGameData, "DEFAULT_TICK_INTERVAL", addr);
	StoreToAddress(addr, view_as<int>(g_fTickInterval), NumberType_Int32);

	for (int i = 0; i < sizeof(g_mPatch); i++)
		delete g_mPatch[i];

	// Linux: CGameClient::SetRate -> ClampClientRate -> CBaseClient::SetRate -> CNetChan::SetDataRate
	// windows: CGameClient::SetRate (inline ClampClientRate) -> CBaseClient::SetRate -> CNetChan::SetDataRate
	// windows: CBoundedCvar_Rate.GetFloat() -> ClampClientRate
	if (windows)
		SetupPatch(hGameData, "CGameClient::SetRate", g_mPatch[0]);
	SetupPatch(hGameData, "ClampClientRate", g_mPatch[1]);
	SetupPatch(hGameData, "CNetChan::SetDataRate", g_mPatch[2]);

	// FixBoomer
	delete gGlobals;
	delete gpGlobals;

	gGlobals = new MemoryBlock(0x14);
	gGlobals.StoreToOffset(16, view_as<int>(0.033333333), NumberType_Int32); //frametime
	
	gpGlobals = new MemoryBlock(4);
	gpGlobals.StoreToOffset(0, view_as<int>(gGlobals.Address), NumberType_Int32);

	SetupPatch(hGameData, "CVomit::UpdateAbility::patch1", g_mPatch[3]);
	StoreToAddress(g_mPatch[3].Address + view_as<Address>(1), gpGlobals.Address, NumberType_Int32);

	SetupPatch(hGameData, "CVomit::UpdateAbility::patch2", g_mPatch[4]);
	StoreToAddress(g_mPatch[4].Address + view_as<Address>(1), gpGlobals.Address, NumberType_Int32);

	if (windows)
	{
		SetupPatch(hGameData, "CVomit::UpdateAbility::patch3", g_mPatch[5]);
		StoreToAddress(g_mPatch[5].Address + view_as<Address>(1), gpGlobals.Address, NumberType_Int32);
	}

	delete hGameData;
}

void GetAddress(GameData hGameData, const char[] name, Address &address)
{
	address = hGameData.GetAddress(name);
	if (address == Address_Null)
		SetFailState("Failed to get address: %s", name);
}

void SetupPatch(GameData hGameData, const char[] name, MemoryPatch &patch = null)
{
	patch = MemoryPatch.CreateFromConf(hGameData, name);
	if (!patch.Validate())
		SetFailState("Failed to validate patch: %s", name);
	if (!patch.Enable())
		SetFailState("Failed to enable patch: %s", name);
}

void FindConVarEx(const char[] name, ConVar &cvar)
{
	cvar = FindConVar(name);
	cvar.SetBounds(ConVarBound_Upper, false);
	cvar.SetBounds(ConVarBound_Lower, false);
}

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

	return Plugin_Handled;
}

