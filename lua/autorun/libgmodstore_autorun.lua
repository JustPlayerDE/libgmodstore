hook.Add("Think", "LibGmodstore Init", function()
    AddCSLuaFile("libgmodstore/init.lua")
    AddCSLuaFile("libgmodstore/client.lua")
    include("libgmodstore/init.lua")

    if CLIENT then
        include("libgmodstore/client.lua")
    end

    hook.Remove("Think", "LibGmodstore Init")
end)