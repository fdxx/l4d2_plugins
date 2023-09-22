/*
sv_vote_issue_change_difficulty_allowed
sv_vote_issue_change_map_later_allowed   
sv_vote_issue_change_map_now_allowed    
sv_vote_issue_change_mission_allowed    
sv_vote_issue_kick_allowed              
sv_vote_issue_restart_game_allowed  
sv_vote_returnlobby_allowed // Created by this plugin. 
*/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "0.1"

MemoryPatch g_mPatch;

public Plugin myinfo = 
{
	name = "L4D2 Vote Return Lobby patch",
	author = "fdxx",
	version = VERSION,
	description = "Create cvar sv_vote_returnlobby_allowed.",
};

public void OnPluginStart()
{
	CreateConVar("l4d2_vote_returnlobby_patch_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	ConVar cvar = CreateConVar("sv_vote_returnlobby_allowed", "0", "Can people hold votes to return lobby?");
	OnConVarChanged(cvar, "", "");
	cvar.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	delete g_mPatch;
	if (!convar.BoolValue)
	{
		GameData hGameData = new GameData("l4d2_vote_returnlobby_patch");

		g_mPatch = MemoryPatch.CreateFromConf(hGameData, "CReturnToLobbyIssue::CanCallVote");
		if (!g_mPatch.Validate())
			SetFailState("Verify patch failed!");
		if (!g_mPatch.Enable())
			SetFailState("Enable patch failed!");

		delete hGameData;
	}
}

