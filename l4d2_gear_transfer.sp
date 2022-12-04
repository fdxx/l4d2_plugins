#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <sourcescramble>	// https://github.com/nosoop/SMExt-SourceScramble

#define PLUGIN_VERSION "0.1"

#define SOUND_GIVE		"ui/bigreward.wav"
#define SOUND_RECEIVE	"ui/littlereward.wav"

#define EF_NODRAW		32
#define ANIMEVENT_USE	64

#define WEAPON_SLOT			0
#define WEAPON_NAME			1
#define WEAPON_MODEL		2
#define WEAPON_TRANSLATE	3

static const char g_sWeapons[][][] = 
{
	{"2",	"weapon_molotov",					"models/w_models/weapons/w_eq_molotov.mdl",				"燃烧瓶"},
	{"2",	"weapon_pipe_bomb",					"models/w_models/weapons/w_eq_pipebomb.mdl",			"土制炸弹"},
	{"2",	"weapon_vomitjar",					"models/w_models/weapons/w_eq_bile_flask.mdl",			"胆汁瓶"},

	{"3",	"weapon_first_aid_kit",				"models/w_models/weapons/w_eq_Medkit.mdl",				"急救包"},
	{"3",	"weapon_defibrillator",				"models/w_models/weapons/w_eq_defibrillator.mdl",		"电击除颤器"},
	{"3",	"weapon_upgradepack_incendiary",	"models/w_models/weapons/w_eq_incendiary_ammopack.mdl",	"燃烧弹升级包"},
	{"3",	"weapon_upgradepack_explosive",		"models/w_models/weapons/w_eq_explosive_ammopack.mdl",	"高爆弹升级包"},	

	{"4",	"weapon_pain_pills",				"models/w_models/weapons/w_eq_painpills.mdl",			"止痛药"},
	{"4",	"weapon_adrenaline",				"models/w_models/weapons/w_eq_adrenaline.mdl",			"肾上腺素"},
};

Handle
	g_hFindUseEntity,
	g_hUseEntity,
	g_hDoAnimationEvent,
	g_hIsBaseCombatWeapon,
	g_hGetSlot,
	g_hGetDropTarget,
	g_hGiveActiveWeapon,
	g_hSDKIsVisibleToPlayer,
	g_hAutoTransferTimer,
	g_hRoundStartDelayTimer;
	
ConVar
	g_cvBotGiveDist,
	g_cvPlayerGiveDist,
	g_cvGrabDist,
	g_cvCheckTime,
	g_cvDelayCheck,
	g_cvDelayTransfer,
	z_use_belt_item_tolerance;

bool
	g_bCanGive[MAXPLAYERS][5],
	g_bCanReceive[MAXPLAYERS][5];

float
	g_fBotGiveDist,
	g_fPlayerGiveDist,
	g_fGrabDist,
	g_fCheckTime,
	g_fDelayCheck,
	g_fDelayTransfer,
	g_fUseTolerance,
	g_fLastReceivedTime[MAXPLAYERS],
	g_fEyePos[MAXPLAYERS][3];

StringMap
	g_smNameToNum,
	g_smModelToNum;

ArrayList
	g_aEntData;

enum struct EntData
{
	int ref;
	int slot;
	float fPos[3];
	bool bCanGrab;
	int num;
}

public Plugin myinfo =
{
	name = "L4D2 Gear Transfer",
	author = "SilverShot, fork by fdxx",
	description = "Survivor bots can automatically pickup and give items. Players can give items.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=137616"
}

public void OnPluginStart()
{
	Init();

	CreateConVar("l4d2_gear_transfer_version", PLUGIN_VERSION, "Version", FCVAR_DONTRECORD);
	z_use_belt_item_tolerance = FindConVar("z_use_belt_item_tolerance");

	g_cvBotGiveDist =		CreateConVar("l4d2_gear_transfer_bot_give_dist",	"150.0", "How close the bot must be to transfer the item.");
	g_cvPlayerGiveDist =	CreateConVar("l4d2_gear_transfer_player_give_dist",	"256.0", "How close the player must be to transfer the item.");
	g_cvGrabDist =			CreateConVar("l4d2_gear_transfer_dist_grab",		"150.0", "How close the bots need to be for them to pick up an item.");
	g_cvCheckTime =			CreateConVar("l4d2_gear_transfer_check_time",		"1.0",	"How often to check bot for auto grab/give. 0.0=disable auto grab/give");
	g_cvDelayCheck =		CreateConVar("l4d2_gear_transfer_delay_check",		"-1.0", "How many seconds to delay auto grab/give after a new round starts. -1.0=PlayerLeftSafeArea, 0.0=NoDelay, GreaterThan 0.0=DelayTime.");
	g_cvDelayTransfer =		CreateConVar("l4d2_gear_transfer_delay_transfer",	"10.0", "How many seconds after the bot receives the given item before it can transfer the item again.");
	
	OnConVarChanged(null, "", "");
	
	g_cvBotGiveDist.AddChangeHook(OnConVarChanged);
	g_cvPlayerGiveDist.AddChangeHook(OnConVarChanged);
	g_cvGrabDist.AddChangeHook(OnConVarChanged);
	g_cvCheckTime.AddChangeHook(OnConVarChanged);
	g_cvDelayCheck.AddChangeHook(OnConVarChanged);
	g_cvDelayTransfer.AddChangeHook(OnConVarChanged);
	z_use_belt_item_tolerance.AddChangeHook(OnConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
	HookEvent("weapon_given", Event_WeaponGiven);

	AutoExecConfig(true, "l4d2_gear_transfer");
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fBotGiveDist = g_cvBotGiveDist.FloatValue;
	g_fPlayerGiveDist = g_cvPlayerGiveDist.FloatValue;
	g_fGrabDist = g_cvGrabDist.FloatValue;
	g_fCheckTime = g_cvCheckTime.FloatValue;
	g_fDelayCheck = g_cvDelayCheck.FloatValue;
	g_fDelayTransfer = g_cvDelayTransfer.FloatValue;
	g_fUseTolerance = z_use_belt_item_tolerance.FloatValue;
}

public void OnConfigsExecuted()
{
	static bool shit;
	if (shit) return;
	shit = true;

	Event_RoundStart(null, "", true);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hAutoTransferTimer;
	delete g_hRoundStartDelayTimer;

	if (g_fDelayCheck == 0.0)
		g_hAutoTransferTimer = CreateTimer(g_fCheckTime, AutoTransfer_Timer, _, TIMER_REPEAT);

	else if (g_fDelayCheck > 0.0)
		g_hRoundStartDelayTimer = CreateTimer(g_fDelayCheck, RoundStartDelay_Timer);
}

Action RoundStartDelay_Timer(Handle timer)
{
	delete g_hAutoTransferTimer;
	g_hAutoTransferTimer = CreateTimer(g_fCheckTime, AutoTransfer_Timer, _, TIMER_REPEAT);

	g_hRoundStartDelayTimer = null;
	return Plugin_Continue;
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
	if (g_fDelayCheck < 0.0)
	{
		delete g_hAutoTransferTimer;
		g_hAutoTransferTimer = CreateTimer(g_fCheckTime, AutoTransfer_Timer, _, TIMER_REPEAT);
	}
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
	delete g_hAutoTransferTimer;
	delete g_hRoundStartDelayTimer;
	g_aEntData.Clear();
}

public void OnMapStart()
{
	PrecacheSound(SOUND_GIVE, true);
	PrecacheSound(SOUND_RECEIVE, true);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (classname[0] == 'w')
		RequestFrame(NextFrame_EntityCreated, EntIndexToEntRef(entity));	
}

void NextFrame_EntityCreated(int ref)
{
	static char sEntName[64], sModel[PLATFORM_MAX_PATH];
	static int ent, num;
	static EntData data;

	ent = EntRefToEntIndex(ref);
	if (ent > MaxClients && IsValidEntity(ent))
	{
		if (GetEdictClassname(ent, sEntName, sizeof(sEntName)) && GetEntPropString(ent, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
		{
			if (g_smModelToNum.GetValue(sModel, num) || g_smNameToNum.GetValue(sEntName, num))
			{
				if (g_aEntData.FindValue(ref) == -1)
				{
					data.ref = ref;
					data.slot = StringToInt(g_sWeapons[num][WEAPON_SLOT]);
					data.num = num;
					g_aEntData.PushArray(data);
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (buttons & IN_RELOAD == 0)
		return Plugin_Continue;
	
	if (IsValidSur(client) && !IsFakeClient(client) && IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		int slot = GetSlotFromEnt(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"));
		if (2 <= slot <= 4)
		{
			int target = SDKCall(g_hFindUseEntity, client, g_fPlayerGiveDist, 0.0, g_fUseTolerance, 0, true);
			if (IsValidSur(target) && IsPlayerAlive(target) && !GetEntProp(target, Prop_Send, "m_isIncapacitated"))
			{
				SDKCall(g_hGiveActiveWeapon, client, target);
			}
		}
	}

	return Plugin_Continue;
}

Action AutoTransfer_Timer(Handle timer)
{
	// ------ Initialize ------
	for (int i; i <= MaxClients; i++)
	{
		for (int slot; slot <= 4; slot++)
		{
			g_bCanGive[i][slot] = false;
			g_bCanReceive[i][slot] = false;
		}
	}

	int iBotCount;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
		{
			if (IsFakeClient(i))
			{
				iBotCount++;

				if (IsDoingUseAction(i) || HasIdlePlayer(i) || GetEntPropEnt(i, Prop_Send, "m_reviveTarget") > 0)
					continue;
			}
				
			GetClientEyePosition(i, g_fEyePos[i]);

			for (int slot = 2; slot <= 4; slot++)
			{
				int ent = GetPlayerWeaponSlot(i, slot);
				if (ent > MaxClients && IsValidEntity(ent))
					g_bCanGive[i][slot] = true;
				else g_bCanReceive[i][slot] = true;
			}
		}
	}

	if (iBotCount == 0)
		return Plugin_Continue;


	static EntData data;
	int len = g_aEntData.Length;

	for (int i; i < len; i++)
	{
		g_aEntData.GetArray(i, data);
		int ent = EntRefToEntIndex(data.ref);
		if (ent > MaxClients && IsValidEntity(ent))
		{
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", data.fPos);
			data.bCanGrab = IsCanGrab(ent);
			g_aEntData.SetArray(i, data);
		}
		else
		{
			g_aEntData.Erase(i);
			i--;
			len--;
		}
	}
	
	
	// ------ Auto Grab ------
	for (int graber = 1; graber <= MaxClients; graber++)
	{
		for (int slot = 2; slot <= 4; slot++)
		{
			if (g_bCanReceive[graber][slot] && IsFakeClient(graber))
			{
				for (int i; i < len; i++)
				{
					g_aEntData.GetArray(i, data);
					if (data.slot == slot && data.bCanGrab && GetVectorDistance(g_fEyePos[graber], data.fPos) < g_fGrabDist)
					{
						int ent = EntRefToEntIndex(data.ref);
						if (ent > MaxClients && IsValidEntity(ent))
						{
							data.bCanGrab = false;
							g_aEntData.SetArray(i, data);

							g_bCanReceive[graber][slot] = false;

							SDKCall(g_hDoAnimationEvent, graber, ANIMEVENT_USE, 0);
							SDKCall(g_hUseEntity, ent, graber, graber, Use_On, 0.0);
							
							// Items not transferred by this plugin will not be notified.
							PrintToChatAll("\x05%N \x01拿了 \x04%s", graber, g_sWeapons[data.num][WEAPON_TRANSLATE]);

							break;
						}
						else
						{
							g_aEntData.Erase(i);
							i--;
							len--;
						}
					}
				}
			}
		}
	}

	float fNow = GetEngineTime();

	// ------ Auto Give ------
	for (int giver = 1; giver <= MaxClients; giver++)
	{
		for (int slot = 2; slot <= 4; slot++)
		{
			if (g_bCanGive[giver][slot] && IsFakeClient(giver) && fNow - g_fLastReceivedTime[giver] > g_fDelayTransfer)
			{
				for (int target = 1; target <= MaxClients; target++)
				{
					if (g_bCanReceive[target][slot] && !IsFakeClient(target))
					{
						if (GetVectorDistance(g_fEyePos[giver], g_fEyePos[target]) < g_fBotGiveDist && SDKCall(g_hSDKIsVisibleToPlayer, g_fEyePos[target], giver, 2, 3, 0.0, 0, 0, false))
						{
							int ent = GetPlayerWeaponSlot(giver, slot);
							if (ent > MaxClients && IsValidEntity(ent))
							{
								g_bCanGive[giver][slot] = false;
								g_bCanReceive[target][slot] = false;

								SetEntPropEnt(giver, Prop_Send, "m_hActiveWeapon", ent);
								SDKCall(g_hGiveActiveWeapon, giver, target);

								break;
							}
							else
							{
								g_bCanGive[giver][slot] = false;
								break;
							}
						}
					}
				}
			}
		}
	}

	return Plugin_Continue;
}

// From left4dhooks
enum
{
	L4D2UseAction_None				= 0, // No use action active
	L4D2UseAction_Healing			= 1, // Includes healing yourself or a teammate.
	L4D2UseAction_Defibing			= 4, // When defib'ing a dead body.
	L4D2UseAction_GettingDefibed	= 5, // When comming back to life from a dead body.
	L4D2UseAction_PouringGas		= 8, // Pouring gas into a generator
	L4D2UseAction_Cola				= 9, // For Dead Center map 2 cola event, when handing over the cola to whitalker.
	L4D2UseAction_Button			= 10 // Such as buttons, timed buttons, generators, etc.
	/* List is not fully done, these are just the ones I have found so far */
}

bool IsDoingUseAction(int client)
{
	switch (GetEntProp(client, Prop_Send, "m_iCurrentUseAction"))
	{
		case L4D2UseAction_Healing:
		{
			int target = GetEntPropEnt(client, Prop_Send, "m_useActionTarget");
			if (target > 0 && target != client) // exclude self healing.
			{
				return true;
			}
		}
		case L4D2UseAction_Defibing, L4D2UseAction_GettingDefibed, L4D2UseAction_PouringGas, L4D2UseAction_Cola, L4D2UseAction_Button:
			return true;
	}
	return false;
}

bool HasIdlePlayer(int bot) 
{
	static char sNetClass[12];
	static int offset, player;

	GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));
	offset = FindSendPropInfo(sNetClass, "m_humanSpectatorUserID");

	if (offset > 0)
	{
		player = GetClientOfUserId(GetEntData(bot, offset));
		if (player > 0 && IsClientConnected(player) && !IsFakeClient(player))
			return true;
	}

	return false;
}

bool IsCanGrab(int entity)
{
	// Carried by the player.
	if (IsCarriedByClient(entity))
		return false;
	
	// This should not happen.
	if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") > 0)
		return false;

	// Invisible.
	// https://developer.valvesoftware.com/wiki/EF_NODRAW
	if (GetEntProp(entity, Prop_Send, "m_fEffects") & EF_NODRAW)
		return false;
	
	// Transferring, or transfer fails and the item falls on the ground for less than 5 seconds.
	if (SDKCall(g_hIsBaseCombatWeapon, entity) && SDKCall(g_hGetDropTarget, entity) > 0)
		return false;
	
	return true;
}

// https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/shared/shareddefs.h#L180
bool IsCarriedByClient(int entity)
{
	if (HasEntProp(entity, Prop_Data, "m_iState"))
		return GetEntProp(entity, Prop_Data, "m_iState") > 0;
	return false;
}

void Event_WeaponGiven(Event event, const char[] name, bool dontBroadcast)
{
	static int ent, giver, target, num, slot;
	static char sEntName[64];

	ent = event.GetInt("weaponentid");
	giver = GetClientOfUserId(event.GetInt("giver"));
	target = GetClientOfUserId(event.GetInt("userid"));

	if (IsValidSur(giver) && IsPlayerAlive(giver))
	{
		if (IsValidSur(target) && IsPlayerAlive(target))
		{
			if (ent > MaxClients && IsValidEntity(ent) && GetEdictClassname(ent, sEntName, sizeof(sEntName)))
			{
				if (g_smNameToNum.GetValue(sEntName, num))
				{
					slot = StringToInt(g_sWeapons[num][WEAPON_SLOT]);
					if (2 <= slot <= 4)
					{
						// Items not transferred by this plugin will also be notified.
						PrintToChatAll("\x05%N \x01给了 \x05%N \x04%s", giver, target, g_sWeapons[num][WEAPON_TRANSLATE]);

						if (IsFakeClient(target))
						{
							g_fLastReceivedTime[target] = GetEngineTime();
						}

						if (slot != 4)
						{
							EmitSoundToClient(giver, SOUND_GIVE);
							EmitSoundToClient(target, SOUND_RECEIVE);
						}
					}
				}
			}
		}
	}
}

int GetSlotFromEnt(int entity)
{
	if (entity > MaxClients && IsValidEntity(entity) && SDKCall(g_hIsBaseCombatWeapon, entity))
		return SDKCall(g_hGetSlot, entity);
	return -1;
}

bool IsValidSur(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			return true;
		}
	}
	return false;
}

void Init()
{
	GameData hGameData = new GameData("l4d2_gear_transfer");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_gear_transfer.txt\" gamedata.");

	// https://github.com/lua9520/source-engine-2018-cstrike15_src/blob/master/game/shared/cstrike15/weapon_baseitem.cpp#L131
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "FindUseEntity");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);				// range
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);				// unknown
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);				// tolerance
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);		// unknown bool pointer
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);				// player priority
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hFindUseEntity = EndPrepSDKCall();
	if (g_hFindUseEntity == null)
		SetFailState("Failed to create SDKCall: FindUseEntity");

	// void CBaseEntity::Use( CBaseEntity *pActivator, CBaseEntity *pCaller, USE_TYPE useType, float value ) 
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "UseEntity");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);	
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); 
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);	
	g_hUseEntity = EndPrepSDKCall();
	if (g_hUseEntity == null)
		SetFailState("Failed to create SDKCall: UseEntity");

	// bool CBaseCombatWeapon::IsBaseCombatWeapon()
	// CBaseEntity -> CBaseAnimating -> CBaseCombatWeapon -> CWeaponCSBase -> CTerrorWeapon
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "IsBaseCombatWeapon");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hIsBaseCombatWeapon = EndPrepSDKCall();
	if (g_hIsBaseCombatWeapon == null)
		SetFailState("Failed to create SDKCall: IsBaseCombatWeapon");

	// int CBaseCombatWeapon::GetSlot()
	// Only valid for weapons already carried. (CBaseCombatWeapon)
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetSlot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hGetSlot = EndPrepSDKCall();
	if (g_hGetSlot == null)
		SetFailState("Failed to create SDKCall: GetSlot");

	// CBaseEntity* CTerrorWeapon::GetDropTarget()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetDropTarget");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hGetDropTarget = EndPrepSDKCall();
	if (g_hGetDropTarget == null)
		SetFailState("Failed to create SDKCall: GetDropTarget");

	// void CTerrorPlayer::DoAnimationEvent(PlayerAnimEvent_t, int)
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::DoAnimationEvent");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hDoAnimationEvent = EndPrepSDKCall();
	if (g_hDoAnimationEvent == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::DoAnimationEvent");

	// void CTerrorPlayer::GiveActiveWeapon(CTerrorPlayer*)
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GiveActiveWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hGiveActiveWeapon = EndPrepSDKCall();
	if (g_hGiveActiveWeapon == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GiveActiveWeapon");

	// bool IsVisibleToPlayer(Vector const&, CBasePlayer *, int, int, float, CBaseEntity const*, TerrorNavArea **, bool *);
	// SDKCall(g_hSDKIsVisibleToPlayer, g_fEyePos[target], giver, 2, 3, 0.0, 0, 0, false)
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "IsVisibleToPlayer");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsVisibleToPlayer = EndPrepSDKCall();
	if (g_hSDKIsVisibleToPlayer == null)
		SetFailState("Failed to create SDKCall: IsVisibleToPlayer");

	// Cancel slot limit. (game only supports slot 4)
	MemoryPatch mPatch = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::GiveActiveWeapon");
	if (!mPatch.Validate())
		SetFailState("Verify patch failed.");
	if (!mPatch.Enable())
		SetFailState("Enable patch failed.");
	
	// NOP Weapon_Switch function.
	mPatch = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::OnGivenWeapon");
	if (!mPatch.Validate())
		SetFailState("Verify patch failed.");
	if (!mPatch.Enable())
		SetFailState("Enable patch failed.");
	
	delete hGameData;

	g_aEntData = new ArrayList(sizeof(EntData));
	g_smNameToNum = new StringMap();
	g_smModelToNum = new StringMap();

	for (int i; i < sizeof(g_sWeapons); i++)
	{
		g_smNameToNum.SetValue(g_sWeapons[i][WEAPON_NAME], i);
		g_smModelToNum.SetValue(g_sWeapons[i][WEAPON_MODEL], i);
	}
}
