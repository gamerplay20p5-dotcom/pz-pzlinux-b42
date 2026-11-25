require "PZLinuxConfig"
-- Dark Web UI - by Raixxar 
-- Updated : 25/01/25

require "PZLinuxEconomy"
require "Context/World/Features/PZLinuxUtils"
require "PZLinuxDarkWebCatalog"

darkWebUI = ISPanel:derive("darkWebUI")

local LAST_CONNECTION_TIME = 0
local ITEMS_MAX = ZombRand(5,50)
local currentOffers = {}
local PZLinuxOnItemBuyOnDarkWeb = {}
local getItemName = nil
local sharedCatalogLoaded = false
PZLinuxDarkWebInstance = PZLinuxDarkWebInstance or nil

local function styleDarkWebButton(button)
    if not button then
        return
    end
    button.textColor = { r = 0, g = 1, b = 0, a = 1 }
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0.58 }
    button.borderColor = { r = 0, g = 0.55, b = 0, a = 0.78 }
end

local function createDarkWebScrollPanel(x, y, w, h)
    local panel = ISPanel:new(x, y, w, h)
    panel:initialise()
    panel:instantiate()
    function panel:prerender()
        ISPanel.prerender(self)
        self:setStencilRect(0, 0, self.width, self.height)
    end
    function panel:postrender()
        self:clearStencilRect()
        ISPanel.postrender(self)
    end
    panel:setScrollChildren(true)
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.38 }
    panel.borderColor = { r = 0, g = 0.5, b = 0, a = 0.7 }
    panel.onMouseWheel = function(self, del)
        if self:getScrollHeight() > 0 then
            self:setYScroll(self:getYScroll() - (del * 40))
            return true
        end
        return false
    end
    return panel
end

local function darkWebUsesSharedCatalog()
    return PZLinuxDarkWebCatalog and PZLinuxDarkWebCatalog.IsSharedEnabled()
end

local function requestSharedCatalog()
    if not darkWebUsesSharedCatalog() then
        return
    end

    if isClient() then
        sendClientCommand(PZLinuxModule, "RequestDarkWebCatalog", {})
    elseif PZLinuxDarkWebServerRequestCatalog then
        PZLinuxDarkWebServerRequestCatalog(getPlayer())
    end
end

local function applySharedCatalog(snapshot)
    currentOffers = {}
    if type(snapshot) ~= "table" or type(snapshot.offers) ~= "table" then
        return
    end

    for _, offer in ipairs(snapshot.offers) do
        local clientOffer = PZLinuxDarkWebCatalog.BuildClientOffer(offer)
        if clientOffer then
            currentOffers[#currentOffers + 1] = clientOffer
        end
    end
end

function PZLinuxDarkWebOnCatalogData(args)
    if not darkWebUsesSharedCatalog() then
        return
    end

    applySharedCatalog(args)
    sharedCatalogLoaded = true
    if PZLinuxDarkWebInstance
        and not PZLinuxDarkWebInstance.isClosing
        and PZLinuxDarkWebInstance.mode == "buy"
    then
        PZLinuxDarkWebInstance:onBuy()
    end
end

function PZLinuxDarkWebOnPurchaseResult(args)
    local playerObj = getPlayer()
    if not playerObj then
        return
    end

    if args and tonumber(args.balance) ~= nil then
        local modData = PZLinuxGetModData(playerObj)
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
        end
    end

    if args and type(args.catalog) == "table" then
        applySharedCatalog(args.catalog)
        sharedCatalogLoaded = true
    end

    local instance = PZLinuxDarkWebInstance
    if instance and not instance.isClosing then
        instance.titleLabel:setName(PZLinuxText(
            "UI_PZLinux_BankBalance",
            "Bank Balance: %s",
            PZLinuxFormatCurrency(loadAtmBalance())
        ))
        if instance.mode == "buy" then
            instance:onBuy()
        end
    end

    local volume = getCore():getOptionSoundVolume() / 50
    if args and args.ok then
        local sound = getSoundManager():PlayWorldSound("buy", false, playerObj:getSquare(), 0, 20, 1, true)
        if sound and sound.setVolume then
            sound:setVolume(volume)
        end
        HaloTextHelper.addGoodText(playerObj, PZLinuxText("UI_PZLinux_ItemAvailableMailbox", "Item available in a mailbox"))
        addXp(playerObj, Perks.PlantScavenging, 3)
        return
    end

    local sound = getSoundManager():PlayWorldSound("error", false, playerObj:getSquare(), 0, 20, 1, true)
    if sound and sound.setVolume then
        sound:setVolume(volume)
    end

    local reason = args and tostring(args.reason or "") or ""
    if reason == "not_enough_money" then
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_NeedMoneyBank", "I need money in my bank account"))
    elseif reason == "offer_unavailable" then
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_DarkWebOfferUnavailable", "This offer is no longer available"))
    else
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
    end
end

local function darkWebIsSellableItem(playerObj, item)
    return PZLinuxDarkWebIsSellableItem(playerObj, item)
end

local function darkWebCountSellableItemsByType(playerObj, itemIds)
    return PZLinuxCountInventoryItemsByFullTypes(playerObj, itemIds)
end

-- GEN WEB OFFERS
function GenerateDarkWebOffers()
    if darkWebUsesSharedCatalog() then
        currentOffers = {}
        sharedCatalogLoaded = false
        requestSharedCatalog()
        return
    end

    local getHourTime = math.ceil(getGameTime():getWorldAgeHours())

    if getHourTime < 24 then
        getHourTime = 24
    end

    if (getHourTime - LAST_CONNECTION_TIME) < 24 then
        return
    end
    
    currentOffers = {}
    LAST_CONNECTION_TIME = getHourTime
    local player = getPlayer()

    for i = 1, ITEMS_MAX do
        local randomItem = PZLinuxDarkWebItemsTable[ZombRand(#PZLinuxDarkWebItemsTable) + 1]
        if randomItem.id and #randomItem.id > 0 then

            local perkLevel = player:getPerkLevel(Perks.PlantScavenging)
            local buyMaxMultiplier = 3.0 - (2.0 * perkLevel / 10)
            local sellMinMultiplier = 0.25 + (0.025 * perkLevel)
            local sellMaxMultiplier = 0.5 + (0.025 * perkLevel)

            local sandbox = SandboxVars and SandboxVars.PZLinux or nil
            local SandboxVarsPurchasePriceMultiplier = sandbox and tonumber(sandbox.PurchasePriceMultiplier) or 1.0
            local agePriceMultiplier = math.max(1, math.ceil(getGameTime():getWorldAgeHours()/2190))
            local demandKey = PZLinuxEconomyBuildItemDemandKey(randomItem.id)
            local basePrice = PZLinuxEconomyNormalizeBasePrice(randomItem.Price)
            local maxPrice = math.max(basePrice + 1, math.floor(basePrice * buyMaxMultiplier))
            local rawPrice = math.ceil((ZombRand(basePrice, maxPrice + 1))/10) * 10 * agePriceMultiplier * SandboxVarsPurchasePriceMultiplier
            rawPrice = PZLinuxEconomyApplyDemandPrice(rawPrice, demandKey)
            local transactionType = "Buy"
            local transactionQty = 1

            table.insert(currentOffers, {
                item = { id = randomItem.id },
                price = rawPrice,
                itemKey = demandKey,
                transactionType = transactionType,
                transactionQty = transactionQty
            })
        end
    end
end

-- CONSTRUCTOR
function darkWebUI:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.width = width
    o.height = height
    o.player = player
    o.filterMode = "all"
    o.searchTextLower = ""
    o.isClosing = false
    o.mode = "main"
    return o
end

-- INIT
function darkWebUI:initialise()
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

    self.titleLabel = ISLabel:new(self.width * 0.20, self.height * 0.17, self.height * 0.025, PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(loadAtmBalance())), 0, 1, 0, 1, UIFont.Small, true)
    self.topBar.backgroundColor = {r=0, g=0, b=0, a=0}
    self.titleLabel:setVisible(false)
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
    local safe = PZLinuxLayoutTerminalControls(self)

    self.filterAllBtn = ISButton:new(safe.x, safe.y + safe.rowH + safe.gap, math.floor(safe.w * 0.16), safe.rowH, PZLinuxText("UI_PZLinux_FilterAll", "All"), self, self.OnFilter)
    self.filterAllBtn.internal = "all"
    styleDarkWebButton(self.filterAllBtn)
    self.filterAllBtn:setVisible(false)
    self.filterAllBtn:initialise()
    self:addChild(self.filterAllBtn)

    self.searchBtn = ISButton:new(safe.x + math.floor(safe.w * 0.17), safe.y + safe.rowH + safe.gap, math.floor(safe.w * 0.16), safe.rowH, PZLinuxText("UI_PZLinux_Search", "Search"), self, self.OnSearch)
    self.searchBtn.internal = "search"
    styleDarkWebButton(self.searchBtn)
    self.searchBtn:setVisible(false)
    self.searchBtn:initialise()
    self:addChild(self.searchBtn)

    local mainButtonW = math.floor(safe.w * 0.46)
    local mainButtonH = math.max(30, math.floor(safe.h * 0.12))
    local mainButtonGap = math.max(18, math.floor(safe.h * 0.055))
    local mainButtonX = safe.x + math.floor((safe.w - mainButtonW) / 2)
    local mainButtonY = safe.y + math.floor(safe.h * 0.25)

    self.shoppingBuyButton = ISButton:new(mainButtonX, mainButtonY, mainButtonW, mainButtonH, PZLinuxText("UI_PZLinux_Buy", "BUY"), self, self.onBuy)
    styleDarkWebButton(self.shoppingBuyButton)
    self.shoppingBuyButton:setVisible(true)
    self.shoppingBuyButton:initialise()
    self.topBar:addChild(self.shoppingBuyButton)

    self.shoppingSellButton = ISButton:new(mainButtonX, mainButtonY + mainButtonH + mainButtonGap, mainButtonW, mainButtonH, PZLinuxText("UI_PZLinux_Sell", "SELL"), self, self.onSell)
    styleDarkWebButton(self.shoppingSellButton)
    self.shoppingSellButton:setVisible(true)
    self.shoppingSellButton:initialise()
    self.topBar:addChild(self.shoppingSellButton)

    self.shoppingHelpButton = ISButton:new(mainButtonX, mainButtonY + ((mainButtonH + mainButtonGap) * 2), mainButtonW, mainButtonH, PZLinuxText("UI_PZLinux_Help", "HELP"), self, self.onHelp)
    styleDarkWebButton(self.shoppingHelpButton)
    self.shoppingHelpButton:setVisible(true)
    self.shoppingHelpButton:initialise()
    self.topBar:addChild(self.shoppingHelpButton)

    self.searchField = ISTextEntryBox:new("", safe.x + math.floor(safe.w * 0.34), safe.y + safe.rowH + safe.gap, math.floor(safe.w * 0.66), safe.rowH)
    self.searchField.backgroundColor = { r = 0, g = 0, b = 0, a = 0.72 }
    self.searchField.borderColor = { r = 0, g = 0.5, b = 0, a = 0.7 }
    self.searchField.onCommandEntered = function(entry) self:onCommandEnter() end
    self.searchField:setVisible(false)
    self.searchField:initialise()
    self:addChild(self.searchField)

    self.scrollPanel = ISPanel:new(safe.x, safe.y + (safe.rowH * 2) + (safe.gap * 2), safe.w, safe.h - ((safe.rowH * 2) + (safe.gap * 2)))
    self.scrollPanel:initialise()
    self.scrollPanel:instantiate()
    function self.scrollPanel:prerender()
        ISPanel.prerender(self)
        self:setStencilRect(0, 0, self.width, self.height)
    end
    function self.scrollPanel:postrender()
        self:clearStencilRect()
        ISPanel.postrender(self)
    end

    self.scrollPanel:setScrollChildren(true)
    self.scrollPanel.backgroundColor = {r=0, g=0, b=0, a=0.38}
    self.scrollPanel.borderColor     = {r=0, g=0.5, b=0, a=0.7}
    self:addChild(self.scrollPanel)

    self.offerBackgrounds = {}
    self.offerIcons = {}
    self.offerLabels = {}
    self.offerPriceLabels = {}
    self.transactionBtns = {}
    self.transactionQtys = {}

    local rowHeight = self.height * 0.045
    local totalHeight = 100 * rowHeight + 10
    self.scrollPanel:setScrollHeight(totalHeight)
    self.scrollPanel.onMouseWheel = function(self, del)
        if self:getScrollHeight() > 0 then
            self:setYScroll(self:getYScroll() - (del * 40))
            return true
        end
        return false
    end

    for i = 1, ITEMS_MAX do
        local yOffset = 5 + (i - 1) * rowHeight
        local offerBackground = ISPanel:new(5, yOffset, self.scrollPanel.width - 23, rowHeight)
        offerBackground.backgroundColor = {r=0, g=0, b=0, a=0.42}
        offerBackground.borderColor     = {r=0, g=0.28, b=0, a=0.62}
        offerBackground:initialise()
        self.scrollPanel:addChild(offerBackground)
        self.offerBackgrounds[i] = offerBackground

        local iconSize = 28
        local iconY    = (rowHeight - iconSize) / 2
        local iconImg  = ISImage:new(5, iconY, iconSize, iconSize, nil)
        iconImg:initialise()
        offerBackground:addChild(iconImg)
        self.offerIcons[i] = iconImg

        local labelNameX = 5 + iconSize + 5
        local labelNameY = (rowHeight - 16) / 2
        local nameLabel  = ISLabel:new(labelNameX, labelNameY, 20, "", 0, 1, 0, 1, UIFont.Small, true)
        nameLabel:initialise()
        offerBackground:addChild(nameLabel)
        self.offerLabels[i] = nameLabel

        local labelPriceX = math.floor(offerBackground.width * 0.58)
        local priceLabel = ISLabel:new(labelPriceX, labelNameY, 20, "", 0, 1, 0, 1, UIFont.Small, true)
        priceLabel:initialise()
        offerBackground:addChild(priceLabel)
        self.offerPriceLabels[i] = priceLabel
        
        local buttonWidth, buttonHeight = math.floor(offerBackground.width * 0.16), math.max(20, math.floor(rowHeight * 0.68))
        local qtyWidth = math.max(32, math.floor(offerBackground.width * 0.08))
        local transactionQty = ISTextEntryBox:new("0", offerBackground.width - buttonWidth - qtyWidth - 16, (rowHeight - buttonHeight - 2) / 2, qtyWidth, buttonHeight)
        transactionQty.backgroundColor = {r=0, g=0, b=0, a=1}
        transactionQty.borderColor = {r=0, g=0.5, b=0, a=0.7}
        transactionQty.internal = i
        transactionQty:setVisible(true)
        transactionQty:initialise()
        transactionQty:setOnlyNumbers(true)
        offerBackground:addChild(transactionQty)
        self.transactionQtys[i] = transactionQty
       
        local transactionBtn = ISButton:new(offerBackground.width - buttonWidth - 10, (rowHeight - buttonHeight) / 2, buttonWidth, buttonHeight, "", self, function(self, btn)
            local quantityTrading = tonumber(transactionQty:getText()) or 0
            self:OnBuyItem(btn, quantityTrading)
        end)
        styleDarkWebButton(transactionBtn)
        transactionBtn.internal = i
        transactionBtn:setVisible(false)
        transactionBtn:initialise()
        offerBackground:addChild(transactionBtn)
        self.transactionBtns[i] = transactionBtn


        function offerBackground:onMouseMove(dx, dy)
            self.backgroundColor = {r=0.5, g=0.5, b=0.5, a=0.3}
        end
        function offerBackground:onMouseMoveOutside(dx, dy)
            self.backgroundColor = {r=0, g=0, b=0, a=0.42}
        end
    end
end

function darkWebUI:clearSecondaryPanels()
    if self.sellScrollPanel then
        self:removeChild(self.sellScrollPanel)
        self.sellScrollPanel = nil
    end
    if self.helpScrollPanel then
        self:removeChild(self.helpScrollPanel)
        self.helpScrollPanel = nil
    end
    if self.helpMessage then
        self:removeChild(self.helpMessage)
        self.helpMessage = nil
    end
end

-- STOP
function darkWebUI:onStop(button)
    self.isClosing = true
    if PZLinuxDarkWebInstance == self then
        PZLinuxDarkWebInstance = nil
    end

    Events.OnKeyStartPressed.Remove(self.onKeyEvent)
    Events.OnKeyPressed.Remove(self.onKeyEvent)
    Events.OnKeyKeepPressed.Remove(self.onKeyEvent)

    if self.updateCoroutineFunc then
        Events.OnTick.Remove(self.updateCoroutineFunc)
        self.updateCoroutineFunc = nil
    end

    self:clearSecondaryPanels()

    if self.loadingMessage and self.scrollPanel then
        self.scrollPanel:removeChild(self.loadingMessage)
        self.loadingMessage = nil
    end

    if self.centeredImage then
        self.centeredImage:removeFromUIManager()
        self.centeredImage = nil
    end
    
    self:removeFromUIManager()
    self.terminalCoroutine = nil
end

-- LOGOUT
function darkWebUI:onMinimize(button)
    self.isClosing = true
    if PZLinuxDarkWebInstance == self then
        PZLinuxDarkWebInstance = nil
    end
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 1
end

function darkWebUI:onMinimizeBack(button)
    self.isClosing = true
    if PZLinuxDarkWebInstance == self then
        PZLinuxDarkWebInstance = nil
    end
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 3
end


-- LOGOUT
function darkWebUI:onClose(button)
    self.isClosing = true
    if PZLinuxDarkWebInstance == self then
        PZLinuxDarkWebInstance = nil
    end
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 1
end

function darkWebUI:onCloseX(button)
    self.isClosing = true
    getPlayer():StopAllActionQueue()
end

function darkWebUI:onSFXOn(button)
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

function darkWebUI:onSFXOff(button)
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

-- UPDATE UI
function darkWebUI:startUI()
    self.mode = "main"
    self:clearSecondaryPanels()
    self.titleLabel:setVisible(true)
    self.minimizeButton:setVisible(true)
    self.closeButton:setVisible(true)
    self.filterAllBtn:setVisible(false)
    self.searchField:setVisible(false)
    self.searchBtn:setVisible(false)
    self.scrollPanel:setVisible(false)
    self.scrollPanel:addScrollBars(false)
end

function darkWebUI:onBuy()
    if not PZLinuxRequireFeature("DarkWeb", self.player or getPlayer()) then return end
    self.mode = "buy"
    self:clearSecondaryPanels()
    if darkWebUsesSharedCatalog() and not sharedCatalogLoaded then
        requestSharedCatalog()
    end

    self.shoppingBuyButton:setVisible(false)
    self.shoppingSellButton:setVisible(false)
    self.shoppingHelpButton:setVisible(false)
    self.titleLabel:setVisible(true)
    self.minimizeButton:setVisible(false)
    self.minimizeBackButton:setVisible(true)
    self.closeButton:setVisible(true)
    self.filterAllBtn:setVisible(true)
    self.searchField:setVisible(true)
    self.searchBtn:setVisible(true)
    self.scrollPanel:setVisible(true)
    self.scrollPanel:addScrollBars(true)

    local lineIndex = 1
    for i, rowData in ipairs(currentOffers) do
        if self:FilterMatch(rowData) then
            local firstId
            if type(rowData.item.id) == "table" then
                firstId = rowData.item.id[1]
            else
                firstId = rowData.item.id
            end
            local scriptItem = getScriptManager():FindItem(firstId)
            local isValid = scriptItem and scriptItem:getDisplayName() and scriptItem:getDisplayName():match("%S")

            if isValid then
                if lineIndex <= ITEMS_MAX then
                    local iconName = scriptItem:getIcon()
                    local iconTex  = getTexture(iconName) or getTexture("Item_" .. iconName)

                    if iconTex and self.offerIcons[lineIndex] then
                        self.offerIcons[lineIndex].texture = iconTex
                        self.offerIcons[lineIndex]:setVisible(true)
                    elseif self.offerIcons[lineIndex] then
                        self.offerIcons[lineIndex].texture = nil
                        self.offerIcons[lineIndex]:setVisible(false)
                    end

                    if self.offerLabels[lineIndex] then
                        local displayName = rowData.displayName or scriptItem:getDisplayName()
                        if #displayName > 37 then
                            displayName = displayName:sub(1, 35) .. "..."
                        end
                        self.offerLabels[lineIndex]:setName(displayName)
                    end

                    if self.offerPriceLabels[lineIndex] then
                        self.offerPriceLabels[lineIndex]:setName(PZLinuxFormatCurrency(rowData.price))
                    end

                    if self.transactionBtns[lineIndex] then
                        self.transactionBtns[lineIndex].internal = i
                        self.transactionBtns[lineIndex]:setEnable(true)
                        if rowData.transactionType == "Buy" then
                            self.transactionBtns[lineIndex]:setTitle(PZLinuxText("UI_PZLinux_Buy", "Buy"))
                            self.transactionBtns[lineIndex].backgroundColor = {r=0, g=0.6, b=0, a=1}
                        end
                        self.transactionBtns[lineIndex]:setVisible(true)
                    end

                    if self.transactionQtys[lineIndex] then
                        if rowData.shared then
                            self.transactionQtys[lineIndex]:setText("1")
                            self.transactionQtys[lineIndex]:setVisible(false)
                        else
                            self.transactionQtys[lineIndex]:setVisible(true)
                        end
                    end

                    lineIndex = lineIndex + 1
                end
            end
        end
    end

    for j = lineIndex, ITEMS_MAX do
        if self.offerIcons[j] then
            self.offerIcons[j]:setVisible(false)
        end
        if self.offerLabels[j] then
            self.offerLabels[j]:setName("")
        end
        if self.offerPriceLabels[j] then
            self.offerPriceLabels[j]:setName("")
        end
        if self.transactionBtns[j] then
            self.transactionBtns[j]:setVisible(false)
        end
        if self.transactionQtys[j] then
            self.transactionQtys[j]:setVisible(false)
        end
    end

    if self.loadingMessage then
        self.scrollPanel:removeChild(self.loadingMessage)
        self.loadingMessage = nil
    end
end

function darkWebUI:onSell()
    if not PZLinuxRequireFeature("DarkWeb", self.player or getPlayer()) then return end
    self.mode = "sell"
    self:clearSecondaryPanels()
    self.shoppingBuyButton:setVisible(false)
    self.shoppingSellButton:setVisible(false)
    self.shoppingHelpButton:setVisible(false)
    self.minimizeButton:setVisible(false)
    self.minimizeBackButton:setVisible(true)
    self.filterAllBtn:setVisible(false)
    self.searchField:setVisible(false)
    self.searchBtn:setVisible(false)
    self.titleLabel:setVisible(true)
    if self.scrollPanel then
        self.scrollPanel:setVisible(false)
        self.scrollPanel:addScrollBars(false)
    end

    local itemsToSell = {}
    local playerObj = getPlayer()

    for _, itemData in ipairs(PZLinuxDarkWebItemsTable) do
        local itemIds = itemData.id
        local itemPrice = itemData.Price
        local firstItemId = type(itemIds) == "table" and itemIds[1] or itemIds

        local itemCount = darkWebCountSellableItemsByType(playerObj, itemIds)

        if itemCount > 0 then
            local scriptItem = getScriptManager():FindItem(firstItemId)
            local itemName = scriptItem and scriptItem:getDisplayName() or PZLinuxText("UI_PZLinux_UnknownItem", "Unknown Item")
            local iconName = scriptItem and scriptItem:getIcon()
            local iconTex = iconName and (getTexture(iconName) or getTexture("Item_" .. iconName)) or nil

            local rawPrice = PZLinuxCalculateDarkWebSellUnitPrice(playerObj, itemData)

            table.insert(itemsToSell, { 
                id = itemIds, 
                itemKey = PZLinuxEconomyBuildItemDemandKey(itemIds),
                name = itemName, 
                count = itemCount, 
                price = rawPrice, 
                icon = iconTex 
            })
        end
    end

    local safe = self.pzSafe or PZLinuxGetTerminalSafeArea(self.width, self.height)
    local scrollPanel = createDarkWebScrollPanel(safe.x, safe.y + (safe.rowH * 2) + (safe.gap * 2), safe.w, safe.h - ((safe.rowH * 2) + (safe.gap * 2)))
    self.sellScrollPanel = scrollPanel
    self:addChild(scrollPanel)

    self.offerBackgrounds = {}
    self.offerIcons = {}
    self.offerLabels = {}
    self.offerPriceLabels = {}
    self.transactionBtns = {}
    self.transactionQtysSell = {}

    local rowHeight = safe.rowH
    local totalHeight = math.max(scrollPanel.height, #itemsToSell * rowHeight + 10)
    scrollPanel:setScrollHeight(totalHeight)

    local yOffset = 0
    for _, item in ipairs(itemsToSell) do
        local rowPanel = ISPanel:new(4, yOffset, scrollPanel.width - 24, rowHeight - 3)
        rowPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.52 }
        rowPanel.borderColor = { r = 0, g = 0.28, b = 0, a = 0.62 }
        rowPanel:initialise()
        scrollPanel:addChild(rowPanel)

        if item.icon then
            local iconSize = math.max(24, math.min(32, rowHeight - 4))
            local itemIcon = ISImage:new(6, math.floor((rowHeight - iconSize) / 2), iconSize, iconSize, item.icon)
            itemIcon:initialise()
            rowPanel:addChild(itemIcon)
        end

        local labelX = math.max(38, rowHeight)
        local itemSellLabel = ISLabel:new(labelX, math.floor((rowHeight - 18) / 2), 20, tostring(item.name) .. " x" .. tostring(item.count or 0), 0, 1, 0, 1, UIFont.Small, true)
        itemSellLabel:initialise()
        rowPanel:addChild(itemSellLabel)

        local priceLabel = ISLabel:new(math.floor(rowPanel.width * 0.60), math.floor((rowHeight - 18) / 2), 20, PZLinuxFormatCurrency(item.price), 0, 1, 0, 1, UIFont.Small, true)
        priceLabel:initialise()
        rowPanel:addChild(priceLabel)

        local buttonWidth, buttonHeight = math.floor(scrollPanel.width * 0.16), safe.rowH
        local sellButton = ISButton:new(rowPanel.width - buttonWidth - 8, math.floor((rowHeight - buttonHeight) / 2), buttonWidth, buttonHeight, PZLinuxText("UI_PZLinux_Sell", "SELL"), self, self.onSellItem)
        styleDarkWebButton(sellButton)
        sellButton.internal = item.id
        sellButton.price = item.price
        sellButton.count = item.count
        sellButton:initialise()
        rowPanel:addChild(sellButton)

        yOffset = yOffset + rowHeight
    end
end

-- FILTER
function darkWebUI:OnFilter(button)
    if button.internal == "all" then
        self.filterMode = "all"
    end
    self.searchField:setText("")
    self.searchTextLower = ""
    self:onBuy()
end

function darkWebUI:FilterMatch(rowData)
    if self.filterMode == "all" then
        return true
    elseif self.filterMode == "search" then    
        if type(rowData.item.id) == "table" then
            firstId = rowData.item.id[1]
        else
            firstId = rowData.item.id
        end    
        local scriptItem = getScriptManager():FindItem(firstId)
        local itemName = rowData.displayName or (scriptItem and scriptItem:getDisplayName())
        if type(itemName) ~= "string" then
            return false
        end
        local itemNameLower = string.lower(itemName)
        return string.find(itemNameLower, self.searchTextLower, 1, true) ~= nil
    end
    return true
end

-- SEARCH
function darkWebUI:onCommandEnter()
    self:OnSearch()
end

function darkWebUI:OnSearch()
    local searchText = self.searchField:getText()
    if self.noResultsWindow then
        self.noResultsWindow:setVisible(false)
    end
    if self.emptySearchWindow then
        self.emptySearchWindow:setVisible(false)
    end
    if not searchText then
        searchText = ""
    end
    if searchText ~= "" then
        self.searchTextLower = string.lower(searchText)
        self.filterMode = "search"
        self:onBuy()
    else
        self.filterMode = "all"
        self.searchTextLower = ""
        self:onBuy()
    end
end

-- CLICK BUY SELL
function darkWebUI:OnBuyItem(button, quantityTrading)
    local globalVolume = getCore():getOptionSoundVolume() / 50
    if self.isClosing then
        return
    end

    local playerObj = getPlayer()
    local offer = currentOffers[button.internal]
    if not offer then return end

    if offer.shared then
        button:setEnable(false)
        if isClient() then
            sendClientCommand(PZLinuxModule, "BuyDarkWebOffer", {
                offerId = offer.id,
            })
        elseif PZLinuxDarkWebServerBuyOffer then
            PZLinuxDarkWebServerBuyOffer(playerObj, {
                offerId = offer.id,
            })
        end
        return
    end

    local transactionType = offer.transactionType
    local transactionQty = tonumber(quantityTrading)
    local inv = playerObj:getInventory()
    local purchasedCount = 0
    
    local batch = { items = {} }     
    for i = 1, transactionQty do
        local checkBalance = tonumber(loadAtmBalance())
        if i > 1 then globalVolume = 0 end
        if checkBalance >= offer.price then
            local itemToAdd = nil
            if type(offer.item.id) == "table" then
                itemToAdd = offer.item.id[1]
            else
                itemToAdd = offer.item.id
            end
            table.insert(batch.items, { name = itemToAdd })
            purchasedCount = purchasedCount + 1
            getSoundManager():PlayWorldSound("buy", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
            HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_ItemAvailableMailbox", "Item available in a mailbox"))

            local newBalance = checkBalance - offer.price
            saveAtmBalance(newBalance)
            self.titleLabel:setName(PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(loadAtmBalance())))
        else
            getSoundManager():PlayWorldSound("error", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
            HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_NeedMoneyBank", "I need money in my bank account"))
        end
    end

    PZLinuxOnItemBuyOnDarkWeb = {}
    table.insert(PZLinuxOnItemBuyOnDarkWeb, batch)
    local modData = getPlayer():getModData()
    if type(modData.PZLinuxOnItemBuyOnDarkWeb) ~= "table" then
        modData.PZLinuxOnItemBuyOnDarkWeb = {}
    end

    if purchasedCount > 0 then
        modData.PZLinuxOnItemBuyOnDarkWebStatus = 1
        table.insert(modData.PZLinuxOnItemBuyOnDarkWeb, PZLinuxOnItemBuyOnDarkWeb)
        addXp(getPlayer(), Perks.PlantScavenging, 3)
        PZLinuxEconomyRecordDemand(offer.itemKey or PZLinuxEconomyBuildItemDemandKey(offer.item.id), "up", purchasedCount, true)
        PZLinuxSyncPlayerModData(getPlayer())
    end
end

function darkWebUI:onSellItem(button)
    if not PZLinuxRequireFeature("DarkWeb", self.player or getPlayer()) then return end
    local itemIds = button.internal
    local playerObj = getPlayer()
    local sellableCount = PZLinuxCountInventoryItemsByFullTypes(playerObj, itemIds)
    if sellableCount <= 0 then
        getSoundManager():PlayWorldSound("error", false, playerObj:getSquare(), 0, 20, 1, true):setVolume(getCore():getOptionSoundVolume() / 50)
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_NotInMainInventory", "The item is not in my main inventory"))
        return
    end

    sendClientCommand(PZLinuxModule, "ProcessDarkWebSale", {
        itemIds = PZLinuxNormalizeFullTypeList(itemIds),
    })
end

function darkWebUI:onHelp()
    self.mode = "help"
    self:clearSecondaryPanels()
    self.shoppingBuyButton:setVisible(false)
    self.shoppingSellButton:setVisible(false)
    self.shoppingHelpButton:setVisible(false)
    self.minimizeButton:setVisible(false)
    self.minimizeBackButton:setVisible(true)
    self.filterAllBtn:setVisible(false)
    self.searchField:setVisible(false)
    self.searchBtn:setVisible(false)
    self.titleLabel:setVisible(true)
    if self.scrollPanel then
        self.scrollPanel:setVisible(false)
        self.scrollPanel:addScrollBars(false)
    end

    local safe = self.pzSafe or PZLinuxGetTerminalSafeArea(self.width, self.height)
    local helpMessageTitle = PZLinuxText("UI_PZLinux_DarkWebHelpMessage", "To sell an item, it must be in the main inventory. Clicking 'Sell'\nsells all eligible items of that type and credits the value directly\nto your PZLinux bank account.\n\nHere is the list of items that can be bought and sold:")
    self.helpMessage = ISRichTextPanel:new(safe.x, safe.y + (safe.rowH * 2) + safe.gap, safe.w, math.floor(safe.h * 0.28))
    self.helpMessage.backgroundColor = { r = 0, g = 0, b = 0, a = 0.42 }
    self.helpMessage.borderColor = { r = 0, g = 0.5, b = 0, a = 0.7 }
    self.helpMessage.autosetheight = false
    self.helpMessage.text = "<GREEN>" .. helpMessageTitle .. "</GREEN>"
    self.helpMessage:initialise()
    self.helpMessage:instantiate()
    self.helpMessage:paginate()
    self:addChild(self.helpMessage)

    local helpListY = self.helpMessage:getY() + self.helpMessage:getHeight() + safe.gap
    local scrollPanel = createDarkWebScrollPanel(safe.x, helpListY, safe.w, safe.bottom - helpListY)
    self.helpScrollPanel = scrollPanel
    self:addChild(scrollPanel)

    local rowHeight = safe.rowH
    local totalHeight = #PZLinuxDarkWebItemsTable * rowHeight + 10
    scrollPanel:setScrollHeight(math.max(scrollPanel.height, totalHeight))

    local yOffset = 0
    for _, itemData in ipairs(PZLinuxDarkWebItemsTable) do
        local itemIds = itemData.id
        local itemPrice = itemData.Price
        local firstItemId = type(itemIds) == "table" and itemIds[1] or itemIds

        local scriptItem = getScriptManager():FindItem(firstItemId)
        local itemName = scriptItem and scriptItem:getDisplayName() or PZLinuxText("UI_PZLinux_UnknownItem", "Unknown Item")
        local iconName = scriptItem and scriptItem:getIcon()
        local iconTex = iconName and (getTexture(iconName) or getTexture("Item_" .. iconName)) or nil

        if iconTex and itemName ~= PZLinuxText("UI_PZLinux_UnknownItem", "Unknown Item") then
            local rowPanel = ISPanel:new(4, yOffset, scrollPanel.width - 24, rowHeight - 3)
            rowPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.42 }
            rowPanel.borderColor = { r = 0, g = 0.25, b = 0, a = 0.58 }
            rowPanel:initialise()
            scrollPanel:addChild(rowPanel)

            local iconSize = math.max(24, math.min(32, rowHeight - 4))
            local itemIcon = ISImage:new(6, math.floor((rowHeight - iconSize) / 2), iconSize, iconSize, iconTex)
            itemIcon:initialise()
            rowPanel:addChild(itemIcon)

            local itemLabel = ISLabel:new(math.max(38, rowHeight), math.floor((rowHeight - 18) / 2), 20, itemName .. " | " .. PZLinuxFormatCurrency(itemPrice or 0), 0, 1, 0, 1, UIFont.Small, true)
            itemLabel:initialise()
            rowPanel:addChild(itemLabel)
            yOffset = yOffset + rowHeight
        end

    end
end

-- UI
function darkWebMenu_ShowUI(player)
    if not PZLinuxRequireFeature("DarkWeb", player) then return end
    GenerateDarkWebOffers()
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

    local ui = darkWebUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)

    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    ui:addChild(centeredImage)
    ui.centeredImage = centeredImage
    ui:initialise()
    ui:addToUIManager()
    ui:startUI()
    PZLinuxDarkWebInstance = ui
    
    return ui 
end
