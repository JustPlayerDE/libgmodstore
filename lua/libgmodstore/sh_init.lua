local developer = GetConVar("developer")
local URL = "https://libgmod.justplayer.de"
libgmodstore = {}
-- Enums
libgmodstore.ERROR = 0
libgmodstore.OK = 1
libgmodstore.OUTDATED = 2
libgmodstore.NO_VERSION = 3

-- Internal stuff 
local function filter(str)
    str = string.gsub(str, "[0-9]?[0-9]?[0-9]%.[0-9]?[0-9]?[0-9]%.[0-9]?[0-9]?[0-9]%.[0-9]?[0-9]?[0-9]", "x.x.x.x") -- Remove any IP

    return str
end

-- https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
local function urlencode(str)
    str = string.gsub(str, "\r?\n", "\r\n")
    str = string.gsub(str, "([^%w%-%.%_%~ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    str = string.gsub(str, " ", "+")

    return str
end

local function generateAddonReport()
    local addons = {}

    -- Getting Gmodstore Addons
    for id, meta in pairs(libgmodstore.addons) do
        local data = {
            name = meta.script_name,
            id = id or "N/A",
            version = meta.options.version or "N/A",
            branch = meta.options.branch or "N/A",
            licensee = meta.options.licensee or "N/A",
            type = "gmodstore"
        }

        table.insert(addons, data)
    end

    -- Getting Mounted (workshop) Addons
    local mounted_addons = engine.GetAddons()

    for i = 1, #mounted_addons do
        local addon = mounted_addons[i]

        if addon.mounted then
            table.insert(addons, {
                name = addon.title,
                id = addon.wsid,
                type = "workshop"
            })
        end
    end

    return urlencode(util.TableToJSON(addons))
end

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
    self:_Log(prefix({...}))
end

function libgmodstore:LogDebug(...)
    if not developer:GetBool() then return end
    self:_Log(prefix({...}, "[DEBUG] ", Color(0, 0, 255)))
end

function libgmodstore:LogOk(...)
    self:_Log(prefix({...}, "[OK]", Color(0, 255, 0)))
end

function libgmodstore:LogError(...)
    self:_Log(prefix({...}, "[ERROR] ", Color(255, 0, 0)))

    if developer:GetBool() then
        debug.Trace()
    end
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
        if not tonumber(script_id) or (script_name or ""):Trim():len() == 0 then return false end
        libgmodstore:Log("[" .. script_id .. "] " .. script_name .. " is using libgmodstore")

        libgmodstore.addons[script_id] = {
            script_name = script_name,
            options = options,
            metadata = {
                status = libgmodstore.NO_VERSION
            }
        }

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

    -- TODO: make it a bit better
    net.Receive("libgmodstore_uploadlog", function(_, ply)
        local authcode = net.ReadString()

        if ply:IsSuperAdmin() then
            if file.Exists("console.log", "GAME") then
                local gamemode = (GM or GAMEMODE)
                local gamemode_name = gamemode.Name

                if gamemode.BaseClass then
                    gamemode_name = gamemode_name .. " (derived from " .. gamemode.BaseClass.Name .. ")"
                end

                local avg_ping = 0

                for _, v in ipairs(player.GetHumans()) do
                    avg_ping = avg_ping + v:Ping()
                end

                avg_ping = math.Round(avg_ping / #player.GetHumans())

                local arguments = {
                    uploader = ply:SteamID64(),
                    ip_address = game.GetIPAddress(),
                    server_name = GetConVar("hostname"):GetString(),
                    server_addons = generateAddonReport(), -- Usefull for later
                    gamemode = gamemode_name,
                    avg_ping = tostring(avg_ping),
                    consolelog = filter(file.Read("console.log", "GAME")),
                    token = authcode
                }

                libgmodstore:Log("Uploading Log...")

                http.Post(URL .. "/api/log/push", arguments, function(body, size, headers, code)
                    if code ~= 200 then
                        net.Start("libgmodstore_uploadlog")
                        net.WriteBool(false)
                        net.WriteString("HTTP " .. code)
                        net.Send(ply)

                        return
                    end

                    if size == 0 then
                        net.Start("libgmodstore_uploadlog")
                        net.WriteBool(false)
                        net.WriteString("Empty body!")
                        net.Send(ply)

                        return
                    end

                    local decoded_body = util.JSONToTable(body)

                    if not decoded_body then
                        net.Start("libgmodstore_uploadlog")
                        net.WriteBool(false)
                        net.WriteString("JSON error!")
                        net.Send(ply)

                        return
                    end

                    if not decoded_body.success then
                        net.Start("libgmodstore_uploadlog")
                        net.WriteBool(false)
                        net.WriteString(decoded_body.error)
                        net.Send(ply)

                        return
                    end

                    net.Start("libgmodstore_uploadlog")
                    net.WriteBool(true)
                    net.WriteString(decoded_body.result)
                    net.Send(ply)
                end, function(err)
                    net.Start("libgmodstore_uploadlog")
                    net.WriteBool(false)
                    net.WriteString(err)
                    net.Send(ply)
                end)
            else
                libgmodstore:LogError("console.log was not found on your server!")
                libgmodstore:LogError("You probably have not added -condebug to your server's command line.")
                libgmodstore:LogError("Add -condebug to your server's command line, restart the server and try again.")
                net.Start("libgmodstore_uploadlog")
                net.WriteBool(false)
                net.WriteString("console.log was not found on your server. Please look at your server's console for how to fix this.")
                net.Send(ply)
            end
        end
    end)

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

    -- We run on the first Think of the game and check for updates
    hook.Add("Think", "libgmodstore_checkforupdates", function()
        hook.Remove("Think", "libgmodstore_checkforupdates")
        hook.Run("libgmodstore_init") -- Getting addon informations
        local addons = {}

        for id, addon in pairs(libgmodstore.addons) do
            if not addon.options.version then continue end -- ignore addons without version info

            addons[#addons + 1] = {
                id = id,
                version = urlencode(addon.options.version),
                type = urlencode(addon.options.branch or "stable")
            }
        end

        -- Stats are disabled for now
        http.Post(URL .. "/api/versions", {
            addons = util.TableToJSON(addons) -- i hate http.Post for that
        }, function(body, size, headers, code)
            if (code ~= 200) then
                libgmodstore:LogError("[2] Error while checking for updates: HTTP " .. code)

                return
            end

            if (size == 0) then
                libgmodstore:LogError("[3] Error while checking for updates: empty body!")

                return
            end

            local decoded_body = util.JSONToTable(body)

            if not decoded_body then
                libgmodstore:LogError("[4] Error while checking for updates: JSON error!")

                return
            end

            for id, result in pairs(decoded_body) do
                if not istable(result) then
                    libgmodstore:LogError("[5]  Error while checking for updates on script " .. id .. ": Malformed Result.")
                    continue
                end

                if not result.success then
                    libgmodstore:LogError("[4] Error while checking for updates on script " .. id .. ": " .. result.error)
                    libgmodstore.addons[id].metadata.status = libgmodstore.ERROR
                    continue
                end

                if result.result.outdated then
                    libgmodstore:LogError("[" .. id .. "] " .. libgmodstore.addons[id].script_name .. " is outdated! The latest version is " .. result.result.version .. " while you have " .. libgmodstore.addons[id].options.version)
                    libgmodstore.addons[id].metadata.status = libgmodstore.OUTDATED
                else
                    libgmodstore:LogOk("[" .. id .. "] " .. libgmodstore.addons[id].script_name .. " is up to date!")
                    libgmodstore.addons[id].metadata.status = libgmodstore.OK
                end
            end
        end, function(err)
            libgmodstore:LogError("[1] Error while checking for updates: " .. err)
            libgmodstore.addons[id].metadata.status = libgmodstore.ERROR
        end)
    end)
end
