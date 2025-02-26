中文 | [English](./README_EN.md)

## About
使用命令执行一次指定的配置文件。

## Notes
`AutoExecConfig/server.cfg`每次地图更换后都会执行，并覆盖游戏中动态修改的 cvar 值。对于没有启用`AutoExecConfig`功能的插件，本插件的目的是为其他插件的 cvar 值进行初始设置。例如在`server.cfg`中添加：
```c
sm_cfgexec_once "addons/file.cfg"
```
这将确保`file.cfg`只执行一次。

## Command
```c
// 管理员命令。执行的配置文件，相对于`left4dead2/`目录。
// 多个文件使用`;`分隔
sm_cfgexec_once <path/file1;path/file2>
```
