#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define VERSION "0.7"

#define EF_NODRAW 32
#define FSOLID_NOT_SOLID 4
#define ICON_SKULL "materials/sprites/skull_icon.vmt"
#define ICON_ORIGIN {-3.0, 0.0, 11.0}

// https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/shareddefs.h#L378
enum
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming
	NUM_OBSERVER_MODES,
};

ConVar
	survivor_max_incapacitated_count,
	g_cvGlowEnable,
	g_cvGlowColor,
	g_cvIconEnable,
	g_cvIconColor;

int
	g_iSurMaxIncapCount,
	g_iGlowColor,
	g_iIconColor[4],
	g_iIconRef[MAXPLAYERS+1] = {-1, ...},
	g_iPlayerAnimStateOffset;

bool
	g_bGlowEnable,
	g_bIconEnable,
	g_bGlowMark[MAXPLAYERS+1],
	g_bIconVisible[MAXPLAYERS+1][MAXPLAYERS+1]; // [iconClient][client];

Handle
	g_hSDK_IsDominatedBySpecialInfected,
	g_hSDK_IsGettingUp,
	g_hSDK_IsPounded;



public Plugin myinfo =
{
	name = "L4D2 Black and White Notifier",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_black_and_white_notifier_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	survivor_max_incapacitated_count = FindConVar("survivor_max_incapacitated_count");

	g_cvGlowEnable = CreateConVar("l4d2_black_and_white_notifier_glow", "1", "B&W player glow.");
	g_cvGlowColor = CreateConVar("l4d2_black_and_white_notifier_glow_color", "255,255,255", "RGB value of glow.");
	g_cvIconEnable = CreateConVar("l4d2_black_and_white_notifier_skull_icon", "1", "Displays a skull icon above the B&W player's head.");
	g_cvIconColor = CreateConVar("l4d2_black_and_white_notifier_skull_icon_color", "255,0,0,200", "RGBA value of skull icon.");

	OnConVarChanged(null, "", "");

	survivor_max_incapacitated_count.AddChangeHook(OnConVarChanged);
	g_cvGlowEnable.AddChangeHook(OnConVarChanged);
	g_cvGlowColor.AddChangeHook(OnConVarChanged);
	g_cvIconEnable.AddChangeHook(OnConVarChanged);
	g_cvIconColor.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	CreateTimer(0.1, Check_Timer, _, TIMER_REPEAT);
}

void OnConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_iSurMaxIncapCount = survivor_max_incapacitated_count.IntValue;
	g_bGlowEnable = g_cvGlowEnable.BoolValue;
	g_bIconEnable = g_cvIconEnable.BoolValue;

	char sBuffer[16], sGlowColor[3][5], sIconColor[4][5];

	g_cvGlowColor.GetString(sBuffer, sizeof(sBuffer));
	ExplodeString(sBuffer, ",", sGlowColor, sizeof(sGlowColor), sizeof(sGlowColor[]));
	g_iGlowColor = StringToInt(sGlowColor[0]) | (StringToInt(sGlowColor[1]) << 8) | (StringToInt(sGlowColor[2]) << 16);

	g_cvIconColor.GetString(sBuffer, sizeof(sBuffer));
	ExplodeString(sBuffer, ",", sIconColor, sizeof(sIconColor), sizeof(sIconColor[]));
	for (int i = 0; i < sizeof(sIconColor); i++)
		g_iIconColor[i] = StringToInt(sIconColor[i]);

	for (int i = 1; i <= MaxClients; i++)
	{
		RemoveGlow(i);
		RemoveIcon(i);
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();
}

public void OnMapEnd()
{
	Reset();
}

void Reset()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_bGlowMark[i] = false;
		g_iIconRef[i] = -1;
	}
}

public void OnMapStart()
{
	if (!IsModelPrecached(ICON_SKULL))
		PrecacheModel(ICON_SKULL, true);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	RemoveGlow(client);
	RemoveIcon(client);
}

public void OnClientDisconnect(int client)
{
	RemoveGlow(client);
	RemoveIcon(client);
}

Action Check_Timer(Handle timer)
{
	int entity;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsBlackAndWhite(i))
		{
			if (g_bGlowEnable && !g_bGlowMark[i])
				SetGlow(i);

			if (g_bIconEnable)
			{
				entity = EntRefToEntIndex(g_iIconRef[i]);
				if (entity <= MaxClients || !IsValidEntity(entity))
					SetIcon(i);
				SetIconVisible(i);
			}
			continue;
		}

		RemoveGlow(i);
		RemoveIcon(i);
	}

	return Plugin_Continue;
}

void SetGlow(int client)
{
	SetEntProp(client, Prop_Send, "m_iGlowType", 3);
	SetEntProp(client, Prop_Send, "m_nGlowRangeMin", 0);
	SetEntProp(client, Prop_Send, "m_nGlowRange", 1000);
	SetEntProp(client, Prop_Send, "m_glowColorOverride", g_iGlowColor);
	g_bGlowMark[client] = true;
}

// https://forums.alliedmods.net/showpost.php?p=2720796&postcount=18
void SetIcon(int client)
{
	int entity = CreateEntityByName("env_sprite");
	if (entity <= MaxClients)
	{
		LogError("Failed to create env_sprite entity.");
		return;
	}

	g_iIconRef[client] = EntIndexToEntRef(entity);

	DispatchKeyValue(entity, "model", ICON_SKULL);
	DispatchKeyValueFloat(entity, "scale", 0.001);
	DispatchSpawn(entity);

	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	AcceptEntityInput(entity, "DisableCollision");

	SetEntityRenderMode(entity, RENDER_WORLDGLOW);
	SetEntityRenderColor(entity, g_iIconColor[0], g_iIconColor[1], g_iIconColor[2], g_iIconColor[3]);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);
	SetVariantString("eyes");
	AcceptEntityInput(entity, "SetParentAttachment");
	
	float origin[3] = ICON_ORIGIN;
	TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);

	SDKUnhook(entity, SDKHook_SetTransmit, OnSetIconTransmit);
	SDKHook(entity, SDKHook_SetTransmit, OnSetIconTransmit);
}

Action OnSetIconTransmit(int entity, int client)
{
	int iconClient = GetIconClient(EntIndexToEntRef(entity));
	if (iconClient > 0 && g_bIconVisible[iconClient][client])
		return Plugin_Continue;
	return Plugin_Handled;
}

void SetIconVisible(int client)
{
	bool bThirdPerson = IsThirdPerson(client);

	for (int i = 1; i <= MaxClients; i++)
	{
		g_bIconVisible[client][i] = true;

		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			g_bIconVisible[client][i] = false;
			continue;
		}

		switch (GetEntProp(i, Prop_Send, "m_iObserverMode"))
		{
			case OBS_MODE_NONE:
			{
				if (i == client && !bThirdPerson)
					g_bIconVisible[client][i] = false;
			}
			case OBS_MODE_IN_EYE:
			{
				int target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
				if (target > 0 && target == client && !bThirdPerson)
					g_bIconVisible[client][i] = false;
			}
		}
	}
}

void RemoveGlow(int client)
{
	if (g_bGlowMark[client] && IsClientInGame(client))
		SetEntProp(client, Prop_Send, "m_iGlowType", 0);
	g_bGlowMark[client] = false;
}

void RemoveIcon(int client)
{
	int ent = EntRefToEntIndex(g_iIconRef[client]);
	if (ent > MaxClients && IsValidEntity(ent))
	{
		SetEntProp(ent, Prop_Data, "m_fEffects", EF_NODRAW);
		RemoveEntity(ent);
	}
	g_iIconRef[client] = -1;
}

bool IsBlackAndWhite(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurMaxIncapCount;
}

bool IsThirdPerson(int client)
{
	if (GetEntProp(client, Prop_Send, "m_iCurrentUseAction") > 0)
		return true;

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return true;

	if (SDKCall(g_hSDK_IsDominatedBySpecialInfected, client) || SDKCall(g_hSDK_IsGettingUp, client))
		return true;
	
	// CTerrorPlayer::IsGettingUp function does not check Charger GettingUp.
	Address pPlayerAnimState = LoadFromAddress(GetEntityAddress(client) + view_as<Address>(g_iPlayerAnimStateOffset), NumberType_Int32);
	if (pPlayerAnimState && SDKCall(g_hSDK_IsPounded, pPlayerAnimState))
		return true;

	return false;
}

int GetIconClient(int ref)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iIconRef[i] == ref)
			return i;
	}
	return -1;
}

void Init()
{
	char sBuffer[128];

	strcopy(sBuffer, sizeof(sBuffer), "l4d2_black_and_white_notifier");
	GameData hGameData = new GameData(sBuffer);
	if (hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", sBuffer);

	strcopy(sBuffer, sizeof(sBuffer), "m_PlayerAnimState");
	g_iPlayerAnimStateOffset = hGameData.GetOffset(sBuffer);
	if (g_iPlayerAnimStateOffset == -1)
		SetFailState("Failed to GetOffset: %s", sBuffer);

	// bool CTerrorPlayer::IsDominatedBySpecialInfected(void)
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorPlayer::IsDominatedBySpecialInfected");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_IsDominatedBySpecialInfected = EndPrepSDKCall();
	if(g_hSDK_IsDominatedBySpecialInfected == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// bool CTerrorPlayer::IsGettingUp(void)
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorPlayer::IsGettingUp");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_IsGettingUp = EndPrepSDKCall();
	if(g_hSDK_IsGettingUp == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);

	// bool CTerrorPlayerAnimState::IsPounded(void)
	strcopy(sBuffer, sizeof(sBuffer), "CTerrorPlayerAnimState::IsPounded");
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sBuffer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_IsPounded = EndPrepSDKCall();
	if(g_hSDK_IsPounded == null)
		SetFailState("Failed to create SDKCall: %s", sBuffer);
	
	delete hGameData;
}
