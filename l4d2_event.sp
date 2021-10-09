#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

ArrayList g_aEventName;
bool g_bEnable;
char g_sLogPath[PLATFORM_MAX_PATH];

static const char g_sEventFile[][] = 
{
	"resource/gameevents.res",
	"resource/serverevents.res",
	"resource/modevents.res",
	"resource/hltvevents.res"
};

public Plugin myinfo =
{
	name = "L4D2 Event listen",
	author = "McFlurry, fdxx",
	description = "从 res 文件挂钩所有事件",
	version = "0.1",
	url = "https://forums.alliedmods.net/showthread.php?p=1651619"
};

public void OnPluginStart()   
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_event_listen.log");

	RegAdminCmd("sm_event_listen", Cmd_EventListenEnable, ADMFLAG_ROOT, "开启或关闭");
	RegAdminCmd("sm_list_events", Cmd_EventList, ADMFLAG_ROOT, "查看所有事件列表");

	SaveEvents();
	HookAllEvents();
}

public Action Cmd_EventList(int client, int args)
{
	char sName[128];
	if (g_aEventName.Length > 0)
	{
		for (int i = 0; i < g_aEventName.Length; i++)
		{
			g_aEventName.GetString(i, sName, sizeof(sName));
			ReplyToCommand(client, "%i/%i: %s", i+1, g_aEventName.Length, sName);
		}
	}
	else ReplyToCommand(client, "g_aEventName.Length <= 0");
}

public Action Cmd_EventListenEnable(int client, int args)
{
	g_bEnable = !g_bEnable;

	if (g_bEnable)
	{
		ReplyToCommand(client, "Event listen: Enable");
	}
	else ReplyToCommand(client, "Event listen: Disable");
}

void SaveEvents()
{
	g_aEventName = new ArrayList(128);
	char sName[128];

	for (int i = 0; i < sizeof(g_sEventFile); i++)
	{
		KeyValues kv = new KeyValues("l4d2_event");
		if (kv.ImportFromFile(g_sEventFile[i]))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					if (kv.GetSectionName(sName, sizeof(sName)))
					{
						if (g_aEventName.FindString(sName) == -1)
						{
							g_aEventName.PushString(sName);
						}
						//else LogMessage("Duplicate events, skip. %s -> %s", g_sEventFile[i], sName);
					}
				}
				while (kv.GotoNextKey(false));
			}
		}
		delete kv;
	}
	//LogMessage("%i events found", g_aEventName.Length);
}

void HookAllEvents()
{
	char sName[128];
	if (g_aEventName.Length > 0)
	{
		for (int i = 0; i < g_aEventName.Length; i++)
		{
			g_aEventName.GetString(i, sName, sizeof(sName));
			if (!HookEventEx(sName, EventHook_All))
			{
				LogMessage("HookEvent %s failed", sName);
			}
		}
	}
}

public void EventHook_All(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bEnable)
	{
		char sName[64];
		event.GetName(sName, sizeof(sName));
		PrintToChatAll("Trigger event: %s", sName);
		LogToFileEx(g_sLogPath, "Trigger event: %s", sName);
	}
}
