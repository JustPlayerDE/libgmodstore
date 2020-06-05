if (libgmodstore and not libgmodstore.debug) then return end -- We don't want to be running multiple times if we've already initialised
libgmodstore = {}
libgmodstore.ERROR = 0
libgmodstore.OK = 1
libgmodstore.OUTDATED = 2
libgmodstore.NO_VERSION = 3

function libgmodstore:print(msg, type)
    if (type == "error" or type == "bad") then
        MsgC(Color(255, 0, 0), "[libgmodstore] ", Color(255, 255, 255), msg .. "\n")
    elseif (type == "success" or type == "good") then
        MsgC(Color(0, 255, 0), "[libgmodstore] ", Color(255, 255, 255), msg .. "\n")
    else
        MsgC(Color(0, 255, 255), "[libgmodstore] ", Color(255, 255, 255), msg .. "\n")
    end
end

function libgmodstore:Load()
    AddCSLuaFile("libgmodstore/libgmodstore.lua")
    include("libgmodstore/libgmodstore.lua")
end

hook.Add("Think", "LibGmodstore Init", function()
    libgmodstore:Load()
    hook.Remove("Think", "LibGmodstore Init")
end)
