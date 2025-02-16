[中文](./README.md) | English

## About
To crash the server when there is an update available. so that the server is automatically restarted and automatically updated.

## Notes
Linux only. for automatic updates, Need `-autoupdate`, `-steam_dir`, `-steamcmd_script`, see [command line options](https://developer.valvesoftware.com/wiki/Command_line_options). Example:

### start.sh
```bash
screen ~/game/l4d2/srcds_run -game left4dead2 -autoupdate -steam_dir $HOME/game -steamcmd_script $HOME/game/l4d2/update.txt -port 35006 -tickrate 100 -ip 0.0.0.0 +map c2m1 +exec server.cfg -nowatchdog -timeout 1 -nobreakpad -noassert
```

### update.txt
```bash
force_install_dir l4d2
login anonymous
app_update 222860
quit
```

## ConVar
```c
// If there is an update, after how much time the server will crash and restart.
l4d2_server_update_restart_time "60.0"
```
