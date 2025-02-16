#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.2"

#define MAX_EVENTNAME_LEN	128

#define LISTEN_DISABLED	0
#define LISTEN_RES_FILE	1
#define LISTEN_COMMAND	2

ArrayList g_aEvents;
int g_iListenMode;
ConVar net_showevents;

enum struct EventData
{
	char sName[MAX_EVENTNAME_LEN];
	bool bHooked;
}

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
	version = VERSION,
};

public void OnPluginStart()   
{
	CreateConVar("l4d2_event_listen_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	net_showevents = FindConVar("net_showevents");
	RegAdminCmd("sm_event_listen", Cmd_Listen, ADMFLAG_ROOT, "0=Disabled, 1=Listen from res file, 2=Listen from net_showevents command");
	RegAdminCmd("sm_list_events", Cmd_ViewList, ADMFLAG_ROOT, "View all event list");

	GetEventsFromFile();
}

void GetEventsFromFile()
{
	EventData data;
	delete g_aEvents;
	g_aEvents = new ArrayList(sizeof(data));

	for (int i = 0; i < sizeof(g_sEventFile); i++)
	{
		KeyValues kv = new KeyValues("");
		for (bool iter = kv.ImportFromFile(g_sEventFile[i]) && kv.GotoFirstSubKey(false); iter; iter = kv.GotoNextKey(false))
		{
			if (!kv.GetSectionName(data.sName, sizeof(data.sName)))
				continue;

			if (g_aEvents.FindString(data.sName) == -1)
				g_aEvents.PushArray(data);
		}
		delete kv;
	}
}

Action Cmd_ViewList(int client, int args)
{
	EventData data;
	for (int i = 0; i < g_aEvents.Length; i++)
	{
		g_aEvents.GetArray(i, data);
		ReplyToCommand(client, "%i/%i: %s", i+1, g_aEvents.Length, data.sName);
	}

	return Plugin_Handled;
}

Action Cmd_Listen(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "Syntax: sm_event_listen <0|1|2>");
		ReplyToCommand(client, "0=Disabled, 1=Listen from res file, 2=Listen from net_showevents command");
		return Plugin_Handled;
	}

	net_showevents.IntValue = 0;

	EventData data;
	for (int i = 0; i < g_aEvents.Length; i++)
	{
		g_aEvents.GetArray(i, data);
		if (data.bHooked)
			UnhookEvent(data.sName, EventHook_All);
		data.bHooked = false;
		g_aEvents.SetArray(i, data);
	}

	g_iListenMode = GetCmdArgInt(1);

	if (g_iListenMode == LISTEN_COMMAND)
		net_showevents.IntValue = 2;

	else if (g_iListenMode == LISTEN_RES_FILE)
	{
		for (int i = 0; i < g_aEvents.Length; i++)
		{
			g_aEvents.GetArray(i, data);
			data.bHooked = HookEventEx(data.sName, EventHook_All);
			g_aEvents.SetArray(i, data);

			if (!data.bHooked)
				LogMessage("HookEvent %s failed", data.sName);
		}
	}

	return Plugin_Handled;
}

void EventHook_All(Event event, const char[] name, bool dontBroadcast)
{
	PrintToChatAll("Trigger event: %s", name);
	PrintToServer("Trigger event: %s", name);
}
