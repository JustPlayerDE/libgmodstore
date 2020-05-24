local DEBUGGING = true
if (libgmodstore and not DEBUGGING) then return end -- We don't want to be running multiple times if we've already initialised
libgmodstore = {}

function libgmodstore:print(msg, type)
    if (type == "error" or type == "bad") then
        MsgC(Color(255, 0, 0), "[libgmodstore] ", Color(255, 255, 255), msg .. "\n")
    elseif (type == "success" or type == "good") then
        MsgC(Color(0, 255, 0), "[libgmodstore] ", Color(255, 255, 255), msg .. "\n")
    else
        MsgC(Color(0, 255, 255), "[libgmodstore] ", Color(255, 255, 255), msg .. "\n")
    end
end

function libgmodstore:LoadBackup()
    AddCSLuaFile("libgmodstore/libgmodstore.lua")
    include("libgmodstore/libgmodstore.lua")
end

hook.Add("Think", "LibGmodstore Init", function()
    libgmodstore:LoadBackup()
    hook.Remove("Think", "LibGmodstore Init")
end)