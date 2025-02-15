中文 | [English](./README_EN.md)

## About
当服务器有更新时使服务器崩溃，以便自动重启服务器并自动更新。

## Notes
只支持Linux，要实现自动更新，需要`-autoupdate`、`-steam_dir`、`-steamcmd_script`，见[命令行选项](https://developer.valvesoftware.com/wiki/Command_line_options)。示例：

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
// 如果有更新，服务器将在多少时间后崩溃并重启。
l4d2_server_update_restart_time "60.0"
```
