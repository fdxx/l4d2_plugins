中文 | [English](./README_EN.md)

## About
在聊天区域打印广告。

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)

## ConVar
```c
// 0=顺序打印, 1=随机打印.
l4d2_advertisements_type "0"

// 打印广告的间隔时间.
l4d2_advertisements_time "360.0"

// 配置文件路径
l4d2_advertisements_cfg "data/server_info.cfg"
```

## Command
```c
// 控制台命令，查看所有广告列表
sm_adlist

// 管理员命令，重新加载配置文件
sm_adreload 
```

## server_info.cfg
```vdf
"server_info"
{    
    // 根据端口号读取
    "27017"
    {
        "advertisements"
        {
            "message" "{olive}olive {default}default {lightgreen}lightgreen {yellow}yellow"
            "message" "time: {time}"
            "message" "newline test\nnewline 1\nnewline 2\nnewline 3"
            "message" "Other message"
        }
    }

    // 其他配置
}
```