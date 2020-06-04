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

This is where server owners will interact with the library. At the moment, it's a simple docked default Derma skin frame, so it's not the nicest looking thing in the world but it's fast, efficient and has maximum portability. It is opened by typing `!libgmodstore` in chat.

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
* User that Uploaded that log

There will be a message if the user need to enable `-condebug`.

## Example Code for your addon

```lua
local SHORT_SCRIPT_NAME = "FlatHud" -- A short version of your script's name to identify it
local SCRIPT_ID = 7034 -- The script's ID on gmodstore
local SCRIPT_VERSION = "1.3.6" -- [Optional] The version of your script. You don't have to use the update notification feature, so you can remove it from libgmodstore:InitScript if you want to
local LICENSEE = "{{ user_id }}" -- [Optional] The SteamID64 of the person who bought the script. They will have access to debug logs, update notifications, etc. If you do not supply this, superadmins (:IsSuperAdmin()) will have permission instead.

hook.Add("libgmodstore_init",SHORT_SCRIPT_NAME .. "_libgmodstore",function()
    libgmodstore:InitScript(SCRIPT_ID,SHORT_SCRIPT_NAME,{
        version = SCRIPT_VERSION,
        licensee = LICENSEE
    })
end)
```
