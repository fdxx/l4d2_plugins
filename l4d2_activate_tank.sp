#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

float g_fActivateDelay;
ConVar CvarActivateDelay;

public Plugin myinfo = 
{
	name = "L4D2 Activate Tank",
	author = "XDglory, fdxx",
	description = "使Tank产生时立即行动攻击玩家, 而不是等待玩家靠近",
	version = "0.4",
	url = "https://forums.alliedmods.net/showthread.php?t=319342"
};

public void OnPluginStart()
{
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Post);

	CvarActivateDelay = CreateConVar("l4d2_activate_tank_delay", "3.0", "Tank产生后多久开始行动", FCVAR_NONE);
	g_fActivateDelay = CvarActivateDelay.FloatValue;
	CvarActivateDelay.AddChangeHook(ConVarChange);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fActivateDelay = CvarActivateDelay.FloatValue;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (g_fActivateDelay >= 0.1)
	{
		CreateTimer(g_fActivateDelay, ActivateTank_Timer, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ActivateTank_Timer(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (iTank > 0 && iTank <= MaxClients)
	{
		if (IsClientInGame(iTank) && GetClientTeam(iTank) == 3 && GetEntProp(iTank, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(iTank) && IsFakeClient(iTank))
		{
			int iAttacker = GetRandomSur();
			if (iAttacker > 0)
			{
				int iTankHealth = GetEntProp(iTank, Prop_Data, "m_iHealth");
				SDKHooks_TakeDamage(iTank, iAttacker, iAttacker, 1.0, DMG_BULLET);
				SetEntProp(iTank, Prop_Data, "m_iHealth", iTankHealth);
				//PrintToChatAll("激活Tank");
			}
		}
	}
}

int GetRandomSur()
{
	int client;
	ArrayList aClients = new ArrayList();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			aClients.Push(i);
		}
	}

	if (aClients.Length > 0)
	{
		client = aClients.Get(GetRandomInt(0, aClients.Length - 1));
	}

	delete aClients;

	return client;
}
