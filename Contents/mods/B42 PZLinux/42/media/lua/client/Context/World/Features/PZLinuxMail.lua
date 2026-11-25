require "PZLinuxConfig"
-- Mails UI - by Raixxar 
-- Updated : 13/12/25

require "Context/World/Features/PZLinuxUtils"

mailUI = ISPanel:derive("mailUI")

local LAST_CONNECTION_TIME = 0
local STAY_CONNECTED_TIME = 0
local PZLinuxOnItemMailName = ""
local ZLinuxOnItemMailPriceDelta = 1
local PZLinuxOnItemMail = {}
local PZLinuxOnItemMailCount = 0
local MONTH_HOURS = 30 * 24

local function addMailBox(parent, x, y, w, h)
    local panel = ISPanel:new(x, y, w, h)
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.48 }
    panel.borderColor = { r = 0, g = 0.45, b = 0, a = 0.72 }
    panel:initialise()
    parent:addChild(panel)
    return panel
end

local function styleMailButton(button)
    if not button then
        return
    end
    button.textColor = { r = 0, g = 1, b = 0, a = 1 }
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0.58 }
    button.borderColor = { r = 0, g = 0.52, b = 0, a = 0.78 }
end

-- CONSTRUCTOR
function mailUI:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.width = width
    o.height = height
    o.player = player
    o.isClosing = false
    return o
end

-- INIT
function mailUI:initialise()
    ISPanel.initialise(self)

    self.topBar = ISPanel:new(0, 0, self.width, self.height)
    self.topBar.backgroundColor = {r=0, g=0, b=0, a=0}
    self.topBar.borderColor = {r=0, g=0, b=0, a=0}
    self.topBar:setVisible(true)
    self:addChild(self.topBar)

    self.topBar.parent = self

    function self.topBar:onMouseDown(x, y)
        self.parent.isDragging = true
        self.parent.initialX = self.parent:getX()
        self.parent.initialY = self.parent:getY()
        self.parent.mouseStartX = getMouseX()
        self.parent.mouseStartY = getMouseY()
    end

    function self.topBar:onMouseMove(x, y)
        if self.parent.isDragging then
            local curMouseX = getMouseX()
            local curMouseY = getMouseY()
            local dx = curMouseX - self.parent.mouseStartX
            local dy = curMouseY - self.parent.mouseStartY
            self.parent:setX(self.parent.initialX + dx)
            self.parent:setY(self.parent.initialY + dy)
        end
    end

    function self.topBar:onMouseUp(x, y)
        self.parent.isDragging = false
        local modData = getPlayer():getModData()
        modData.PZLinuxUIX = self.parent:getX()
        modData.PZLinuxUIY = self.parent:getY()
    end

    self.stopButton = ISButton:new(self.width * 0.0728, self.height * 0.923, self.width * 0.045, self.height * 0.027, "X", self, self.onCloseX)
    self.stopButton.backgroundColor = {r=0.5, g=0, b=0, a=0.5}
    self.stopButton.borderColor = {r=0, g=0, b=0, a=1}
    self.stopButton:setVisible(false)
    self.stopButton:initialise()
    self.stopButton:setAnchorRight(true)
    self.topBar:addChild(self.stopButton)
    self.stopButton:setVisible(false)

    local playerUsername = "user@aol.com"
    local player = getPlayer()
    if player and player.getUsername then
        local okUsername, resolvedUsername = pcall(function()
            return player:getUsername()
        end)
        if okUsername and resolvedUsername and tostring(resolvedUsername) ~= "" then
            playerUsername = string.lower(tostring(resolvedUsername)) .. "@aol.com"
        end
    end

    self.titleLabel = ISLabel:new(self.width * 0.20, self.height * 0.17, self.height * 0.025, PZLinuxText("UI_PZLinux_MailTitle", "AOL | America Online - %s", tostring(playerUsername)), 0, 1, 0, 1, UIFont.Small, true)
    self.titleLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.titleLabel:setVisible(true)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    local modData = getPlayer():getModData()
    if modData.PZLinuxUISFX == 0 then
        self.skipAnimationButton = ISButton:new(self.width * 0.66, self.height * 0.17, self.width * 0.030, self.height * 0.025, "SFX", self, self.onSFXOff)
        self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
        self.skipAnimationButton.backgroundColor = {r=1, g=0, b=0, a=0.5}
        self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
        self.skipAnimationButton:setVisible(true)
        self.skipAnimationButton:initialise()
        self.topBar:addChild(self.skipAnimationButton)
    else
        self.skipAnimationButton = ISButton:new(self.width * 0.66, self.height * 0.17, self.width * 0.030, self.height * 0.025, "SFX", self, self.onSFXOn)
        self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
        self.skipAnimationButton.backgroundColor = {r=0, g=1, b=0, a=0.5}
        self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
        self.skipAnimationButton:setVisible(true)
        self.skipAnimationButton:initialise()
        self.topBar:addChild(self.skipAnimationButton)
    end

    self.minimizeButton = ISButton:new(self.width * 0.70, self.height * 0.17, self.width * 0.030, self.height * 0.025, "-", self, self.onMinimize)
    self.minimizeButton.textColor = {r=0, g=1, b=0, a=1}
    self.minimizeButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.minimizeButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.minimizeButton:setVisible(true)
    self.minimizeButton:initialise()
    self.topBar:addChild(self.minimizeButton)

    self.minimizeBackButton = ISButton:new(self.width * 0.70, self.height * 0.17, self.width * 0.030, self.height * 0.025, "-", self, self.onMinimizeBack)
    self.minimizeBackButton.textColor = {r=0, g=1, b=0, a=1}
    self.minimizeBackButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.minimizeBackButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.minimizeBackButton:setVisible(false)
    self.minimizeBackButton:initialise()
    self.topBar:addChild(self.minimizeBackButton)

    self.closeButton = ISButton:new(self.width * 0.73, self.height * 0.17, self.width * 0.030, self.height * 0.025, "x", self, self.onClose)
    self.closeButton.textColor = {r=0, g=1, b=0, a=1}
    self.closeButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.closeButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.topBar:addChild(self.closeButton)
    PZLinuxLayoutTerminalControls(self)
   
    local safe = self.pzSafe or PZLinuxGetTerminalSafeArea(self.width, self.height)
    local startX   = safe.x
    local rowH     = safe.rowH
    local colDateW = math.floor(safe.w * 0.28)
    local colFromW = math.floor(safe.w * 0.30)
    local colObjW  = safe.w - colDateW - colFromW

    local headerX = safe.x
    local headerY = safe.y + (safe.rowH * 2)

    local headerDate = ISLabel:new(headerX, headerY, rowH, PZLinuxText("UI_PZLinux_MailHeaderDate", "Date"), 0, 1, 0, 1, UIFont.Small, true)
    headerDate:initialise()
    self.topBar:addChild(headerDate)

    local headerFrom = ISLabel:new(headerX + colDateW, headerY, rowH, PZLinuxText("UI_PZLinux_MailHeaderFrom", "From"), 0, 1, 0, 1, UIFont.Small, true)
    headerFrom:initialise()
    self.topBar:addChild(headerFrom)

    local headerObj = ISLabel:new(headerX + colDateW + colFromW, headerY, rowH, PZLinuxText("UI_PZLinux_MailHeaderObject", "Object"), 0, 1, 0, 1, UIFont.Small, true)
    headerObj:initialise()
    self.topBar:addChild(headerObj)

    local sepY = headerY + rowH * 0.9
    local sep = ISPanel:new(startX, sepY, safe.w, 1)
    sep.backgroundColor = { r=0, g=1, b=0, a=0.35 }
    sep.borderColor     = { r=0, g=0, b=0, a=0 }
    sep:initialise()
    self.topBar:addChild(sep)
    -- Removed stale coordinate increment. In B42/Kahlua this was using the
    -- `initialise(x, y)` argument as a local coordinate and caused:
    -- "__add not defined for operands in initialise" when opening E-mail.
    -- Layout below is already calculated from the terminal safe area.

    local listX = safe.x
    local listY = headerY + rowH + safe.gap
    local listW = safe.w
    local listH = safe.bottom - listY

    local inboxBox = addMailBox(self.topBar, listX - 8, headerY - 6, listW + 16, (listY + listH) - headerY + 14)

    self.mailList = ISScrollingListBox:new(listX, listY, listW, listH)
    self.mailList:initialise()
    self.mailList:instantiate()
    self.mailList.backgroundColor = { r = 0, g = 0, b = 0, a = 0.78 }
    self.mailList.borderColor = { r = 0, g = 0.42, b = 0, a = 0.7 }
    self.mailList.itemheight = safe.rowH
    self.mailList.font = UIFont.Small
    self.mailList.doDrawItem = self.drawMailItem
    self.mailList.onMouseDown = function(_, x, y)
        ISScrollingListBox.onMouseDown(self.mailList, x, y)
        self:onMailClicked()
    end

    self.topBar:addChild(self.mailList)
    local md = PZLinuxGetModData()
    md.pzlinux.mails.inbox = md.pzlinux.mails.inbox or {}

    self.readWidgets = {}
    local function addRead(w)
        table.insert(self.readWidgets, w)
        w:setVisible(false)
    end

    self.inboxWidgets = { inboxBox, headerDate, headerFrom, headerObj, sep, self.mailList }

    local rx = safe.x
    local ry = safe.y + (safe.rowH * 2)
    local rw = safe.w
    local rh = safe.h - (safe.rowH * 5) - safe.gap

    self.readBox = addMailBox(self.topBar, rx - 8, ry - 8, rw + 16, rh + safe.rowH + (safe.gap * 3))
    addRead(self.readBox)

    self.readTitle = ISLabel:new(rx, ry, 20, "", 0,1,0,1, UIFont.Medium, true)
    self.readTitle:initialise()
    self.topBar:addChild(self.readTitle)
    addRead(self.readTitle)

    self.readMeta = ISLabel:new(rx, ry + 22, 20, "", 0,1,0,1, UIFont.Small, true)
    self.readMeta:initialise()
    self.topBar:addChild(self.readMeta)
    addRead(self.readMeta)

    self.readBody = ISRichTextPanel:new(rx, ry + 45, rw, rh)
    self.readBody:initialise()
    self.readBody:instantiate()
    self.readBody.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
    self.readBody.borderColor = { r = 0, g = 0.35, b = 0, a = 0.6 }
    self.topBar:addChild(self.readBody)
    addRead(self.readBody)

    -- Boutons bas
    local by = ry + rh + safe.gap
    local btnW = math.floor((rw - (safe.gap * 2)) / 3)
    self.btnBack = ISButton:new(rx, by, btnW, safe.rowH, PZLinuxText("UI_PZLinux_MailBack", "< Back"), self, self.onBackToInbox)
    styleMailButton(self.btnBack)
    self.btnBack:initialise(); self.topBar:addChild(self.btnBack); addRead(self.btnBack)

    self.btnAccept = ISButton:new(rx + btnW + safe.gap, by, btnW, safe.rowH, PZLinuxText("UI_PZLinux_MailAccept", "Accept"), self, self.onAcceptMail)
    styleMailButton(self.btnAccept)
    self.btnAccept:initialise(); self.topBar:addChild(self.btnAccept); addRead(self.btnAccept)

    self.btnDelete = ISButton:new(rx + ((btnW + safe.gap) * 2), by, btnW, safe.rowH, PZLinuxText("UI_PZLinux_MailDelete", "Delete"), self, self.onDeleteMail)
    styleMailButton(self.btnDelete)
    self.btnDelete:initialise(); self.topBar:addChild(self.btnDelete); addRead(self.btnDelete)

    self.selectedMailId = nil

    self:refreshInbox()
    self:setInboxVisible(true)
end

function mailUI:setInboxVisible(visible)
    for _,w in ipairs(self.inboxWidgets or {}) do w:setVisible(visible) end
    for _,w in ipairs(self.readWidgets  or {}) do w:setVisible(not visible) end
end

function mailUI:refreshInbox()
    if not self.mailList then return end

    if self.mailList.clear then
        self.mailList:clear()
    else
        self.mailList.items = {}
        self.mailList.selected = 0
    end

    local md = PZLinuxGetModData()
    md.pzlinux.mails.inbox = md.pzlinux.mails.inbox or {}

    for i = 1, #md.pzlinux.mails.inbox do
        local mail = md.pzlinux.mails.inbox[i]
        self.mailList:addItem(mail.id, mail)
    end
end

function mailUI:drawMailItem(y, item, alt)
    local mail = item.item

    if self.selected == item.index then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0, 1, 0)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.1, 0, 0, 0)
    end

    local r, g, b = 0, 1, 0
    if mail.read then
        r, g, b = 0.6, 0.6, 0.6
    end

    self:drawText(tostring(mail.date or ""), 10, y + 6, r, g, b, 1)
    self:drawText(tostring(mail.from or ""), math.floor(self.width * 0.32), y + 6, r, g, b, 1)
    self:drawText(tostring(mail.name or ""), math.floor(self.width * 0.62), y + 6, r, g, b, 1)

    return y + self.itemheight
end

function mailUI:onMailClicked()
    local item = self.mailList.items[self.mailList.selected]
    if not item then return end

    local mail = item.item
    mail.read = true

    self.selectedMailId = mail.id
    local body = ""
    local okBody, generatedBody = pcall(function()
        if mail.type == "ads" then
            return PZLinuxMailGenerateBodyADS(mail.from, mail.id)
        elseif mail.type == "ammo" then
            return PZLinuxMailGenerateBodyAmmo(mail.from, mail.id)
        elseif mail.type == "medical" then
            return PZLinuxMailGenerateBodyMedical(mail.from, mail.id)
        end
        return ""
    end)

    if okBody then
        body = tostring(generatedBody or "")
    else
        body = PZLinuxText("UI_PZLinux_MailBodyError", "Unable to load this message.")
        if not self.mailBodyErrorLogged then
            print("[PZLinuxMail] Failed to generate mail body: " .. tostring(generatedBody))
            self.mailBodyErrorLogged = true
        end
    end

    self.readTitle:setName(tostring(mail.name))
    self.readMeta:setName(PZLinuxText("UI_PZLinux_MailMeta", "From: %s | Date: %s", tostring(mail.from), tostring(mail.date)))

    self.readBody.text = "<GREEN>" .. tostring(body) .. "</GREEN>"
    self.readBody:paginate()

    self:setInboxVisible(false)
end

function mailUI:onBackToInbox()
    self.selectedMailId = nil
    self:setInboxVisible(true)
    self:refreshInbox()
end

function mailUI:onAcceptMail()
    local md = PZLinuxGetModData()
    local id = self.selectedMailId
    local _, _, mail = PZLinuxGetMailEntry(nil, id)
    if not mail then return end

    local inboxMail = nil
    for i = 1, #md.pzlinux.mails.inbox do
        local entry = md.pzlinux.mails.inbox[i]
        if entry and PZLinuxMailIdsMatch(entry.id, id) then
            inboxMail = entry
            break
        end
    end

    local mailType = mail.type or (inboxMail and inboxMail.type) or ""
    local mailStatus = tonumber(mail.status) or mail.status
    if mailStatus == 10 or mailStatus == 2 or mailType == "ads" then return end

    mail.status = 2
    if not mail.type and mailType ~= "" then
        mail.type = mailType
    end
    self:onBackToInbox()
    if mail.x ~= nil and mail.y ~= nil and mail.quantity ~= nil and type(mail.object) == "string" then
        local displayName = PZLinuxGetItemDisplayName(mail.object, mail.object)
        local mapText = tostring(mail.quantity) .. "* " .. displayName
        contractsDrawOnMap(mail.x, mail.y, mapText)
    end
    PZLinuxSyncPlayerModData()
end

function mailUI:onDeleteMail()
    local md = PZLinuxGetModData()
    md.pzlinux.mails.inbox = md.pzlinux.mails.inbox or {}

    local id = self.selectedMailId
    local _, mails, _, resolvedKey = PZLinuxGetMailEntry(nil, id)
    if mails and resolvedKey ~= nil then
        mails[resolvedKey] = nil
    end

    for i = #md.pzlinux.mails.inbox, 1, -1 do
        local inboxMail = md.pzlinux.mails.inbox[i]
        if inboxMail and PZLinuxMailIdsMatch(inboxMail.id, id) then
            table.remove(md.pzlinux.mails.inbox, i)
            break
        end
    end

    self:onBackToInbox()
    PZLinuxSyncPlayerModData()
end

-- LOGOUT
function mailUI:onMinimize(button)
    self.isClosing = true
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 1
end

function mailUI:onMinimizeBack(button)
    self.isClosing = true
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 8
end

-- CLOSE
function mailUI:onClose(button)
    self.isClosing = true
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 1
end

function mailUI:onCloseX(button)
    self.isClosing = true
    getPlayer():StopAllActionQueue()

end

function mailUI:onSFXOn(button)
    local modData = getPlayer():getModData()
    modData.PZLinuxUISFX = 0
    self.skipAnimationButton:close()
    self.skipAnimationButton = ISButton:new(self.width * 0.66, self.height * 0.17, self.width * 0.030, self.height * 0.025, "SFX", self, self.onSFXOff)
    self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
    self.skipAnimationButton.backgroundColor = {r=1, g=0, b=0, a=0.5}
    self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.skipAnimationButton:setVisible(true)
    self.skipAnimationButton:initialise()
    self.topBar:addChild(self.skipAnimationButton)
    PZLinuxLayoutTerminalControls(self)
end

function mailUI:onSFXOff(button)
    local modData = getPlayer():getModData()
    modData.PZLinuxUISFX = 1
    self.skipAnimationButton:close()
    self.skipAnimationButton = ISButton:new(self.width * 0.66, self.height * 0.17, self.width * 0.030, self.height * 0.025, "SFX", self, self.onSFXOn)
    self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
    self.skipAnimationButton.backgroundColor = {r=0, g=1, b=0, a=0.5}
    self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.skipAnimationButton:setVisible(true)
    self.skipAnimationButton:initialise()
    self.topBar:addChild(self.skipAnimationButton)
    PZLinuxLayoutTerminalControls(self)
end

function mailMenu_ShowUI(player)
    if not PZLinuxRequireFeature("Mail", player) then return end
    local texture = getTexture("media/ui/PC100.png")
    if not texture then return end

    local realScreenW = getCore():getScreenWidth()
    local realScreenH = getCore():getScreenHeight()

    local maxW = realScreenW * 0.86
    local maxH = realScreenH * 0.90
    local texW = texture:getWidth()
    local texH = texture:getHeight()

    local ratioX, ratioY = maxW / texW, maxH / texH
    local scale  = math.min(ratioX, ratioY)
    local finalW, finalH = math.floor(texW * scale), math.floor(texH * scale)
    
    local modData = getPlayer():getModData()
    local uiX = modData.PZLinuxUIX or (realScreenW - finalW) / 2
    local uiY = modData.PZLinuxUIY or (realScreenH - finalH) / 2
    uiX = math.max(0, math.min(uiX, realScreenW - finalW))
    uiY = math.max(0, math.min(uiY, realScreenH - finalH))

    local ui = mailUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)

    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    ui:addChild(centeredImage)
    ui.centeredImage = centeredImage
    ui:initialise()
    ui:addToUIManager()
 
    return ui
end
