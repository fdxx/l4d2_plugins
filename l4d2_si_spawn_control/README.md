中文 | [English](./README_EN.md)

## About
特感产生控制。

## Dependencies
- left4dhooks
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

## ConVar
```c
// 每种类型特感产生限制。
l4d2_si_spawn_control_hunter_limit "1"
l4d2_si_spawn_control_jockey_limit "1"
l4d2_si_spawn_control_smoker_limit "1"
l4d2_si_spawn_control_boomer_limit "1"
l4d2_si_spawn_control_spitter_limit "1"
l4d2_si_spawn_control_charger_limit "1"

// 特感产生最大限制。
l4d2_si_spawn_control_max_specials "6"

// 特感产生时间。
l4d2_si_spawn_control_spawn_time "10.0"

// 特感首次产生时间（离开安全区域后）。
l4d2_si_spawn_control_first_spawn_time "10.0"

// 自动杀死特感的时间，例如距离太远或者看不见。
l4d2_si_spawn_control_kill_si_time "25.0"

// 阻止本插件以外的特感产生 
l4d2_si_spawn_control_block_other_si_spawn "1"

// 找位模式。见下文
l4d2_si_spawn_control_spawn_mode "0"

// 普通模式产生范围，从1到该范围内随机生成。
l4d2_si_spawn_control_spawn_range_normal "1500"

// NavArea模式产生范围，从1到该范围内随机生成。
l4d2_si_spawn_control_spawn_range_navarea "1500"

// 特感死亡后，等待其他特感一起产生。
l4d2_si_spawn_control_together_spawn "0" 
```

### l4d2_si_spawn_control_spawn_mode

- 0=普通模式。使用官方实现的`GetRandomPZSpawnPosition`函数寻找产生位置，产生范围见`l4d2_si_spawn_control_spawn_range_normal`。
- 2=NavArea模式。使用本插件自己实现的函数寻找产生位置，产生范围见`l4d2_si_spawn_control_spawn_range_navarea`。
- 3=普通模式增强。0和2自动切换。当普通模式找位失败时或者事件尸潮开始时使用NavArea模式找位。比如在c8m3, c3m2中事件尸潮开始后，普通模式特感会产生在非常远的地方。
- 1=NavArea模式增强。将在幸存者最近的看不见的地方产生，幸存者倒地视为看不见。

## Change Log

### v3.3
- Cvar 更改: l4d2_si_spawn_control_radical_spawn ==> l4d2_si_spawn_control_spawn_mode
- 优化性能。
- 优先在真实玩家附近产生特感。(对于 SpawnMode == 1)。
- 当特感产生时间更改后，立即在设定时间产生特感。
- 修复特感产生数量可能异常的问题。

### v3.4
- 添加更多产生模式

### v3.5
- 当在首次产生最大数量的特感时，允许重生被杀死的特感。为了确保后续最大特感数量的正确性。

### v3.6
- 卸载插件时将官方cvar恢复为默认值。

### v3.7
- 修复 SourceMod 1.12 编译错误。
- 删除 Native `L4D2_CanSpawnSpecial`. 使用 `l4d2_si_spawn_control_block_other_si_spawn` 控制。
