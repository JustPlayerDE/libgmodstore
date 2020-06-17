-- TODO: should i merge libgmodstore_init and libgmodstore?
-- TODO: Very basic Usage Statistics Tracker is planned, i'll implement the Opt-out option first in the next days or weeks! 
local URL = "https://libgmod.justplayer.de"
-- Will be disabled on default until 2020-06-25
local usage_stats_convar = CreateConVar("libgmodstore_enable_usage_tracker", "0", {FCVAR_ARCHIVE}, "Sends usage statistics for Content Creators.")

if libgmodstore and libgmodstore.debug then
    if (IsValid(libgmodstore.Menu)) then
        libgmodstore.Menu:Close()
    end

    if (IsValid(libgmodstore.AuthWindow)) then
        libgmodstore.AuthWindow:Remove()
    end
end

-- https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
local function urlencode(str)
    str = string.gsub(str, "\r?\n", "\r\n")
    str = string.gsub(str, "([^%w%-%.%_%~ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    str = string.gsub(str, " ", "+")

    return str
end

local function privacy(str)
    str = string.gsub(str, "[0-9]?[0-9]?[0-9]%.[0-9]?[0-9]?[0-9]%.[0-9]?[0-9]?[0-9]%.[0-9]?[0-9]?[0-9]", "x.x.x.x") -- Remove any IP

    return str
end

local function generateAddonReport()
    local addons = {}

    for id, meta in pairs(libgmodstore.scripts) do
        local data = {
            name = meta.script_name,
            id = id or "N/A",
            version = meta.options.version or "N/A",
            licensee = meta.options.licensee or "N/A"
        }

        table.insert(addons, data)
    end

    return urlencode(util.TableToJSON(addons))
end

if (SERVER) then
    libgmodstore.scripts = {}
    util.AddNetworkString("libgmodstore_openmenu")
    util.AddNetworkString("libgmodstore_uploaddebuglog")

    function libgmodstore:CanOpenMenu(ply, return_data)
        if (return_data == true) then
            local my_scripts = {}
            local my_scripts_count = 0

            for script_id, data in pairs(libgmodstore.scripts) do
                if (data.options.licensee ~= nil) then
                    if (ply:SteamID64() == data.options.licensee) then
                        my_scripts[script_id] = data
                        my_scripts_count = my_scripts_count + 1
                    end
                elseif (ply:IsSuperAdmin()) then
                    my_scripts[script_id] = data
                    my_scripts_count = my_scripts_count + 1
                end
            end

            return my_scripts, my_scripts_count
        else
            for script_id, data in pairs(libgmodstore.scripts) do
                if (data.options.licensee ~= nil) then
                    if (ply:SteamID64() == data.options.licensee) then return true end
                elseif (ply:IsSuperAdmin()) then
                    return true
                end
            end

            return false
        end
    end

    net.Receive("libgmodstore_uploaddebuglog", function(_, ply)
        local authcode = net.ReadString()

        if (libgmodstore:CanOpenMenu(ply, false)) then
            if (file.Exists("console.log", "GAME")) then
                local gamemode = (GM or GAMEMODE).Name

                if ((GM or GAMEMODE).BaseClass) then
                    gamemode = gamemode .. " (derived from " .. (GM or GAMEMODE).BaseClass.Name .. ")"
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
                    gamemode = gamemode,
                    avg_ping = tostring(avg_ping),
                    consolelog = privacy(file.Read("console.log", "GAME")),
                    token = authcode
                }

                http.Post(URL .. "/api/log/push", arguments, function(body, size, headers, code)
                    if (code ~= 200) then
                        net.Start("libgmodstore_uploaddebuglog")
                        net.WriteBool(false)
                        net.WriteString("HTTP " .. code)
                        net.Send(ply)

                        return
                    end

                    if (size == 0) then
                        net.Start("libgmodstore_uploaddebuglog")
                        net.WriteBool(false)
                        net.WriteString("Empty body!")
                        net.Send(ply)

                        return
                    end

                    local decoded_body = util.JSONToTable(body)

                    if (not decoded_body) then
                        net.Start("libgmodstore_uploaddebuglog")
                        net.WriteBool(false)
                        net.WriteString("JSON error!")
                        net.Send(ply)

                        return
                    end

                    if (not decoded_body.success) then
                        net.Start("libgmodstore_uploaddebuglog")
                        net.WriteBool(false)
                        net.WriteString(decoded_body.error)
                        net.Send(ply)

                        return
                    end

                    net.Start("libgmodstore_uploaddebuglog")
                    net.WriteBool(true)
                    net.WriteString(decoded_body.result)
                    net.Send(ply)
                end, function(err)
                    net.Start("libgmodstore_uploaddebuglog")
                    net.WriteBool(false)
                    net.WriteString(err)
                    net.Send(ply)
                end)
            else
                libgmodstore:print("console.log was not found on your server!", "bad")
                libgmodstore:print("You probably have not added -condebug to your server's command line.")
                libgmodstore:print("Add -condebug to your server's command line, restart the server and try again.")
                net.Start("libgmodstore_uploaddebuglog")
                net.WriteBool(false)
                net.WriteString("console.log was not found on your server. Please look at your server's console for how to fix this.")
                net.Send(ply)
            end
        end
    end)

    hook.Add("PlayerSay", "libgmodstore_openmenu", function(ply, txt)
        if (txt:lower() == "!libgmodstore") then
            local my_scripts, my_scripts_count = libgmodstore:CanOpenMenu(ply, true)
            net.Start("libgmodstore_openmenu")
            net.WriteInt(my_scripts_count, 12)

            for script_id, data in pairs(my_scripts) do
                net.WriteInt(script_id, 16)
                net.WriteString(data.script_name)
                net.WriteUInt(data.metadata.status, 2) -- ERROR,OK and OUTDATED
                net.WriteString(tostring(data.options.version or "UNKNOWN"))
            end

            net.Send(ply)

            return ""
        end
    end)

    function libgmodstore:InitScript(script_id, script_name, options)
        if (not tonumber(script_id) or (script_name or ""):Trim():len() == 0) then return false end
        libgmodstore:print("[" .. script_id .. "] " .. script_name .. " is using libgmodstore")

        libgmodstore.scripts[script_id] = {
            script_name = script_name,
            options = options,
            metadata = {}
        }

        if (options.version ~= nil) then
            local UpdateURL = URL .. "/api/checkversion/" .. urlencode(script_id) .. "/" .. urlencode(options.version)

            if usage_stats_convar:GetBool() and options.tracker then
                UpdateURL = UpdateURL .. "?tracking_id=" .. options.tracker
            end

            http.Fetch(UpdateURL, function(body, size, headers, code)
                if (code ~= 200) then
                    libgmodstore:print("[2] Error while checking for updates on script " .. script_id .. ": HTTP " .. code, "bad")
                    libgmodstore.scripts[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                if (size == 0) then
                    libgmodstore:print("[3] Error while checking for updates on script " .. script_id .. ": empty body!", "bad")
                    libgmodstore.scripts[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                local decoded_body = util.JSONToTable(body)

                if (not decoded_body) then
                    print(body)
                    libgmodstore:print("[4] Error while checking for updates on script " .. script_id .. ": JSON error!", "bad")
                    libgmodstore.scripts[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                if (not decoded_body.success) then
                    libgmodstore:print("[4] Error while checking for updates on script " .. script_id .. ": " .. decoded_body.error, "bad")
                    libgmodstore.scripts[script_id].metadata.status = libgmodstore.ERROR

                    return
                end

                if (decoded_body.result.outdated == true) then
                    libgmodstore:print("[" .. script_id .. "] " .. script_name .. " is outdated! The latest version is " .. decoded_body.result.version .. " while you have " .. options.version, "bad")
                    libgmodstore.scripts[script_id].metadata.status = libgmodstore.OUTDATED
                else
                    libgmodstore:print("[" .. script_id .. "] " .. script_name .. " is up to date!", "good")
                    libgmodstore.scripts[script_id].metadata.status = libgmodstore.OK
                end
            end, function(err)
                libgmodstore:print("[1] Error while checking for updates on script " .. script_id .. ": " .. err, "bad")
                libgmodstore.scripts[script_id].metadata.status = libgmodstore.ERROR
            end)
        else
            libgmodstore.scripts[script_id].metadata.status = libgmodstore.NO_VERSION
        end
        --]]

        return true
    end

    hook.Run("libgmodstore_init")
else
    local function paint_blank()
    end

    surface.CreateFont("libgmodstore", {
        font = "Roboto",
        size = 16
    })

    net.Receive("libgmodstore_uploaddebuglog", function()
        local success = net.ReadBool()

        if (not success) then
            local error = net.ReadString()
            Derma_Message("Error with trying to upload the debug log:\n" .. error, "Error", "OK")
        else
            local url = net.ReadString()

            Derma_StringRequest("Success", "Your debug log has been uploaded.\nYou can now copy and paste the link below to the content creator.", url, function() end, function()
                gui.OpenURL(url)
            end, "Close", "Open URL")
        end

        if (IsValid(libgmodstore.Menu)) then
            libgmodstore.Menu.Tabs.DebugLogs.Submit:SetDisabled(false)
        end
    end)

    net.Receive("libgmodstore_openmenu", function()
        local script_count = net.ReadInt(12)
        local scripts = {}

        for i = 1, script_count do
            local script_id = net.ReadInt(16)
            local script_name = net.ReadString()
            local status = net.ReadUInt(2)
            local version = net.ReadString()

            scripts[script_id] = {
                script_name = script_name,
                status = status,
                version = version
            }
        end

        if (IsValid(libgmodstore.Menu)) then
            libgmodstore.Menu:Close()
        end

        local width = ScrW() * 0.6
        local height = ScrH() * 0.6
        libgmodstore.Menu = vgui.Create("DFrame")
        local m = libgmodstore.Menu
        m:SetTitle("libgmodstore")
        m:SetIcon("icon16/shield.png")
        m:SetSize(width, height)
        m:Center()
        m:MakePopup()
        m.Tabs = vgui.Create("DPropertySheet", m)
        m.Tabs:Dock(FILL)

        function m.Tabs:OnActiveTabChanged(old, new)
            if new and new.m_pPanel.Html then
                self.m_pActiveTab = new
                new.m_pPanel.Html:LoadWebsite(new)
            end
        end

        m.Tabs.Info = vgui.Create("DPanel", m.Tabs)
        m.Tabs.Info:SetBackgroundColor(Color(35, 36, 31))
        m.Tabs:AddSheet("Info", m.Tabs.Info, "icon16/information.png")
        m.Tabs.Info.HTML = vgui.Create("DHTML", m.Tabs.Info)
        m.Tabs.Info.HTML:Dock(FILL)
        m.Tabs.Info.HTML:OpenURL(URL)
        m.Tabs.ActiveScripts = vgui.Create("DPanel", m.Tabs)
        m.Tabs.ActiveScripts:SetBackgroundColor(Color(35, 36, 31))
        m.Tabs:AddSheet("Active Scripts", m.Tabs.ActiveScripts, "icon16/script.png")
        m.Tabs.ScriptUpdates = vgui.Create("DPanel", m.Tabs)
        m.Tabs.ScriptUpdates:SetBackgroundColor(Color(35, 36, 31))
        m.Tabs:AddSheet("Script Updates", m.Tabs.ScriptUpdates, "icon16/script_edit.png")
        m.Tabs.DebugLogs = vgui.Create("DPanel", m.Tabs)
        m.Tabs.DebugLogs:SetBackgroundColor(Color(35, 36, 31))
        m.Tabs:AddSheet("Debug Logs", m.Tabs.DebugLogs, "icon16/bug_delete.png")
        m.Tabs.DebugLogs.Container = vgui.Create("DPanel", m.Tabs.DebugLogs)
        m.Tabs.DebugLogs.Container.Paint = paint_blank
        m.Tabs.DebugLogs.Instructions = vgui.Create("DLabel", m.Tabs.DebugLogs.Container)
        m.Tabs.DebugLogs.Instructions:SetFont("libgmodstore")
        m.Tabs.DebugLogs.Instructions:SetTextColor(Color(255, 255, 255))
        m.Tabs.DebugLogs.Instructions:SetContentAlignment(8)
        m.Tabs.DebugLogs.Instructions:Dock(TOP)
        m.Tabs.DebugLogs.Instructions:DockMargin(0, 0, 0, 20)
        m.Tabs.DebugLogs.Instructions:SetText([[If you're here, a content creator has probably asked you to supply them with a debug log
To do this, you need to Authenticate yourself with your Steam account.

This is only to prevent abuse of this system.

All IPs are removed before uploading.]])
        m.Tabs.DebugLogs.Submit = vgui.Create("DButton", m.Tabs.DebugLogs.Container)
        m.Tabs.DebugLogs.Submit:SetTall(25)
        m.Tabs.DebugLogs.Submit:Dock(TOP)
        m.Tabs.DebugLogs.Submit:SetText("Authenticate")

        -- TODO: Optimising Auth stuff
        -- i should replace the entire Instructions panel with a DHTML frame
        -- so there is no bad looking popup and the informations can be always up to date
        function m.Tabs.DebugLogs.Submit:DoClick()
            --m.Tabs.DebugLogs.Submit:SetDisabled(true)
            m.Tabs:SwitchToName("Authenticate")
        end

        function m.Tabs.DebugLogs:PerformLayout()
            m.Tabs.DebugLogs.Instructions:SizeToContentsY()
            --m.Tabs.DebugLogs.AuthorisationCode:DockMargin((self:GetWide() - 240) / 2, 0, (self:GetWide() - 240) / 2, 0)
            m.Tabs.DebugLogs.Submit:DockMargin((self:GetWide() - 100) / 2, 5, (self:GetWide() - 100) / 2, 0)
            m.Tabs.DebugLogs.Container:SizeToChildren(false, true)
            m.Tabs.DebugLogs.Container:Center()
            m.Tabs.DebugLogs.Container:SetWide(self:GetWide())
        end

        --[[
            Authenticate Tab
        ]]
        m.Tabs.AuthWindow = vgui.Create("DPanel", m.Tabs)
        m.Tabs.AuthWindow:SetBackgroundColor(Color(35, 36, 31))
        m.Tabs:AddSheet("Authenticate", m.Tabs.AuthWindow, "icon16/bug_delete.png").Tab:SetVisible(false)
        m.Tabs.AuthWindow.Html = vgui.Create("DHTML", m.Tabs.AuthWindow)
        m.Tabs.AuthWindow.Html:Dock(FILL)

        function m.Tabs.AuthWindow.Html:LoadWebsite(tab)
            if m.Tabs:GetActiveTab():GetText() ~= "Authenticate" then return end
            self:OpenURL(URL .. "/iaa")
        end

        m.Tabs.AuthWindow.Html:AddFunction("window", "SetAccessToken", function(token)
            if IsValid(m.Tabs) then
                m.Tabs:SwitchToName("Debug Logs")
            end

            net.Start("libgmodstore_uploaddebuglog")
            net.WriteString(token)
            net.SendToServer()
        end)

        m.Tabs.AuthWindow.Buttons = vgui.Create("DPanel", m.Tabs.AuthWindow)
        m.Tabs.AuthWindow.Buttons.Paint = function() end
        m.Tabs.AuthWindow.Buttons:Dock(BOTTOM)
        m.Tabs.AuthWindow.Retry = vgui.Create("DButton", m.Tabs.AuthWindow.Buttons)
        m.Tabs.AuthWindow.Retry:SetTall(25)
        m.Tabs.AuthWindow.Retry:Dock(LEFT)
        m.Tabs.AuthWindow.Retry:SetText("Retry")

        m.Tabs.AuthWindow.Retry.DoClick = function(self)
            if not IsValid(m.Tabs.AuthWindow.Html) then return end
            m.Tabs.AuthWindow.Html:LoadWebsite()
        end

        if (script_count == 0) then
            m.Tabs.ActiveScripts.Label = vgui.Create("DLabel", m.Tabs.ActiveScripts)
            m.Tabs.ActiveScripts.Label:SetFont("libgmodstore")
            m.Tabs.ActiveScripts.Label:Dock(FILL)
            m.Tabs.ActiveScripts.Label:SetContentAlignment(5)
            m.Tabs.ActiveScripts.Label:SetText("No scripts on your server are using libgmodstore.")
        else
            m.Tabs.ActiveScripts.List = vgui.Create("DListView", m.Tabs.ActiveScripts)
            m.Tabs.ActiveScripts.List:AddColumn("ID")
            m.Tabs.ActiveScripts.List:AddColumn("Name")
            m.Tabs.ActiveScripts.List:SetMultiSelect(false)
            m.Tabs.ActiveScripts.List:Dock(LEFT)

            function m.Tabs.ActiveScripts.List:OnRowSelected(_, row)
                m.Tabs.ActiveScripts.ScriptHTML:OpenURL("https://www.gmodstore.com/market/view/" .. row.script_id)
            end

            for script_id, data in pairs(scripts) do
                m.Tabs.ActiveScripts.List:AddLine(script_id, data.script_name).script_id = script_id
            end

            m.Tabs.ActiveScripts.List:SortByColumn(1, true)
            m.Tabs.ActiveScripts.ScriptHTML = vgui.Create("DHTML", m.Tabs.ActiveScripts)
            m.Tabs.ActiveScripts.ScriptHTML:Dock(RIGHT)

            function m.Tabs.ActiveScripts:PerformLayout()
                m.Tabs.ActiveScripts.List:SetSize(self:GetWide() * 0.25, 0)
                m.Tabs.ActiveScripts.ScriptHTML:SetSize(self:GetWide() * 0.75, 0)
            end

            m.Tabs.ActiveScripts.List:SelectFirstItem()
            m.Tabs.ScriptUpdates.List = vgui.Create("DListView", m.Tabs.ScriptUpdates)
            m.Tabs.ScriptUpdates.List:AddColumn("ID")
            m.Tabs.ScriptUpdates.List:AddColumn("Name")
            m.Tabs.ScriptUpdates.List:AddColumn("Outdated")
            m.Tabs.ScriptUpdates.List:AddColumn("Installed")
            m.Tabs.ScriptUpdates.List:SetMultiSelect(false)
            m.Tabs.ScriptUpdates.List:Dock(LEFT)

            function m.Tabs.ScriptUpdates.List:OnRowSelected(_, row)
                m.Tabs.ScriptUpdates.ScriptHTML:OpenURL("https://www.gmodstore.com/market/view/" .. row.script_id .. "/versions")
            end

            for script_id, data in pairs(scripts) do
                if data.status == libgmodstore.NO_VERSION then
                    m.Tabs.ScriptUpdates.List:AddLine(script_id, data.script_name, "N/A", data.version).script_id = script_id
                elseif data.status == libgmodstore.ERROR then
                    m.Tabs.ScriptUpdates.List:AddLine(script_id, data.script_name, "ERROR", data.version).script_id = script_id
                elseif data.status == libgmodstore.OUTDATED then
                    m.Tabs.ScriptUpdates.List:AddLine(script_id, data.script_name, "YES", data.version).script_id = script_id
                else
                    m.Tabs.ScriptUpdates.List:AddLine(script_id, data.script_name, "NO", data.version).script_id = script_id
                end
            end

            m.Tabs.ScriptUpdates.List:SortByColumn(1, true)
            m.Tabs.ScriptUpdates.ScriptHTML = vgui.Create("DHTML", m.Tabs.ScriptUpdates)
            m.Tabs.ScriptUpdates.ScriptHTML:Dock(RIGHT)

            function m.Tabs.ScriptUpdates:PerformLayout()
                m.Tabs.ScriptUpdates.List:SetSize(self:GetWide() * 0.35, 0)
                m.Tabs.ScriptUpdates.ScriptHTML:SetSize(self:GetWide() * 0.65, 0)
            end

            m.Tabs.ScriptUpdates.List:SelectFirstItem()
        end
    end)
end

libgmodstore:print("Initialised", "good")