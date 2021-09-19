#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define MSG_MAX_SIZE 1024

char g_sPath[PLATFORM_MAX_PATH];
ArrayList g_aAdList;
Handle g_hTimer;
ConVar CvarType, CvarTime;
bool g_bType;
float g_fTime;
int g_iNum;

public Plugin myinfo = 
{
	name = "L4D2 Advertisements",
	author = "Tsunami, fdxx",
	description = "",
	version = "0.1",
	url = ""
};

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "data/l4d2_advertisements.txt");

	g_aAdList = new ArrayList(MSG_MAX_SIZE);
	LoadAdvertisements();

	CvarType = CreateConVar("l4d2_advertisements_type", "0", "0=顺序，1=随机", FCVAR_NONE, true, 0.0, true, 1.0);
	CvarTime = CreateConVar("l4d2_advertisements_time", "300.0", "间隔时间", FCVAR_NONE, true, 0.1);

	GetCvars();

	CvarType.AddChangeHook(ConVarChanged);
	CvarTime.AddChangeHook(ConVarChanged);

	RegConsoleCmd("sm_adlist", Cmd_CheckAdList);
	RegAdminCmd("sm_adreload", Cmd_AdReload, ADMFLAG_ROOT);

	if (g_fTime >= 0.1)
		g_hTimer = CreateTimer(g_fTime, PrintAd_Timer, _, TIMER_REPEAT);
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();

	delete g_hTimer;
	if (g_fTime >= 0.1)
		g_hTimer = CreateTimer(g_fTime, PrintAd_Timer, _, TIMER_REPEAT);
}

void GetCvars()
{
	g_bType = CvarType.BoolValue;
	g_fTime = CvarTime.FloatValue;
}

public Action PrintAd_Timer(Handle timer)
{	
	static char sSource[MSG_MAX_SIZE];
	static char sMsg[20][MSG_MAX_SIZE];
	static int iSplit;

	if (g_aAdList.Length > 0)
	{
		if (g_aAdList.GetString(GetAdNum(), sSource, sizeof(sSource)) > 0)
		{
			iSplit = ExplodeString(sSource, "\\n", sMsg, sizeof(sMsg), sizeof(sMsg[]));
			for (int i = 0; i < iSplit; i++)
			{
				ReplaceStr(sMsg[i]);
				PrintToChatAll(sMsg[i]);
			}
		}
	}
	
	return Plugin_Continue;
}

int GetAdNum()
{
	static int iNum;
	if (g_bType) //随机
	{
		iNum = GetRandomInt(0, g_aAdList.Length - 1);
	}
	else //顺序
	{
		iNum = g_iNum;
		g_iNum++;
		if (g_iNum >= g_aAdList.Length) g_iNum = 0;
	}
	return iNum;
}

void ReplaceStr(char sMsg[MSG_MAX_SIZE])
{
	ReplaceString(sMsg, sizeof(sMsg), "{default}", "\x01");
	ReplaceString(sMsg, sizeof(sMsg), "{lightgreen}", "\x03");
	ReplaceString(sMsg, sizeof(sMsg), "{yellow}", "\x04");
	ReplaceString(sMsg, sizeof(sMsg), "{green}", "\x05");
	ReplaceString(sMsg, sizeof(sMsg), "{time}", GetCurTime());
}

char[] GetCurTime()
{
	static char sTime[64];
	FormatTime(sTime, sizeof(sTime), "%F %T");
	return sTime;
}

public Action Cmd_CheckAdList(int client, int args)
{
	static char sSource[MSG_MAX_SIZE];
	static char sMsg[20][MSG_MAX_SIZE];
	static int iSplit;

	for (int i = 0; i < g_aAdList.Length; i++)
	{
		if (g_aAdList.GetString(i, sSource, sizeof(sSource)) > 0)
		{
			iSplit = ExplodeString(sSource, "\\n", sMsg, sizeof(sMsg), sizeof(sMsg[]));
			for (int p = 0; p < iSplit; p++)
			{
				ReplaceStr(sMsg[p]);
				PrintToChatAll(sMsg[p]);
			}
		}
	}
}

public Action Cmd_AdReload(int client, int args)
{
	LoadAdvertisements();
	Cmd_CheckAdList(0,0);
}

void LoadAdvertisements()
{
	g_aAdList.Clear();

	static char str[MSG_MAX_SIZE];
	if (FileExists(g_sPath))
	{
		File hFile = OpenFile(g_sPath, "r");
		if (hFile != null)
		{
			while (!hFile.EndOfFile())
			{
				if (hFile.ReadLine(str, sizeof(str)))
				{
					TrimString(str);
					if (IsValidLine(str))
					{
						g_aAdList.PushString(str);
					}
				}
			}
		}
		delete hFile;
	}
}

bool IsValidLine(const char[] str)
{
	return str[0] != '\0' && str[0] != '/' && str[0] != '\\';
}
