Read the [thread](https://www.gmodstore.com/community/threads/4465-libgmodstore) on gmodstore.

~~Do NOT package this branch with your addons! Package the [launcher branch](https://github.com/WilliamVenner/libgmodstore/tree/launcher) as it automatically updates using `RunString`.~~

For now please use this branch in case you want to use this, Auto update will be fixed later. (sorry billy)

You can Download the newest version here: [Download](https://github.com/JustPlayerDE/libgmodstore/archive/master.zip) (Auto updater comes later)

This version is using [libgmod.justplayer.de](https://libgmod.justplayer.de).

### Example Code for your addon

```lua
local SHORT_SCRIPT_NAME = "bLogs" -- A short version of your script's name to identify it
local SCRIPT_ID = 1599 -- The script's ID on gmodstore
local SCRIPT_VERSION = "Remastered-12" -- [Optional] The version of your script. You don't _have_ to use the update notification feature, so you can remove it from libgmodstore:InitScript if you want to
local LICENSEE = "{{ user_id }}" -- [Optional] The SteamID64 of the person who bought the script. They will have access to debug logs, update notifications, etc. If you do not supply this, superadmins (:IsSuperAdmin()) will have permission instead.

hook.Add("libgmodstore_init",SHORT_SCRIPT_NAME .. "_libgmodstore",function()
    libgmodstore:InitScript(SCRIPT_ID,SHORT_SCRIPT_NAME,{
        version = SCRIPT_VERSION,
        licensee = LICENSEE
    })
end)
```
