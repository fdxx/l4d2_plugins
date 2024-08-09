#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>  

#define VERSION "0.4"

#define SOUND "ui/helpful_event_1.wav"
#define CFG_FILE "data/l4d2_gift.cfg"

#define COMMAND_MAX_LENGTH 511

#define GNFLAG_NONE 0
#define GNFLAG_CHAT 1
#define GNFLAG_SOUND 2

ConVar
	g_cvChance,
	g_cvNotify,
	g_cvGiftTime,
	g_cvCfgPath;

Handle
	g_hSDK_CreateGift,
	g_hGiftTimer;

ArrayList
	g_aAward,
	g_aGift;

int
	g_iNotify,
	g_iTotalWeights;

float
	g_fChance,
	g_fGiftTime;


char g_sCfgPath[PLATFORM_MAX_PATH];

enum struct award_t
{
	char type[32];
	char cmd[COMMAND_MAX_LENGTH];
	char cmdArgs[COMMAND_MAX_LENGTH];
	int weights;
	char message[MAX_MESSAGE_LENGTH];
}

enum struct gift_t
{
	int ref;
	float fSpawnTime;
}

public Plugin myinfo = 
{
	name = "L4D2 Gift",
	author = "fdxx",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_gift_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
	g_cvChance = CreateConVar("l4d2_gift_chance", "0.03", "Probability of a gift box appearing (0.0-1.0).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvNotify = CreateConVar("l4d2_gift_notify", "3", "Notify award info. 0=None, 1=Chat message, 2=Play sound, 3=Both.", FCVAR_NONE, true, 0.0, true, 3.0);
	g_cvGiftTime = CreateConVar("l4d2_gift_time", "75", "Time for the gift to disappear automatically (in seconds), 0=permanent.");
	g_cvCfgPath = CreateConVar("l4d2_gift_cfg", CFG_FILE, "config file path");

	OnConVarChanged(null, "", "");

	g_cvChance.AddChangeHook(OnConVarChanged);
	g_cvNotify.AddChangeHook(OnConVarChanged);
	g_cvGiftTime.AddChangeHook(OnConVarChanged);
	g_cvCfgPath.AddChangeHook(OnConVarChanged);

	HookEvent("christmas_gift_grab", Event_GiftGrab);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	RegAdminCmd("sm_award_weights", Cmd_SetWeights, ADMFLAG_ROOT);
	RegAdminCmd("sm_award_reload", Cmd_Reload, ADMFLAG_ROOT);

	RegAdminCmd("sm_award_list", Cmd_List, ADMFLAG_ROOT);
	RegAdminCmd("sm_award_test", Cmd_Test, ADMFLAG_ROOT);

	CreateTimer(2.0, Init_Timer);
}

Action Init_Timer(Handle timer)
{
	Init();
	return Plugin_Continue;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fChance = g_cvChance.FloatValue;
	g_iNotify = g_cvNotify.IntValue;
	g_fGiftTime = g_cvGiftTime.FloatValue;
	g_cvCfgPath.GetString(g_sCfgPath, sizeof(g_sCfgPath));

	if (convar == g_cvCfgPath)
		Init();

	delete g_hGiftTimer;
	if (g_fGiftTime > 0.0)
		g_hGiftTimer = CreateTimer(1.0, GiftRemoveCheck_Timer, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	if (!IsModelPrecached("models/w_models/weapons/w_sniper_awp.mdl"))
		PrecacheModel("models/w_models/weapons/w_sniper_awp.mdl", true);
	PrecacheSound(SOUND, true);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_aGift)
		g_aGift.Clear();
}

Action GiftRemoveCheck_Timer(Handle timer)
{
	if (!g_aGift)
		return Plugin_Continue;
		
	int len = g_aGift.Length;
	if (!len)
		return Plugin_Continue;

	gift_t gift;
	float fCurTime = GetEngineTime();
	int entity;

	for (int i = 0; i < len; i++)
	{
		g_aGift.GetArray(i, gift);
		entity = EntRefToEntIndex(gift.ref);

		if (!IsValidEntity(entity))
		{
			g_aGift.Erase(i);
			i--;
			len--;
			continue;
		}

		if (fCurTime - gift.fSpawnTime > g_fGiftTime)
			RemoveEntity(entity);
	}

	return Plugin_Continue;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 3)
	{
		if (GetURandomFloat() < g_fChance)
		{
			float fAbsOrigin[3], fAbsAngles[3], fEyeAngles[3], fAbsVelocity[3];
			GetClientAbsOrigin(client, fAbsOrigin);
			GetClientAbsAngles(client, fAbsAngles);
			GetClientEyeAngles(client, fEyeAngles);
			int entity = SDKCall(g_hSDK_CreateGift, fAbsOrigin, fAbsAngles, fEyeAngles, fAbsVelocity, client);

			gift_t gift;
			gift.ref = EntIndexToEntRef(entity);
			gift.fSpawnTime = GetEngineTime();
			g_aGift.PushArray(gift);
		}
	}
}

void Event_GiftGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		award_t award;
		WeightedRandomSelect(award);
		ExecRewards(client, award);

		if (g_iNotify & GNFLAG_CHAT)
		{
			CPrintToChatAll("{blue}[Gift] {olive}%N {default}%s", client, award.message);
		}
			
		if (g_iNotify & GNFLAG_SOUND)
		{
			float origin[3];
			GetClientAbsOrigin(client, origin);
			EmitAmbientSound(SOUND, origin);
		}
	} 
}

int WeightedRandomSelect(award_t award)
{
	int randomNum;
	if (g_iTotalWeights < 1)
	{
		randomNum = GetURandomInt() % g_aAward.Length;
		g_aAward.GetArray(randomNum, award);
		return randomNum;
	}
	
	randomNum = GetURandomInt() % g_iTotalWeights;
	for (int i = 0, len = g_aAward.Length; i < len; i++)
	{
		g_aAward.GetArray(i, award); 
		if (randomNum < award.weights)
			return i;
		randomNum -= award.weights;
	}

	LogError("WTF?");
	return -1;
}

void ExecRewards(int client, const award_t award)
{
	// Valve cvars cheat command. (give xx)
	if (!strcmp(award.type, "CheatCommand", false))
	{
		int iFlags = GetCommandFlags(award.cmd);
		SetCommandFlags(award.cmd, iFlags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "%s %s", award.cmd, award.cmdArgs);
		SetCommandFlags(award.cmd, iFlags);
	}

	// Normal client command. (RegConsoleCmd)
	else if (!strcmp(award.type, "ClientCommand", false))
	{
		ClientCommand(client, "%s", award.cmd);
	}

	// Server command. (RegServerCmd/RegAdminCmd)
	else if (!strcmp(award.type, "ServerCommand", false))
	{
		ServerCommand("%s", award.cmd);
	}
}

Action Cmd_Reload(int client, int args)
{
	Init();
	return Plugin_Handled;
}

Action Cmd_SetWeights(int client, int args)
{
	if (args != 2)
	{
		char cmd[128];
		GetCmdArg(0, cmd, sizeof(cmd));
		ReplyToCommand(client, "Syntax: %s <index> <weights>", cmd);
		return Plugin_Handled;
	}
	
	int index = GetCmdArgInt(1);
	award_t award;

	g_aAward.GetArray(index, award);
	award.weights = GetCmdArgInt(2);
	g_aAward.SetArray(index, award);

	g_iTotalWeights = GetTotalWeights();
	return Plugin_Handled;
}


Action Cmd_List(int client, int args)
{
	award_t award;
	for (int i = 0; i < g_aAward.Length; i++)
	{
		g_aAward.GetArray(i, award);
		ReplyToCommand(client, "[%i] %s, %s %s, %i, %s", i, award.type, award.cmd, award.cmdArgs, award.weights, award.message);
	}
	return Plugin_Handled;
}

Action Cmd_Test(int client, int args)
{
	award_t award;
	int[] nums = new int[g_aAward.Length];

	int count = 1000000;
	if (args) 
		count = GetCmdArgInt(1);

	for (int i = 0; i < count; i++)
		nums[WeightedRandomSelect(award)]++;

	for (int i = 0; i < g_aAward.Length; i++)
	{
		g_aAward.GetArray(i, award);
		ReplyToCommand(client, "[%i] cmd = %s %s, weights = %i, expected = %.4f, actual = %.4f", i, award.cmd, award.cmdArgs, award.weights, float(award.weights)/g_iTotalWeights, float(nums[i])/count);
	}

	return Plugin_Handled;
}

void Init()
{
	delete g_aAward;
	delete g_aGift;
	g_aAward = new ArrayList(sizeof(award_t));
	g_aGift = new ArrayList(sizeof(gift_t));

	GameData hGameData = new GameData("l4d2_gift");
	char buffer[COMMAND_MAX_LENGTH];

	// CHolidayGift* CHolidayGift::Create( const Vector &position, const QAngle &angles, const QAngle &eyeAngles, const Vector &velocity, CBaseCombatCharacter *pOwner )
	// CHolidayGift::Create( WorldSpaceCenter(), GetAbsAngles(), EyeAngles(), GetAbsVelocity(), this );
	strcopy(buffer, sizeof(buffer), "CHolidayGift::Create");
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, buffer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	delete g_hSDK_CreateGift;
	g_hSDK_CreateGift = EndPrepSDKCall();
	if (g_hSDK_CreateGift == null)
		SetFailState("Failed to create SDKCall: %s", buffer);

	delete hGameData;

	// --------------------------------
	BuildPath(Path_SM, buffer, sizeof(buffer), "%s", g_sCfgPath);
	KeyValues kv = new KeyValues("");
	if (!kv.ImportFromFile(buffer))
		SetFailState("Failed to load %s", buffer);

	for (bool iter = kv.GotoFirstSubKey(); iter; iter = kv.GotoNextKey())
	{
		award_t award;

		kv.GetString("type", award.type, sizeof(award.type));
		kv.GetString("command", buffer, sizeof(buffer));
		award.weights = kv.GetNum("weights");
		kv.GetString("message", award.message, sizeof(award.message));
		
		if (!strcmp(award.type, "CheatCommand", false))
		{
			int num = SplitString(buffer, " ", award.cmd, sizeof(award.cmd));
			if (num != -1)
				strcopy(award.cmdArgs, sizeof(award.cmdArgs), buffer[num]);
			else
				strcopy(award.cmd, sizeof(award.cmd), buffer);
		}
		else 
			strcopy(award.cmd, sizeof(award.cmd), buffer);
		
		g_aAward.PushArray(award);
	}

	delete kv;
	g_iTotalWeights = GetTotalWeights();
}

int GetTotalWeights()
{
	int count;
	award_t award;

	for (int i = 0, len = g_aAward.Length; i < len; i++)
	{
		g_aAward.GetArray(i, award);
		count += award.weights;
	}

	return count;
}
