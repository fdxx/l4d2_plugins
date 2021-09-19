#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

bool g_bTrainTankSpawn;

public Plugin myinfo = 
{
	name = "L4D2 Train door fix",
	author = "fdxx",
	description = "Remove shit second train door on c7m1 map",
	version = "0.2",
	url = ""
};

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	RegAdminCmd("sm_deldoor", deldoor, ADMFLAG_ROOT);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bTrainTankSpawn = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (IsC7M1Map() && !g_bTrainTankSpawn)
	{
		int iTank = GetClientOfUserId(event.GetInt("userid"));

		if (IsTank(iTank))
		{
			float fPos[3];
			GetClientAbsOrigin(iTank, fPos);
			float fDistance = GetVectorDistance(fPos, view_as<float>({6947.4, 684.9, 167.1}));
			//LogMessage("pos: {%.1f, %.1f, %.1f} 距离：%.1f", fPos[0], fPos[1], fPos[2], fDistance);
			if (fDistance <= 100.0)
			{
				g_bTrainTankSpawn = true;
			}
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (IsC7M1Map() && g_bTrainTankSpawn)
	{
		int iTank = GetClientOfUserId(event.GetInt("userid"));

		if (IsTank(iTank))
		{
			DelSecondTrainDoor();
			g_bTrainTankSpawn = false;
		}
	}
	return Plugin_Continue;
}

void DelSecondTrainDoor()
{
	char sEntClassName[256], sTargetName[256];

	for (int i = MaxClients+1; i <= GetMaxEntities(); i++)
	{
		if (IsValidEntity(i))
		{
			if (GetEdictClassname(i, sEntClassName, sizeof(sEntClassName)))
			{
				if (strcmp(sEntClassName, "func_movelinear") == 0)
				{
					if (GetEntPropString(i, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName)) > 1)
					{
						if (strcmp(sTargetName, "tankdoorout") == 0)
						{
							float fDoorPos[3];
							GetEntPropVector(i, Prop_Data, "m_vecOrigin", fDoorPos);

							for (int b = MaxClients+1; b <= GetMaxEntities(); b++)
							{
								if (IsValidEntity(b))
								{
									if (GetEdictClassname(b, sEntClassName, sizeof(sEntClassName)))
									{
										if (strcmp(sEntClassName, "func_button_timed") == 0)
										{
											if (GetEntPropString(b, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName)) > 1)
											{
												if (strcmp(sTargetName, "tankdoorout_button") == 0)
												{
													float fButtonPos[3];
													GetEntPropVector(b, Prop_Data, "m_vecOrigin", fButtonPos);
													//LogMessage("距离 %.1f", GetVectorDistance(fDoorPos, fButtonPos));
													if (GetVectorDistance(fDoorPos, fButtonPos) <= 7.0)
													{
														RemoveEntity(b);
														//LogMessage("删除 tankdoorout_button");
														break;
													}
												}
											}
										}
									}
								}
							}

							RemoveEntity(i);
							//LogMessage("删除 tankdoorout");
							break;
						}
					}
				}
			}
		}
	}
}

public Action deldoor(int client, int args)
{
	DelSecondTrainDoor();
}

bool IsC7M1Map()
{
	static char sCurMap[256];
	GetCurrentMap(sCurMap, sizeof(sCurMap));
	return (strcmp(sCurMap, "c7m1_docks", false) == 0);
}

bool IsTank(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}
