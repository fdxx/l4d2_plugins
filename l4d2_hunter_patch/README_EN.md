[中文](./README.md) | English

## About
In versus mode and coop mode, Hunter's behavior is a little different, this plugin can enable or disable these features.

## Dependencies
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

## Notes
If patch is enabled, will work on: all modes, hunter bot, hunter player.

## ConVar

### l4d2_hunter_patch_convert_leap
- Whether convert leap to pounce. 0=game default, 1=always, 2=never.
- Hunter has a leap ability, different from pounce, This leap cannot knock down survivors. In coop mode, it's mainly used to make hunter run away, while in versus mode leap is converted to pounce.

### l4d2_hunter_patch_crouch_pounce
- While on the ground, Whether need press crouch button to pounce. 0=game default, 1=always, 2=never.
- Need by default in versus mode.

### l4d2_hunter_patch_bonus_damage
- Whether enable bonus pounce damage. 0=game default, 1=always, 2=never.
- Doing the same thing as plugin [[L4D2] Hunter Pounce Damage](https://forums.alliedmods.net/showthread.php?p=2675236), this plugin just uses a version of the [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble) extension.
- By default the game only deals bonus Hunter Pounce damage in versus mode，controlled by the official cvar `z_hunter_max_pounce_bonus_damage`.

### l4d2_hunter_patch_pounce_interrupt
-  Whether enable "pounce interrupt". 0=game default, 1=always, 2=never.
- By default, hunter bot are harder to "skeet" than hunter player. This is because the game only has "pounce interrupt" enabled for real player, When hunter take certain damage in the air, will directly kill it, controlled by the official cvar `z_pounce_damage_interrupt` (coop = 50, versus = 150). 
- If enabled in coop mode, it is recommended to also set `z_pounce_damage_interrupt` to `150` to keep the experience consistent with that of versus mode.

## Command
```c
// Admin command. Print the value of cvar.
sm_hunter_patch_print_cvars
```