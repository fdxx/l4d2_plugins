#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
	name = "L4D2 Saferoom HP Restore",
	author = "fdxx",
	version = "1.3",
}

public void OnPluginStart()
{
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) 
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			RestoreHealth(i, GetEntProp(i, Prop_Send, "m_iMaxHealth"));
		}
	}
}

void RestoreHealth(int client, int iHealth)
{
	Event event = CreateEvent("heal_success", true);
	event.SetInt("userid", GetClientUserId(client));
	event.SetInt("subject", GetClientUserId(client));
	event.SetInt("health_restored", iHealth - GetEntProp(client, Prop_Send, "m_iHealth"));

	int iflags = GetCommandFlags("give");
	SetCommandFlags("give", iflags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give health");
	SetCommandFlags("give", iflags);

	SetEntProp(client, Prop_Send, "m_iHealth", iHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());

	event.Fire();
}

