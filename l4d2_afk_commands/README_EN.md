[中文](./README.md) | English

## About
Provides some commands to join spectator, join survivor, and commit suicide.

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)
- left4dhooks

## Notes
Idle is different from spectator, in coop mode you execute the idle command `go_away_from_keyboard`, the bot will take over your character, but your view will still be locked on the current character, press the left mouse button to take over the current character again. On the other hand, spectator allows you to switch viewpoints and move freely.

## ConVar
```c
// Delay time for switching to spectator, 0.0=no delay.
l4d2_afk_commands_afk_delay "3.0"

// Actions after the player executes the idle (go_away_from_keyboard) command.
// 0=Game default.
// 1=Block use idle command (only spectator command can be used).
// 2=Idle commands can be used without restriction. by default it cannot be used in versus mode and when there is only 1 person.
l4d2_afk_commands_idle_type "1"
```

## Command
```c
// Console command. Join spectator.
sm_afk
sm_away
sm_idle
sm_spectate
sm_spectators
sm_joinspectators
sm_jointeam1

// Console command. Join survivor.
sm_survivors
sm_sur
sm_join
sm_jg
sm_jiaru
sm_jointeam2
sm_jr

// Console command. commit suicide.
sm_kill
sm_zs
```