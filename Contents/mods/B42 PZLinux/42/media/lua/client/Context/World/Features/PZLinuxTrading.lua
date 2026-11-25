require "PZLinuxConfig"
-- Dark Web UI - by Raixxar 
-- Updated : 25/01/25

require "PZLinuxTradingCore"
require "PZLinuxEconomy"

tradingUI = ISPanel:derive("tradingUI")

local LAST_CONNECTION_TIME = 0
local PZLINUX_ACTIVE_TRADING_UI = nil

local function PZLinuxTradingFormatSignedNumber(value)
    local numberValue = math.floor(tonumber(value) or 0)
    if numberValue > 0 then
        return "+" .. PZLinuxFormatCurrency(numberValue)
    elseif numberValue < 0 then
        return "-" .. PZLinuxFormatCurrency(math.abs(numberValue))
    end
    return PZLinuxFormatCurrency(0)
end

local function PZLinuxTradingFormatPositionLine(modData, code, currentPrice)
    local stats = PZLinuxTradingGetPortfolioStats(modData, code, currentPrice)
    if stats.quantity <= 0 then
        return PZLinuxText("UI_PZLinux_PortfolioNoPosition", "No position bought yet")
    end

    return PZLinuxText(
        "UI_PZLinux_PortfolioPositionLine",
        "Avg buy %s | P/L %s (%s%%)",
        PZLinuxFormatCurrency(stats.avgPrice),
        PZLinuxTradingFormatSignedNumber(stats.profit),
        string.format("%.2f", stats.profitPercent)
    )
end

local function getTradingSafeArea(ui)
    return {
        x = math.floor(ui.width * 0.17),
        y = math.floor(ui.height * 0.16),
        w = math.floor(ui.width * 0.62),
        h = math.floor(ui.height * 0.50),
        gap = math.max(8, math.floor(ui.height * 0.014)),
        rowH = math.max(24, math.floor(ui.height * 0.034)),
        buttonH = math.max(26, math.floor(ui.height * 0.04)),
    }
end

local function styleTradingButton(button)
    if not button then return end
    button.textColor = {r=0, g=1, b=0, a=1}
    button.backgroundColor = {r=0, g=0, b=0, a=0.58}
    button.borderColor = {r=0, g=0.5, b=0, a=0.75}
end

local function PZLinuxTradingRequestServerData()
    PZLinuxRequestTradingGlobalModData()
    if PZLinuxSendClientCommandThrottled then
        PZLinuxSendClientCommandThrottled(PZLinuxModule, "RequestTradingData", {}, 10000)
        return true
    elseif isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "RequestTradingData", {})
        return true
    end

    PZLinuxTradingEnsureMarketFresh(true)
    return false
end

local function PZLinuxTradingSendOrder(action, code, quantity)
    if not isClient() or not sendClientCommand then
        return false
    end

    sendClientCommand(PZLinuxModule, "ExecuteTradingOrder", {
        action = action,
        code = code,
        quantity = quantity,
    })
    return true
end

local function PZLinuxTradingUpdateActiveLabels(args)
    local ui = PZLINUX_ACTIVE_TRADING_UI
    if not ui or ui.isClosing then
        return
    end

    local code = tostring(args and args.code or ui.currentTradingCode or "")
    if code == "" or (ui.currentTradingCode and ui.currentTradingCode ~= code) then
        return
    end

    local company = PZLinuxTradingGetCompany(code)
    local unitPrice = math.max(1, math.floor(tonumber(args and args.unitPrice) or PZLinuxTradingGetCurrentPrice(code, company and company.price or 1)))
    local balance = math.max(0, math.floor(tonumber(args and args.balance) or tonumber(loadAtmBalance()) or 0))
    local walletQuantity = args and tonumber(args.walletQuantity) or nil
    if walletQuantity == nil then
        local modData = PZLinuxGetModData(getPlayer())
        walletQuantity = math.max(0, math.floor(tonumber(modData and modData["ZLinuxPlayerWallet" .. code]) or 0))
    else
        walletQuantity = math.max(0, math.floor(walletQuantity))
    end

    if ui.companyCodeLabel then
        ui.companyCodeLabel:setName(code .. " " .. PZLinuxFormatCurrency(unitPrice))
    end
    if ui.tradingBalanceLabel then
        ui.tradingBalanceLabel:setName(PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(balance)))
    end
    if ui.tradingWalletLabel then
        ui.tradingWalletLabel:setName(PZLinuxText("UI_PZLinux_WalletBalanceCode", "Wallet Balance %s %s", tostring(walletQuantity), code))
    end
    if ui.tradingPortfolioLabel then
        ui.tradingPortfolioLabel:setName(PZLinuxTradingFormatPositionLine(PZLinuxGetModData(getPlayer()), code, unitPrice))
    end
    if ui.titleLabel then
        ui.titleLabel:setName(PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(balance)))
    end
    if ui.quantityInput and args and args.ok then
        ui.quantityInput:setText("")
    end
end

function PZLinuxTradingOnMarketData(args)
    PZLinuxTradingUpdateActiveLabels(args)
end

function PZLinuxTradingOnOrderResult(args)
    PZLinuxTradingUpdateActiveLabels(args)
end

local function PZLinuxTradingResolveLastPrice(priceHistory, fallbackPrice)
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

local function PZLinuxTradingRecordWalletHistory(modData)
    if type(modData) ~= "table" then
        return 0
    end

    modData.playerWallet = type(modData.playerWallet) == "table" and modData.playerWallet or {}

    local totalWalletBalance = 0
    for _, company in ipairs(PZLinuxTradingCompanyNameTable or {}) do
        local playerWallet = "ZLinuxPlayerWallet" .. tostring(company.code or "")
        local totalTokenQuantity = math.max(0, math.floor(tonumber(modData[playerWallet]) or 0))
        local dataName = "PZLinuxTrading" .. tostring(company.code or "")
        local globalData = ModData.getOrCreate(dataName)
        local _, lastPrice = PZLinuxTradingResolveLastPrice(globalData.dataName or {}, company.price)
        totalWalletBalance = totalWalletBalance + (lastPrice * totalTokenQuantity)
    end

    table.insert(modData.playerWallet, totalWalletBalance)
    if #modData.playerWallet > 48 then
        table.remove(modData.playerWallet, 1)
    end

    return totalWalletBalance
end

function tradingUI:loadModFile()
    local fileName = "PZLinux.ini"
    local file = getFileReader(fileName, false)

    if not file then
        return {}
    end

    local prices = {}
    local section = nil
    local line = file:readLine()

    while line do
        local sectionHeader = line:match("^%[(.-)%]$")
        if sectionHeader then
            section = sectionHeader
        elseif section == "trading" then
            local code, values = line:match("^(%w+)=(.+)$")
            if code and values then
                prices[code] = {}
                for price in values:gmatch("%d+") do
                    table.insert(prices[code], tonumber(price))
                end
            end
        end
        line = file:readLine()
    end

    file:close()
    return prices
end

-- CONSTRUCTOR
function tradingUI:new(x, y, width, height, player)
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
function tradingUI:initialise()
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

    self.safe = getTradingSafeArea(self)
    local safe = self.safe
    local controlW = math.max(26, math.floor(self.width * 0.032))
    local controlGap = math.max(4, math.floor(self.width * 0.006))

    self.titleLabel = ISLabel:new(safe.x, safe.y + 2, safe.rowH, PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(loadAtmBalance())), 0, 1, 0, 1, UIFont.Small, true)
    self.titleLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.titleLabel:setVisible(false)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    local modData = PZLinuxGetModData()
    if modData.PZLinuxUISFX == 0 then
        self.skipAnimationButton = ISButton:new(safe.x + safe.w - ((controlW + controlGap) * 3), safe.y, controlW, safe.rowH, "SFX", self, self.onSFXOff)
        self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
        self.skipAnimationButton.backgroundColor = {r=1, g=0, b=0, a=0.5}
        self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
        self.skipAnimationButton:setVisible(true)
        self.skipAnimationButton:initialise()
        self.topBar:addChild(self.skipAnimationButton)
    else
        self.skipAnimationButton = ISButton:new(safe.x + safe.w - ((controlW + controlGap) * 3), safe.y, controlW, safe.rowH, "SFX", self, self.onSFXOn)
        self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
        self.skipAnimationButton.backgroundColor = {r=0, g=1, b=0, a=0.5}
        self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
        self.skipAnimationButton:setVisible(true)
        self.skipAnimationButton:initialise()
        self.topBar:addChild(self.skipAnimationButton)
    end

    self.minimizeButton = ISButton:new(safe.x + safe.w - ((controlW + controlGap) * 2), safe.y, controlW, safe.rowH, "-", self, self.onMinimize)
    self.minimizeButton.textColor = {r=0, g=1, b=0, a=1}
    self.minimizeButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.minimizeButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.minimizeButton:setVisible(true)
    self.minimizeButton:initialise()
    self.topBar:addChild(self.minimizeButton)

    self.minimizeTradingButton = ISButton:new(safe.x + safe.w - ((controlW + controlGap) * 2), safe.y, controlW, safe.rowH, "-", self, self.onMinimizeTrading)
    self.minimizeTradingButton.textColor = {r=0, g=1, b=0, a=1}
    self.minimizeTradingButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.minimizeTradingButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.minimizeTradingButton:setVisible(false)
    self.minimizeTradingButton:initialise()
    self.topBar:addChild(self.minimizeTradingButton)

    self.closeButton = ISButton:new(safe.x + safe.w - controlW, safe.y, controlW, safe.rowH, "x", self, self.onClose)
    self.closeButton.textColor = {r=0, g=1, b=0, a=1}
    self.closeButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.closeButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.topBar:addChild(self.closeButton)
end

function tradingUI:startTrading()
    PZLinuxTrading_initializePrices()
    self.titleLabel:setVisible(true)
    self.closeButton:setVisible(true)
    self.minimizeButton:setVisible(true)

    local y = 0
    self.tradingButtons = {}
    local safe = self.safe or getTradingSafeArea(self)
    local headerY = safe.y + (safe.rowH * 2) + safe.gap
    local tableY = headerY + safe.rowH + 2
    local tableH = math.max(safe.rowH * 6, safe.h - ((safe.rowH * 3) + safe.gap))
    local codeW = math.floor(safe.w * 0.14)
    local infoW = math.max(24, math.floor(safe.w * 0.06))
    local h1W = math.floor(safe.w * 0.16)
    local d1W = math.floor(safe.w * 0.16)
    local nameW = safe.w - codeW - infoW - h1W - d1W
    local codeX = 0
    local nameX = codeX + codeW
    local h1X = nameX + nameW
    local d1X = h1X + h1W
    local infoX = d1X + d1W

    self.marketTitleLabel = ISLabel:new(safe.x, safe.y + safe.rowH + safe.gap, safe.rowH, "================ " .. PZLinuxText("UI_PZLinux_StockMarketTitle", "MERCADO DE ACOES") .. " ================", 0, 1, 0, 1, UIFont.Small, true)
    self.marketTitleLabel:initialise()
    self.topBar:addChild(self.marketTitleLabel)

    local scrollPanel = ISScrollingListBox:new(safe.x, tableY, safe.w, tableH)
    scrollPanel.backgroundColor = {r=0, g=0, b=0, a=1}
    scrollPanel.borderColor = {r=0, g=0.5, b=0, a=0.72}
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

    local rowHeight = safe.rowH
    local totalHeight = (#PZLinuxTradingCompanyNameTable * rowHeight) + safe.gap
    scrollPanel:setScrollHeight(totalHeight)
    scrollPanel.onMouseWheel = function(self, del)
        if self:getScrollHeight() > 0 then
            self:setYScroll(self:getYScroll() - (del * 40))
            return true
        end
        return false
    end
    
    local tradingMenuCodeLabel = ISButton:new(safe.x + codeX, headerY, codeW, safe.rowH, PZLinuxText("UI_PZLinux_Code", "CODE"), self, self.onFilter)
    styleTradingButton(tradingMenuCodeLabel)
    tradingMenuCodeLabel:initialise()
    self.topBar:addChild(tradingMenuCodeLabel)

    local tradingMenuNameLabel = ISButton:new(safe.x + nameX, headerY, nameW, safe.rowH, PZLinuxText("UI_PZLinux_Name", "NAME"), self, self.onFilter)
    styleTradingButton(tradingMenuNameLabel)
    tradingMenuNameLabel:initialise()
    self.topBar:addChild(tradingMenuNameLabel)

    local tradingMenuH1Label = ISButton:new(safe.x + h1X, headerY, h1W, safe.rowH, "H1", self, self.onFilter)
    styleTradingButton(tradingMenuH1Label)
    tradingMenuH1Label:initialise()
    self.topBar:addChild(tradingMenuH1Label)

    local tradingMenuD1Label = ISButton:new(safe.x + d1X, headerY, d1W, safe.rowH, "D1", self, self.onFilter)
    styleTradingButton(tradingMenuD1Label)
    tradingMenuD1Label:initialise()
    self.topBar:addChild(tradingMenuD1Label)

    for i, company in ipairs(PZLinuxTradingCompanyNameTable) do
        local codeButton = ISButton:new(codeX, y, codeW, rowHeight, company.code, self, nil)
        styleTradingButton(codeButton)
        codeButton:initialise()

        local nameButton = ISButton:new(nameX, y, nameW, rowHeight, company.name, self, nil)
        styleTradingButton(nameButton)
        nameButton:initialise()

        local infoButton = ISButton:new(infoX, y, infoW, rowHeight, "i", self, function()
            self.titleLabel:setVisible(false)
            if self.marketTitleLabel then self.marketTitleLabel:setVisible(false) end
            tradingMenuCodeLabel:setVisible(false)
            tradingMenuNameLabel:setVisible(false)
            tradingMenuH1Label:setVisible(false)
            tradingMenuD1Label:setVisible(false)
            scrollPanel:setVisible(false)
            self:showCompanyInfo(company.code, company.name)
        end)
        styleTradingButton(infoButton)
        infoButton:initialise()

        -- % PRICE

        local dataName = "PZLinuxTrading" .. company.code
        local companyData = ModData.getOrCreate(dataName)
        local priceHistory = companyData.dataName or {}
        local firstPrice, lastPrice, secondLastPrice = PZLinuxTradingResolveLastPrice(priceHistory, company.price)

        -- H1
        local h1 = string.format("%.2f", PZLinuxSafePercentDelta(lastPrice, secondLastPrice))
        local h1Color = tonumber(math.ceil(h1))
        local priceH1Button = ISButton:new(h1X, y, h1W, rowHeight, h1 .. "%", self, nil)
        if h1Color > 0 then
            priceH1Button.backgroundColor = {r=0, g=1, b=0, a=0.5}
        else
            priceH1Button.backgroundColor = {r=1, g=0, b=0, a=0.5}
        end
        priceH1Button:initialise()

        -- D1
        local d1 = string.format("%.2f", PZLinuxSafePercentDelta(lastPrice, firstPrice))
        local d1Color = tonumber(math.ceil(d1))
        local priceD1Button = ISButton:new(d1X, y, d1W, rowHeight, d1 .. "%", self, nil)
        if d1Color > 0 then
            priceD1Button.backgroundColor = {r=0, g=1, b=0, a=0.5}
        else
            priceD1Button.backgroundColor = {r=1, g=0, b=0, a=0.5}
        end
        priceD1Button:initialise()
        
        table.insert(self.tradingButtons, {codeButton, nameButton, infoButton, priceH1Button, priceD1Button})

        scrollPanel:addChild(codeButton)
        scrollPanel:addChild(nameButton)
        scrollPanel:addChild(infoButton)
        scrollPanel:addChild(priceH1Button)
        scrollPanel:addChild(priceD1Button)

        y = y + rowHeight
    end
end

function tradingUI:showCompanyInfo(code, name)
    self.currentTradingCode = code
    self.currentTradingName = name
    local safe = self.safe or getTradingSafeArea(self)

    local dataName = "PZLinuxTrading" .. code

    local companyData = ModData.getOrCreate(dataName)
    local priceHistory = companyData.dataName or {}
    local _, lastPrice = PZLinuxTradingResolveLastPrice(priceHistory, 1)

    self.closeButton:setVisible(true)
    self.minimizeTradingButton:setVisible(true)
    self.minimizeButton:setVisible(true)

    self.companyCodeLabel = ISLabel:new(safe.x, safe.y + safe.rowH + safe.gap, safe.rowH, code .. " " .. PZLinuxFormatCurrency(lastPrice), 0, 1, 0, 1, UIFont.Small, true)
    self.companyCodeLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.companyCodeLabel:initialise()
    self.topBar:addChild(self.companyCodeLabel)

    self.companyNameLabel = ISLabel:new(safe.x, safe.y + ((safe.rowH + safe.gap) * 2), safe.rowH, name, 0, 1, 0, 1, UIFont.Small, true)
    self.companyNameLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.companyNameLabel:initialise()
    self.topBar:addChild(self.companyNameLabel)

    local chartWidth = safe.w
    local chartHeight = math.floor(safe.h * 0.42)
    local chartX = safe.x
    local chartY = safe.y + ((safe.rowH + safe.gap) * 3)

    local candlestickChart = ISPanel:new(chartX, chartY, chartWidth, chartHeight)
    candlestickChart:initialise()
    candlestickChart.backgroundColor = {r=0, g=0, b=0, a=0.3}
    candlestickChart.borderColor = {r=1, g=1, b=1, a=0.3}

    function candlestickChart:render()
        local numCandles = #priceHistory
        if numCandles < 2 then return end

        local maxPrice = math.max(unpack(priceHistory))
        local minPrice = math.min(unpack(priceHistory))
        local priceRange = maxPrice - minPrice
        if priceRange <= 0 then
            priceRange = 1
        end

        local candleWidth = chartWidth / numCandles
        for i = 2, numCandles do
            local openPrice = priceHistory[i - 1]
            local closePrice = priceHistory[i]
            local highPrice = math.max(openPrice, closePrice)
            local lowPrice = math.min(openPrice, closePrice)

            local x = (i - 2) * candleWidth + 0
            local highY = chartHeight - ((highPrice - minPrice) / priceRange) * chartHeight
            local lowY = chartHeight - ((lowPrice - minPrice) / priceRange) * chartHeight
            local openY = chartHeight - ((openPrice - minPrice) / priceRange) * chartHeight
            local closeY = chartHeight - ((closePrice - minPrice) / priceRange) * chartHeight

            self:drawRect(x + candleWidth / 2, highY, 1, lowY - highY, 1, 1, 1, 1)
            local color = { r = 0, g = 1, b = 0, a = 1 } -- Green for upward movement
            if closePrice < openPrice then
                color = { r = 1, g = 0, b = 0, a = 1 } -- Red for downward movement
            end

            -- Draw body
            local bodyY = math.min(openY, closeY)
            local bodyHeight = math.abs(closeY - openY)
            if bodyHeight == 0 then bodyHeight = 1 end -- Ensure visible body
            self:drawRect(x, bodyY, candleWidth, bodyHeight, color.a, color.r, color.g, color.b)
        end
    end
    self.topBar:addChild(candlestickChart)

    local player = getPlayer()
    local modData = PZLinuxGetModData(player)
    local playerWallet = "ZLinuxPlayerWallet" .. code
    local totalTokenQuantity = math.max(0, math.floor(tonumber(modData[playerWallet]) or 0))

    self.tradingBalanceLabel = ISLabel:new(safe.x, chartY + chartHeight + safe.gap, safe.rowH, PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(loadAtmBalance())), 0, 1, 0, 1, UIFont.Small, true)
    self.tradingBalanceLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.tradingBalanceLabel:initialise()
    self.topBar:addChild(self.tradingBalanceLabel)

    self.tradingWalletLabel = ISLabel:new(safe.x, chartY + chartHeight + safe.gap + safe.rowH, safe.rowH, PZLinuxText("UI_PZLinux_WalletBalanceCode", "Wallet Balance %s %s", totalTokenQuantity, code), 0, 1, 0, 1, UIFont.Small, true)
    self.tradingWalletLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.tradingWalletLabel:initialise()
    self.topBar:addChild(self.tradingWalletLabel)

    self.tradingPortfolioLabel = ISLabel:new(safe.x, chartY + chartHeight + safe.gap + (safe.rowH * 2), safe.rowH, PZLinuxTradingFormatPositionLine(modData, code, lastPrice), 0, 1, 0, 1, UIFont.Small, true)
    self.tradingPortfolioLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.tradingPortfolioLabel:initialise()
    self.topBar:addChild(self.tradingPortfolioLabel)

    local tradeY = chartY + chartHeight + safe.gap + (safe.rowH * 3)
    local inputW = math.floor(safe.w * 0.44)
    self.quantityInput = ISTextEntryBox:new("", safe.x, tradeY, inputW, safe.rowH)
    self.quantityInput:initialise()
    self.quantityInput:instantiate()
    self.quantityInput:setOnlyNumbers(true)
    self.topBar:addChild(self.quantityInput)

    local tradeButtonW = math.floor((safe.w - inputW - (safe.gap * 2)) / 2)
    self.tradingSoldButton = ISButton:new(safe.x + inputW + safe.gap, tradeY, tradeButtonW, safe.rowH, PZLinuxText("UI_PZLinux_Sell", "SELL"), self, function()
        local quantityTrading = tonumber(self.quantityInput:getText()) or 0
        if quantityTrading > 0 then
            self:onTradingSold(code, lastPrice, quantityTrading)
        end
    end)

    self.tradingSoldButton.backgroundColor = {r=0.5, g=0, b=0, a=1}
    self.tradingSoldButton.borderColor = {r=0, g=0, b=0, a=1}
    self.tradingSoldButton:setVisible(true)
    self.tradingSoldButton:initialise()
    self.tradingSoldButton:setAnchorRight(true)
    self.topBar:addChild(self.tradingSoldButton)

    self.tradingBuyButton = ISButton:new(safe.x + inputW + safe.gap + tradeButtonW + safe.gap, tradeY, tradeButtonW, safe.rowH, PZLinuxText("UI_PZLinux_Buy", "BUY"), self, function()
        local quantityTrading = tonumber(self.quantityInput:getText()) or 0
        if quantityTrading > 0 then
            self:onTradingBuy(code, lastPrice, quantityTrading)
        end
    end)
    self.tradingBuyButton.backgroundColor = {r=0, g=0.5, b=0, a=1}
    self.tradingBuyButton.borderColor = {r=0, g=0, b=0, a=1}
    self.tradingBuyButton:setVisible(true)
    self.tradingBuyButton:initialise()
    self.topBar:addChild(self.tradingBuyButton)
end

function tradingUI:onTradingSold(code, lastPrice, quantityTrading)
    if not PZLinuxRequireFeature("Trading", self.player or getPlayer()) then return end
    local player = getPlayer()
    local modData = PZLinuxGetModData(player)
    local playerWallet = "ZLinuxPlayerWallet" .. code
    local totalTokenQuantity = math.max(0, math.floor(tonumber(modData[playerWallet]) or 0))
    local quantity = math.max(0, math.floor(tonumber(quantityTrading) or 0))
    local unitPrice = math.max(0, math.floor(tonumber(lastPrice) or 0))
    local newQuantity = totalTokenQuantity - quantity

    if isClient() then
        if quantity > 0 then
            PZLinuxTradingSendOrder("sell", code, quantity)
        end
        return
    end

    if quantity > 0 and newQuantity >= 0 and unitPrice > 0 then
        local balance = math.max(0, math.floor(tonumber(loadAtmBalance()) or 0))
        local totalPrice = unitPrice * quantity
        local newBalance = balance + totalPrice
        modData.PZLinuxBank = newBalance
        self.tradingBalanceLabel:setName(PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(newBalance)))

        PZLinuxTradingApplyPortfolioOrder(modData, "sell", code, quantity, unitPrice, totalTokenQuantity)
        modData[playerWallet] = newQuantity
        self.tradingWalletLabel:setName(PZLinuxText("UI_PZLinux_WalletBalanceCode", "Wallet Balance %s %s", newQuantity, code))
        if self.tradingPortfolioLabel then
            self.tradingPortfolioLabel:setName(PZLinuxTradingFormatPositionLine(modData, code, unitPrice))
        end
        PZLinuxTradingRecordWalletHistory(modData)
        PZLinuxSyncPlayerModData(player)
        if self.titleLabel then
            self.titleLabel:setName(PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(newBalance)))
        end
        if self.quantityInput then
            self.quantityInput:setText("")
        end

        if totalPrice >= 5000 then
            getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -10)
            getPlayer():getStats():add(CharacterStat.STRESS, -0.5)
        elseif totalPrice >= 1000 then
            getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -5)
            getPlayer():getStats():add(CharacterStat.STRESS, -0.1)
        end

        PZLinuxTradingApplyCompanyImpact(code, "down", true)
        PZLinuxEconomyRecordDemand(PZLinuxEconomyBuildTradingDemandKey(code), "down", quantity, true)
    end
end

function tradingUI:onTradingBuy(code, lastPrice, quantityTrading)
    if not PZLinuxRequireFeature("Trading", self.player or getPlayer()) then return end
    local quantity = math.max(0, math.floor(tonumber(quantityTrading) or 0))
    if quantity <= 0 then
        return
    end

    local unitPrice = math.max(0, math.floor(tonumber(lastPrice) or 0))
    local balance = math.max(0, math.floor(tonumber(loadAtmBalance()) or 0))
    local totalPrice = unitPrice * quantity

    if isClient() then
        PZLinuxTradingSendOrder("buy", code, quantity)
        return
    end

    if unitPrice <= 0 or balance < totalPrice then
        return
    end
    local newBalance = balance - totalPrice
    self.tradingBalanceLabel:setName(PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(newBalance)))

    local player = getPlayer()
    local modData = PZLinuxGetModData(player)
    local playerWallet = "ZLinuxPlayerWallet" .. code
    local totalTokenQuantity = tonumber(modData[playerWallet] or 0)
    modData.PZLinuxBank = newBalance
    PZLinuxTradingApplyPortfolioOrder(modData, "buy", code, quantity, unitPrice, totalTokenQuantity)
    modData[playerWallet] = totalTokenQuantity + quantity
    self.tradingWalletLabel:setName(PZLinuxText("UI_PZLinux_WalletBalanceCode", "Wallet Balance %s %s", modData[playerWallet], code))
    if self.tradingPortfolioLabel then
        self.tradingPortfolioLabel:setName(PZLinuxTradingFormatPositionLine(modData, code, unitPrice))
    end
    PZLinuxTradingRecordWalletHistory(modData)
    PZLinuxSyncPlayerModData(player)
    if self.titleLabel then
        self.titleLabel:setName(PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(newBalance)))
    end
    if self.quantityInput then
        self.quantityInput:setText("")
    end

    PZLinuxTradingApplyCompanyImpact(code, "up", true)
    PZLinuxEconomyRecordDemand(PZLinuxEconomyBuildTradingDemandKey(code), "up", quantity, true)
end

function PZLinuxUpdateTradingPrices()
    if isClient() then
        PZLinuxTradingRequestServerData()
        return
    end

    PZLinuxTradingAdvanceMarket(1, true)
end

function PZLinuxTrading_initializePrices()
    PZLinuxTradingRequestServerData()
end

-- LOGOUT
function tradingUI:onMinimizeTrading(button)
    self.isClosing = true
    if PZLINUX_ACTIVE_TRADING_UI == self then
        PZLINUX_ACTIVE_TRADING_UI = nil
    end
    self:removeFromUIManager()
    local modData = PZLinuxGetModData()
    modData.PZLinuxUIOpenMenu = 4
end

function tradingUI:onMinimize(button)
    self.isClosing = true
    if PZLINUX_ACTIVE_TRADING_UI == self then
        PZLINUX_ACTIVE_TRADING_UI = nil
    end
    self:removeFromUIManager()
    local modData = PZLinuxGetModData()
    modData.PZLinuxUIOpenMenu = 1
end

-- CLOSE
function tradingUI:onClose(button)
    self.isClosing = true
    if PZLINUX_ACTIVE_TRADING_UI == self then
        PZLINUX_ACTIVE_TRADING_UI = nil
    end
    self:removeFromUIManager()
    local modData = PZLinuxGetModData()
    modData.PZLinuxUIOpenMenu = 1
end

function tradingUI:onCloseX(button)
    self.isClosing = true
    getPlayer():StopAllActionQueue()
end

function tradingUI:onSFXOn(button)
    local modData = PZLinuxGetModData()
    modData.PZLinuxUISFX = 0
    self.skipAnimationButton:close()
    local safe = self.safe or getTradingSafeArea(self)
    local controlW = math.max(26, math.floor(self.width * 0.032))
    local controlGap = math.max(4, math.floor(self.width * 0.006))
    self.skipAnimationButton = ISButton:new(safe.x + safe.w - ((controlW + controlGap) * 3), safe.y, controlW, safe.rowH, "SFX", self, self.onSFXOff)
    self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
    self.skipAnimationButton.backgroundColor = {r=1, g=0, b=0, a=0.5}
    self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.skipAnimationButton:setVisible(true)
    self.skipAnimationButton:initialise()
    self.topBar:addChild(self.skipAnimationButton)
end

function tradingUI:onSFXOff(button)
    local modData = PZLinuxGetModData()
    modData.PZLinuxUISFX = 1
    self.skipAnimationButton:close()
    local safe = self.safe or getTradingSafeArea(self)
    local controlW = math.max(26, math.floor(self.width * 0.032))
    local controlGap = math.max(4, math.floor(self.width * 0.006))
    self.skipAnimationButton = ISButton:new(safe.x + safe.w - ((controlW + controlGap) * 3), safe.y, controlW, safe.rowH, "SFX", self, self.onSFXOn)
    self.skipAnimationButton.textColor = {r=1, g=1, b=1, a=1}
    self.skipAnimationButton.backgroundColor = {r=0, g=1, b=0, a=0.5}
    self.skipAnimationButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.skipAnimationButton:setVisible(true)
    self.skipAnimationButton:initialise()
    self.topBar:addChild(self.skipAnimationButton)
end

-- UI
function tradingMenu_ShowUI(player)
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

    local ui = tradingUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)

    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    ui:addChild(centeredImage)
    ui.centeredImage = centeredImage
    ui:initialise()
    ui:addToUIManager()
    PZLINUX_ACTIVE_TRADING_UI = ui

    local getHourTime = math.ceil(getGameTime():getWorldAgeHours())
    if getHourTime + 1 > LAST_CONNECTION_TIME then
        if LAST_CONNECTION_TIME == 0 then LAST_CONNECTION_TIME = getHourTime end
        if LAST_CONNECTION_TIME > 0 then 
            local deltaTrading = getHourTime - LAST_CONNECTION_TIME
            for i = 1, deltaTrading do
                PZLinuxUpdateTradingPrices()
            end
            LAST_CONNECTION_TIME = getHourTime
        end
    end
    ui:startTrading()

    return ui
end
