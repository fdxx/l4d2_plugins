#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>  

#define VERSION "0.3"

public Plugin myinfo = 
{
	name = "L4D kick Guard",
	author = "Crimson, fdxx",
	description = "Kick Admin == kick Self",
	version = VERSION,
}

public void OnPluginStart()
{
	AddCommandListener(OnCallVote, "callvote");
}

Action OnCallVote(int client, const char[] command, int argc)
{
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		char sVoteType[5];
		GetCmdArg(1, sVoteType, sizeof(sVoteType));
		if (strcmp(sVoteType, "kick"))
			return Plugin_Continue;
		
		int target = GetClientOfUserId(GetCmdArgInt(2));
		if (target > 0 && IsClientInGame(target) && !IsFakeClient(target) && CheckCommandAccess(target, "sm_admin", ADMFLAG_ROOT))
		{
			if (!IsClientInKickQueue(client))
			{
				KickClient(client, "试图踢管理员被系统自动踢出");
				CPrintToChatAll("{blue}[提示] {olive}%N {default}试图踢管理员被系统自动踢出", client);
			}
		}
	}
	return Plugin_Continue;
}
