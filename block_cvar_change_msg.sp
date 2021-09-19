#pragma semicolon 1
#pragma newdecls required

ConVar CvarBlock;
bool g_bBlock;

public Plugin myinfo = 
{
	name = "Block cvar change messages",
	author = "Sir, fdxx",
	description = "",
	version = "1.1",
	url = ""
}

public void OnPluginStart()
{
	HookEvent("server_cvar", Event_ServerCvar, EventHookMode_Pre);
	CvarBlock = CreateConVar("block_cvar_change_msg", "1", "0/1 block cvar change messages");
	g_bBlock = CvarBlock.BoolValue;
	CvarBlock.AddChangeHook(ConVarChange);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bBlock = CvarBlock.BoolValue;
}

public Action Event_ServerCvar(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bBlock) return Plugin_Handled;
	return Plugin_Continue;
}
