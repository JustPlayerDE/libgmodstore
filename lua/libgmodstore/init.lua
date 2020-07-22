local developer = GetConVar("developer")
local URL = "https://libgmod.justplayer.de"
libgmodstore = {}
-- Enums
libgmodstore.ERROR = 0
libgmodstore.OK = 1
libgmodstore.OUTDATED = 2
libgmodstore.NO_VERSION = 3

-- Internal stuff 
-- Logging
local function prefix(tbl, prefix, prefixColor)
    table.insert(tbl, 1, Color(200, 200, 200))
    table.insert(tbl, 1, prefix or "")
    table.insert(tbl, 1, prefixColor or Color(100, 255, 100))

    return tbl
end

function libgmodstore:_Log(stuff)
    table.insert(stuff, 1, "[libgmodstore] ")
    table.insert(stuff, 1, Color(0, 255, 255))
    table.insert(stuff, "\n")
    MsgC(unpack(stuff))
end

function libgmodstore:Log(...)
    stuff = {...}
    prefix(stuff)
    self:_Log(stuff)
end

function libgmodstore:LogDebug(...)
    if not developer:GetBool() then return end
    stuff = {...}
    prefix(stuff, "[DEBUG] ", Color(0, 0, 255))
    self:_Log(stuff)
end

function libgmodstore:LogOk(...)
    stuff = {...}
    prefix(stuff, "[OK]", Color(0, 255, 0))
    self:_Log(stuff)
end

function libgmodstore:LogError(...)
    stuff = {...}
    prefix(stuff, "[ERROR] ", Color(255, 0, 0))
    self:_Log(stuff)

    if developer:GetBool() then
        debug.Trace()
    end
end

-- https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
local function urlencode(str)
    str = string.gsub(str, "\r?\n", "\r\n")
    str = string.gsub(str, "([^%w%-%.%_%~ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    str = string.gsub(str, " ", "+")

    return str
end

libgmodstore:LogDebug("Initialising Libgmodstore")

-- Run stuff
if SERVER then
    -- Init Libgmodstore serverside
    libgmodstore.addons = {}
    util.AddNetworkString("libgmodstore_open")
    util.AddNetworkString("libgmodstore_uploadlog")

    -- To add Addons to Libgmodstore
    function libgmodstore:InitScript(script_id, script_name, options)
        if (not tonumber(script_id) or (script_name or ""):Trim():len() == 0) then return false end
        libgmodstore:Log("(" .. script_id .. ") " .. script_name .. " is using libgmodstore")

        libgmodstore.addons[script_id] = {
            script_name = script_name,
            options = options,
            metadata = {
                status = libgmodstore.NO_VERSION
            }
        }

        if (options.version ~= nil) then
            -- Stats are disabled for now
            http.Fetch(URL .. "/api/checkversion/" .. urlencode(script_id) .. "/" .. urlencode(options.version), function(body, size, headers, code)
                if (code ~= 200) then
                    libgmodstore:LogError("[2] Error while checking for updates on script " .. script_id .. ": HTTP " .. code)
                    libgmodstore.addons[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                if (size == 0) then
                    libgmodstore:LogError("[3] Error while checking for updates on script " .. script_id .. ": empty body!")
                    libgmodstore.addons[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                local decoded_body = util.JSONToTable(body)

                if not decoded_body then
                    libgmodstore:LogError("[4] Error while checking for updates on script " .. script_id .. ": JSON error!")
                    libgmodstore.addons[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                if not decoded_body.success then
                    libgmodstore:LogError("[4] Error while checking for updates on script " .. script_id .. ": " .. decoded_body.error)
                    libgmodstore.addons[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                if decoded_body.result.outdated then
                    libgmodstore:LogError("[" .. script_id .. "] " .. script_name .. " is outdated! The latest version is " .. decoded_body.result.version .. " while you have " .. options.version)
                    libgmodstore.addons[script_id].metadata.status = libgmodstore.OUTDATED
                else
                    libgmodstore:LogOk("[" .. script_id .. "] " .. script_name .. " is up to date!", "good")
                    libgmodstore.addons[script_id].metadata.status = libgmodstore.OK
                end
            end, function(err)
                libgmodstore:LogError("[1] Error while checking for updates on script " .. script_id .. ": " .. err)
                libgmodstore.addons[script_id].metadata.status = libgmodstore.ERROR
            end)
        end

        return true
    end

    -- Permission check
    function libgmodstore:CanOpenMenu(ply, return_data)
        if return_data then
            local scripts = {}
            local count = 0
            local IsSuperAdmin = ply:IsSuperAdmin()

            -- Add addons to list and return them
            for id, data in pairs(libgmodstore.addons) do
                if data.options.licensee ~= nil then
                    if ply:SteamID64() == data.options.licensee or IsSuperAdmin then
                        scripts[id] = data
                        count = count + 1
                    end
                elseif IsSuperAdmin then
                    scripts[id] = data
                    count = count + 1
                end
            end

            return scripts, count
        else
            for id, data in pairs(libgmodstore.addons) do
                if data.options.licensee ~= nil then
                    if ply:SteamID64() == data.options.licensee then return true end
                elseif IsSuperAdmin then
                    return true
                end
            end

            return true
        end
    end

    hook.Add("PlayerSay", "libgmodstore_openmenu", function(ply, txt)
        if txt:lower() == "!libgmodstore" then
            local addons, count = libgmodstore:CanOpenMenu(ply, true)
            libgmodstore:LogDebug("Sending " .. count .. " Addons to " .. ply:Name() .. " (" .. ply:SteamID() .. ")")
            -- Dont do anything if the player has no addons nor is superadmin
            if count <= 0 and not ply:IsSuperAdmin() then return end
            net.Start("libgmodstore_open")
            net.WriteInt(count, 12)

            for id, data in pairs(addons) do
                net.WriteInt(id, 16)
                net.WriteString(data.script_name)
                net.WriteUInt(data.metadata.status, 2)
                net.WriteString(tostring(data.options.version or "UNKNOWN"))
            end

            net.Send(ply)

            return ""
        end
    end)

    hook.Run("libgmodstore_init") -- Getting addon informations
end