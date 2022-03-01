#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <sdktools>
#include <ripext>		// https://github.com/ErikMinekus/sm-ripext
#include <multicolors>	// https://github.com/Bara/Multi-Colors

ConVar g_cvCheckTime, g_cvRestartTime;
float g_fCheckTime, g_fRestartTime;
char g_sLogPath[PLATFORM_MAX_PATH], g_sUrl[256];
int g_iVer;
Handle g_hTimer;


public Plugin myinfo =
{
	name = "L4D2 Server update Checker",
	author = "fdxx",
	description = "Restart the server when the server has an update.",
	version = VERSION,
}

public void OnPluginStart()
{
	InitGameData();

	CreateConVar("l4d2_server_update_checker_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvCheckTime = CreateConVar("l4d2_server_update_check_time", "300.0", "How often to check update (sec), 0.0=disable check", FCVAR_NONE);
	g_cvRestartTime = CreateConVar("l4d2_server_update_restart_time", "60.0", "How many time later the server will restart if there is an update (sec).", FCVAR_NONE);

	GetCvars();

	g_cvCheckTime.AddChangeHook(ConVarChanged);
	g_cvRestartTime.AddChangeHook(ConVarChanged);

	RegAdminCmd("sm_get_server_version", Cmd_GetVersion, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d2_server_update_checker");
}

public void OnConfigsExecuted()
{
	FindConVar("sv_hibernate_when_empty").IntValue = 0;
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fCheckTime = g_cvCheckTime.FloatValue;
	g_fRestartTime = g_cvRestartTime.FloatValue;

	delete g_hTimer;
	if (g_fCheckTime >= 0.1)
	{
		g_hTimer = CreateTimer(g_fCheckTime, CheckUpdate_Timer, _, TIMER_REPEAT);
	}
}

Action CheckUpdate_Timer(Handle timer)
{
	HTTPRequest http = new HTTPRequest(g_sUrl);
	http.Get(RequestResult);
	return Plugin_Continue;
}

void RequestResult(HTTPResponse response, any value, const char[] error)
{
	if (error[0] == '\0' && response.Status == HTTPStatus_OK)
	{
		JSONObject RootNode = view_as<JSONObject>(response.Data);
		if (RootNode != null && RootNode.HasKey("response"))
		{
			JSONObject SubNode = view_as<JSONObject>(RootNode.Get("response"));
			if (SubNode != null && SubNode.HasKey("up_to_date"))
			{
				if (!SubNode.GetBool("up_to_date"))
				{
					delete g_hTimer;
		
					CPrintToChatAll("{default}[{red}Warn{default}] Server update detected, Will auto restart in %.1f seconds.", g_fRestartTime);
					LogToFileEx(g_sLogPath, "Server update detected, Will auto restart in %.1f seconds.", g_fRestartTime);

					CreateTimer(g_fRestartTime, Restart_Timer);
				}
				//else LogMessage("Server is the latest version");
			}
			delete SubNode;
		}
		delete RootNode;
	}
	else LogMessage("error = %s, HTTPStatus = %i", error, view_as<int>(response.Status));
}

Action Restart_Timer(Handle timer)
{
	UnloadAccelerator();
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
	return Plugin_Continue;
}

void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();
	}
}

// by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}

Action Cmd_GetVersion(int client, int args)
{
	ReplyToCommand(client, "Current server version: %i", g_iVer);
	return Plugin_Handled;
}

void InitGameData()
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetSignature(SDKLibrary_Engine, "@_Z14GetHostVersionv", 0);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	Handle hSDKGetVersion = EndPrepSDKCall();
	if (hSDKGetVersion == null)
		SetFailState("Failed to create SDKCall: GetHostVersion, Only supports L4D2 linux server");
	g_iVer = SDKCall(hSDKGetVersion);
	delete hSDKGetVersion;

	FormatEx(g_sUrl, sizeof(g_sUrl), "https://api.steampowered.com/ISteamApps/UpToDateCheck/v0001/?appid=550&version=%i&format=json", g_iVer);
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_server_update_checker.log");
}
