#pragma semicolon 1
#pragma newdecls required

#define VERSION "0.2"

#include <sourcemod>
#include <multicolors>
#include <left4dhooks>

bool
	g_bCanGetBossSpawnFlow,
	g_bSendPanel,
	g_bShowHud[MAXPLAYERS];

Handle
	g_hShowHudTimer[MAXPLAYERS];

ConVar
	g_cvShowSpawnBufferFlow;

float
	g_fSpawnBufferFlow;

#define	SMOKER	1
#define	BOOMER	2
#define	HUNTER	3
#define	SPITTER	4
#define	JOCKEY	5
#define	CHARGER 6
#define	TANK	8

#define	BOSS_TYPE_TANK	0
#define	BOSS_TYPE_WITCH	1

native float L4D2_GetBossSpawnFlow(int iBossType);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("L4D2_GetBossSpawnFlow");
	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "L4D2 Hud",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_hud_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);

	g_cvShowSpawnBufferFlow = CreateConVar("l4d2_hud_show_buffer_flow", "0.0");
	g_fSpawnBufferFlow = g_cvShowSpawnBufferFlow.FloatValue;
	g_cvShowSpawnBufferFlow.AddChangeHook(OnConVarChange);

	RegConsoleCmd("sm_hud", Cmd_ShowHud);
	RegConsoleCmd("sm_spechud", Cmd_ShowHud);
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fSpawnBufferFlow = g_cvShowSpawnBufferFlow.FloatValue;
}

public void OnConfigsExecuted()
{
	g_bCanGetBossSpawnFlow = GetFeatureStatus(FeatureType_Native, "L4D2_GetBossSpawnFlow") == FeatureStatus_Available;
}

public void OnMapStart()
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

public void OnClientDisconnect(int client)
{
	delete g_hShowHudTimer[client];
	g_bShowHud[client] = false;
}

void Reset()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		delete g_hShowHudTimer[i];
		g_bShowHud[i] = false;
	}
}

Action Cmd_ShowHud(int client, int args)
{
	if (IsRealClient(client))
	{
		if (GetClientTeam(client) == 1 || IsRootAdminClient(client))
		{
			g_bShowHud[client] = !g_bShowHud[client];
			if (g_bShowHud[client])
			{
				delete g_hShowHudTimer[client];
				g_hShowHudTimer[client] = CreateTimer(0.5, ShowHud_Timer, GetClientUserId(client), TIMER_REPEAT);
			}
			CPrintToChat(client, "面板状态: {yellow}%s", g_bShowHud[client] ? "已开启" : "已关闭");
		}
		else CPrintToChat(client, "本命令仅限旁观团队使用");
	}
	return Plugin_Handled;
}

Action ShowHud_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (g_bShowHud[client] && IsRealClient(client))
	{
		if (GetClientTeam(client) == 1 || IsRootAdminClient(client))
		{
			Panel panel = new Panel();

			DrawSpecials(panel);
			DrawFlow(panel);
			DrawTankStatus(panel);

			g_bSendPanel = true;
			panel.Send(client, HudHandler, 1);
			g_bSendPanel = false;

			delete panel;
			return Plugin_Continue;
		}
	}
	g_bShowHud[client] = false;
	g_hShowHudTimer[client] = null;
	return Plugin_Stop;
}

int HudHandler(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Cancel && param2 == MenuCancel_Interrupted && !g_bSendPanel) //被其他插件菜单打断
		g_bShowHud[client] = false;
	return 0;
}

void DrawSpecials(Panel panel)
{
	char sBuffer[256];
	int iSpecialCount[7];
	int iTotal = GetSpecialsCount(iSpecialCount);

	panel.DrawItem("特感数量:");

	FormatEx(sBuffer, sizeof(sBuffer), "Smoker: %i", iSpecialCount[SMOKER]);
	panel.DrawText(sBuffer);

	FormatEx(sBuffer, sizeof(sBuffer), "Boomer: %i", iSpecialCount[BOOMER]);
	panel.DrawText(sBuffer);

	FormatEx(sBuffer, sizeof(sBuffer), "Hunter: %i", iSpecialCount[HUNTER]);
	panel.DrawText(sBuffer);

	FormatEx(sBuffer, sizeof(sBuffer), "Spitter: %i", iSpecialCount[SPITTER]);
	panel.DrawText(sBuffer);

	FormatEx(sBuffer, sizeof(sBuffer), "Jockey: %i", iSpecialCount[JOCKEY]);
	panel.DrawText(sBuffer);

	FormatEx(sBuffer, sizeof(sBuffer), "Charger: %i", iSpecialCount[CHARGER]);
	panel.DrawText(sBuffer);

	FormatEx(sBuffer, sizeof(sBuffer), "Total: %i", iTotal);
	panel.DrawText(sBuffer);
}

#define FLOW_DISABLED	-3.0
#define FLOW_DEFAULT	-2.0
#define FLOW_STATIC		-1.0
#define FLOW_NONE		0.0

void DrawFlow(Panel panel)
{
	char sBuffer[256];
	float fSurMaxFlow = GetSurMaxFlow();

	panel.DrawText(" ");
	panel.DrawItem("路程:");

	FormatEx(sBuffer, sizeof(sBuffer), "Current: %i%%", RoundToNearest(fSurMaxFlow * 100.0));
	panel.DrawText(sBuffer);

	if (g_fSpawnBufferFlow > 0.0)
	{
		float fFlow = g_fSpawnBufferFlow / L4D2Direct_GetMapMaxFlowDistance();

		FormatEx(sBuffer, sizeof(sBuffer), "Current (buffer-): %i%%", RoundToNearest((fSurMaxFlow - fFlow) * 100.0));
		panel.DrawText(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "Current (buffer+): %i%%", RoundToNearest((fSurMaxFlow + fFlow) * 100.0));
		panel.DrawText(sBuffer);
	}

	if (!g_bCanGetBossSpawnFlow) return;

	float fTankSpawnFlow = L4D2_GetBossSpawnFlow(BOSS_TYPE_TANK);
	if (fTankSpawnFlow == FLOW_DISABLED)
		FormatEx(sBuffer, sizeof(sBuffer), "Tank: Disabled");
	else if (fTankSpawnFlow == FLOW_DEFAULT)
		FormatEx(sBuffer, sizeof(sBuffer), "Tank: Default");
	else if (fTankSpawnFlow == FLOW_STATIC)
		FormatEx(sBuffer, sizeof(sBuffer), "Tank: Static");
	else if (fTankSpawnFlow == FLOW_NONE)
		FormatEx(sBuffer, sizeof(sBuffer), "Tank: None");
	else if (fTankSpawnFlow > 0.0)
		FormatEx(sBuffer, sizeof(sBuffer), "Tank: %i%%", RoundToNearest(fTankSpawnFlow * 100.0));
	panel.DrawText(sBuffer);

	float fWitchSpawnFlow = L4D2_GetBossSpawnFlow(BOSS_TYPE_WITCH);
	if (fWitchSpawnFlow == FLOW_DISABLED)
		FormatEx(sBuffer, sizeof(sBuffer), "Witch: Disabled");
	else if (fWitchSpawnFlow == FLOW_DEFAULT)
		FormatEx(sBuffer, sizeof(sBuffer), "Witch: Default");
	else if (fWitchSpawnFlow == FLOW_STATIC)
		FormatEx(sBuffer, sizeof(sBuffer), "Witch: Static");
	else if (fWitchSpawnFlow == FLOW_NONE)
		FormatEx(sBuffer, sizeof(sBuffer), "Witch: None");
	else if (fWitchSpawnFlow > 0.0)
		FormatEx(sBuffer, sizeof(sBuffer), "Witch: %i%%", RoundToNearest(fWitchSpawnFlow * 100.0));
	panel.DrawText(sBuffer);
}

void DrawTankStatus(Panel panel)
{
	int client = GetTankClient();
	if (client > 0)
	{
		char sBuffer[256];

		panel.DrawText(" ");
		panel.DrawItem("Tank:");

		if (!IsFakeClient(client))
			FormatEx(sBuffer, sizeof(sBuffer), "Control: %N", client);
		else FormatEx(sBuffer, sizeof(sBuffer), "Control: AI");
		panel.DrawText(sBuffer);

		int iHealth = GetEntProp(client, Prop_Send, "m_iHealth");
		int iMaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
		FormatEx(sBuffer, sizeof(sBuffer), "Health: %i / %i%%", iHealth, RoundToNearest(float(iHealth)/iMaxHealth*100.0));
		panel.DrawText(sBuffer);

		if (!IsFakeClient(client))
		{
			FormatEx(sBuffer, sizeof(sBuffer), "Frustration: %i%%", 100 - GetEntProp(client, Prop_Send, "m_frustration"));
			panel.DrawText(sBuffer);
		}
	}
}

int GetSpecialsCount(int[] iSpecialCount)
{
	int iTotal, iClass;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			iClass = GetZombieClass(i);
			if (1 <= iClass <= 6)
			{
				iSpecialCount[iClass]++;
				iTotal++;
			}
		}
	}
	return iTotal;
}

int GetTankClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetZombieClass(i) == TANK && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			return i;
	}
	return -1;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool IsRootAdminClient(int client)
{
	int iFlags = GetUserFlagBits(client);
	if (iFlags != 0 && (iFlags & ADMFLAG_ROOT)) 
	{
		return true;
	}
	return false;
}

bool IsRealClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

float GetSurMaxFlow()
{
	static float fSurMaxDistance;
	static int iFurthestSur;

	iFurthestSur = L4D_GetHighestFlowSurvivor();

	if (IsValidSur(iFurthestSur)) fSurMaxDistance = L4D2Direct_GetFlowDistance(iFurthestSur);
	else fSurMaxDistance = L4D2_GetFurthestSurvivorFlow();

	return (fSurMaxDistance / L4D2Direct_GetMapMaxFlowDistance());
}

bool IsValidSur(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

