# About

Read the [thread](https://www.gmodstore.com/community/threads/4465-libgmodstore) on gmodstore.

Libgmodstore was originally made by Billy to assist content creators with customer support and customer engagement.

Download: [Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2118049526) or [Direct Download](https://github.com/JustPlayerDE/libgmodstore/archive/master.zip)

Website: [https://libgmod.justplayer.de](https://libgmod.justplayer.de)

Thanks to:

* Billy for making the initial version of Libgmodstore
* Tom.bat for helping me

## Features

### Ingame Menu

This is where server owners will interact with the library. it's a simple and dark design. It's fast, efficient and has maximum portability. It is opened by typing `!libgmodstore` in chat.

Please note that currently the icons are loaded from imgur.

![When you click on a Addon](https://i.imgur.com/WkyG5Vg.png)
![When you click on Log Uploader](https://i.imgur.com/jmk7tQ6.png)

### Script Update information

If a Gmodstore script installed on the server is outdated, a notification will appear in the server console and on the in-game menu.

### Debug Logs

The user only need to Login via Steam (ingame) to upload a copy of the server's console.log.

To help with privacy, all IPs (except the server's one) will be removed from the Logfile before uploading.

Debug Logs contain the following informations:

* Server IP Address
* Server Name
* Gamemode
* Average player ping
* Addons that are using libgmodstore (which includes:)
  * Addon Name
  * Addon Version
  * Gmodstore ID
  * SteamID of the Licensee
* Addons that are workshop mounted
* User that Uploaded that log

There will be a message if the user need to enable `-condebug`.

### [WIP] Usage Statistic

For the content creators libgmodstore also have a very simple usage tracker (it only counts how many servers are using your addon per day)

To Opt-Out of this as a Server owner (for all addons) you only need to run this command in your console and it should never send any data:

> Note: this will be disabled on default on all servers having this addon installed before 2020-06-25.

`libgmodstore_enable_usage_tracker 0`

This tool is currently work in progress and only some creators will have access to it for now.

## Example Code for your addon

```lua
local SHORT_SCRIPT_NAME = "FlatHud" -- A short version of your script's name to identify it
local SCRIPT_ID = 7034 -- The script's ID on gmodstore
local SCRIPT_VERSION = "1.3.6" -- [Optional] The version of your script. You don't have to use the update notification feature, so you can remove it from libgmodstore:InitScript if you want to
local LICENSEE = "{{ user_id }}" -- [Optional] The SteamID64 of the person who bought the script. They will have access to update notifications etc. If you do not supply this, superadmins (:IsSuperAdmin()) will have permission instead.

hook.Add("libgmodstore_init",SHORT_SCRIPT_NAME .. "_libgmodstore",function()
    libgmodstore:InitScript(SCRIPT_ID,SHORT_SCRIPT_NAME,{
        version = SCRIPT_VERSION,
        licensee = LICENSEE
    })
end)
```
