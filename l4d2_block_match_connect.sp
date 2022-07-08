#pragma semicolon 1
#pragma newdecls required

#define VERSION	"0.1"

#include <sourcemod>
#include <sourcescramble> // https://github.com/nosoop/SMExt-SourceScramble

public Plugin myinfo =
{
	name = "L4D2 Block match connect",
	author = "fdxx",
	description = "Block client from connecting to the server via creating a lobby.",
	version = VERSION,
}

public void OnPluginStart()
{
	Init();
	CreateConVar("l4d2_block_match_connect_version", VERSION, "Version", FCVAR_NONE | FCVAR_DONTRECORD);
}

void Init()
{
	GameData hGameData = new GameData("l4d2_block_match_connect");
	if (hGameData == null)
		SetFailState("Failed to load \"l4d2_block_match_connect.txt\" file");

	MemoryPatch mPatch = MemoryPatch.CreateFromConf(hGameData, "CBaseServer::ReplyReservationRequest");
	if (!mPatch.Validate())
		SetFailState("Verify patch failed.");
	if (!mPatch.Enable())
		SetFailState("Enable patch failed.");

	delete hGameData;
}
