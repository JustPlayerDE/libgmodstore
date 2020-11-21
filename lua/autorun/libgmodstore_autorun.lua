hook.Add("Think", "LibGmodstore Init", function()
    AddCSLuaFile("libgmodstore/sh_init.lua")
    AddCSLuaFile("libgmodstore/cl_ui.lua")
    include("libgmodstore/sh_init.lua")

    if CLIENT then
        include("libgmodstore/cl_ui.lua")
    end

    hook.Remove("Think", "LibGmodstore Init")
end)