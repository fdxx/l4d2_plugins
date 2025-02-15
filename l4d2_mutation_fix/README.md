中文 | [English](./README_EN.md)

## About
突变模式脚本执行修复。

## Dependencies
- [l4d2_source_keyvalues](https://github.com/fdxx/l4d2_source_keyvalues) 

## Notes
如果服务器没有开启大厅匹配，第一次进入游戏时，变异模式脚本似乎无法正确执行。例如死亡之门第一局的包不会替换成药。所以我们重新加载当前地图进行修复。

## ConVar
```c
// 服务器启动后多少秒之后，重载当前地图。
l4d2_mutation_fix_time "0.2"
```
