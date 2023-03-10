#if defined _multicolors_included
	#endinput
#endif
#define _multicolors_included



#define MAX_MESSAGE_LENGTH	253

/*
static const char g_sTag[][] = {"{default}", "{teamcolor}", "{lightgreen}", "{white}", "{blue}", "{red}", "{yellow}", "{orange}", "{olive}"};
static const char g_sCode[][] = {"\x01", "\x03", "\x03", "\x03", "\x03", "\x03", "\x04", "\x04", "\x05"};
*/

/**
 * Prints a message to a specific client in the chat area.
 *
 * @param client		Client index.
 * @param message		Message (formatting rules).
 */
native void CPrintToChat(int client, const char[] message, any ...);

/**
 * Prints a message to all clients in the chat area.
 *
 * @param message		Message (formatting rules).
 */
native void CPrintToChatAll(const char[] message, any ...);

/**
 * Prints a message to a specific client in the chat area.
 * 
 * @param client		Client index.
 * @param author		Author index. His team colors will be used in the message.
 * @param message		Message (formatting rules).
 */
native void CPrintToChatEx(int client, int author, const char[] message, any ...);

/**
 * Prints a message to all clients in the chat area.
 * 
 * @param author		Author index. His team colors will be used in the message.
 * @param message		Message (formatting rules).
 */
native void CPrintToChatAllEx(int author, const char[] message, any ...);


public SharedPlugin __pl_l4d2_multicolors = 
{
	name = "multicolors",
	file = "multicolors.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_multicolors_SetNTVOptional()
{
	MarkNativeAsOptional("CPrintToChat");
	MarkNativeAsOptional("CPrintToChatAll");
	MarkNativeAsOptional("CPrintToChatEx");
	MarkNativeAsOptional("CPrintToChatAllEx");
}
#endif

