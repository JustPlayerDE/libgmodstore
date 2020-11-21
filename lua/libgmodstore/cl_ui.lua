local rgb = Color
local fetch = http.Fetch
local ImgurCache = {}
local URL = "https://libgmod.justplayer.de"
file.CreateDir("darklib/images")

local function Scale(base)
    return math.ceil(ScrH() * (base / 1080))
end

local function LoadMaterial(imgur_id, callback)
    if ImgurCache[imgur_id] ~= nil then
        -- Already in cache 
        callback(ImgurCache[imgur_id])
    else
        -- Not in cache
        if file.Exists("darklib/images/" .. imgur_id .. ".png", "DATA") then
            -- File in data cache 
            ImgurCache[imgur_id] = Material("data/darklib/images/" .. imgur_id .. ".png", "noclamp smooth")
            callback(ImgurCache[imgur_id])
        else
            -- File not in data cache
            fetch("https://i.imgur.com/" .. imgur_id .. ".png", function(body, size)
                -- Fetched stuff
                if not body or tonumber(size) == 0 then
                    callback(nil)

                    return
                end

                file.Write("darklib/images/" .. imgur_id .. ".png", body)
                ImgurCache[imgur_id] = Material("data/darklib/images/" .. imgur_id .. ".png", "noclamp smooth")
                callback(ImgurCache[imgur_id])
            end, function(error)
                callback(nil)
            end)
        end
    end
end

surface.CreateFont("libgmodstore.Title", {
    font = "Roboto",
    size = Scale(24)
})

surface.CreateFont("libgmodstore.Button", {
    font = "Roboto",
    size = Scale(18),
    weight = 500
})

surface.CreateFont("libgmodstore", {
    font = "Roboto",
    size = Scale(18)
})

local Colors = {
    Primary = rgb(36, 38, 38),
    PrimaryAlternate = rgb(40, 42, 42),
    Background = rgb(54, 54, 58),
    BackgroundAlternate = rgb(48, 48, 42),
    Accent = rgb(92, 103, 125),
    Red = rgb(230, 58, 64),
    Green = rgb(46, 204, 113),
    Blue = rgb(41, 128, 185),
    Text = color_white,
    TextInactive = Color(200, 200, 200, 190)
}

local Common = {
    HeaderHeight = Scale(34),
    ButtonHeight = Scale(28),
    ItemHeight = Scale(24),
    Padding = Scale(4),
    Line = Scale(2),
    Corners = Scale(6)
}

local InfoMaterials = {
    [libgmodstore.ERROR] = {
        mat = Material("icon16/exclamation.png"),
        color = color_white
    },
    [libgmodstore.OK] = {
        mat = Material("icon16/accept.png"),
        color = Colors.Blue
    },
    [libgmodstore.OUTDATED] = {
        mat = Material("icon16/information.png"),
        color = colors_white
    },
    [libgmodstore.NO_VERSION] = {
        mat = Material("icon16/help.png"),
        color = color_white
    }
}

local CloseMaterial = Material("gui/close_32")
local LoadingMaterial = Material("gui/close_32")

-- Build Addon info stuff
local function BuildAddonInfo(gmodstore_id, pnl, addon)
    if not IsValid(pnl) then return end
    -- Title
    local NamePanel = vgui.Create("DPanel", pnl)
    NamePanel.Paint = nil
    NamePanel:Dock(TOP)

    NamePanel.Paint = function(self, w, h)
        surface.SetDrawColor(Colors.Primary)
        surface.DrawRect(0, h - Common.Line, w, Common.Line)
    end

    NamePanel:SetTall(Common.HeaderHeight)
    local AddonName = vgui.Create("DLabel", NamePanel)
    AddonName:Dock(FILL)
    AddonName:SetText(addon.script_name)
    AddonName:SetFont("libgmodstore.Title")
    -- version
    local AddonVersion = vgui.Create("DLabel", NamePanel)
    AddonVersion:Dock(RIGHT)
    AddonVersion:SetText(addon.version)
    AddonVersion:SetFont("libgmodstore")
    AddonVersion:SizeToContents()
    -- Gmodstore Stuff  
    local html = vgui.Create("DHTML", pnl)
    html:Dock(TOP)
    html:SetTall(pnl:GetTall() - NamePanel:GetTall() - Scale(4))
    html:OpenURL("https://www.gmodstore.com/market/view/" .. gmodstore_id .. "/versions")
    local size = Scale(64)

    html.Paint = function(self, w, h)
        surface.SetMaterial(LoadingMaterial)
        surface.SetDrawColor(Colors.Red)
        surface.DrawTexturedRectRotated(w / 2, h / 2, size, size, (CurTime() % 360) * -100)
    end
end

net.Receive("libgmodstore_open", function()
    local count = net.ReadInt(12)
    local addons = {}
    libgmodstore:LogDebug("Received " .. count .. " Addons")

    for i = 1, count do
        local script_id = net.ReadInt(16)
        local script_name = net.ReadString()
        local status = net.ReadUInt(2)
        local version = net.ReadString()

        addons[script_id] = {
            script_name = script_name,
            status = status,
            version = version
        }
    end

    if (IsValid(libgmodstore.Menu)) then
        libgmodstore.Menu:Close()
    end

    libgmodstore.Menu = vgui.Create("DFrame")
    local m = libgmodstore.Menu

    -- Loading Images 
    do
        LoadMaterial("HgMhjrI", function(mat)
            if not mat or mat:IsError() then return end
            CloseMaterial = mat
        end)

        LoadMaterial("Ao9Ol3D", function(mat)
            if not mat or mat:IsError() then return end
            InfoMaterials[libgmodstore.ERROR].mat = mat
            InfoMaterials[libgmodstore.ERROR].color = Colors.Red
            -- Own icon for no version?
            InfoMaterials[libgmodstore.NO_VERSION].mat = mat
            InfoMaterials[libgmodstore.NO_VERSION].color = Colors.Red
        end)

        LoadMaterial("DtvLocN", function(mat)
            if not mat or mat:IsError() then return end
            InfoMaterials[libgmodstore.OK].mat = mat
            InfoMaterials[libgmodstore.OK].color = Colors.Green
        end)

        LoadMaterial("ziK3us0", function(mat)
            if not mat or mat:IsError() then return end
            InfoMaterials[libgmodstore.OUTDATED].mat = mat
            InfoMaterials[libgmodstore.OUTDATED].color = Colors.Blue
        end)

        LoadMaterial("MSCM9Mf", function(mat)
            if not mat or mat:IsError() then return end
            InfoMaterials[libgmodstore.NO_VERSION].mat = mat
            InfoMaterials[libgmodstore.NO_VERSION].color = Colors.Red
        end)

        LoadMaterial("mJglYYR", function(mat)
            if not mat or mat:IsError() then return end
            LoadingMaterial = mat
        end)
    end

    -- Setup DFrame
    do
        m.btnMinim:Hide()
        m.btnMaxim:Hide()
        m.lblTitle:SetFont("libgmodstore.Title")
        m:SetTitle("libgmodstore")
        m:SetSize(Scale(1150), Scale(650))
        m:SetDraggable(false)
        m:DockPadding(0, Common.HeaderHeight, 0, 0)
        -- Create body panel
        m.body = vgui.Create("DScrollPanel", m)
        m.body:DockMargin(Common.Padding, 0, Common.Padding, 0)
        m.body:Dock(FILL)
        -- Create Addon List panel
        m.listpanel = vgui.Create("DPanel", m)
        m.listpanel:DockPadding(Common.Padding, Common.Padding, Common.Padding, Common.Padding * 2)
        m.listpanel:Dock(LEFT)
        m.list = vgui.Create("DScrollPanel", m.listpanel)
        m.list:Dock(FILL)
        m.list.VBar:SetWide(Scale(3))
        m.list.VBar:SetHideButtons(true)

        m.list.VBar.Paint = function(self, w, h)
            surface.SetDrawColor(Colors.Primary)
            surface.DrawRect(0, 0, w, h)
        end

        m.list.VBar.btnGrip.Paint = function(self, w, h)
            surface.SetDrawColor(Colors.Background)
            surface.DrawRect(0, 0, w, h)
        end

        m.listpanel.Paint = function(self, w, h)
            draw.RoundedBoxEx(Common.Corners, 0, 0, w, h, Colors.Primary, false, false, true)
        end

        m.Paint = function(self, w, h)
            draw.RoundedBox(Common.Corners, 0, 0, w, h, Colors.Background)
            draw.RoundedBoxEx(Common.Corners, 0, 0, w, Common.HeaderHeight, Colors.Primary, true, true)
        end

        m.PerformLayout = function(self, w, h)
            if IsValid(self.listpanel) then
                self.listpanel:SetWide(self:GetWide() * 0.3)
            end

            self.lblTitle:SetSize(self:GetWide() - Common.HeaderHeight, Common.HeaderHeight)
            self.lblTitle:SetPos(Scale(8), Common.HeaderHeight / 2 - self.lblTitle:GetTall() / 2)
            self.btnClose:SetPos(self:GetWide() - Common.HeaderHeight, 0)
            self.btnClose:SetSize(Common.HeaderHeight, Common.HeaderHeight)
        end

        m.btnClose.Paint = function(pnl, w, h)
            local margin = Scale(8)
            surface.SetDrawColor(pnl:IsHovered() and Colors.Red or color_white)
            surface.SetMaterial(CloseMaterial) -- TODO: Create material 
            surface.DrawTexturedRect(margin, margin, w - (margin * 2), h - (margin * 2))
        end

        m:Center()
        m:MakePopup()
    end

    local margin = Scale(4)
    local offset = Scale(2)
    local count = 1

    for id, addon in pairs(addons) do
        local btnPanel = vgui.Create("DPanel", m.list)
        local Color = ((count % 2 == 0) and Colors.PrimaryAlternate or Colors.Primary)
        btnPanel:Dock(TOP)
        btnPanel:DockMargin(0, 0, 0, margin)
        btnPanel:SetTall(Common.ItemHeight)
        btnPanel.Paint = nil
        --- Button
        local btn = vgui.Create("DButton", btnPanel)
        btn:SetFont("libgmodstore.Button")
        btn:SetTextInset(Scale(4), 0)
        btn:SetContentAlignment(4)
        btn:Dock(FILL)
        btn:SetTextColor(Colors.TextInactive)
        btn:SetText(addon.script_name)
        btn.addon = addon

        btn.DoClick = function(self)
            if IsValid(m.list.Current) then
                if m.list.Current == self then return end
                m.list.Current:SetTextColor(Colors.TextInactive)
            end

            m.list.Current = self
            m.body:Clear()
            BuildAddonInfo(id, m.body, addon)
            self:SetTextColor(Colors.Text)
        end

        -- Status
        local status = vgui.Create("DPanel", btnPanel)
        status:Dock(RIGHT)

        status.PerformLayout = function(self, w, h)
            self:SetWide(self:GetTall())
        end

        -- Paint
        btn.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and Colors.Background or Color)
            surface.DrawRect(0, 0, w, h)
        end

        status.Paint = function(self, w, h)
            surface.SetDrawColor(btn:IsHovered() and Colors.Background or Color)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(InfoMaterials[addon.status].color or color_white)
            surface.SetMaterial(InfoMaterials[addon.status].mat)
            surface.DrawTexturedRect(w - h + offset, offset, h - (offset * 2), h - (offset * 2))
        end

        count = count + 1
    end

    --- Upload Log
    local btn = vgui.Create("DButton", m.listpanel)
    btn:SetFont("libgmodstore.Button")
    btn:SetTextInset(Scale(4), 0)
    btn:DockMargin(0, Scale(6), 0, 0)
    btn:Dock(BOTTOM)
    btn:SetTextColor(Colors.Text)
    btn:SetText("Log Uploader")
    btn:SetTall(Common.ButtonHeight)

    btn.Paint = function(self, w, h)
        surface.SetDrawColor(self:IsHovered() and Colors.Background or Colors.PrimaryAlternate)
        surface.DrawRect(0, 0, w, h)
    end

    btn.DoClick = function(self)
        if m.DebugLogs and IsValid(m.DebugLogs.Instructions) then return end

        -- Clear Selection if set
        do
            if IsValid(m.list.Current) then
                if m.list.Current == self then return end
                m.list.Current:SetTextColor(Colors.TextInactive)
            end

            m.list.Current = nil
        end

        m.body:Clear()
        m.DebugLogs = {}
        m.DebugLogs.Instructions = vgui.Create("DLabel", m.body)
        m.DebugLogs.Instructions:SetFont("libgmodstore")
        m.DebugLogs.Instructions:SetTextColor(Color(255, 255, 255))
        m.DebugLogs.Instructions:SetContentAlignment(8)
        m.DebugLogs.Instructions:Dock(TOP)
        m.DebugLogs.Instructions:DockMargin(0, m.body:GetTall() / 3, 0, 10)
        m.DebugLogs.Instructions:SetText([[If you're here, a content creator has probably asked you to supply them with a debug log
To do this, you need to Authenticate yourself with your Steam account.

This is only to prevent abuse of this system.

All IPs are removed before uploading.]])
        m.DebugLogs.Instructions:SizeToContents()
        m.DebugLogs.Submit = vgui.Create("DButton", m.body)
        m.DebugLogs.Submit:SetTall(Common.ButtonHeight)
        m.DebugLogs.Submit:Dock(TOP)
        m.DebugLogs.Submit:SetFont("libgmodstore.Button")
        m.DebugLogs.Submit:SetText("Authenticate")
        m.DebugLogs.Submit:SetTextColor(Colors.Text)

        m.DebugLogs.Submit.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and Colors.PrimaryAlternate or Colors.Background)
            surface.DrawRect(0, 0, w, h)
        end

        m.DebugLogs.Submit.DoClick = function(self)
            --[[
                Authenticate Tab
            ]]
            m.body:Clear()
            m.AuthWindow = vgui.Create("DPanel", m.body)
            m.AuthWindow:Dock(TOP)
            m.AuthWindow:SetTall(m.body:GetTall() * .99)
            m.AuthWindow.Html = vgui.Create("DHTML", m.AuthWindow)
            m.AuthWindow.Html:Dock(FILL)

            function m.AuthWindow.Html:LoadWebsite(tab)
                self:OpenURL(URL .. "/iaa")
            end

            local size = Scale(64)

            m.AuthWindow.Html.Paint = function(self, w, h)
                surface.SetMaterial(LoadingMaterial)
                surface.SetDrawColor(Colors.Red)
                surface.DrawTexturedRectRotated(w / 2, h / 2, size, size, (CurTime() % 360) * -100)
            end

            m.AuthWindow.Html:AddFunction("window", "SetAccessToken", function(token)
                if IsValid(m) then
                    m.body:Clear()
                    --m:SwitchToName("Debug Logs")
                end

                net.Start("libgmodstore_uploadlog")
                net.WriteString(token)
                net.SendToServer()
            end)

            m.AuthWindow.Buttons = vgui.Create("DPanel", m.AuthWindow)
            m.AuthWindow.Buttons.Paint = function() end
            m.AuthWindow.Buttons:Dock(BOTTOM)
            m.AuthWindow.Retry = vgui.Create("DButton", m.AuthWindow.Buttons)
            m.AuthWindow.Retry:SetTall(Common.ButtonHeight)
            m.AuthWindow.Retry:Dock(BOTTOM)
            m.AuthWindow.Retry:SetText("Retry")
            m.AuthWindow.Retry:SetFont("libgmodstore")
            m.AuthWindow.Retry:SetTextColor(Colors.Text)

            m.AuthWindow.Retry.Paint = function(self, w, h)
                surface.SetDrawColor(self:IsHovered() and Colors.PrimaryAlternate or Colors.Background)
                surface.DrawRect(0, 0, w, h)
            end

            m.AuthWindow.Retry.DoClick = function(self)
                if not IsValid(m.AuthWindow.Html) then return end
                m.AuthWindow.Html:LoadWebsite()
            end

            m.AuthWindow.Html:LoadWebsite()
        end
    end
end)

net.Receive("libgmodstore_uploadlog", function()
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
end)