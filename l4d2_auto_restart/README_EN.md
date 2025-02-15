[中文](./README.md) | English

## About
Crash the server when the last player leaves in order to restart the server automatically.

## Notes
On Linux, servers are auto restarted after a crash, provided you are **not using** the `-norestart` command line options.

On Windows, there is no auto restart mechanism, you need to create a batch script to cycle through the startup and use `-nocrashdialog` to prevent Windows from popping up error dialogs, a `l4d2_start.bat` example (source: Hatsune Imagine):

```bat
@echo off
:l4d2
echo "L4D2 Server Starting..."
C:\l4d2server\l4d2\srcds.exe -game left4dead2 -console -nocrashdialog -port 35018 -tickrate 100 -ip 0.0.0.0 +map c2m1 +exec server.cfg
goto l4d2
pause
```

## ConVar
```c
// The delay time before an auto restart, if a new player joins the server during this time it will not restart.
l4d2_auto_restart_delay "30.0"

// Restart method. 1=crash command, 2=Exit
l4d2_auto_restart_method "1"

// if method is Exit, what is the exitcode ?
l4d2_auto_restart_exitcode "60"
```

## Command
```c
// Admin command. manually crash the server.
sm_restart_server
```
