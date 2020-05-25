local DEBUGGING = true

if (libgmodstore) then
    if (DEBUGGING) then
        if (IsValid(libgmodstore.Menu)) then
            libgmodstore.Menu:Close()
        end
    end
end

-- https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
local function urlencode(str)
    str = string.gsub(str, "\r?\n", "\r\n")
    str = string.gsub(str, "([^%w%-%.%_%~ ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    str = string.gsub(str, " ", "+")

    return str
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
            net.Start("libgmodstore_uploaddebuglog")
            net.WriteBool(false)
            net.WriteString("Feature is currently disabled!")
            net.Send(ply)
            -- [[ TODO: Upload log feature
			if (file.Exists("console.log","GAME")) then
				local gamemode = (GM or GAMEMODE).Name
				if ((GM or GAMEMODE).BaseClass) then
					gamemode = gamemode .. " (derived from " .. (GM or GAMEMODE).BaseClass.Name .. ")"
				end
				local avg_ping = 0
				for _,v in ipairs(player.GetHumans()) do
					avg_ping = avg_ping + v:Ping()
				end
				avg_ping = math.Round(avg_ping / #player.GetHumans())
				local arguments = {
					uploader = ply:SteamID64(),
					ip_address = game.GetIPAddress(),
					server_name = GetConVar("hostname"):GetString(),
					gamemode = gamemode,
					avg_ping = tostring(avg_ping),
					consolelog = file.Read("console.log","GAME"),
					authcode = authcode
				}
				http.Post("https://test.test/upload-debug-log.php",arguments,function(body,size,headers,code) -- TODO: server url
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
				end,function(err)
					net.Start("libgmodstore_uploaddebuglog")
						net.WriteBool(false)
						net.WriteString(err)
					net.Send(ply)
				end)
			else
				libgmodstore:print("console.log was not found on your server!","bad")
				libgmodstore:print("You probably have not added -condebug to your server's command line.")
				libgmodstore:print("Add -condebug to your server's command line, restart the server and try again.")

				net.Start("libgmodstore_uploaddebuglog")
					net.WriteBool(false)
					net.WriteString("console.log was not found on your server. Please look at your server's console for how to fix this.")
				net.Send(ply)
			end
            --]]
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
                net.WriteString(tostring(data.outdated))
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
        --[[ TODO: Update check feature
		if (options.version ~= nil) then -- Also broken
			http.Fetch("https://lib.gmodsto.re/api/update-check.php?script_id=" .. urlencode(script_id) .. "&version=" .. urlencode(options.version), function(body,size,headers,code)
				if (code ~= 200) then
					libgmodstore:print("[2] Error while checking for updates on script " .. script_id .. ": HTTP " .. code, "bad")
					libgmodstore.scripts[script_id].metadata.outdated = "ERROR"
					return
				end
				if (size == 0) then
					libgmodstore:print("[3] Error while checking for updates on script " .. script_id .. ": empty body!", "bad")
					libgmodstore.scripts[script_id].metadata.outdated = "ERROR"
					return
				end
				local decoded_body = util.JSONToTable(body)
				if (not decoded_body) then
					print(body)
					libgmodstore:print("[4] Error while checking for updates on script " .. script_id .. ": JSON error!", "bad")
					libgmodstore.scripts[script_id].metadata.outdated = "ERROR"
					return
				end
				if (not decoded_body.success) then
					libgmodstore:print("[4] Error while checking for updates on script " .. script_id .. ": " .. decoded_body.error, "bad")
					libgmodstore.scripts[script_id].metadata.outdated = "ERROR"
					return
				end
				if (decoded_body.result.outdated == true) then
					libgmodstore:print("[" .. script_id .. "] " .. script_name .. " is outdated! The latest version is " .. decoded_body.result.version .. " while you have " .. options.version, "bad")
					libgmodstore.scripts[script_id].metadata.outdated = true
				else
					libgmodstore:print("[" .. script_id .. "] " .. script_name .. " is up to date!", "good")
					libgmodstore.scripts[script_id].metadata.outdated = false
				end
			end,function(err)
				libgmodstore:print("[1] Error while checking for updates on script " .. script_id .. ": " .. err, "bad")
				libgmodstore.scripts[script_id].metadata.outdated = "ERROR"
			end)
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
            libgmodstore.Menu.Tabs.DebugLogs.AuthorisationCode:SetDisabled(false)
            libgmodstore.Menu.Tabs.DebugLogs.AuthorisationCode:SetValue("")
            libgmodstore.Menu.Tabs.DebugLogs.Submit:SetDisabled(false)
        end
    end)

    net.Receive("libgmodstore_openmenu", function()
        local script_count = net.ReadInt(12)
        local scripts = {}

        for i = 1, script_count do
            local script_id = net.ReadInt(16)
            local script_name = net.ReadString()
            local outdated = net.ReadString()
            local version = net.ReadString()

            scripts[script_id] = {
                script_name = script_name
            }

            if (tobool(outdated)) then
                scripts[script_id].outdated = tobool(outdated)
            else
                scripts[script_id].outdated = outdated
            end

            scripts[script_id].version = version
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
        m.Tabs.Info = vgui.Create("DPanel", m.Tabs)
        m.Tabs.Info:SetBackgroundColor(Color(35, 36, 31))
        m.Tabs:AddSheet("Info", m.Tabs.Info, "icon16/information.png")
        m.Tabs.Info.HTML = vgui.Create("DHTML", m.Tabs.Info)
        m.Tabs.Info.HTML:Dock(FILL)
        m.Tabs.Info.HTML:OpenURL("https://lib.gmodsto.re")
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
To do this, you will need an authorisation code that the content creator should supply you with
If they do not know where this is, they can get one at https://lib.gmodsto.re/debug/request/

Please enter the authorisation code below]])
        m.Tabs.DebugLogs.AuthorisationCode = vgui.Create("DTextEntry", m.Tabs.DebugLogs.Container)
        m.Tabs.DebugLogs.AuthorisationCode:SetTall(25)
        m.Tabs.DebugLogs.AuthorisationCode:Dock(TOP)
        m.Tabs.DebugLogs.Submit = vgui.Create("DButton", m.Tabs.DebugLogs.Container)
        m.Tabs.DebugLogs.Submit:SetTall(25)
        m.Tabs.DebugLogs.Submit:Dock(TOP)
        m.Tabs.DebugLogs.Submit:SetText("Submit")

        function m.Tabs.DebugLogs.Submit:DoClick()
            Derma_Message("This feature is currently not working!", "Error", "OK")
            -- TODO: Upload log feature
            m.Tabs.DebugLogs.Submit:SetDisabled(true)
            m.Tabs.DebugLogs.AuthorisationCode:SetDisabled(true)

            http.Fetch("https://test.test/validate-debug-auth.php?authcode=" .. m.Tabs.DebugLogs.AuthorisationCode:GetValue(), function(body, size, headers, code) -- TODO: server url
                if (code ~= 200) then
                    Derma_Message("Error with validating auth code!\nError: HTTP " .. code, "Error", "OK")
                    libgmodstore.Menu.Tabs.DebugLogs.AuthorisationCode:SetDisabled(false)
                    libgmodstore.Menu.Tabs.DebugLogs.Submit:SetDisabled(false)

                    return
                end

                if (size == 0) then
                    Derma_Message("Error with validating auth code!\nError: empty body!", "Error", "OK")
                    libgmodstore.Menu.Tabs.DebugLogs.AuthorisationCode:SetDisabled(false)
                    libgmodstore.Menu.Tabs.DebugLogs.Submit:SetDisabled(false)

                    return
                end

                local decoded_body = util.JSONToTable(body)

                if (not decoded_body) then
                    Derma_Message("Error with validating auth code!\nError: JSON error!", "Error", "OK")
                    libgmodstore.Menu.Tabs.DebugLogs.AuthorisationCode:SetDisabled(false)
                    libgmodstore.Menu.Tabs.DebugLogs.Submit:SetDisabled(false)

                    return
                end

                if (decoded_body.result == true) then
                    if (IsValid(m)) then
                        net.Start("libgmodstore_uploaddebuglog")
                        net.WriteString(m.Tabs.DebugLogs.AuthorisationCode:GetValue())
                        net.SendToServer()
                    end
                else
                    Derma_Message("Invalid authentication code.", "Error", "OK")
                    libgmodstore.Menu.Tabs.DebugLogs.AuthorisationCode:SetDisabled(false)
                    libgmodstore.Menu.Tabs.DebugLogs.Submit:SetDisabled(false)
                end
            end, function(err)
                Derma_Message("Error with validating auth code!\nError: " .. err, "Error", "OK")
                libgmodstore.Menu.Tabs.DebugLogs.AuthorisationCode:SetDisabled(false)
                libgmodstore.Menu.Tabs.DebugLogs.Submit:SetDisabled(false)
            end)
            --]]
        end

        function m.Tabs.DebugLogs:PerformLayout()
            m.Tabs.DebugLogs.Instructions:SizeToContentsY()
            m.Tabs.DebugLogs.AuthorisationCode:DockMargin((self:GetWide() - 240) / 2, 0, (self:GetWide() - 240) / 2, 0)
            m.Tabs.DebugLogs.Submit:DockMargin((self:GetWide() - 100) / 2, 5, (self:GetWide() - 100) / 2, 0)
            m.Tabs.DebugLogs.Container:SizeToChildren(false, true)
            m.Tabs.DebugLogs.Container:Center()
            m.Tabs.DebugLogs.Container:SetWide(self:GetWide())
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
                if (type(data.outdated) == "string") then
                    m.Tabs.ScriptUpdates.List:AddLine(script_id, data.script_name, "ERROR", data.version).script_id = script_id
                elseif (data.outdated == false) then
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