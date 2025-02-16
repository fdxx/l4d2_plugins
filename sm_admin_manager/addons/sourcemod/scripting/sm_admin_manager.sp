#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.2"
ArrayList g_aAdminData;

enum struct AdminData
{
	char identity[128];
	AdminId adminId;
	char name[128];
	char auth[32];
	int immunity;
	int flags;
	char passwd[128];

	void Init()
	{
		this.adminId = INVALID_ADMIN_ID;
		this.name[0] = '\0';
		this.auth[0] = '\0';
		this.identity[0] = '\0';
		this.immunity = 0;
		this.flags = 0;
		this.passwd[0] = '\0';
	}
}

public Plugin myinfo = 
{
	name = "sm_admin_manager",
	author = "fdxx",
	version = VERSION,
	url = "https://github.com/fdxx/l4d2_plugins"
};

public void OnPluginStart()
{
	delete g_aAdminData;
	g_aAdminData = new ArrayList(sizeof(AdminData));

	CreateConVar("sm_admin_manager_version", VERSION, "version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	RegAdminCmd("sm_addadmin", Cmd_AddAdmin, ADMFLAG_ROOT);
	RegAdminCmd("sm_deladmin", Cmd_DelAdmin, ADMFLAG_ROOT);
	RegAdminCmd("sm_listadmin", Cmd_ListAdmin, ADMFLAG_ROOT);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if (part != AdminCache_Admins)
		return;

	for (int i = 0; i < g_aAdminData.Length; i++)
	{
		AdminData data;
		g_aAdminData.GetArray(i, data);
		if (!AddAdmin(data))
		{
			g_aAdminData.Erase(i);
			i--;
		}
	}
}

Action Cmd_AddAdmin(int client, int args)
{
	char buffer[128];

	if (args < 3)
	{
		GetCmdArg(0, buffer, sizeof(buffer));
		ReplyToCommand(client, "Usage: %s <name> <SteamID/!IP/SteamName> <flag> [immunity] [password]", buffer);
		return Plugin_Handled;
	}

	AdminData data;
	data.Init();

	GetCmdArg(1, data.name, sizeof(data.name));

	GetCmdArg(2, buffer, sizeof(buffer));
	GetAuthIdentity(buffer, data);

	GetCmdArg(3, buffer, sizeof(buffer));
	for (int i = 0, len = strlen(buffer); i < len; i++)
	{
		AdminFlag flag;
		if (!FindFlagByChar(buffer[i], flag))
			ReplyToCommand(client, "Invalid flag detected: %c", buffer[i]);
		else
			data.flags |= FlagToBit(flag);
	}

	if (args > 3 && !GetCmdArgIntEx(4, data.immunity))
	{
		ReplyToCommand(client, "Invalid immunity");
		return Plugin_Handled;
	}

	// https://wiki.alliedmods.net/Adding_Admins_(SourceMod)#Passwords
	// requires a password: AUTHMETHOD_NAME
	if (args > 4)
		GetCmdArg(5, data.passwd, sizeof(data.passwd));

	g_aAdminData.PushArray(data);
	// Only when it is set in the forward OnRebuildAdminCache will it take effect in real time. 
	DumpAdminCache(AdminCache_Admins, true); 

	return Plugin_Handled;
}

bool AddAdmin(AdminData data)
{
	if (!data.identity[0] || !data.auth[0])
	{
		LogMessage("Invalid identity or auth of: %s", data.name);
		return false;
	}

	data.adminId = FindAdminByIdentity(data.auth, data.identity);
	if (data.adminId != INVALID_ADMIN_ID)
	{
		LogMessage("Admin identity already exists: %s", data.identity);
		return false;
	}

	data.adminId = CreateAdmin(data.name);
	if (!data.adminId.BindIdentity(data.auth, data.identity))
	{
		RemoveAdmin(data.adminId);
		LogMessage("Failed to BindIdentity: auth: %s, identity: %s", data.auth, data.identity);
		return false;
	}

	data.adminId.ImmunityLevel = data.immunity;
	data.adminId.SetBitFlags(data.flags, true);

	if (data.passwd[0])
		data.adminId.SetPassword(data.passwd);
	
	LogMessage("Add admin %i: %s %s %s %i %i %s", data.adminId, data.name, data.auth, data.identity, data.flags, data.immunity, data.passwd);
	return true;
}

Action Cmd_DelAdmin(int client, int args)
{
	char buffer[128];

	if (args < 1)
	{
		GetCmdArg(0, buffer, sizeof(buffer));
		ReplyToCommand(client, "Usage: %s <identity>", buffer);
		return Plugin_Handled;
	}

	AdminData data;
	data.Init();

	GetCmdArg(1, buffer, sizeof(buffer));
	GetAuthIdentity(buffer, data);

	data.adminId = FindAdminByIdentity(data.auth, data.identity);
	if (data.adminId == INVALID_ADMIN_ID)
	{
		ReplyToCommand(client, "Failed to FindAdminByIdentity: auth: %s, identity: %s", data.auth, data.identity);
		return Plugin_Handled;
	}

	RemoveAdmin(data.adminId);
	int index = g_aAdminData.FindString(data.identity);
	if (index != -1)
	{
		g_aAdminData.Erase(index);
		ReplyToCommand(client, "Delete admin: %s", data.identity);
	}
	
	return Plugin_Handled;
}

void GetAuthIdentity(const char[] buffer, AdminData data)
{
	if (!strncmp(buffer, "STEAM_", 6))
	{
		strcopy(data.auth, sizeof(data.auth), AUTHMETHOD_STEAM);
		strcopy(data.identity, sizeof(data.identity), buffer);
	}
	else if (buffer[0] == '!')
	{
		strcopy(data.auth, sizeof(data.auth), AUTHMETHOD_IP);
		strcopy(data.identity, sizeof(data.identity), buffer[1]);
	}
	else
	{
		strcopy(data.auth, sizeof(data.auth), AUTHMETHOD_NAME);
		strcopy(data.identity, sizeof(data.identity), buffer);
	}
}


Action Cmd_ListAdmin(int client, int args)
{
	AdminData data;

	for (int i = 0; i < g_aAdminData.Length; i++)
	{
		g_aAdminData.GetArray(i, data);
		ReplyToCommand(client, "%i: %s %s %s %i %i %s", data.adminId, data.name, data.auth, data.identity, data.flags, data.immunity, data.passwd);
	}
	
	return Plugin_Handled;
}
