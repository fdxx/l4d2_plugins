[中文](./README.md) | English

## About
Prints advertisements in the chat area.

## Dependencies
- [multicolors](https://github.com/fdxx/l4d2_plugins/tree/main/multicolors)


## ConVar
```c
// 0=sequential print, 1=random print.
l4d2_advertisements_type "0"

// Time between print advertisements.
l4d2_advertisements_time "360.0"

// Config file path.
l4d2_advertisements_cfg "data/server_info.cfg"
```

## Command
```c
// Console command. See a list of all ads.
sm_adlist

// Admin Command. Reload the config file.
sm_adreload 
```

## server_info.cfg
```vdf
"server_info"
{    
    // Read by port number.
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

    // Other config.
}
```
