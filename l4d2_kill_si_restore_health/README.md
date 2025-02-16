中文 | [English](./README_EN.md)

## About
杀死特感回血。

## Notes

相关插件：[l4d2_lifesteal](https://github.com/fdxx/l4d2_plugins/tree/main/l4d2_lifesteal)

- `l4d2_lifesteal`: 对特感造成伤害就实时回血。
- `l4d2_kill_si_restore_health`: 杀死特感后才回血。

## ConVar
```c
// 杀死每种类型的特感回多少血。
l4d2_kill_smoker_restore_health "0"
l4d2_kill_boomer_restore_health "0"
l4d2_kill_hunter_restore_health "0"
l4d2_kill_spitter_restore_health "0"
l4d2_kill_jockey_restore_health "0"
l4d2_kill_charger_restore_health "0"
l4d2_kill_witch_restore_health "10"
l4d2_kill_tank_restore_health "0"

// 回血最大上限。
l4d2_kill_si_restore_health_Limit "110"
```
