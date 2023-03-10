#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>  

#define VERSION "0.2"

public Plugin myinfo = 
{
	name = "L4D Vote Guard",
	author = "Crimson, fdxx",
	description = "Kick Admin == kick Self",
	version = VERSION,
	url = ""
}

public void OnPluginStart()
{
	AddCommandListener(VoteCallBack, "callvote");
}

public Action VoteCallBack(int client, const char[] command, int argc)
{
	if (IsRealClient(client))
	{
		static char sVoteType[64], sTarget[64];
		GetCmdArg(1, sVoteType, sizeof(sVoteType));

		if (strcmp(sVoteType, "kick") == 0)
		{
			GetCmdArg(2, sTarget, sizeof(sTarget));
			int iTarget = GetClientOfUserId(StringToInt(sTarget));

			if (IsRealClient(iTarget) && IsAdminClient(iTarget))
			{
				if (KickPlayer(client))
				{
					CPrintToChatAll("{blue}[提示] {olive}%N {default}试图踢管理员被系统自动踢出", client);
				}
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

bool KickPlayer(int client)
{
	if (IsRealClient(client) && !IsClientInKickQueue(client))
	{
		KickClient(client, "试图踢管理员被系统自动踢出");
	}
	return IsClientInKickQueue(client);
}

bool IsAdminClient(int client)
{
	int iFlags = GetUserFlagBits(client);
	if ((iFlags != 0) && (iFlags & ADMFLAG_ROOT)) 
	{
		return true;
	}
	return false;
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}
