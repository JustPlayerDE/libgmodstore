hook.Add("Think", "LibGmodstore Init", function()
    hook.Remove("Think", "LibGmodstore Init")
    AddCSLuaFile("libgmodstore/sh_init.lua")
    AddCSLuaFile("libgmodstore/cl_ui.lua")
    include("libgmodstore/sh_init.lua")

    if CLIENT then
        include("libgmodstore/cl_ui.lua")
    end

end)