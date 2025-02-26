[中文](./README.md) | English

## About
Use the command to execute the specified configuration file once.

## Notes
`AutoExecConfig/server.cfg` is executed after every map change and overrides the dynamically modified cvar values in the game, For plugins that do not have the `AutoExecConfig` feature enabled, The purpose of this plugin is to set the initial cvar value for other plugins. For example, add it to `server.cfg`:

```c
sm_cfgexec_once "addons/file.cfg"
```

This will ensure that `file.cfg` is executed only once.

## Command
```c
// Admin command. Executes the specified configuration file, Relative to the `left4dead2/` directory.
// Multiple files are separated using `;`
sm_cfgexec_once <path/file1;path/file2>
```
