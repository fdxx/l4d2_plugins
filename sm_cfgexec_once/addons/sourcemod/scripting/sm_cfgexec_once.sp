#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.2"
#define COMMAND_MAX_LENGTH 512

public Plugin myinfo = 
{
	name = "sm_cfgexec_once",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
};

public void OnPluginStart()
{
	CreateConVar("sm_cfgexec_once_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	RegAdminCmd("sm_cfgexec_once", Cmd_Execute, ADMFLAG_ROOT);
}

Action Cmd_Execute(int client, int args)
{
	if (args != 1)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <path/file1;path/file2>", cmd);
		return Plugin_Handled;
	}

	static bool shit = false;
	if (shit) return Plugin_Handled;
	shit = true;

	char buffer[COMMAND_MAX_LENGTH];
	char fileList[32][PLATFORM_MAX_PATH];
	GetCmdArg(1, buffer, sizeof(buffer));

	int num = ExplodeString(buffer, ";", fileList, sizeof(fileList), sizeof(fileList[]));
	for (int i = 0; i < num; i++)
	{
		if (!ExecFile(fileList[i]))
			LogError("Failed to execute file: %s", fileList[i]);
	}

	return Plugin_Handled;
}

bool ExecFile(const char[] file)
{
	File hFile = OpenFile(file, "r");
	if (!hFile)
		return false;

	char buffer[COMMAND_MAX_LENGTH];
	while (!hFile.EndOfFile() && hFile.ReadLine(buffer, sizeof(buffer)-2))
	{
		// All codes after "//" are considered comments.
		int pos = StrContains(buffer, "//");
		if (pos != -1)
			buffer[pos] = '\0';
		
		TrimString(buffer);
		if (buffer[0] == '\0')
			continue;
		
		if (!strncmp(buffer, "exec", 4, false))
		{
			Format(buffer, sizeof(buffer), "%s", buffer[4]);
			TrimString(buffer);
			TrimQuotes(buffer);
			Format(buffer, sizeof(buffer), "cfg/%s", buffer);
			ExecFile(buffer);
			continue;
		}

		ServerCommand("%s", buffer);
		ServerExecute();
	}
	
	LogMessage("Executed file: %s", file);
	delete hFile;
	return true;
}

void TrimQuotes(char[] str)
{
	int len = strlen(str);
	if (!len)
		return;
	
	if (str[len-1] == '\"')
		str[len-1] = '\0';

	if (str[0] == '\"')
		Format(str, len-1, "%s", str[1]);
}
