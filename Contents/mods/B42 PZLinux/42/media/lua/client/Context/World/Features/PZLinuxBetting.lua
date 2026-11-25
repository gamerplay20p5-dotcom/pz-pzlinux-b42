require "PZLinuxConfig"
-- Contracts UI - by Raixxar 
-- Updated : 03/03/25

require "PZLinuxEconomy"

bettingUI = ISPanel:derive("bettingUI")

local LAST_CONNECTION_TIME = 0
local STAY_CONNECTED_TIME = 0

local function PZLinuxBettingName(id, fallback)
    return PZLinuxText("UI_PZLinux_BettingZombie_" .. tostring(id), fallback)
end

local BET_CURRENCIES = {
    { key = "copper", label = "C", value = 1 },
    { key = "silver", label = "S", value = 100 },
    { key = "gold", label = "G", value = 10000 },
}

local function styleBetButton(button)
    if not button then return end
    button.textColor = {r=0, g=1, b=0, a=1}
    button.backgroundColor = {r=0, g=0, b=0, a=0.5}
    button.borderColor = {r=0, g=1, b=0, a=0.5}
end

local function getBettingSafeArea(ui)
    local gap = math.max(6, math.floor(ui.height * 0.010))
    local rowH = math.max(22, math.floor(ui.height * 0.030))
    return {
        x = math.floor(ui.width * 0.17),
        y = math.floor(ui.height * 0.16),
        w = math.floor(ui.width * 0.62),
        h = math.floor(ui.height * 0.52),
        gap = gap,
        rowH = rowH,
        buttonH = math.max(26, math.floor(ui.height * 0.038)),
    }
end

local function addBetPanel(parent, x, y, w, h)
    local panel = ISPanel:new(x, y, math.max(1, w), math.max(1, h))
    panel.backgroundColor = {r=0, g=0, b=0, a=0.55}
    panel.borderColor = {r=0, g=0.45, b=0, a=0.85}
    panel:initialise()
    parent:addChild(panel)
    return panel
end

local bettings = {
    [1] = { baseName = PZLinuxText("UI_PZLinux_BettingZombieRace", "Zombie Race"), price = ZombRand(1,5000) },
    [2] = { baseName = PZLinuxText("UI_PZLinux_BettingSlots777", "777 Slots"), price = 0 },
}

local betGame = {}
for i = 1, #bettings do
    local getHourTimePriceValue = math.ceil(getGameTime():getWorldAgeHours()/2190 + 1)   
    local itemName = bettings[i].baseName
    local itemPrice = bettings[i].price > 0 and math.ceil(ZombRand(bettings[i].price, bettings[i].price * getHourTimePriceValue)/10)*10 or 0
    betGame[i] = { id = i, name = itemName, price = itemPrice, icon = iconTex }
end

-- CONSTRUCTOR
function bettingUI:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.width = width
    o.height = height
    o.player = player
    o.isClosing = false
    o.betCurrencyValue = 1
    o.currentBetAmount = 0
    o.slotSpinStep = 0
    return o
end

-- INIT
function bettingUI:initialise()
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

    self.safe = getBettingSafeArea(self)
    local safe = self.safe
    local controlW = math.max(26, math.floor(self.width * 0.032))
    local controlGap = math.max(4, math.floor(self.width * 0.006))

    self.titleLabel = ISLabel:new(safe.x, safe.y + 2, safe.rowH, PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(loadAtmBalance())), 0, 1, 0, 1, UIFont.Small, true)
    self.titleLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.titleLabel:setVisible(true)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    local modData = getPlayer():getModData()
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

    self.minimizeBackButton = ISButton:new(safe.x + safe.w - ((controlW + controlGap) * 2), safe.y, controlW, safe.rowH, "-", self, self.onMinimizeBack)
    self.minimizeBackButton.textColor = {r=0, g=1, b=0, a=1}
    self.minimizeBackButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.minimizeBackButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.minimizeBackButton:setVisible(false)
    self.minimizeBackButton:initialise()
    self.topBar:addChild(self.minimizeBackButton)

    self.closeButton = ISButton:new(safe.x + safe.w - controlW, safe.y, controlW, safe.rowH, "x", self, self.onClose)
    self.closeButton.textColor = {r=0, g=1, b=0, a=1}
    self.closeButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.closeButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.topBar:addChild(self.closeButton)
   
    self.menuTitleLabel = ISLabel:new(safe.x, safe.y + safe.rowH + safe.gap, safe.rowH, "========= " .. PZLinuxText("UI_PZLinux_OnlineBetting", "ONLINE BETTING") .. " =========", 0, 1, 0, 1, UIFont.Small, true)
    self.menuTitleLabel:initialise()
    self.topBar:addChild(self.menuTitleLabel)

    local y = safe.y + (safe.rowH * 2) + (safe.gap * 2)
    self.betButtons = {}
    for i = 1, #betGame do
        local bet = betGame[i]
        local betButton = ISButton:new(safe.x, y, safe.w, safe.buttonH, bet.name, self, self.onSelectBet)
        styleBetButton(betButton)
        betButton.betId = bet.id
        betButton.betPosition = i
        betButton:setVisible(true)
        betButton:initialise()
        self.topBar:addChild(betButton)
        table.insert(self.betButtons, betButton)
        y = y + safe.buttonH + safe.gap
    end
end

function bettingUI:setBetCurrency(value)
    self.betCurrencyValue = math.max(1, math.floor(tonumber(value) or 1))
    for _, button in ipairs(self.currencyButtons or {}) do
        local selected = tonumber(button.currencyValue) == self.betCurrencyValue
        button.backgroundColor = selected and {r=0, g=0.45, b=0, a=0.75} or {r=0, g=0, b=0, a=0.5}
        button.borderColor = selected and {r=0.35, g=1, b=0.35, a=0.95} or {r=0, g=1, b=0, a=0.5}
    end
end

function bettingUI:addCurrencyTabs(x, y, w, h)
    self.currencyButtons = self.currencyButtons or {}
    local gap = math.max(4, math.floor(w * 0.025))
    local buttonW = math.floor((w - (gap * 2)) / 3)
    for index, currency in ipairs(BET_CURRENCIES) do
        local button = ISButton:new(x + ((buttonW + gap) * (index - 1)), y, buttonW, h, currency.label, self, function()
            self:setBetCurrency(currency.value)
        end)
        button.currencyValue = currency.value
        styleBetButton(button)
        button:setVisible(true)
        button:initialise()
        self.topBar:addChild(button)
        self.currencyButtons[#self.currencyButtons + 1] = button
    end
    self:setBetCurrency(self.betCurrencyValue or 1)
end

function bettingUI:getBetAmountValue()
    local typedAmount = math.max(0, math.floor(tonumber(self.amountInput and self.amountInput:getText() or 0) or 0))
    return typedAmount * math.max(1, math.floor(tonumber(self.betCurrencyValue) or 1))
end

function bettingUI:setCurrencyTabsVisible(visible)
    for _, button in ipairs(self.currencyButtons or {}) do
        button:setVisible(visible and true or false)
    end
end

function bettingUI:onSelectBet(button)
    if button and tonumber(button.betId) == 2 then
        self:onSelectSlots(button)
        return
    end

    self.minimizeBackButton:setVisible(true)
    self.minimizeButton:setVisible(false)

    for _, button in ipairs(self.betButtons) do
        button:setVisible(false)
    end

    local zombie = {
        [1] = { name = PZLinuxBettingName(1, "Gallop Zomb"), rating = ZombRand(2,10) },
        [2] = { name = PZLinuxBettingName(2, "The Great Gallopino"), rating = ZombRand(2,10) },
        [3] = { name = PZLinuxBettingName(3, "Zombplay"), rating = ZombRand(2,15) },
        [4] = { name = PZLinuxBettingName(4, "AppleJack"), rating = ZombRand(2,15) },
        [5] = { name = PZLinuxBettingName(5, "Hocus Pocus"), rating = ZombRand(2,15) },
        [6] = { name = PZLinuxBettingName(6, "Mr Ed"), rating = ZombRand(2,15) },
        [7] = { name = PZLinuxBettingName(7, "Whinny the Poop"), rating = ZombRand(2,15) },
        [8] = { name = PZLinuxBettingName(8, "Long Drop Face"), rating = ZombRand(2,15) },
        [9] = { name = PZLinuxBettingName(9, "Eyes Out"), rating = ZombRand(2,15) },
        [10] = { name = PZLinuxBettingName(10, "Smell Bad"), rating = ZombRand(2,15) },
        [11] = { name = PZLinuxBettingName(11, "Crawler Texas Ranger"), rating = ZombRand(2,15) },
        [12] = { name = PZLinuxBettingName(12, "Walk to the Moon"), rating = ZombRand(2,15) },
        [13] = { name = PZLinuxBettingName(13, "Never Sleep Again"), rating = ZombRand(2,15) },
        [14] = { name = PZLinuxBettingName(14, "Tobit or not Tobit"), rating = ZombRand(2,15) },
        [15] = { name = PZLinuxBettingName(15, "Toothless"), rating = ZombRand(2,20) },
        [16] = { name = PZLinuxBettingName(16, "Barefoot"), rating = ZombRand(2,20) },
        [17] = { name = PZLinuxBettingName(17, "Always Hungry"), rating = ZombRand(2,20) },
        [18] = { name = PZLinuxBettingName(18, "Eat This"), rating = ZombRand(2,20) },
        [19] = { name = PZLinuxBettingName(19, "Horde"), rating = ZombRand(2,20) },
        [20] = { name = PZLinuxBettingName(20, "Toc toc toc"), rating = ZombRand(2,20) },
        [21] = { name = PZLinuxBettingName(21, "I have Maggots"), rating = ZombRand(2,20) },
        [22] = { name = PZLinuxBettingName(22, "Glenn"), rating = ZombRand(2,20) },
        [23] = { name = PZLinuxBettingName(23, "Alpha"), rating = ZombRand(2,20) },
        [24] = { name = PZLinuxBettingName(24, "A Zomb With No Name"), rating = ZombRand(2,20) },
        [25] = { name = PZLinuxBettingName(25, "Nobody"), rating = ZombRand(2,20) },
        [26] = { name = PZLinuxBettingName(26, "No Arms no Chocolate"), rating = ZombRand(2,20) },
        [27] = { name = PZLinuxBettingName(27, "Zomby McZombyface"), rating = ZombRand(2,20) },
        [28] = { name = PZLinuxBettingName(28, "Biscuit"), rating = ZombRand(2,20) },
        [29] = { name = PZLinuxBettingName(29, "Zomby Jumper"), rating = ZombRand(2,20) },
        [30] = { name = PZLinuxBettingName(30, "Rainbow Rider"), rating = ZombRand(2,20) },
        [31] = { name = PZLinuxBettingName(31, "Fuzzy Wuzzy"), rating = ZombRand(2,50) },
        [32] = { name = PZLinuxBettingName(32, "Tony Spark"), rating = ZombRand(2,50) },
        [33] = { name = PZLinuxBettingName(33, "Thannos"), rating = ZombRand(2,50) },
        [34] = { name = PZLinuxBettingName(34, "Worm"), rating = ZombRand(2,50) },
        [35] = { name = PZLinuxBettingName(35, "Should be the wind"), rating = ZombRand(2,50) },
        [36] = { name = PZLinuxBettingName(36, "Machu Pichtou"), rating = ZombRand(2,50) },
        [37] = { name = PZLinuxBettingName(37, "Sponge Zomb"), rating = ZombRand(2,100) },
        [38] = { name = PZLinuxBettingName(38, "Jean Cloud"), rating = ZombRand(2,100) },
        [39] = { name = PZLinuxBettingName(39, "The King is dead"), rating = ZombRand(2,100) },
        [40] = { name = PZLinuxBettingName(40, "Terminathour"), rating = ZombRand(2,100) }
    }

    for i = #zombie, 2, -1 do
        local j = ZombRand(1, i)
        zombie[i], zombie[j] = zombie[j], zombie[i]
    end

    self.selectedZombies = {}
    for i = 1, 8 do
        table.insert(self.selectedZombies, zombie[i])
    end

    if not self.zombieLabels then
        self.zombieLabels = {}
    end

    for _, label in ipairs(self.zombieLabels) do
        label:removeFromUIManager()
    end

    self.zombieLabels = {}
    local safe = self.safe or getBettingSafeArea(self)
    if self.menuTitleLabel then
        self.menuTitleLabel:setName("========= " .. PZLinuxText("UI_PZLinux_BettingZombieRace", "Zombie Race") .. " =========")
    end

    -- Layout responsivo da corrida: deixa a lista, os inputs, o dinheiro e o botao
    -- separados. O layout antigo usava safe.h * 0.64 para os inputs, e em algumas
    -- escalas isso fazia a oitava linha da lista ficar embaixo dos campos.
    local listY = safe.y + (safe.rowH * 2) + (safe.gap * 2)
    local startY = safe.y + safe.h - safe.buttonH
    local currencyY = startY - safe.gap - safe.rowH
    local inputY = currencyY - safe.gap - safe.rowH
    local listH = math.max(1, inputY - listY - safe.gap)
    local minRowStep = math.max(17, math.floor(safe.rowH * 0.72))
    local rowStep = math.floor((listH - (safe.gap * 2)) / math.max(1, #self.selectedZombies))

    if rowStep < minRowStep then
        rowStep = minRowStep
        listH = (rowStep * #self.selectedZombies) + (safe.gap * 2)
        inputY = listY + listH + safe.gap
        currencyY = inputY + safe.rowH + safe.gap
        startY = currencyY + safe.rowH + safe.gap
    else
        rowStep = math.min(safe.rowH, rowStep)
    end

    self.racePanel = addBetPanel(self.topBar, safe.x, listY, safe.w, listH)
    self.raceListY = listY
    self.raceListH = listH
    self.raceInputY = inputY

    local yOffset = listY + safe.gap
    for i, zomb in ipairs(self.selectedZombies) do
        local labelText = string.format("%d. %s - %d/1", i, zomb.name, zomb.rating)
        local label = ISLabel:new(safe.x + safe.gap, yOffset, rowStep, labelText, 0, 1, 0, 1, UIFont.Small, true)
        label:initialise()
        label:instantiate()
        self.topBar:addChild(label)
        table.insert(self.zombieLabels, label)
        yOffset = yOffset + rowStep
    end

    local inputW = math.floor((safe.w - safe.gap) * 0.5)
    self.betInput = ISTextEntryBox:new(PZLinuxText("UI_PZLinux_BettingPromptBetOn", "Bet on?"), safe.x, inputY, inputW, safe.rowH)
    self.betInput:initialise()
    self.betInput:instantiate()
    self.betInput:setOnlyNumbers(true)
    self.topBar:addChild(self.betInput)

    self.amountInput = ISTextEntryBox:new(PZLinuxText("UI_PZLinux_BettingPromptAmount", "Amount"), safe.x + inputW + safe.gap, inputY, inputW, safe.rowH)
    self.amountInput:initialise()
    self.amountInput:instantiate()
    self.amountInput:setOnlyNumbers(true)
    self.topBar:addChild(self.amountInput)

    self.betCurrencyValue = 1
    self:addCurrencyTabs(safe.x, currencyY, safe.w, safe.rowH)

    self.startButton = ISButton:new(safe.x, startY, safe.w, safe.buttonH, PZLinuxText("UI_PZLinux_BettingStartRace", "START THE RACE!"), self, self.onSelectStart)
    styleBetButton(self.startButton)
    self.startButton:setVisible(true)
    self.startButton:initialise()
    self.topBar:addChild(self.startButton)
end

function bettingUI:onSelectStart()
    if not PZLinuxRequireFeature("Betting", self.player or getPlayer()) then return end
    self.minimizeButton:setVisible(false)
    self.minimizeBackButton:setVisible(true)
    local globalVolume = getCore():getOptionSoundVolume() / 50
    local betAmount = self:getBetAmountValue()
    if betAmount > PZLinuxConfig.Get("BettingMaxStake") or betAmount < 1
        or not tonumber(self.betInput:getText()) 
        or tonumber(self.betInput:getText()) < 1 
        or tonumber(self.betInput:getText()) > 8 
        or betAmount > loadAtmBalance() then

        getSoundManager():PlayWorldSound("error", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
        return
    end

    self.currentBetAmount = betAmount
    local newBalance = loadAtmBalance() - betAmount
    saveAtmBalance(newBalance)
    self.titleLabel:setName(PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(newBalance)))

    getSoundManager():PlayWorldSound("race", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    self.betInput:setVisible(false)
    self.amountInput:setVisible(false)
    self:setCurrencyTabsVisible(false)
    self.startButton:setVisible(false)

    if not self.selectedZombies or #self.selectedZombies == 0 then
        return
    end

    self.raceProgress = {}
    self.raceFinished = false

    for i, zomb in ipairs(self.selectedZombies) do
        self.raceProgress[i] = { zombie = zomb, position = -15 }
    end

    self:runRace()
end

function bettingUI:onSelectSlots(button)
    local safe = self.safe or getBettingSafeArea(self)
    self.minimizeBackButton:setVisible(true)
    self.minimizeButton:setVisible(false)

    for _, betButton in ipairs(self.betButtons or {}) do
        betButton:setVisible(false)
    end

    if self.menuTitleLabel then
        self.menuTitleLabel:setName("========== 777 SLOT ==========")
    end

    self.slotTitleLabel = ISLabel:new(safe.x, safe.y + (safe.rowH * 2) + safe.gap, safe.rowH, PZLinuxText("UI_PZLinux_BettingSlots777", "777 Slots"), 0, 1, 0, 1, UIFont.Small, true)
    self.slotTitleLabel:initialise()
    self.topBar:addChild(self.slotTitleLabel)

    self.slotLabels = {}
    self.slotBoxes = {}
    local slotGap = math.max(14, math.floor(safe.w * 0.045))
    local slotW = math.floor((safe.w - (slotGap * 2)) / 3)
    local slotH = math.max(62, math.floor(safe.h * 0.20))
    local slotX = safe.x
    local slotY = safe.y + (safe.rowH * 3) + (safe.gap * 2)
    for i = 1, 3 do
        local boxX = slotX + ((slotW + slotGap) * (i - 1))
        local box = addBetPanel(self.topBar, boxX, slotY, slotW, slotH)
        self.slotBoxes[i] = box
        local label = ISLabel:new(boxX + math.floor(slotW * 0.45), slotY + math.floor(slotH * 0.20), math.floor(slotH * 0.55), "7", 0, 1, 0, 1, UIFont.Large, true)
        label:initialise()
        self.topBar:addChild(label)
        self.slotLabels[i] = label
    end

    local statusY = slotY + slotH + safe.gap
    self.slotStatusLabel = ISLabel:new(safe.x, statusY, safe.rowH, PZLinuxText("UI_PZLinux_BettingSlotsPrompt", "Choose amount and currency."), 0, 1, 0, 1, UIFont.Small, true)
    self.slotStatusLabel:initialise()
    self.topBar:addChild(self.slotStatusLabel)

    self.amountInput = ISTextEntryBox:new(PZLinuxText("UI_PZLinux_BettingPromptAmount", "Amount"), safe.x, statusY + safe.rowH + safe.gap, safe.w, safe.rowH)
    self.amountInput:initialise()
    self.amountInput:instantiate()
    self.amountInput:setOnlyNumbers(true)
    self.topBar:addChild(self.amountInput)

    self.betCurrencyValue = 1
    self:addCurrencyTabs(safe.x, statusY + ((safe.rowH + safe.gap) * 2), safe.w, safe.rowH)

    self.startButton = ISButton:new(safe.x, statusY + ((safe.rowH + safe.gap) * 3), safe.w, safe.buttonH, PZLinuxText("UI_PZLinux_BettingSlotsSpin", "SPIN 777"), self, self.onStartSlots)
    styleBetButton(self.startButton)
    self.startButton:setVisible(true)
    self.startButton:initialise()
    self.topBar:addChild(self.startButton)
end

function bettingUI:onStartSlots()
    if not PZLinuxRequireFeature("Betting", self.player or getPlayer()) then return end
    local globalVolume = getCore():getOptionSoundVolume() / 50
    local betAmount = self:getBetAmountValue()
    if betAmount > PZLinuxConfig.Get("BettingMaxStake") or betAmount < 1 or betAmount > loadAtmBalance() then
        getSoundManager():PlayWorldSound("error", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
        return
    end

    self.currentBetAmount = betAmount
    local newBalance = loadAtmBalance() - betAmount
    saveAtmBalance(newBalance)
    self.titleLabel:setName(PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(newBalance)))

    self.amountInput:setVisible(false)
    self:setCurrencyTabsVisible(false)
    self.startButton:setVisible(false)
    self.slotSpinStep = 0
    self.slotFinalDigits = { ZombRand(10), ZombRand(10), ZombRand(10) }
    if ZombRand(1000) < 8 then
        self.slotFinalDigits = { 7, 7, 7 }
    end
    getSoundManager():PlayWorldSound("race", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    self:spinSlots()
end

function bettingUI:spinSlots()
    if self.isClosing then return end

    self.slotSpinStep = (tonumber(self.slotSpinStep) or 0) + 1
    local finished = self.slotSpinStep >= 16
    for i = 1, 3 do
        local digit = finished and self.slotFinalDigits[i] or ZombRand(10)
        if self.slotLabels and self.slotLabels[i] then
            self.slotLabels[i]:setName(tostring(digit))
        end
    end

    if finished then
        self:finishSlots()
        return
    end

    self:delayFunction(function() self:spinSlots() end, 1)
end

function bettingUI:finishSlots()
    local digits = self.slotFinalDigits or { 0, 0, 0 }
    local betAmount = math.max(0, math.floor(tonumber(self.currentBetAmount) or 0))
    local payout = 0
    local message = PZLinuxText("UI_PZLinux_BettingSlotsLose", "No prize this time.")

    if digits[1] == 7 and digits[2] == 7 and digits[3] == 7 then
        payout = math.floor(betAmount * 25 * PZLinuxConfig.Get("BettingPayoutMultiplier"))
        message = PZLinuxText("UI_PZLinux_BettingSlotsJackpot", "JACKPOT 777! Prize: %s", PZLinuxFormatCurrency(payout))
    elseif digits[1] == digits[2] and digits[2] == digits[3] then
        payout = math.floor(betAmount * 8 * PZLinuxConfig.Get("BettingPayoutMultiplier"))
        message = PZLinuxText("UI_PZLinux_BettingSlotsTriple", "Triple! Prize: %s", PZLinuxFormatCurrency(payout))
    elseif digits[1] == 7 or digits[2] == 7 or digits[3] == 7 then
        payout = math.floor(betAmount * 1.5 * PZLinuxConfig.Get("BettingPayoutMultiplier"))
        message = PZLinuxText("UI_PZLinux_BettingSlotsSeven", "Lucky seven! Prize: %s", PZLinuxFormatCurrency(payout))
    end

    local globalVolume = getCore():getOptionSoundVolume() / 50
    if payout > 0 then
        local newBalance = loadAtmBalance() + payout
        saveAtmBalance(newBalance)
        self.titleLabel:setName(PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(newBalance)))
        getSoundManager():PlayWorldSound("sold", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    else
        getSoundManager():PlayWorldSound("error", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    end

    if self.slotStatusLabel then
        self.slotStatusLabel:setName(message)
    end
    if self.amountInput then
        self.amountInput:setVisible(true)
    end
    self:setCurrencyTabsVisible(true)
    if self.startButton then
        self.startButton:setVisible(true)
    end
end

function bettingUI:runRace()
    if self.raceFinished then return end

    for _, runner in ipairs(self.raceProgress) do
        local rating = runner.zombie.rating
        local baseSpeed = 5
        local bonus = (100 - rating) / 25
        local speed = baseSpeed + ZombRand(0, bonus)
        runner.position = runner.position + speed
    end

    local actualPosition = -math.huge
    local potentialWinner = nil
    local pos = nil

    for i, runner in ipairs(self.raceProgress) do
        if runner.position > actualPosition then
            actualPosition = runner.position
            potentialWinner = runner.zombie
            pos = i
        end
    end

    if actualPosition >= 130 then
        self.raceFinished = true
        self:declareWinner(pos, potentialWinner)
    end

    self:updateRaceDisplay()
    self:delayFunction(function() self:runRace() end, 20)
    getPlayer():getStats():add(CharacterStat.BOREDOM, -2)
end

function bettingUI:updateRaceDisplay()
    local safe = self.safe or getBettingSafeArea(self)
    local sortedRunners = {}
    
    for i, runner in ipairs(self.raceProgress or {}) do
        table.insert(sortedRunners, { id = i, runner = runner })
    end

    table.sort(sortedRunners, function(a, b)
        return a.runner.position > b.runner.position
    end)

    if not self.zombieTextLabels then
        self.zombieTextLabels = {}
    end

    local labelText = PZLinuxText(
        "UI_PZLinux_BettingYourBet",
        "Your bet: %s on the zombie [%s]",
        PZLinuxFormatCurrency(self.currentBetAmount or self:getBetAmountValue()),
        tostring(tonumber(self.betInput and self.betInput:getText() or 0) or 0)
    )

    local maxDots = math.max(8, math.floor(safe.w / 24))
    for rank, data in ipairs(sortedRunners) do
        local corde = data.id
        local dots = string.rep(".", math.min(maxDots, math.max(0, math.floor((tonumber(data.runner.position) or 0) / 5))))
        local progressText = string.format("%d. %s %s", corde, dots, tostring(data.runner.zombie.name or ""))
        if self.zombieLabels and self.zombieLabels[data.id] then
            self.zombieLabels[data.id]:setName(progressText)
        end
        if rank <= 3 then
            labelText = labelText .. "\n" .. PZLinuxText(
                "UI_PZLinux_BettingOddsLine",
                "[%s] -> %s: %s odds: %s/1",
                tostring(rank),
                tostring(corde),
                tostring(data.runner.zombie.name),
                tostring(data.runner.zombie.rating)
            )
        end
    end
    
    if self.runResultLabel then 
        self.runResultLabel:setName(labelText)
        return
    end

    local statusY = self.raceInputY or (safe.y + math.floor(safe.h * 0.76))
    self.runResultLabel = ISLabel:new(safe.x, statusY, safe.rowH, labelText, 0, 1, 0, 1, UIFont.Small, true)
    self.runResultLabel.backgroundColor = {r=0, g=0, b=0, a=0}
    self.runResultLabel:setVisible(true)
    self.runResultLabel:initialise()
    self.topBar:addChild(self.runResultLabel)
end

function bettingUI:declareWinner(winnerId, winner)
    local safe = self.safe or getBettingSafeArea(self)
    local winnerText = PZLinuxText("UI_PZLinux_BettingWinner", "%s HAS WON!", tostring(winner.name))
    self.winnerLabel = ISLabel:new(safe.x, safe.y + safe.rowH + safe.gap, safe.rowH, winnerText, 1, 1, 0, 1, UIFont.Large, true)
    self.winnerLabel:initialise()
    self.winnerLabel:instantiate()
    self:addChild(self.winnerLabel)

    if winnerId == tonumber(self.betInput:getText()) then
        local balance = loadAtmBalance()
        local betAmount = math.max(0, math.floor(tonumber(self.currentBetAmount) or 0))
        local newBalance = balance + math.floor(betAmount * winner.rating * PZLinuxConfig.Get("BettingPayoutMultiplier"))
        saveAtmBalance(newBalance)
        self.titleLabel:setName(PZLinuxText("UI_PZLinux_AccountBalance", "Account Balance %s", PZLinuxFormatCurrency(newBalance)))

        local globalVolume = getCore():getOptionSoundVolume() / 50
        getSoundManager():PlayWorldSound("sold", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)

        if betAmount >= 5000 then
            getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -10)
            getPlayer():getStats():add(CharacterStat.STRESS, -0.5)
        elseif betAmount >= 1000 then
            getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -5)
            getPlayer():getStats():add(CharacterStat.STRESS, -0.1)
        else
            getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -2)
            getPlayer():getStats():add(CharacterStat.STRESS, -0.05)
        end
    else
        local betAmount = math.max(0, math.floor(tonumber(self.currentBetAmount) or 0))
        if betAmount >= 5000 then
            getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -10)
            getPlayer():getStats():add(CharacterStat.STRESS, -0.5)
        elseif betAmount >= 1000 then
            getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -5)
            getPlayer():getStats():add(CharacterStat.STRESS, -0.1)
        end
    end
end

function bettingUI:delayFunction(func, seconds)
    local startTime = getGameTime():getWorldAgeHours() * 3600
    local targetTime = startTime + seconds

    local function timer()
        local elapsed = getGameTime():getWorldAgeHours() * 3600
        if elapsed >= targetTime then
            Events.OnTick.Remove(timer)
            if not self.isClosing then
                func()
            end
        end
    end

    Events.OnTick.Add(timer)
end

function bettingUI:onYesButton(button)
    local modData = PZLinuxGetModData(getPlayer())
    modData.PZLinuxActiveRequest = 1

    local playerBalance = loadAtmBalance()
    local newBalance = playerBalance - (PZLinuxOnItemRequestCount * betGame[button.id].price)
    saveAtmBalance(newBalance)
    self.titleLabel:setName(PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %s", PZLinuxFormatCurrency(loadAtmBalance())))

    if type(modData.PZLinuxOnItemRequest) ~= "table" then
        modData.PZLinuxOnItemRequest = {}
    end

    if type(modData.PZLinuxOnItemRequestCount) ~= "table" then
        modData.PZLinuxOnItemRequestCount = {}
    end

    while #modData.PZLinuxOnItemRequest ~= #modData.PZLinuxOnItemRequestCount do
        if #modData.PZLinuxOnItemRequest > #modData.PZLinuxOnItemRequestCount then
            table.remove(modData.PZLinuxOnItemRequest, 1)
        elseif #modData.PZLinuxOnItemRequest < #modData.PZLinuxOnItemRequestCount then
            table.remove(modData.PZLinuxOnItemRequestCount, 1)
        end
    end

    table.insert(modData.PZLinuxOnItemRequest, PZLinuxOnItemRequest)
    table.insert(modData.PZLinuxOnItemRequestCount, PZLinuxOnItemRequestCount)
    PZLinuxSyncPlayerModData(getPlayer())
    
    self.isClosing = true
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 9
end

-- LOGOUT
function bettingUI:onMinimize(button)
    self.isClosing = true
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 1
end

function bettingUI:onMinimizeBack(button)
    self.isClosing = true
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 9
end

-- CLOSE
function bettingUI:onClose(button)
    self.isClosing = true
    self:removeFromUIManager()
    local modData = getPlayer():getModData()
    modData.PZLinuxUIOpenMenu = 1
end

-- CLOSE
function bettingUI:onCloseX(button)
    self.isClosing = true
    getPlayer():StopAllActionQueue()
end

function bettingUI:onSFXOn(button)
    local modData = getPlayer():getModData()
    modData.PZLinuxUISFX = 0
    self.skipAnimationButton:close()
    local safe = self.safe or getBettingSafeArea(self)
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

function bettingUI:onSFXOff(button)
    local modData = getPlayer():getModData()
    modData.PZLinuxUISFX = 1
    self.skipAnimationButton:close()
    local safe = self.safe or getBettingSafeArea(self)
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

function bettingMenu_ShowUI(player)
    if not PZLinuxRequireFeature("Betting", player) then return end
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

    local ui = bettingUI:new(uiX, uiY, finalW, finalH, player)
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
