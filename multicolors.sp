/*=======================================================================================

Credits:
	- https://github.com/Bara/Multi-Colors
	- https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/include/colors.inc
About: 
	- Only L4D2 is supported.
	- Removed {green} tag since most colors.inc's green is actually yellow. Use the {olive} or {yellow} tag instead.
	- Prevent team colors from being inconsistent with expectations.

=======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>

#define VERSION "0.1"

#define MAX_COLORS 9

#define CTEAM_NONE			-2
#define CTEAM_AUTHORCOLOR	-1
#define CTEAM_LIGHTGREEN	0
#define CTEAM_WHITE			1
#define CTEAM_BLUE			2
#define CTEAM_RED			3

#define AUTHOR_NONE			-3
#define AUTHOR_NOTFOUND		-2
#define AUTHOR_WHITE		-1
#define AUTHOR_LIGHTGREEN	0

static const char g_sTag[][] = {"{default}", "{teamcolor}", "{lightgreen}", "{white}", "{blue}", "{red}", "{yellow}", "{orange}", "{olive}"};
static const char g_sCode[][] = {"\x01", "\x03", "\x03", "\x03", "\x03", "\x03", "\x04", "\x04", "\x05"};
static const int g_iTeam[] = {CTEAM_NONE, CTEAM_AUTHORCOLOR, CTEAM_LIGHTGREEN, CTEAM_WHITE, CTEAM_BLUE, CTEAM_RED, CTEAM_NONE, CTEAM_NONE, CTEAM_NONE};

float g_fLastChangeTeamTime[MAXPLAYERS+1];
ArrayList g_aAuthorArray;

enum struct AuthorInfo
{
	float time;
	int author;
}

public Plugin myinfo = 
{
	name = "Multi Colors",
	author = "Bara, fdxx",
	version = VERSION,
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2) 
		LogError("Plugin only supports L4D2"); // Only throw error, try to continue loading.

	CreateNative("CPrintToChat", Native_CPrintToChat);
	CreateNative("CPrintToChatAll", Native_CPrintToChatAll);
	CreateNative("CPrintToChatEx", Native_CPrintToChatEx);
	CreateNative("CPrintToChatAllEx", Native_CPrintToChatAllEx);

	RegPluginLibrary("multicolors");

	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("multicolors_version", VERSION, "version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("player_team", Event_PlayerTeam);
	g_aAuthorArray = new ArrayList(sizeof(AuthorInfo));
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_fLastChangeTeamTime[client] = GetEngineTime();
}

// native void CPrintToChat(int client, const char[] message, any ...);
any Native_CPrintToChat(Handle plugin, int numParams)
{
	static int client, author;
	static char sBuffer[MAX_MESSAGE_LENGTH];

	client = GetNativeCell(1);
	author = AUTHOR_NONE;

	SetGlobalTransTarget(client);
	FormatNativeString(0, 2, 3, sizeof(sBuffer), _, sBuffer);
	ReplaceColorCodes(sBuffer, sizeof(sBuffer), author, false);
	Format(sBuffer, sizeof(sBuffer), "\x01%s", sBuffer);
	SendMessage(author, client, sBuffer);

	return 0;
}

// native void CPrintToChatAll(const char[] message, any ...);
any Native_CPrintToChatAll(Handle plugin, int numParams)
{
	static int author, i;
	static char sBuffer[MAX_MESSAGE_LENGTH];

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			author = AUTHOR_NONE;
			SetGlobalTransTarget(i);
			FormatNativeString(0, 1, 2, sizeof(sBuffer), _, sBuffer);
			ReplaceColorCodes(sBuffer, sizeof(sBuffer), author, false);
			Format(sBuffer, sizeof(sBuffer), "\x01%s", sBuffer);
			SendMessage(author, i, sBuffer);
		}
	}

	return 0;
}

// native void CPrintToChatEx(int client, int author, const char[] message, any ...);
any Native_CPrintToChatEx(Handle plugin, int numParams)
{
	static int client, author;
	static char sBuffer[MAX_MESSAGE_LENGTH];

	client = GetNativeCell(1);
	author = GetNativeCell(2);

	SetGlobalTransTarget(client);
	FormatNativeString(0, 3, 4, sizeof(sBuffer), _, sBuffer);
	ReplaceColorCodes(sBuffer, sizeof(sBuffer), author, true);
	Format(sBuffer, sizeof(sBuffer), "\x01%s", sBuffer);
	SendMessage(author, client, sBuffer);

	return 0;
}

// native void CPrintToChatAllEx(int author, const char[] message, any ...);
any Native_CPrintToChatAllEx(Handle plugin, int numParams)
{
	static int author, i;
	static char sBuffer[MAX_MESSAGE_LENGTH];

	author = GetNativeCell(1);

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			FormatNativeString(0, 2, 3, sizeof(sBuffer), _, sBuffer);
			ReplaceColorCodes(sBuffer, sizeof(sBuffer), author, true);
			Format(sBuffer, sizeof(sBuffer), "\x01%s", sBuffer);
			SendMessage(author, i, sBuffer);
		}
	}

	return 0;
}

void ReplaceColorCodes(char[] message, int maxlength, int &author, bool specifyAuthor)
{
	// If {teamcolor} is used in CPrintToChat(All) function, change to default color.
	if (specifyAuthor)
		ReplaceString(message, maxlength, "{teamcolor}", "\x03", false);
	else
		ReplaceString(message, maxlength, "{teamcolor}", "\x01", false); 

	for (int i = 0; i < MAX_COLORS; i++)
	{	
		if (StrContains(message, g_sTag[i], false) == -1)
			continue;

		if (g_iTeam[i] == CTEAM_NONE)
			ReplaceString(message, maxlength, g_sTag[i], g_sCode[i], false);
		else
		{
			if (specifyAuthor) 
				ThrowError("Use a team color other than {teamcolor} tag in CPrintToChat(All)Ex function.");
			
			if (author == AUTHOR_NONE)
			{
				author = FindAuthorByTeam(g_iTeam[i]);

				// If no author is found, change to default color.
				if (author == AUTHOR_NOTFOUND)
					ReplaceString(message, maxlength, g_sTag[i], "\x01", false);
				else
					ReplaceString(message, maxlength, g_sTag[i], g_sCode[i], false);
			}
			else
				ThrowError("Use more than two team colors in one message.");
		}
	}
}

int FindAuthorByTeam(int team)
{
	if (team == CTEAM_LIGHTGREEN)
		return AUTHOR_LIGHTGREEN;
	
	// Since author == -1 is white color, so we don't have to look for author with team == 1.
	if (team == CTEAM_WHITE)
		return AUTHOR_WHITE;

	static AuthorInfo info;
	static int author, i;

	g_aAuthorArray.Clear();
	author = AUTHOR_NOTFOUND;

	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			info.time = g_fLastChangeTeamTime[i];
			info.author = i;
			g_aAuthorArray.PushArray(info);
		}
	}

	// Server player team changes will not be synchronized to the client immediately, so look for the author of the earliest team changes.
	// Prevent team colors from being inconsistent with expectations.
	// Alternative plan: Call CBaseClient::UpdateAcknowledgedFramecount.
	if (g_aAuthorArray.Length > 0)
	{
		g_aAuthorArray.Sort(Sort_Ascending, Sort_Float);
		g_aAuthorArray.GetArray(0, info);
		author = info.author;
	}

	return author;
}

void SendMessage(int author, int client, const char[] message)
{
	// https://github.com/alliedmodders/hl2sdk/blob/l4d2/game/client/hud_basechat.cpp#L765
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	bf.WriteByte(author);		// author
	bf.WriteByte(0);			// bWantsToChat, don't call EmitSound.
	bf.WriteString(message);
	EndMessage();
}

