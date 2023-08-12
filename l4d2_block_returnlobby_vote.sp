#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

#define VERSION "0.1"

public Plugin myinfo = 
{
	name = "L4D2 Block Return Lobby Vote",
	author = "fdxx",
	version = VERSION,
};

public void OnPluginStart()
{
	CreateConVar("l4d2_block_returnlobby_vote_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	GameData hGameData = new GameData("l4d2_block_returnlobby_vote");

	MemoryPatch mPatcher = MemoryPatch.CreateFromConf(hGameData, "CReturnToLobbyIssue::CanCallVote");
	if (!mPatcher.Validate())
		SetFailState("Verify patch failed!");
	if (!mPatcher.Enable())
		SetFailState("Enable patch failed!");

	delete hGameData;
}
