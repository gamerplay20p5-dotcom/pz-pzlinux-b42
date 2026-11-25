require "PZLinuxConfig"
-- Dark Web UI - by Raixxar 
-- Updated : 25/01/25

require "PZLinuxTradingCore"
require "PZLinuxEconomy"
require "Context/World/Features/PZLinuxUtils"

walletUI = ISPanel:derive("walletUI")

local walletBalance = 0
local LAST_CONNECTION_TIME = 0
local STAY_CONNECTED_TIME = 0

local function PZLinuxWalletFormatSignedNumber(value)
    local numberValue = math.floor(tonumber(value) or 0)
    if numberValue > 0 then
        return "+" .. PZLinuxFormatCurrency(numberValue)
    elseif numberValue < 0 then
        return "-" .. PZLinuxFormatCurrency(math.abs(numberValue))
    end
    return PZLinuxFormatCurrency(0)
end

local function PZLinuxWalletFormatProfit(stats)
    return PZLinuxWalletFormatSignedNumber(stats.profit)
end

local function PZLinuxWalletRequestTradingData()
    PZLinuxRequestTradingGlobalModData()
    if PZLinuxTrading_initializePrices then
        PZLinuxTrading_initializePrices()
    elseif PZLinuxSendClientCommandThrottled then
        PZLinuxSendClientCommandThrottled(PZLinuxModule, "RequestTradingData", {}, 10000)
    elseif isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "RequestTradingData", {})
    else
        PZLinuxTradingEnsureMarketFresh(true)
    end
end

local function PZLinuxWalletUpdateTradingPrices()
    if PZLinuxUpdateTradingPrices then
        PZLinuxUpdateTradingPrices()
    elseif PZLinuxSendClientCommandThrottled then
        PZLinuxSendClientCommandThrottled(PZLinuxModule, "RequestTradingData", {}, 10000)
    elseif isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "RequestTradingData", {})
    else
        PZLinuxTradingAdvanceMarket(1, true)
    end
end

local function PZLinuxWalletResolveLastPrice(priceHistory, fallbackPrice)
    local firstPrice, lastPrice, secondLastPrice = PZLinuxGetHistoryExtremes(priceHistory)
    local safeFallback = math.max(1, math.floor(tonumber(fallbackPrice) or 1))
    if tonumber(lastPrice) == nil or tonumber(lastPrice) <= 0 then
        lastPrice = safeFallback
    end
    if tonumber(firstPrice) == nil or tonumber(firstPrice) <= 0 then
        firstPrice = lastPrice
    end
    if tonumber(secondLastPrice) == nil or tonumber(secondLastPrice) <= 0 then
        secondLastPrice = lastPrice
    end
    return tonumber(firstPrice) or lastPrice, tonumber(lastPrice) or safeFallback, tonumber(secondLastPrice) or lastPrice
end

-- CONSTRUCTOR
function walletUI:new(x, y, width, height, player)
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
function walletUI:initialise()
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
        local modData = PZLinuxGetModData()
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

    self.titleLabel = ISLabel:new(self.width * 0.20, self.height * 0.17, self.height * 0.025, PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(loadAtmBalance())), 0, 1, 0, 1, UIFont.Small, true)
    self.titleLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.titleLabel:setVisible(false)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    local modData = PZLinuxGetModData()
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

    self.closeButton = ISButton:new(self.width * 0.73, self.height * 0.17, self.width * 0.030, self.height * 0.025, "x", self, self.onClose)
    self.closeButton.textColor = {r=0, g=1, b=0, a=1}
    self.closeButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.closeButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.topBar:addChild(self.closeButton)
    PZLinuxLayoutTerminalControls(self)
end

-- Terminal loading
function walletUI:startWallet()
    PZLinuxWalletRequestTradingData()
    self.titleLabel:setVisible(true)
    self.minimizeButton:setVisible(true)
    self.closeButton:setVisible(true)

    local safe = self.pzSafe or PZLinuxGetTerminalSafeArea(self.width, self.height)
    local rowHeight = safe.rowH
    local headerY = safe.y + (safe.rowH * 2) + safe.gap
    local tableY = headerY + safe.rowH + 2
    local tableH = math.floor(safe.h * 0.34)
    local codeW = math.floor(safe.w * 0.15)
    local quantityW = math.floor(safe.w * 0.17)
    local avgW = math.floor(safe.w * 0.21)
    local priceW = math.floor(safe.w * 0.19)
    local profitW = safe.w - codeW - quantityW - avgW - priceW

    local scrollPanel = ISScrollingListBox:new(safe.x, tableY, safe.w, tableH)
    self.scrollPanel = scrollPanel
    scrollPanel.backgroundColor = {r=0, g=0, b=0, a=1}
    scrollPanel.borderColor = {r=0, g=0.5, b=0, a=0.7}
    scrollPanel:initialise()
    scrollPanel:instantiate()
    
    function scrollPanel:prerender()
        ISPanel.prerender(self)
        self:setStencilRect(0, 0, self.width, self.height)
    end
    function scrollPanel:postrender()
        self:clearStencilRect()
        ISPanel.postrender(self)
    end
    
    scrollPanel:setScrollChildren(true)
    self:addChild(scrollPanel)

    local totalHeight = 100 * rowHeight + 10
    scrollPanel:setScrollHeight(totalHeight)
    scrollPanel.onMouseWheel = function(self, del)
        if self:getScrollHeight() > 0 then
            self:setYScroll(self:getYScroll() - (del * 40))
            return true
        end
        return false
    end

    local tradingMenuCodeLabel = ISButton:new(safe.x, headerY, codeW, safe.rowH, PZLinuxText("UI_PZLinux_Code", "CODE"), self, self.onFilter)
    PZLinuxStyleTerminalButton(tradingMenuCodeLabel)
    tradingMenuCodeLabel:initialise()
    self.topBar:addChild(tradingMenuCodeLabel)

    local tradingMenuNameLabel = ISButton:new(safe.x + codeW, headerY, quantityW, safe.rowH, PZLinuxText("UI_PZLinux_Quantity", "QUANTITY"), self, self.onFilter)
    PZLinuxStyleTerminalButton(tradingMenuNameLabel)
    tradingMenuNameLabel:initialise()
    self.topBar:addChild(tradingMenuNameLabel)

    local tradingMenuNameLabel = ISButton:new(safe.x + codeW + quantityW, headerY, avgW, safe.rowH, PZLinuxText("UI_PZLinux_BuyAverage", "BUY AVG"), self, self.onFilter)
    PZLinuxStyleTerminalButton(tradingMenuNameLabel)
    tradingMenuNameLabel:initialise()
    self.topBar:addChild(tradingMenuNameLabel)

    local tradingMenuH1Label = ISButton:new(safe.x + codeW + quantityW + avgW, headerY, priceW, safe.rowH, PZLinuxText("UI_PZLinux_Price", "PRICE"), self, self.onFilter)
    PZLinuxStyleTerminalButton(tradingMenuH1Label)
    tradingMenuH1Label:initialise()
    self.topBar:addChild(tradingMenuH1Label)

    local tradingMenuD1Label = ISButton:new(safe.x + codeW + quantityW + avgW + priceW, headerY, profitW, safe.rowH, PZLinuxText("UI_PZLinux_ProfitLossShort", "P/L"), self, self.onFilter)
    PZLinuxStyleTerminalButton(tradingMenuD1Label)
    tradingMenuD1Label:initialise()
    self.topBar:addChild(tradingMenuD1Label)

    local tokens = {}
    local totalWalletBalance = 0
    local player = getPlayer()
    local modData = PZLinuxGetModData(player)
    for i, company in ipairs(PZLinuxTradingCompanyNameTable) do
        local playerWallet = "ZLinuxPlayerWallet" .. company.code
        local totalTokenQuantity = math.max(0, math.floor(tonumber(modData[playerWallet]) or 0))

        local dataName = "PZLinuxTrading" .. company.code
        local globalData = ModData.getOrCreate(dataName)
        local priceHistory = globalData.dataName or {}
        local firstPrice, lastPrice, secondLastPrice = PZLinuxWalletResolveLastPrice(priceHistory, company.price)

        if totalTokenQuantity > 0 then
            local stats = PZLinuxTradingGetPortfolioStats(modData, company.code, lastPrice)
            table.insert(tokens, {c = company.code, q = tostring(totalTokenQuantity), fp = firstPrice, lp = lastPrice, slp = secondLastPrice, avg = stats.avgPrice, profit = stats.profit, profitPercent = stats.profitPercent})
            totalWalletBalance = totalWalletBalance + lastPrice * totalTokenQuantity
            walletBalance = totalWalletBalance
        end
    end
    
    local y = 0
    for i, token in ipairs(tokens) do
        local codeButton = ISButton:new(0, y, codeW, rowHeight, tostring(token.c), self, nil)
        PZLinuxStyleTerminalButton(codeButton)
        codeButton:initialise()
        scrollPanel:addChild(codeButton)
    
        local quantityButton = ISButton:new(codeW, y, quantityW, rowHeight, token.q, self, nil)
        PZLinuxStyleTerminalButton(quantityButton)
        quantityButton:initialise()
        scrollPanel:addChild(quantityButton)

        local avgPriceButton = ISButton:new(codeW + quantityW, y, avgW, rowHeight, PZLinuxFormatCurrency(token.avg or 0), self, nil)
        PZLinuxStyleTerminalButton(avgPriceButton)
        avgPriceButton:initialise()
        scrollPanel:addChild(avgPriceButton)

        local tokenPriceButton = ISButton:new(codeW + quantityW + avgW, y, priceW, rowHeight, PZLinuxFormatCurrency(token.lp), self, nil)
        PZLinuxStyleTerminalButton(tokenPriceButton)
        tokenPriceButton:initialise()
        scrollPanel:addChild(tokenPriceButton)

        local profitText = PZLinuxWalletFormatProfit(token) .. " (" .. string.format("%.2f", tonumber(token.profitPercent) or 0) .. "%)"
        local profitButton = ISButton:new(codeW + quantityW + avgW + priceW, y, profitW, rowHeight, profitText, self, nil)
        if (tonumber(token.profit) or 0) >= 0 then
            profitButton.backgroundColor = {r=0, g=1, b=0, a=0.5}
        else
            profitButton.backgroundColor = {r=1, g=0, b=0, a=0.5}
        end
        profitButton.textColor = {r=0, g=1, b=0, a=1}
        profitButton.borderColor = {r=0, g=1, b=0, a=0.5}
        profitButton:initialise()
        scrollPanel:addChild(profitButton)
        
        y = y + rowHeight
    end

    if #tokens == 0 then
        local emptyLabel = ISLabel:new(safe.gap, safe.gap, rowHeight, PZLinuxText("UI_PZLinux_WalletEmpty", "No assets in wallet yet."), 0, 1, 0, 1, UIFont.Small, true)
        self.scrollPanel:addChild(emptyLabel)
    end

    local walletTitleY = tableY + tableH + safe.gap
    self.walletTitleLabel = ISLabel:new(safe.x, walletTitleY, safe.rowH, PZLinuxText("UI_PZLinux_WalletBalance", "Wallet Balance: %s", PZLinuxFormatCurrency(totalWalletBalance)), 0, 1, 0, 1, UIFont.Small, true)
    self.walletTitleLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.walletTitleLabel:setVisible(true)
    self.walletTitleLabel:initialise()
    self.topBar:addChild(self.walletTitleLabel) 
    
    local chartWidth = safe.w
    local chartHeight = math.max(safe.rowH * 3, safe.bottom - walletTitleY - safe.rowH - safe.gap)
    local chartX = safe.x
    local chartY = walletTitleY + safe.rowH + safe.gap

    self.walletChart = ISPanel:new(chartX, chartY, chartWidth, chartHeight)
    self.walletChart.backgroundColor = {r=0, g=0, b=0, a=0.3}
    self.walletChart.borderColor = {r=1, g=1, b=1, a=0.3}
    self.walletChart:setVisible(true)
    self.walletChart:initialise()

    function  self.walletChart:render()
        local player = getPlayer()
        local values = PZLinuxGetModData(player).playerWallet
        if type(values) ~= "table" then
            return
        end
        local numPoints = #values
        if numPoints < 2 then return end
    
        local maxValue = math.max(unpack(values))
        local minValue = math.min(unpack(values))
        if maxValue == minValue then return end
    
        local barWidth = 7
    
        for i = 2, numPoints do
            local closePrice = values[i]
            local barX = (i - 1) * barWidth
            local barY = chartHeight - ((closePrice - minValue) / (maxValue - minValue)) * chartHeight
            local barHeight = chartHeight - barY
            local color = { r = 0, g = 1, b = 0, a = 0.8 }
            self:drawRect(barX, barY, barWidth, barHeight, color.a, color.r, color.g, color.b)
        end
    end
    self.topBar:addChild(self.walletChart)
end

function walletUI:updateWallet()
    local totalWalletBalance = 0
    local player = getPlayer()
    local modData = PZLinuxGetModData(player)

    for i, company in ipairs(PZLinuxTradingCompanyNameTable) do
        local playerWallet = "ZLinuxPlayerWallet" .. company.code
        local totalTokenQuantity = math.max(0, math.floor(tonumber(modData[playerWallet]) or 0))

        local dataName = "PZLinuxTrading" .. company.code
        local globalData = ModData.getOrCreate(dataName)
        local priceHistory = globalData.dataName or {}
        local _, lastPrice = PZLinuxWalletResolveLastPrice(priceHistory, company.price)

        totalWalletBalance = totalWalletBalance + lastPrice * totalTokenQuantity
    end

    walletBalance = totalWalletBalance
    modData.playerWallet = type(modData.playerWallet) == "table" and modData.playerWallet or {}
    table.insert(modData.playerWallet, totalWalletBalance)
    if #modData.playerWallet > 48 then
        table.remove(modData.playerWallet, 1)
    end

    PZLinuxSyncPlayerModData(player)
end

-- LOGOUT
function walletUI:onMinimize(button)
    self.isClosing = true
    self:removeFromUIManager()
    local modData = PZLinuxGetModData()
    modData.PZLinuxUIOpenMenu = 1
end

-- CLOSE
function walletUI:onClose(button)
    self.isClosing = true
    lastConnectionTimestamp = 0
    self:removeFromUIManager()
    local modData = PZLinuxGetModData()
    modData.PZLinuxUIOpenMenu = 1
end

function walletUI:onCloseX(button)
    self.isClosing = true
    getPlayer():StopAllActionQueue()
end

function walletUI:onSFXOn(button)
    local modData = PZLinuxGetModData()
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

function walletUI:onSFXOff(button)
    local modData = PZLinuxGetModData()
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

function walletMenu_ShowUI(player)
    if not PZLinuxRequireFeature("Trading", player) then return end
    PZLinuxRequestTradingGlobalModData()

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
    
    local modData = PZLinuxGetModData()
    local uiX = modData.PZLinuxUIX or (realScreenW - finalW) / 2
    local uiY = modData.PZLinuxUIY or (realScreenH - finalH) / 2
    uiX = math.max(0, math.min(uiX, realScreenW - finalW))
    uiY = math.max(0, math.min(uiY, realScreenH - finalH))

    local ui = walletUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)
    
    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    ui:addChild(centeredImage)
    ui.centeredImage = centeredImage
    ui:initialise()
    ui:addToUIManager()

    local getHourTime = math.ceil(getGameTime():getWorldAgeHours())
    if getHourTime + 1 > LAST_CONNECTION_TIME then
        if LAST_CONNECTION_TIME == 0 then LAST_CONNECTION_TIME = getHourTime end
        if LAST_CONNECTION_TIME > 0 then 
            local deltaTrading = getHourTime - LAST_CONNECTION_TIME
            for i = 1, deltaTrading do
                PZLinuxWalletUpdateTradingPrices()
            end
            ui:updateWallet()
            LAST_CONNECTION_TIME = getHourTime
        end
    end
    ui:startWallet()

    return ui
end
