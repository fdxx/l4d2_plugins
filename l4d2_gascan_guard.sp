#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define VERSION "0.1"

public Plugin myinfo = 
{
	name = "L4D2 Gascan guard",
	author = "fdxx",
	description = "Avoid damage when the gascan is in the air",
	version = VERSION,
}

public void OnPluginStart()
{
	CreateConVar("l4d2_gascan_guard_version", VERSION, "version", FCVAR_NONE | FCVAR_DONTRECORD);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (classname[0] == 'w' || classname[0] == 'p')
	{
		if (strncmp(classname, "weapon_gascan", 13) == 0 || strcmp(classname, "prop_physics") == 0)
		{
			RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
		}
	}
}

public void OnNextFrame(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if (IsValidEntity(entity))
	{
		static char sModel[PLATFORM_MAX_PATH];
		if (GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel)) > 1)
		{
			if (strcmp(sModel, "models/props_junk/gascan001a.mdl") == 0)
			{
				SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
				SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsInTheAir(victim))
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

// FL_ONGROUND and m_hGroundEntity don't work
bool IsInTheAir(int entity)
{
	static float fStartPos[3], fEndPos[3];

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fStartPos);
	fEndPos[0] = fStartPos[0];
	fEndPos[1] = fStartPos[1];
	fEndPos[2] = fStartPos[2] - 12.0;

	Handle hTrace = TR_TraceRayFilterEx(fStartPos, fEndPos, MASK_SHOT, RayType_EndPoint, TraceFilter, entity);
	bool bInTheAir = !TR_DidHit(hTrace);

	delete hTrace;
	return bInTheAir;
}

public bool TraceFilter(int entity, int contentsMask, int self)
{
	if (entity <= MaxClients || entity == self)
	{
		return false;
	}
   	return true;
}
