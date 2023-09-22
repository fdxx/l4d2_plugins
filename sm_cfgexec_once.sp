#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "0.1"

int g_iCCommandSize;

Handle
	g_hSDK_CCommand_Constructor,
	g_hSDK_CCommand_Tokenize,
	g_hSDK_CmdExecf;

public Plugin myinfo = 
{
	name = "sm_cfgexec_once",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	Init();
	CreateConVar("sm_cfgexec_once_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	RegAdminCmd("sm_cfgexec_once", Cmd_Execute, ADMFLAG_ROOT);
}

void Init()
{
	char buffer[128];

	strcopy(buffer, sizeof(buffer), "sm_cfgexec_once");
	GameData hGameData = new GameData(buffer);

	strcopy(buffer, sizeof(buffer), "CCommandSize");
	g_iCCommandSize = hGameData.GetOffset(buffer);
	if (g_iCCommandSize == -1) 
		SetFailState("Failed to GetOffset: %s", buffer);

	// void CCommand::CCommand()
	strcopy(buffer, sizeof(buffer), "CCommand::CCommand");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	g_hSDK_CCommand_Constructor = EndPrepSDKCall();
	if (g_hSDK_CCommand_Constructor == null)
		SetFailState("Failed to create SDKCall: \"%s\"", buffer);

	// bool CCommand::Tokenize( const char *pCommand, characterset_t *pBreakSet )
	strcopy(buffer, sizeof(buffer), "CCommand::Tokenize");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CCommand_Tokenize = EndPrepSDKCall();
	if (g_hSDK_CCommand_Tokenize == null)
		SetFailState("Failed to create SDKCall: \"%s\"", buffer);
		
	//void Cmd_Exec_f( const CCommand &args )
	strcopy(buffer, sizeof(buffer), "Cmd_Exec_f");
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_CmdExecf = EndPrepSDKCall();
	if (g_hSDK_CmdExecf == null)
		SetFailState("Failed to create SDKCall: \"%s\"", buffer);

	delete hGameData;
}

Action Cmd_Execute(int client, int args)
{
	if (args != 1)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <filename>", cmd);
		return Plugin_Handled;
	}

	static bool shit = false;
	if (shit) return Plugin_Handled;
	shit = true;

	char file[PLATFORM_MAX_PATH], buffer[PLATFORM_MAX_PATH];

	GetCmdArg(1, file, sizeof(file));
	FormatEx(buffer, sizeof(buffer), "cfg/%s", file);
	if (!FileExists(buffer))
	{
		LogError("%s does not exist", buffer);
		return Plugin_Handled;
	}

	// https://github.com/lua9520/source-engine-2018-cstrike15_src/blob/master/engine/cmd.h#L193
	// For some reason, it will not be executed immediately on Windows.	So we manually call the Cmd_Exec_f function.
	//ServerCommand("exec \"%s\"", file);
	//ServerExecute();

	FormatEx(buffer, sizeof(buffer), "exec \"%s\"", file);
	
	if (ExecuteFile(buffer))
		ReplyToCommand(client, "Executed file: %s", file);
	else
		LogError("Failed to execute file: %s", file);

	return Plugin_Handled;
}

bool ExecuteFile(const char[] cmdStr)
{
	bool result = false;
	MemoryBlock hMemoryBlock = new MemoryBlock(g_iCCommandSize);

	SDKCall(g_hSDK_CCommand_Constructor, hMemoryBlock.Address);
	if (SDKCall(g_hSDK_CCommand_Tokenize, hMemoryBlock.Address, cmdStr, 0))
	{
		SDKCall(g_hSDK_CmdExecf, hMemoryBlock.Address);
		result = true;
	}

	delete hMemoryBlock;
	return result;
}

