require "PZLinuxConfig"
require "PZLinuxEconomy"

converterUI = ISPanel:derive("converterUI")

local function playConverterSound(player, soundName)
    if not player or not soundName or not player.getSquare then
        return
    end

    local square = player:getSquare()
    if not square then
        return
    end

    local sound = getSoundManager():PlayWorldSound(soundName, false, square, 0, 20, 1, true)
    if sound and sound.setVolume then
        sound:setVolume(getCore():getOptionSoundVolume() / 50)
    end
end

local function styleTerminalButton(button)
    button.textColor = { r = 0, g = 1, b = 0, a = 1 }
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0.62 }
    button.borderColor = { r = 0, g = 0.65, b = 0, a = 0.78 }
end

local function getTerminalScreenRect(width, height)
    return {
        x = math.floor(width * 0.12),
        y = math.floor(height * 0.125),
        w = math.floor(width * 0.76),
        h = math.floor(height * 0.52),
    }
end

local function getResponsiveTerminalSize(texture)
    local realScreenW = getCore():getScreenWidth()
    local realScreenH = getCore():getScreenHeight()
    local maxW = realScreenW * 0.86
    local maxH = realScreenH * 0.90
    local scale = math.min(maxW / texture:getWidth(), maxH / texture:getHeight())
    return realScreenW, realScreenH, math.floor(texture:getWidth() * scale), math.floor(texture:getHeight() * scale)
end

function converterUI:new(x, y, width, height, player)
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

function converterUI:initialise()
    ISPanel.initialise(self)

    local screen = getTerminalScreenRect(self.width, self.height)
    local x = screen.x
    local y = screen.y
    local w = screen.w
    local h = screen.h
    local gap = math.max(8, math.floor(h * 0.025))
    local rowH = math.max(24, math.floor(h * 0.075))
    local buttonW = math.floor(w * 0.34)
    local leftX = x + math.floor(w * 0.04)
    local rightX = x + math.floor(w * 0.54)

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
            local dx = getMouseX() - self.parent.mouseStartX
            local dy = getMouseY() - self.parent.mouseStartY
            self.parent:setX(self.parent.initialX + dx)
            self.parent:setY(self.parent.initialY + dy)
        end
    end
    function self.topBar:onMouseUp(x, y)
        self.parent.isDragging = false
        local modData = PZLinuxGetModData()
        modData.PZLinuxUIX = self.parent:getX()
        modData.PZLinuxUIY = self.parent:getY()
    end

    self.stopButton = ISButton:new(self.width * 0.0728, self.height * 0.923, self.width * 0.045, self.height * 0.027, "X", self, self.onCloseX)
    self.stopButton.backgroundColor = {r=0.5, g=0, b=0, a=0.5}
    self.stopButton.borderColor = {r=0, g=0, b=0, a=1}
    self.stopButton:setVisible(false)
    self.stopButton:initialise()
    self.topBar:addChild(self.stopButton)

    self.minimizeButton = ISButton:new(x + w - 52, y + 2, 24, 20, "-", self, self.onMinimize)
    styleTerminalButton(self.minimizeButton)
    self.minimizeButton:setVisible(true)
    self.minimizeButton:initialise()
    self.topBar:addChild(self.minimizeButton)

    self.closeButton = ISButton:new(x + w - 24, y + 2, 24, 20, "x", self, self.onClose)
    styleTerminalButton(self.closeButton)
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.topBar:addChild(self.closeButton)

    self.titleLabel = ISLabel:new(leftX, y + 4, rowH, PZLinuxText("UI_PZLinux_ConverterTitle", "Money Converter"), 0, 1, 0, 1, UIFont.Small, true)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    self.coinLabel = ISLabel:new(leftX, y + rowH + gap, rowH, "", 0, 1, 0, 1, UIFont.Small, true)
    self.coinLabel:initialise()
    self.topBar:addChild(self.coinLabel)

    self.inventoryCoinLabel = ISLabel:new(leftX, y + rowH + gap + rowH, rowH, "", 0, 0.78, 0, 1, UIFont.Small, true)
    self.inventoryCoinLabel:initialise()
    self.topBar:addChild(self.inventoryCoinLabel)

    self.forwardLabel = ISLabel:new(leftX, y + math.floor(h * 0.34), rowH, PZLinuxText("UI_PZLinux_ConverterForward", "Converter"), 0, 1, 0, 1, UIFont.Small, true)
    self.forwardLabel:initialise()
    self.topBar:addChild(self.forwardLabel)

    self.convertCopperButton = ISButton:new(leftX, y + math.floor(h * 0.43), buttonW, rowH, PZLinuxCurrencyText("UI_PZLinux_ConvertCopperSilver", "100 Money -> 1 Money Bundle"), self, self.onConvert)
    self.convertCopperButton.internal = "copper_to_silver"
    styleTerminalButton(self.convertCopperButton)
    self.convertCopperButton:initialise()
    self.topBar:addChild(self.convertCopperButton)

    self.convertSilverButton = ISButton:new(leftX, y + math.floor(h * 0.43) + rowH + gap, buttonW, rowH, PZLinuxCurrencyText("UI_PZLinux_ConvertSilverGold", "100 Money -> 1 Money Bundle"), self, self.onConvert)
    self.convertSilverButton.internal = "silver_to_gold"
    styleTerminalButton(self.convertSilverButton)
    self.convertSilverButton:initialise()
    self.convertSilverButton:setVisible(PZLinuxConfig.Get("CurrencyMode") == 2)
    self.topBar:addChild(self.convertSilverButton)

    self.retroTitleLabel = ISLabel:new(rightX, y + math.floor(h * 0.34), rowH, PZLinuxText("UI_PZLinux_Retroceder", "Retroceder"), 0, 1, 0, 1, UIFont.Small, true)
    self.retroTitleLabel:initialise()
    self.topBar:addChild(self.retroTitleLabel)

    self.retroGoldButton = ISButton:new(rightX, y + math.floor(h * 0.43), buttonW, rowH, PZLinuxCurrencyText("UI_PZLinux_RetroGoldSilver", "1 Money Bundle -> 100 Money"), self, self.onConvert)
    self.retroGoldButton.internal = "gold_to_silver"
    styleTerminalButton(self.retroGoldButton)
    self.retroGoldButton:initialise()
    self.topBar:addChild(self.retroGoldButton)

    self.retroSilverButton = ISButton:new(rightX, y + math.floor(h * 0.43) + rowH + gap, buttonW, rowH, PZLinuxCurrencyText("UI_PZLinux_RetroSilverCopper", "1 Money Bundle -> 100 Money"), self, self.onConvert)
    self.retroSilverButton.internal = "silver_to_copper"
    styleTerminalButton(self.retroSilverButton)
    self.retroSilverButton:initialise()
    self.retroSilverButton:setVisible(PZLinuxConfig.Get("CurrencyMode") == 2)
    self.topBar:addChild(self.retroSilverButton)

    self.statusLabel = ISLabel:new(leftX, y + h - rowH - 2, rowH, "", 0, 1, 0, 1, UIFont.Small, true)
    self.statusLabel:initialise()
    self.topBar:addChild(self.statusLabel)

    self:refreshCoinLabel()
end

function converterUI:refreshCoinLabel(counts)
    local player = getPlayer()
    counts = counts or (PZLinuxEconomyGetBankCoinCounts and PZLinuxEconomyGetBankCoinCounts(player)) or { gold = 0, silver = 0, copper = 0, value = 0 }
    local text = PZLinuxCurrencyText(
        "UI_PZLinux_CoinBankLine",
        "Bank money: %1 bundles %2 cash (%4)",
        tostring(counts.gold or 0),
        tostring(counts.silver or 0),
        tostring(counts.copper or 0),
        PZLinuxFormatCurrency(counts.value or 0)
    )
    self.coinLabel:setName(text)

    if self.inventoryCoinLabel then
        local inventoryCounts = PZLinuxEconomyGetInventoryCoinCounts(player)
        self.inventoryCoinLabel:setName(PZLinuxCurrencyText(
        "UI_PZLinux_CoinInventoryLine",
        "Money: %1 bundles %2 cash (%4)",
        tostring(inventoryCounts.gold or 0),
        tostring(inventoryCounts.silver or 0),
        tostring(inventoryCounts.copper or 0),
        PZLinuxFormatCurrency(inventoryCounts.value or 0)
        ))
    end
end

function converterUI:onConvert(button)
    local action = button and button.internal
    if not action then
        return
    end

    local player = getPlayer()
    if isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "ConvertCoins", { action = action, source = "bank" })
        return
    end

    local result = PZLinuxEconomyConvertBankCoins and PZLinuxEconomyConvertBankCoins(player, action) or PZLinuxEconomyConvertCoins(player, action)
    self:onConvertResult(result)
end

function converterUI:onConvertResult(result)
    local player = getPlayer()
    if result and tonumber(result.balance) ~= nil then
        local modData = PZLinuxGetModData(player)
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(result.balance) or 0))
        end
    end

    if result and result.ok then
        playConverterSound(player, "sold")
        self.statusLabel:setName(PZLinuxText("UI_PZLinux_ConvertOk", "Conversion complete"))
        self:refreshCoinLabel(result.counts)
        return
    end

    playConverterSound(player, "error")
    self.statusLabel:setName(PZLinuxText("UI_PZLinux_ConvertFailed", "Not enough money"))
    self:refreshCoinLabel()
end

function converterUI:onMinimize(button)
    self.isClosing = true
    self:removeFromUIManager()
    if PZLinuxConverterInstance == self then
        PZLinuxConverterInstance = nil
    end
    PZLinuxGetModData().PZLinuxUIOpenMenu = 1
end

function converterUI:onClose(button)
    self.isClosing = true
    self:removeFromUIManager()
    if PZLinuxConverterInstance == self then
        PZLinuxConverterInstance = nil
    end
    local modData = PZLinuxGetModData()
    if modData then
        modData.PZLinuxUIOpenMenu = 0
    end
    local player = self.player or getPlayer()
    if player and player.StopAllActionQueue then
        player:StopAllActionQueue()
    end
end

function converterUI:onCloseX(button)
    self.isClosing = true
    if PZLinuxConverterInstance == self then
        PZLinuxConverterInstance = nil
    end
    getPlayer():StopAllActionQueue()
end

function converterMenu_ShowUI(player)
    if not PZLinuxRequireFeature("CurrencyConversion", player) then return end
    local texture = getTexture("media/ui/PC100.png")
    if not texture then return end

    local realScreenW, realScreenH, finalW, finalH = getResponsiveTerminalSize(texture)

    local modData = PZLinuxGetModData()
    local uiX = modData.PZLinuxUIX or (realScreenW - finalW) / 2
    local uiY = modData.PZLinuxUIY or (realScreenH - finalH) / 2
    uiX = math.max(0, math.min(uiX, realScreenW - finalW))
    uiY = math.max(0, math.min(uiY, realScreenH - finalH))

    local ui = converterUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)
    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    ui:addChild(centeredImage)
    ui.centeredImage = centeredImage
    ui:initialise()
    ui:addToUIManager()
    PZLinuxConverterInstance = ui

    return ui
end
