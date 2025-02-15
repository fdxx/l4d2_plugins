[中文](./README.md) | English

## About
Map voting. Automatically resolve names in map files.

## Dependencies
- [l4d2_nativevote](https://github.com/fdxx/l4d2_nativevote)
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## ConVar
```c
// Whether admins bypass `*TeamFlags`
// See sm_mapvote_attribute
l4d2_map_vote_adminteamflags "1"

// Whether to clear the score when changing maps.
// Mainly used in versus mode.
l4d2_map_vote_clearscores "1"
```

## Command
```c
// Admin commands. Some settings for voting.
// See https://github.com/fdxx/l4d2_config_vote
sm_mapvote_attribute <MenuTeamFlags|VoteTeamFlags|AdminOneVotePassed|AdminOneVoteAgainst> <value>

// Admin command. Export the map's kv information
sm_missions_export <filename>

// Admin command. Hot load vpk files.
sm_missions_reload

// Admin command. clear score
sm_clear_scores
```

## Translations
Translation of map names is supported, but chapter names are excluded. See `l4d2_map_vote.phrases.txt`.

By default, only official maps are translated. If you want to add or modify, please note that the option name must correspond to the `DisplayTitle` in the missions file. You can use `sm_missions_export` to export and view it.

