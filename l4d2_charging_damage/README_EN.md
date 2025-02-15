[中文](./README.md) | English

## About
Adjusts the damage taken by Charger bot while charging.

## Dependencies
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

## Notes
The Charger bot has a damage reduction that is 0.333x that of the Charger player. This plugin allows for customization of this damage multiplier.

## ConVar
```c
// Damage multiplier for Charger bot when charging.
// 0.333=game default, 1.0=same as Charger players.
l4d2_charging_damage_multiples "1.1"
```