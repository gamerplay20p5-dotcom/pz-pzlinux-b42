-- ATM UI - by Raixxar 
-- Updated : 08/06/26

require "PZLinuxEconomy"

AtmUI = ISPanel:derive("AtmUI")

-- CONSTRUCTOR
function AtmUI:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0.05, g=0.05, b=0.05, a=0}
    o.borderColor     = {r=0.2, g=0.2, b=0.2, a=0}
    o.width           = width
    o.height          = height
    o.player          = player
    o.isClosing       = false
    o.balance         = loadAtmBalance()
    o.mode            = "main"
    o.pendingBankAction = false
    return o
end

-- SAVE BALANCE BANK ACCOUNT
function saveAtmBalance(balance)
    if balance then
        local player = getPlayer()
        local modData = PZLinuxGetModData(player)
        modData.PZLinuxBank = balance
        PZLinuxSyncPlayerModData(player)
    end
end

function loadAtmBalance()
    local player = getPlayer()
    local modData = PZLinuxGetModData(player)
    local bankBalance = modData.PZLinuxBank
    if tonumber(bankBalance) ~= nil then
        return bankBalance
    end

    if isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "RequestBankBalance", {})
        return 0
    end

    bankBalance = PZLinuxConfig.NewBankBalance()
    modData.PZLinuxBank = bankBalance
    PZLinuxSyncPlayerModData(player)
    return bankBalance
end

-- INIT
function AtmUI:initialise()
    ISPanel.initialise(self)
    self:showLoginMenu()
end

function AtmUI:showLoginMenu()
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
    end

    self.titleLabel = ISLabel:new(self.width * 0.225, self.width * 0.43, self.width * 0.1, PZLinuxText("UI_PZLinux_ATMTitle", "ATM AMERICAN BANK"), 0.8, 1, 0.8, 1, UIFont.Small, true)
    self.titleLabel:setVisible(true)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    self.closeButton = ISButton:new(self.width * 0.527, self.width * 0.461, self.width * 0.1, self.height * 0.027, PZLinuxText("UI_PZLinux_Leave", "LEAVE"), self, self.onClose)
    self.closeButton.backgroundColor = {r=0.5, g=0, b=0, a=1}
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.topBar:addChild(self.closeButton)

    self.loginButton = ISButton:new(self.width * 0.295, self.width * 0.55, self.width * 0.25, self.height * 0.08, "  " .. PZLinuxText("UI_PZLinux_Login", "LOGIN") .. "   ", self, self.onLoginMenu)
    self.loginButton:setVisible(true)
    self.loginButton:initialise()
    self.topBar:addChild(self.loginButton)

    self.passwordLabel = ISLabel:new(self.width * 0.225, self.width * 0.48, self.width * 0.1, PZLinuxText("UI_PZLinux_Password", "PASSWORD"), 0.8, 1, 0.8, 1, UIFont.Small, true)
    self.passwordLabel:setVisible(false)
    self.passwordLabel:initialise()
    self.topBar:addChild(self.passwordLabel)
end

function AtmUI:showMainMenu()
    self.withdrawalButton = ISButton:new(self.width * 0.295, self.width * 0.56, self.width * 0.25, self.height * 0.08, "  " .. PZLinuxText("UI_PZLinux_Withdrawal", "WITHDRAWAL") .. "   ", self, self.onWithdrawal)
    self.withdrawalButton:setVisible(true)
    self.withdrawalButton:initialise()
    self.topBar:addChild(self.withdrawalButton)

    self.depositeButton = ISButton:new(self.width * 0.295, self.width * 0.67, self.width * 0.25, self.height * 0.08, "      " .. PZLinuxText("UI_PZLinux_Deposit", "DEPOSIT") .. "      ", self, self.onDeposite)
    self.depositeButton:setVisible(true)
    self.depositeButton:initialise()
    self.topBar:addChild(self.depositeButton)

    self.balanceLabel = ISLabel:new(self.width * 0.225, self.width * 0.45, self.width * 0.1, PZLinuxText("UI_PZLinux_Balance", "Balance: %1", PZLinuxFormatCurrency(self.balance)), 1, 1, 1, 1, UIFont.Small, true)
    self.balanceLabel:initialise()
    self:addChild(self.balanceLabel)
end

function AtmUI:showDepositeMenu()
    self.titleLabelDeposite = ISLabel:new(self.width * 0.225, self.width * 0.47, self.width * 0.1, PZLinuxText("UI_PZLinux_DepositMoney", "DEPOSIT MONEY"), 1, 1, 1, 1, UIFont.Small, true)
    self.titleLabelDeposite:initialise()
    self:addChild(self.titleLabelDeposite)

    self.amountFieldDeposite = ISTextEntryBox:new("", self.width * 0.315, self.width * 0.58, self.width * 0.229, self.height * 0.025)
    self.amountFieldDeposite:initialise()
    self.amountFieldDeposite:instantiate()
    self:addChild(self.amountFieldDeposite)

    self.sendButtonDeposite = ISButton:new(self.width * 0.315, self.width * 0.63, self.width * 0.10, self.height * 0.05, PZLinuxText("UI_PZLinux_Send", "SEND"), self, self.onDepositeSend)
    self.sendButtonDeposite:initialise()
    self:addChild(self.sendButtonDeposite)

    self.backButtonDeposite = ISButton:new(self.width * 0.445, self.width * 0.63, self.width * 0.10, self.height * 0.05, PZLinuxText("UI_PZLinux_Back", "BACK"), self, self.onDepositeBack)
    self.backButtonDeposite:initialise()
    self:addChild(self.backButtonDeposite)
end

function AtmUI:showWithdrawalMenu()
    self.titleLabelWithdrawal = ISLabel:new(self.width * 0.225, self.width * 0.47, self.width * 0.1, PZLinuxText("UI_PZLinux_WithdrawalMoney", "WITHDRAWAL MONEY"), 1, 1, 1, 1, UIFont.Small, true)
    self.titleLabelWithdrawal:initialise()
    self:addChild(self.titleLabelWithdrawal)

    self.amountFieldWithdrawal = ISTextEntryBox:new("", self.width * 0.315, self.width * 0.58, self.width * 0.229, self.height * 0.025)
    self.amountFieldWithdrawal:initialise()
    self.amountFieldWithdrawal:instantiate()
    self:addChild(self.amountFieldWithdrawal)

    self.sendButtonWithdrawal = ISButton:new(self.width * 0.315, self.width * 0.63, self.width * 0.10, self.height * 0.05, PZLinuxText("UI_PZLinux_Send", "SEND"), self, self.onWithdrawalSend)
    self.sendButtonWithdrawal:initialise()
    self:addChild(self.sendButtonWithdrawal)

    self.backButtonWithdrawal = ISButton:new(self.width * 0.445, self.width * 0.63, self.width * 0.10, self.height * 0.05, PZLinuxText("UI_PZLinux_Back", "BACK"), self, self.onWithdrawalBack)
    self.backButtonWithdrawal:initialise()
    self:addChild(self.backButtonWithdrawal)
end

function AtmUI:showConvertMenu()
    PZLinuxAtmConverterInstance = self

    self.titleLabelConvert = ISLabel:new(self.width * 0.225, self.width * 0.47, self.width * 0.1, PZLinuxText("UI_PZLinux_ConverterTitle", "Money Converter"), 1, 1, 1, 1, UIFont.Small, true)
    self.titleLabelConvert:initialise()
    self:addChild(self.titleLabelConvert)

    self.coinLabelConvert = ISLabel:new(self.width * 0.225, self.width * 0.52, self.width * 0.1, "", 1, 1, 1, 1, UIFont.Small, true)
    self.coinLabelConvert:initialise()
    self:addChild(self.coinLabelConvert)

    self.convertCopperButton = ISButton:new(self.width * 0.225, self.width * 0.58, self.width * 0.17, self.height * 0.045, PZLinuxCurrencyText("UI_PZLinux_ConvertCopperSilver", "100 Money -> 1 Money Bundle"), self, self.onConvertAction)
    self.convertCopperButton.internal = "copper_to_silver"
    self.convertCopperButton:initialise()
    self:addChild(self.convertCopperButton)

    self.convertSilverButton = ISButton:new(self.width * 0.405, self.width * 0.58, self.width * 0.17, self.height * 0.045, PZLinuxCurrencyText("UI_PZLinux_ConvertSilverGold", "100 Money -> 1 Money Bundle"), self, self.onConvertAction)
    self.convertSilverButton.internal = "silver_to_gold"
    self.convertSilverButton:initialise()
    self.convertSilverButton:setVisible(PZLinuxConfig.Get("CurrencyMode") == 2)
    self:addChild(self.convertSilverButton)

    self.retroGoldButton = ISButton:new(self.width * 0.225, self.width * 0.64, self.width * 0.17, self.height * 0.045, PZLinuxCurrencyText("UI_PZLinux_RetroGoldSilver", "1 Money Bundle -> 100 Money"), self, self.onConvertAction)
    self.retroGoldButton.internal = "gold_to_silver"
    self.retroGoldButton:initialise()
    self:addChild(self.retroGoldButton)

    self.retroSilverButton = ISButton:new(self.width * 0.405, self.width * 0.64, self.width * 0.17, self.height * 0.045, PZLinuxCurrencyText("UI_PZLinux_RetroSilverCopper", "1 Money Bundle -> 100 Money"), self, self.onConvertAction)
    self.retroSilverButton.internal = "silver_to_copper"
    self.retroSilverButton:initialise()
    self.retroSilverButton:setVisible(PZLinuxConfig.Get("CurrencyMode") == 2)
    self:addChild(self.retroSilverButton)

    self.backButtonConvert = ISButton:new(self.width * 0.445, self.width * 0.70, self.width * 0.10, self.height * 0.05, PZLinuxText("UI_PZLinux_Back", "BACK"), self, self.onConvertBack)
    self.backButtonConvert:initialise()
    self:addChild(self.backButtonConvert)

    self:refreshConvertCoinLabel()
end

function AtmUI:refreshConvertCoinLabel(counts)
    if not self.coinLabelConvert then return end
    counts = counts or (PZLinuxEconomyGetBankCoinCounts and PZLinuxEconomyGetBankCoinCounts(getPlayer())) or PZLinuxEconomyGetInventoryCoinCounts(getPlayer())
    self.coinLabelConvert:setName(PZLinuxCurrencyText(
        "UI_PZLinux_CoinBankLine",
        "Bank: %1G %2S %3C (%4)",
        tostring(counts.gold or 0),
        tostring(counts.silver or 0),
        tostring(counts.copper or 0),
        PZLinuxFormatCurrency(counts.value or 0)
    ))
end

function AtmUI:hideMainButtons()
    if self.depositeButton then self.depositeButton:setVisible(false) end
    if self.withdrawalButton then self.withdrawalButton:setVisible(false) end
    if self.convertButton then self.convertButton:setVisible(false) end
end

function AtmUI:showMainButtons()
    if self.depositeButton then self.depositeButton:setVisible(true) end
    if self.withdrawalButton then self.withdrawalButton:setVisible(true) end
    if self.convertButton then self.convertButton:setVisible(true) end
end

function AtmUI:onLoginMenu()
    local globalVolume = getCore():getOptionSoundVolume() / 50
    self.loginButton:setVisible(false)
    if self.isClosing or not getPlayer() then
        return
    end

    local loginBase = PZLinuxText("UI_PZLinux_InsertCreditCard", "INSERT YOUR CREDIT CARD")
    local currentLogin = loginBase
    local index = 1

    local passwordBase = PZLinuxText("UI_PZLinux_PasswordPrompt", "PASSWORD: ")
    local currentPassword = passwordBase
    local passwordIndex = 1
    local totalAsterisks = 4

    local messageTemplates = {
        {base = PZLinuxText("UI_PZLinux_Loading", "Loading"), variations = 2},
    }

    local messages = {}

    for _, template in ipairs(messageTemplates) do
        if template.variations and template.variations > 0 then
            for i = 1, template.variations do
                table.insert(messages, template.base .. string.rep(".", i))
            end
            if template.repeatCount then
                for _ = 1, template.repeatCount do
                    table.insert(messages, template.base .. string.rep(".", template.variations))
                end
            end
        else
            table.insert(messages, template.base)
        end
    end

    if not self.loadingMessage then
        self.loadingMessage = ISLabel:new(self.width * 0.225, self.width * 0.45, self.width * 0.1, "", 0.8, 1, 0.8, 1, UIFont.Small, true)
        self.loadingMessage:initialise()
        self.topBar:addChild(self.loadingMessage)
    end

    self.terminalCoroutine = coroutine.create(function()
        getSoundManager():PlayWorldSound("creditCard", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
        self.loadingMessage:setName(loginBase)

        local elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
        local initialDelay = elapsed + 40
        while elapsed < initialDelay do
            if self.isClosing then return end
            coroutine.yield()
            elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
        end

        self.loadingMessage:setName(passwordBase)
        local elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
        local initialDelay = elapsed + 40
        while elapsed < initialDelay do
            if self.isClosing then return end
            coroutine.yield()
            elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
        end

        while passwordIndex <= totalAsterisks do
            if self.isClosing then
                return
            end
            
            getSoundManager():PlayWorldSound("atmBip", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
            currentPassword = currentPassword .. "*"
            passwordIndex = passwordIndex + 1
            self.loadingMessage:setName(currentPassword)
            
            local elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
            local letterDelay = elapsed + ZombRand(2, math.ceil((-((getPlayer():getPerkLevel(Perks.Electricity)^2) / 1) + 130) / 10))
            while elapsed < letterDelay do
                if self.isClosing then return end
                coroutine.yield()
                elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
            end
        end

        for _, message in ipairs(messages) do
            if self.isClosing then
                return
            end

            self.loadingMessage:setName(message)
            local delay = ZombRand(60, 240)
            for _ = 1, delay do
                if self.isClosing then
                    return
                end
                coroutine.yield()
            end
        end
        
        self.loadingMessage:setVisible(false)
        self.loadingMessage = nil
        self:showMainMenu()
    end)

    self.updateCoroutineFunc = function()
        if coroutine.status(self.terminalCoroutine) ~= "dead" then
            coroutine.resume(self.terminalCoroutine)
        else
            Events.OnTick.Remove(self.updateCoroutineFunc)
            self.updateCoroutineFunc = nil
            self.terminalCoroutine = nil
        end
    end
    Events.OnTick.Add(self.updateCoroutineFunc)
end

function AtmUI:onClose()
    self.isClosing = true
    if PZLinuxAtmInstance == self then
        PZLinuxAtmInstance = nil
    end
    if PZLinuxAtmConverterInstance == self then
        PZLinuxAtmConverterInstance = nil
    end
    self:removeFromUIManager()
    getPlayer():StopAllActionQueue()
end

function AtmUI:onWithdrawal()
    self:hideMainButtons()
    self:showWithdrawalMenu()
end

function AtmUI:onDeposite()
    local playerObj = getPlayer()
    if PZLinuxEconomyTransferCoinsToMainInventory then
        PZLinuxEconomyTransferCoinsToMainInventory(playerObj)
    end
    self:hideMainButtons()
    self:showDepositeMenu()
end

function AtmUI:onConvert()
    if not PZLinuxRequireFeature("CurrencyConversion", self.player or getPlayer()) then return end
    local playerObj = getPlayer()
    if PZLinuxEconomyTransferCoinsToMainInventory then
        PZLinuxEconomyTransferCoinsToMainInventory(playerObj)
    end
    self:hideMainButtons()
    self:showConvertMenu()
end

function AtmUI:onDepositeBack()
    self.titleLabelDeposite:setVisible(false)
    self.amountFieldDeposite:setVisible(false)
    self.sendButtonDeposite:setVisible(false)
    self.backButtonDeposite:setVisible(false)
    self:showMainButtons()
end

function AtmUI:onWithdrawalBack()
    self.titleLabelWithdrawal:setVisible(false)
    self.amountFieldWithdrawal:setVisible(false)
    self.sendButtonWithdrawal:setVisible(false)
    self.backButtonWithdrawal:setVisible(false)
    self:showMainButtons()
end

function AtmUI:onConvertBack()
    if PZLinuxAtmConverterInstance == self then
        PZLinuxAtmConverterInstance = nil
    end
    if self.titleLabelConvert then self.titleLabelConvert:setVisible(false) end
    if self.coinLabelConvert then self.coinLabelConvert:setVisible(false) end
    if self.convertCopperButton then self.convertCopperButton:setVisible(false) end
    if self.convertSilverButton then self.convertSilverButton:setVisible(PZLinuxConfig.Get("CurrencyMode") == 2) end
    if self.retroGoldButton then self.retroGoldButton:setVisible(false) end
    if self.retroSilverButton then self.retroSilverButton:setVisible(PZLinuxConfig.Get("CurrencyMode") == 2) end
    if self.backButtonConvert then self.backButtonConvert:setVisible(false) end
    self:showMainButtons()
end

function AtmUI:onConvertAction(button)
    local action = button and button.internal
    local playerObj = getPlayer()
    if not action or not playerObj then return end

    if isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "ConvertCoins", { action = action, source = "bank" })
        return
    end

    self:onConvertResult((PZLinuxEconomyConvertBankCoins and PZLinuxEconomyConvertBankCoins(playerObj, action)) or PZLinuxEconomyConvertCoins(playerObj, action))
end

function AtmUI:onConvertResult(result)
    local playerObj = getPlayer()
    if result and tonumber(result.balance) ~= nil then
        local modData = PZLinuxGetModData(playerObj)
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(result.balance) or 0))
        end
    end

    if result and result.ok then
        if HaloTextHelper then
            HaloTextHelper.addGoodText(playerObj, PZLinuxText("UI_PZLinux_ConvertOk", "Money converted"))
        end
        self:refreshConvertCoinLabel(result.counts)
        return
    end

    if HaloTextHelper then
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_ConvertFailed", "Not enough money"))
    end
    self:refreshConvertCoinLabel()
end

function AtmUI:setBankBalance(balance)
    local normalizedBalance = math.max(0, math.floor(tonumber(balance) or 0))
    self.balance = normalizedBalance

    local playerObj = getPlayer()
    local modData = PZLinuxGetModData(playerObj)
    if modData then
        modData.PZLinuxBank = normalizedBalance
        modData.PZLinuxBankCoins = nil
    end

    if self.balanceLabel then
        self.balanceLabel:setName(PZLinuxText("UI_PZLinux_Balance", "Balance: %1", PZLinuxFormatCurrency(normalizedBalance)))
    end
end

function AtmUI:onBankBalanceResult(result)
    if result and tonumber(result.balance) ~= nil then
        self:setBankBalance(result.balance)
    end
end

function AtmUI:onWithdrawalResult(result)
    self.pendingBankAction = false
    if self.sendButtonWithdrawal then
        self.sendButtonWithdrawal:setEnable(true)
    end
    self:onBankBalanceResult(result)

    local playerObj = getPlayer()
    if result and result.ok then
        HaloTextHelper.addGoodText(playerObj, PZLinuxText(
            "UI_PZLinux_WithdrawalOk",
            "Withdrawal completed: %1",
            PZLinuxFormatCurrency(result.amount or 0)
        ))
        self.amountFieldWithdrawal:setText("")
        return
    end

    local reason = tostring(result and result.reason or "")
    if reason == "disabled" then
        HaloTextHelper.addBadText(playerObj, getText("UI_PZLinux_FeatureDisabled"))
    elseif reason == "transaction_limit" then
        HaloTextHelper.addBadText(playerObj, getText("UI_PZLinux_CashTransactionLimit"))
    elseif reason == "not_enough_money" then
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_NotEnoughMoney", "Not enough money"))
    elseif reason == "create_failed" then
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_ItemCreationFailed", "The money could not be created."))
    else
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_InvalidAmount", "Invalid amount"))
    end
end

function AtmUI:onDepositResult(result)
    self.pendingBankAction = false
    if self.sendButtonDeposite then
        self.sendButtonDeposite:setEnable(true)
    end
    self:onBankBalanceResult(result)

    local playerObj = getPlayer()
    if result and result.ok then
        HaloTextHelper.addGoodText(playerObj, PZLinuxText(
            "UI_PZLinux_DepositMoneyOk",
            "Deposit completed: %1",
            PZLinuxFormatCurrency(result.amount or 0)
        ))
        self.amountFieldDeposite:setText("")
        return
    end

        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_DepositMoneyFailed", "Not enough money"))
end

function AtmUI:onWithdrawalSend()
    if not PZLinuxRequireFeature("ATM", self.player or getPlayer()) then return end
    local playerObj = getPlayer()
    local text = self.amountFieldWithdrawal:getText()
    local amount = PZLinuxConfig.Amount(text)
    if amount > PZLinuxConfig.Get("MaxCashTransaction") then
        HaloTextHelper.addBadText(playerObj, getText("UI_PZLinux_CashTransactionLimit")); return
    end
    if amount <= 0 or self.pendingBankAction then
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_InvalidAmount", "Invalid amount"))
        return
    end

    if isClient() and sendClientCommand then
        self.pendingBankAction = true
        self.sendButtonWithdrawal:setEnable(false)
        sendClientCommand(PZLinuxModule, "WithdrawBankCoins", { amount = amount })
        return
    end

    local checkBalance = tonumber(loadAtmBalance()) or 0
    if amount > checkBalance then
        self:onWithdrawalResult({ ok = false, reason = "not_enough_money", balance = checkBalance })
        return
    end

    if not PZLinuxEconomyGiveCoinValue(playerObj, amount) then
        self:onWithdrawalResult({ ok = false, reason = "create_failed", balance = checkBalance })
        return
    end

    local newBalance = checkBalance - amount
    saveAtmBalance(newBalance)
    self:onWithdrawalResult({ ok = true, amount = amount, balance = newBalance })
end

function AtmUI:onDepositeSend()
    if not PZLinuxRequireFeature("ATM", self.player or getPlayer()) then return end
    local playerObj = getPlayer()
    local text = self.amountFieldDeposite:getText()
    local amount = PZLinuxConfig.Amount(text)
    if amount > PZLinuxConfig.Get("MaxCashTransaction") then
        HaloTextHelper.addBadText(playerObj, getText("UI_PZLinux_CashTransactionLimit")); return
    end
    if amount <= 0 or self.pendingBankAction then
        HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_InvalidAmount", "Invalid amount"))
        return
    end

    if isClient() and sendClientCommand then
        self.pendingBankAction = true
        self.sendButtonDeposite:setEnable(false)
        sendClientCommand(PZLinuxModule, "DepositBankCoins", { amount = amount })
        return
    end

    local checkBalance = tonumber(loadAtmBalance()) or 0
    local result = PZLinuxEconomyRemoveCoinValueFromInventory(playerObj, amount)
    if not result or not result.ok or result.removedValue ~= amount then
        self:onDepositResult({ ok = false, reason = "not_enough_money", balance = checkBalance })
        return
    end

    local newBalance = checkBalance + amount
    saveAtmBalance(newBalance)
    self:onDepositResult({ ok = true, amount = amount, balance = newBalance })
end

function AtmMenu_ShowUI(player)
    if not PZLinuxConfig.IsEnabled("ATM") then return end
    local texture = getTexture("media/ui/oldATM.png")
    if not texture then return end

    local realScreenW = getCore():getScreenWidth()
    local realScreenH = getCore():getScreenHeight()

    local maxW = realScreenW * 0.80
    local maxH = realScreenH * 0.80
    local texW = texture:getWidth()
    local texH = texture:getHeight()

    local ratioX, ratioY = maxW / texW, maxH / texH
    local scale  = math.min(ratioX, ratioY)
    local finalW, finalH = math.floor(texW * scale), math.floor(texH * scale)
    local uiX, uiY = (realScreenW - finalW) / 2, (realScreenH - finalH) / 2

    local uiAtm = AtmUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)
    
    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    uiAtm:addChild(centeredImage)
    uiAtm.centeredImage = centeredImage
    uiAtm:initialise()
    uiAtm:addToUIManager()
    PZLinuxAtmInstance = uiAtm

    if isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "RequestBankBalance", {})
    end

    return uiAtm
end

function AtmMenu_AddContext(player, context, worldobjects)
    if not PZLinuxConfig.IsEnabled("ATM") then return end
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoObject") then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() then
                if string.find(sprite:getName(), "location_business_bank_01_67")
                or string.find(sprite:getName(), "location_business_bank_01_66")
                or string.find(sprite:getName(), "location_business_bank_01_65")
                or string.find(sprite:getName(), "location_business_bank_01_64") then
                    local square = obj:getSquare()
                    if PZLinuxConfig.HasPower(square, "ATM") then
                        local x, y, z = square:getX(), square:getY(), square:getZ()
                        context:addOption(PZLinuxText("UI_PZLinux_ATMContext", "ATM"), obj, AtmMenu_OnUse, player, x, y, z, sprite:getName())
                        break
                     else
                        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_NeedPower", "I need power"))
                    end
                end
            end
        end
    end
end

function AtmMenu_OnUse(obj, player, x, y, z, sprite)
    if not PZLinuxConfig.IsEnabled("ATM") then return end
    local playerSquare = getPlayer():getSquare()
    if not (math.abs(playerSquare:getX() - x) + math.abs(playerSquare:getY() - y) <= 1) then
        local freeSquare = getAdjacentFreeSquare(x, y, z, sprite)
        if freeSquare then
            ISTimedActionQueue.add(ISWalkToTimedAction:new(getPlayer(), freeSquare))
        end
    end
    ISTimedActionQueue.add(ISATMAction:new(getPlayer(), obj))
end

Events.OnFillWorldObjectContextMenu.Add(AtmMenu_AddContext)
