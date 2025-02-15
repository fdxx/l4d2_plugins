#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION	"0.1"
StringMap g_smAlias;

public Plugin myinfo =
{
	name = "sm_cmdalias",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	Init();
	RegAdminCmd("sm_addalias", Cmd_AddAlias, ADMFLAG_ROOT);
	RegAdminCmd("sm_delalias", Cmd_DelAlias, ADMFLAG_ROOT);
	RegAdminCmd("sm_listalias", Cmd_ListAlias, ADMFLAG_ROOT);
}

void Init()
{
	delete g_smAlias;
	g_smAlias = new StringMap();
}

Action Cmd_AddAlias(int client, int args)
{
	if (args < 2)
	{
		char buffer[128];
		GetCmdArg(0, buffer, sizeof(buffer));
		ReplyToCommand(client, "Usage: %s <cmd> <alias1> [alias2] ...", buffer);
		return Plugin_Handled;
	}

	char cmd[256], alias[256];
	GetCmdArg(1, cmd, sizeof(cmd));
	CharToLowerCase(cmd, strlen(cmd));

	for (int i = 2; i <= args; i++)
	{
		GetCmdArg(i, alias, sizeof(alias));
		CharToLowerCase(alias, strlen(alias));

		if (!strcmp(cmd, alias) || g_smAlias.ContainsKey(alias))
			continue;

		g_smAlias.SetString(alias, cmd);
		RegConsoleCmdEx(alias, Cmd_Forward);
		ReplyToCommand(client, "add alias: %s -> %s", alias, cmd);
	}

	return Plugin_Handled;
}

Action Cmd_DelAlias(int client, int args)
{
	char buffer[256];
	if (args < 1)
	{
		GetCmdArg(0, buffer, sizeof(buffer));
		ReplyToCommand(client, "Usage: %s <name>", buffer);
		return Plugin_Handled;
	}

	GetCmdArg(1, buffer, sizeof(buffer));
	CharToLowerCase(buffer, strlen(buffer));

	if (!strcmp(buffer, "@all"))
	{
		Init();
		ReplyToCommand(client, "del all alias.");
		return Plugin_Handled;
	}

	StringMapSnapshot hSnapshot = g_smAlias.Snapshot();
	char cmd[256], alias[256];

	for (int i = 0; i < hSnapshot.Length; i++)
	{
		hSnapshot.GetKey(i, alias, sizeof(alias));
		g_smAlias.GetString(alias, cmd, sizeof(cmd));

		if (strcmp(alias, buffer) && strcmp(cmd, buffer))
			continue;

		if (g_smAlias.ContainsKey(alias) && g_smAlias.Remove(alias))
			ReplyToCommand(client, "del alias: %s -> %s", alias, cmd);
	}

	delete hSnapshot;
	return Plugin_Handled;
}

Action Cmd_ListAlias(int client, int args)
{
	StringMapSnapshot hSnapshot = g_smAlias.Snapshot();
	char cmd[256], alias[256];

	for (int i = 0; i < hSnapshot.Length; i++)
	{
		hSnapshot.GetKey(i, alias, sizeof(alias));
		g_smAlias.GetString(alias, cmd, sizeof(cmd));
		ReplyToCommand(client, "%s -> %s", alias, cmd);
	}

	ReplyToCommand(client, "There are %i aliases in total", hSnapshot.Length);
	delete hSnapshot;
	return Plugin_Handled;
}


Action Cmd_Forward(int client, int args)
{
	char cmd[256], sArgs[512], alias[256];
	GetCmdArg(0, alias, sizeof(alias));
	CharToLowerCase(alias, strlen(alias));

	if (!g_smAlias.GetString(alias, cmd, sizeof(cmd)))
		return Plugin_Continue;

	GetCmdArgString(sArgs, sizeof(sArgs));

	if (client == 0)
		ServerCommand("%s %s", cmd, sArgs);

	else if (client > 0 && IsClientConnected(client))
		ClientCommand(client, "%s %s", cmd, sArgs);

	return Plugin_Continue;
}

void CharToLowerCase(char[] chr, int len)
{
	for (int i = 0; i < len; i++)
		chr[i] = CharToLower(chr[i]);
}

void RegConsoleCmdEx(const char[] cmd, ConCmd callback, const char[] description="", int flags=0)
{
	if (!CommandExists(cmd))
		RegConsoleCmd(cmd, callback, description, flags);
	else
	{
		char pluginName[PLATFORM_MAX_PATH];
		FindPluginNameByCmd(pluginName, sizeof(pluginName), cmd);
		LogError("The command \"%s\" already exists, plugin: \"%s\"", cmd, pluginName);
	}
}

bool FindPluginNameByCmd(char[] buffer, int maxlength, const char[] cmd)
{
	char cmdBuffer[128];
	bool result = false;
	CommandIterator iter = new CommandIterator();

	while (iter.Next())
	{
		iter.GetName(cmdBuffer, sizeof(cmdBuffer));
		if (strcmp(cmdBuffer, cmd, false))
			continue;

		GetPluginFilename(iter.Plugin, buffer, maxlength);
		result = true;
		break;
	}

	if (!result)
	{
		ConVar cvar = FindConVar(cmd);
		if (cvar)
		{
			GetPluginFilename(cvar.Plugin, buffer, maxlength);
			result = true;
		}
	}

	delete iter;
	return result;
}
