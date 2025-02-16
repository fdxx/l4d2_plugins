#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>  

#define VERSION "0.4"

public Plugin myinfo = 
{
	name = "L4D2 kick Guard",
	author = "Crimson, fdxx",
	description = "Kick Admin == kick Self",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	LoadTranslations("l4d2_kick_guard.phrases");
	AddCommandListener(OnCallVote, "callvote");
}

Action OnCallVote(int client, const char[] command, int argc)
{
	char type[5];
	GetCmdArg(1, type, sizeof(type));
	if (strcmp(type, "kick"))
		return Plugin_Continue;
		
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	int target = GetClientOfUserId(GetCmdArgInt(2));
	if (!target || !IsClientInGame(target) || IsFakeClient(target) || !CheckCommandAccess(target, "sm_admin", ADMFLAG_ROOT))
		return Plugin_Continue;

	if (!IsClientInKickQueue(client))
	{
		char buffer[128];
		FormatEx(buffer, sizeof(buffer), "%T", "kickmsg", client);
		KickClient(client, "%s", buffer);
		CPrintToChatAll("{olive}%N {default}%s", client, buffer);
	}
	
	return Plugin_Continue;
}
