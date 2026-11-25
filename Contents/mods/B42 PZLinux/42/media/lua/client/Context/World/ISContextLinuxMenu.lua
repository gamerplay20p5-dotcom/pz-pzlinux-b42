linuxUI = ISPanel:derive("linuxUI")

require "PZLinuxTradingCore"
require "PZLinuxEconomy"
require "PZLinuxLocalMarket"
require "Context/World/Features/PZLinuxUtils"

local STAY_CONNECTED_TIME = 0
local CONNECTED_TO_INTERNET_TIME = 0
local PZLinuxVersion = "v." .. PZLinuxConfig.Version

local function styleLinuxMenuButton(button)
    if not button then
        return
    end
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0.62 }
    button.borderColor = { r = 0, g = 0.48, b = 0, a = 0.78 }
    button.textColor = { r = 0, g = 1, b = 0, a = 1 }
end

local function addLinuxBox(parent, x, y, w, h)
    local panel = ISPanel:new(x, y, w, h)
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.48 }
    panel.borderColor = { r = 0, g = 0.42, b = 0, a = 0.72 }
    panel:initialise()
    parent:addChild(panel)
    return panel
end

local function PZLinuxLinuxMenuRequestTradingData()
    PZLinuxRequestTradingGlobalModData()
    if PZLinuxSendClientCommandThrottled then
        PZLinuxSendClientCommandThrottled(PZLinuxModule, "RequestEconomyDemand", {}, 10000)
    elseif isClient() and sendClientCommand then
        sendClientCommand(PZLinuxModule, "RequestEconomyDemand", {})
    end

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

-- CONSTRUCTOR
function linuxUI:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.width = width
    o.height = height
    o.player = player
    o.isClosing = false
    o.isConnected = false
    o.isDragging = false
    return o
end

-- INIT
function linuxUI:initialise()
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

    self.closeButton = ISButton:new(0, 0, self.width * 0.045, self.height * 0.027, "x", self, self.onClose)
    self.closeButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.closeButton.borderColor = {r=0, g=1, b=0, a=0.5}
    self.closeButton.textColor = {r=0, g=1, b=0, a=1}
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.closeButton:setAnchorRight(true)
    self.topBar:addChild(self.closeButton)

    local safe = PZLinuxGetTerminalSafeArea(self.width, self.height)

    self.bootOutput = ISRichTextPanel:new(safe.x, safe.y + (safe.rowH * 2), safe.w, safe.h - (safe.rowH * 2))
    self.bootOutput.backgroundColor = {r=0, g=0, b=0, a=0}
    self.bootOutput.borderColor = {r=0, g=0, b=0, a=0}
    self.bootOutput.autosetheight = false
    self.bootOutput:setVisible(true)
    self.bootOutput:initialise()
    self.topBar:addChild(self.bootOutput)

    -- PROMPT CLI
    self.promptLabel = ISLabel:new(self.width * 0.20, self.height * 0.195, self.height * 0.025, PZLinuxText("UI_PZLinux_WelcomeVersion", "Welcome to PZLinux %s.", PZLinuxVersion), 0, 1, 0, 1, UIFont.Small, true)
    self.promptLabel:setVisible(false)
    self.promptLabel:initialise()
    self.topBar:addChild(self.promptLabel)

    self.helpLabel = ISLabel:new(self.width * 0.20, self.height * 0.40, self.height * 0.025, "", 0, 1, 0, 1, UIFont.Small, true)
    self.helpLabel:setVisible(false)
    self.helpLabel:initialise()
    self.topBar:addChild(self.helpLabel)

    self.notConnectButton = ISButton:new(self.width * 0.20, self.height * 0.17, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_NotConnected", "NOT CONNECTED"), self, self.onStop)
    self.notConnectButton.backgroundColor = {r=0.5, g=0, b=0, a=0.5}
    self.notConnectButton.borderColor = {r=0, g=0, b=0, a=1}
    self.notConnectButton:setVisible(true)
    self.notConnectButton:initialise()
    self.topBar:addChild(self.notConnectButton)

    self.connectButton = ISButton:new(self.width * 0.20, self.height * 0.17, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_Connected", "CONNECTED"), self, self.onStop)
    self.connectButton.backgroundColor = {r=0, g=0.5, b=0, a=0.5}
    self.connectButton.borderColor = {r=0, g=0, b=0, a=1}
    self.connectButton:setVisible(false)
    self.connectButton:initialise()
    self.topBar:addChild(self.connectButton)

    self.internetButton = ISButton:new(self.width * 0.20, self.height * 0.23, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_Connect", "CONNECT"), self, self.onInternet)
    self.internetButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.internetButton.textColor = {r=0, g=1, b=0, a=1}
    self.internetButton.borderColor = {r=0, g=0, b=0, a=0}
    self.internetButton:setVisible(false)
    self.internetButton:initialise()
    self.topBar:addChild(self.internetButton)

    self.mailLabel = ISLabel:new(self.width * 0.71, self.height * 0.155, self.height * 0.05, "[@]", 0, 1, 0, 1, UIFont.Small, true)
    self.mailLabel:setVisible(false)
    self.mailLabel:initialise()
    self.topBar:addChild(self.mailLabel)

    local md = PZLinuxGetModData()
    md.pzlinux.mails.inbox = md.pzlinux.mails.inbox or {}
    for _, mail in ipairs(md.pzlinux.mails.inbox) do
        if mail.read == false then
            self.mailLabel:setVisible(true)
        end
    end

    self.darkWebButton = ISButton:new(self.width * 0.20, self.height * 0.26, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_DarkWeb", "DARK WEB"), self, self.onDarkWeb)
    self.darkWebButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.darkWebButton.textColor = {r=0, g=1, b=0, a=1}
    self.darkWebButton.borderColor = {r=0, g=0, b=0, a=0}
    self.darkWebButton:setVisible(false)
    self.darkWebButton:initialise()
    self.topBar:addChild(self.darkWebButton)

    self.tradingButton = ISButton:new(self.width * 0.20, self.height * 0.29, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_Trading", "TRADING"), self, self.onTrading)
    self.tradingButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.tradingButton.textColor = {r=0, g=1, b=0, a=1}
    self.tradingButton.borderColor = {r=0, g=0, b=0, a=0}
    self.tradingButton:setVisible(false)
    self.tradingButton:initialise()
    self.topBar:addChild(self.tradingButton)

    self.localMarketButton = ISButton:new(self.width * 0.20, self.height * 0.35, self.width * 0.07, self.height * 0.025, PZLinuxText("UI_PZLinux_LocalMarket", "LOCAL MARKET"), self, self.onLocalMarket)
    self.localMarketButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.localMarketButton.textColor = {r=0, g=1, b=0, a=1}
    self.localMarketButton.borderColor = {r=0, g=0, b=0, a=0}
    self.localMarketButton:setVisible(false)
    self.localMarketButton:initialise()
    self.topBar:addChild(self.localMarketButton)

    self.hackingIdButton = ISButton:new(self.width * 0.20, self.height * 0.38, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_HackID", "HACK AN ID CARD"), self, self.onHackingId)
    self.hackingIdButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.hackingIdButton.textColor = {r=0, g=1, b=0, a=1}
    self.hackingIdButton.borderColor = {r=0, g=0, b=0, a=0}
    self.hackingIdButton:setVisible(false)
    self.hackingIdButton:initialise()
    self.topBar:addChild(self.hackingIdButton)

    self.contractsButton = ISButton:new(self.width * 0.20, self.height * 0.41, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_Contracts", "CONTRACTS"), self, self.onContracts)
    self.contractsButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.contractsButton.textColor = {r=0, g=1, b=0, a=1}
    self.contractsButton.borderColor = {r=0, g=0, b=0, a=0}
    self.contractsButton:setVisible(false)
    self.contractsButton:initialise()
    self.topBar:addChild(self.contractsButton)

    self.requestButton = ISButton:new(self.width * 0.20, self.height * 0.44, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_SendRequest", "SEND A REQUEST"), self, self.onRequest)
    self.requestButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.requestButton.textColor = {r=0, g=1, b=0, a=1}
    self.requestButton.borderColor = {r=0, g=0, b=0, a=0}
    self.requestButton:setVisible(false)
    self.requestButton:initialise()
    self.topBar:addChild(self.requestButton)

    self.bettingButton = ISButton:new(self.width * 0.20, self.height * 0.47, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_OnlineBetting", "ONLINE BETTING"), self, self.onBetting)
    self.bettingButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.bettingButton.textColor = {r=0, g=1, b=0, a=1}
    self.bettingButton.borderColor = {r=0, g=0, b=0, a=0}
    self.bettingButton:setVisible(false)
    self.bettingButton:initialise()
    self.topBar:addChild(self.bettingButton)

    self.mailButton = ISButton:new(self.width * 0.20, self.height * 0.50, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_Mail", "MAIL"), self, self.onMail)
    self.mailButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.mailButton.textColor = {r=0, g=1, b=0, a=1}
    self.mailButton.borderColor = {r=0, g=0, b=0, a=0}
    self.mailButton:setVisible(false)
    self.mailButton:initialise()
    self.topBar:addChild(self.mailButton)

    self.conditionButton = ISButton:new(self.width * 0.20, self.height * 0.53, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_CheckCondition", "CHECK CONDITION"), self, self.onCondition)
    self.conditionButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.conditionButton.textColor = {r=0, g=1, b=0, a=1}
    self.conditionButton.borderColor = {r=0, g=0, b=0, a=0}
    self.conditionButton:setVisible(false)
    self.conditionButton:initialise()
    self.topBar:addChild(self.conditionButton)

    self.helpMainButton = ISButton:new(self.width * 0.20, self.height * 0.38, self.width * 0.05, self.height * 0.025, PZLinuxText("UI_PZLinux_Help", "HELP"), self, self.onHelpMain)
    self.helpMainButton.backgroundColor = {r=0, g=0, b=0, a=0.5}
    self.helpMainButton.textColor = {r=0, g=1, b=0, a=1}
    self.helpMainButton.borderColor = {r=0, g=0, b=0, a=0}
    self.helpMainButton:setVisible(false)
    self.helpMainButton:initialise()
    self.topBar:addChild(self.helpMainButton)

    local screenX = safe.x
    local screenY = safe.y
    local screenW = safe.w
    local primaryGap = safe.gap
    local columnGap = math.max(28, math.floor(self.width * 0.055))
    local primaryH = safe.buttonH
    local primaryW = math.floor((screenW - columnGap) * 0.48)
    local secondaryW = screenW - primaryW - columnGap
    local primaryX = screenX
    local secondaryX = primaryX + primaryW + columnGap
    local statusY = screenY
    local promptY = statusY + primaryH + 3
    local connectY = promptY + primaryH + primaryGap
    local primaryY = connectY + primaryH + (primaryGap * 2)
    local statusW = math.max(92, math.floor(primaryW * 0.62))
    local iconW = math.max(24, math.floor(self.width * 0.032))
    local iconH = math.max(22, math.floor(self.height * 0.028))

    local function layoutMenuButton(button, x, y, w, h, title)
        if not button then
            return
        end
        button:setX(x)
        button:setY(y)
        button:setWidth(w)
        button:setHeight(h)
        button:setTitle(title)
        styleLinuxMenuButton(button)
    end

    local function layoutTopButton(button, index, title)
        if not button then
            return
        end
        local gap = math.max(4, math.floor(self.width * 0.006))
        local x = screenX + screenW - ((iconW + gap) * index)
        button:setX(x)
        button:setY(statusY)
        button:setWidth(iconW)
        button:setHeight(iconH)
        button:setTitle(title)
        styleLinuxMenuButton(button)
    end

    layoutTopButton(self.closeButton, 1, "x")
    layoutMenuButton(self.notConnectButton, primaryX, statusY, statusW, primaryH, PZLinuxText("UI_PZLinux_NotConnected", "NOT CONNECTED"))
    layoutMenuButton(self.connectButton, primaryX, statusY, statusW, primaryH, PZLinuxText("UI_PZLinux_Connected", "CONNECTED"))
    layoutMenuButton(self.internetButton, primaryX, connectY, primaryW, primaryH, PZLinuxText("UI_PZLinux_Connect", "CONNECT"))
    if self.promptLabel then
        self.promptLabel:setX(primaryX)
        self.promptLabel:setY(promptY)
        self.promptLabel:setHeight(primaryH)
    end
    if self.mailLabel then
        self.mailLabel:setX(screenX + screenW - iconW - math.max(36, primaryH))
        self.mailLabel:setY(statusY)
        self.mailLabel:setHeight(primaryH)
    end

    layoutMenuButton(self.tradingButton, primaryX, primaryY, primaryW, primaryH, PZLinuxText("UI_PZLinux_Bank", "BANK"))
    layoutMenuButton(self.localMarketButton, primaryX, primaryY + (primaryH + primaryGap), primaryW, primaryH, PZLinuxText("UI_PZLinux_LocalMarket", "LOCAL MARKET"))
    layoutMenuButton(self.darkWebButton, primaryX, primaryY + ((primaryH + primaryGap) * 2), primaryW, primaryH, PZLinuxText("UI_PZLinux_DarkWeb", "DARK WEB"))
    layoutMenuButton(self.mailButton, primaryX, primaryY + ((primaryH + primaryGap) * 3), primaryW, primaryH, PZLinuxText("UI_PZLinux_Mail", "MAIL"))
    layoutMenuButton(self.helpMainButton, primaryX, primaryY + ((primaryH + primaryGap) * 4), primaryW, primaryH, PZLinuxText("UI_PZLinux_Help", "HELP"))

    layoutMenuButton(self.hackingIdButton, secondaryX, primaryY, secondaryW, primaryH, PZLinuxText("UI_PZLinux_HackID", "HACK AN ID CARD"))
    layoutMenuButton(self.contractsButton, secondaryX, primaryY + (primaryH + primaryGap), secondaryW, primaryH, PZLinuxText("UI_PZLinux_Contracts", "CONTRACTS"))
    layoutMenuButton(self.requestButton, secondaryX, primaryY + ((primaryH + primaryGap) * 2), secondaryW, primaryH, PZLinuxText("UI_PZLinux_SendRequest", "SEND A REQUEST"))
    layoutMenuButton(self.bettingButton, secondaryX, primaryY + ((primaryH + primaryGap) * 3), secondaryW, primaryH, PZLinuxText("UI_PZLinux_OnlineBetting", "ONLINE BETTING"))
    layoutMenuButton(self.conditionButton, secondaryX, primaryY + ((primaryH + primaryGap) * 4), secondaryW, primaryH, PZLinuxText("UI_PZLinux_CheckCondition", "CHECK CONDITION"))

    local helpX = primaryX
    local helpY = primaryY + ((primaryH + primaryGap) * 5) + primaryGap
    local helpW = (secondaryX + secondaryW) - primaryX
    local helpH = math.min(self.height * 0.115, safe.bottom - helpY)
    self.helpBox = addLinuxBox(self.topBar, helpX, helpY, helpW, helpH)
    self.helpBox:setVisible(false)

    self.helpRichText = ISRichTextPanel:new(helpX + primaryGap, helpY + primaryGap, helpW - (primaryGap * 2), helpH - (primaryGap * 2))
    self.helpRichText.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.helpRichText.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.helpRichText.autosetheight = false
    self.helpRichText.text = ""
    self.helpRichText:setVisible(false)
    self.helpRichText:initialise()
    self.helpRichText:instantiate()
    self.topBar:addChild(self.helpRichText)
end

function linuxUI:setMainHelpVisible(visible, text)
    if self.helpLabel then
        self.helpLabel:setVisible(false)
    end
    if self.helpBox then
        self.helpBox:setVisible(visible and true or false)
    end
    if self.helpRichText then
        if visible then
            self.helpRichText.text = "<GREEN>" .. tostring(text or "") .. "</GREEN>"
            self.helpRichText:paginate()
        end
        self.helpRichText:setVisible(visible and true or false)
    end
end

-- CLOSE
function linuxUI:onCloseX(button)
    self.isClosing = true
    getPlayer():StopAllActionQueue()
end

function linuxUI:onClose(button)
    self.isClosing = true
    self:removeFromUIManager()
end

function linuxUI:onBoot()
    local player = getPlayer()
    local globalVolume = getCore():getOptionSoundVolume() / 50

    if getPlayer():getModData().PZLinuxComputerCondition <= 25 then
        getSoundManager():PlayWorldSound("computerBootLow", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    elseif getPlayer():getModData().PZLinuxComputerCondition <= 50 then
        getSoundManager():PlayWorldSound("computerBootMedium", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    else
        getSoundManager():PlayWorldSound("computerBoot", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    end

    self.bootMessages = PZLinuxTextLines("UI_PZLinux_MainBootMessages", {
        "<RGB:0,1,0>PZLinux version " .. PZLinuxVersion .. " (POSIX compliant)",
        "Copyright (c) 1991 The PZLinux Project",
        "The Regents of the University of Louisville, Kentucky, USA",
        "Booting PZLinux...",
        "Loading kernel version 1.0.0 (Wed Feb 6 12:00:00 UTC 1991)",
        "Memory: 4096k/4096k available (512k kernel, 256k reserved, 1024k shared)",
        "Kernel command line: root=/dev/hda1 ro",
        "Checking 386/387 coupling... OK",
        "Calibrating delay loop... 5.27 BogoMIPS",
        "Checking BIOS EDD... OK",
        "Detecting hardware...",
        " ide0: BM-DMA at 0x1f0-0x1f7,0x3f6 on IRQ 14",
        " ide1: BM-DMA at 0x170-0x177,0x376 on IRQ 15",
        " hda: CONNER CP-3204F, 420MB, CHS=683/16/38, UDMA(16)",
        " hdb: MAXTOR 7213AT, 213MB, CHS=683/16/38, UDMA(16)",
        " hdc: CD-ROM 2X, ATAPI CD/DVD-ROM drive",
        " Floppy drive(s): fd0 is 1.44M",
        " FDC 0 is a post-1991 82077",
        "Partition check:",
        " hda: hda1 hda2",
        " hdb: hdb1",
        "RAMDISK: Compressed image found at block 0",
        "Mounting root filesystem...",
        "EXT2-fs: mounted filesystem with ordered data mode.",
        "VFS: Mounted root (ext2 filesystem) readonly on device 03:01.",
        "Freeing unused kernel memory: 128k freed",
        "INIT: version 1.0 booting",
        "Setting hostname to pzlinux.local",
        "Checking filesystems",
        "/dev/hda1: clean, 3021/32768 files, 10540/131072 blocks",
        "/dev/hdb1: clean, 2498/16384 files, 7340/65536 blocks",
        "Mounting local filesystems... done",
        "Initializing random number generator... done",
        "Starting system log daemon: syslogd, klogd",
        "Starting network services: inetd, named",
        "Starting virtual terminals: tty1 tty2 tty3 tty4",
        "PZLinux  " .. PZLinuxVersion .. " (tty1)</RGB>"
    }, PZLinuxVersion)

    self.terminalCoroutine = coroutine.create(function()
        local elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
        local initialDelay = elapsed + 1
        while elapsed < initialDelay do
            if self.isClosing then return end
            coroutine.yield()
            elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
        end

        for _, line in ipairs(self.bootMessages) do
            if self.isClosing then return end

            self.bootOutput.text = self.bootOutput.text .. "\n" .. line
            self.bootOutput:paginate()

            local maxYScroll = self.bootOutput:getScrollHeight() - self.bootOutput:getHeight()
            if maxYScroll > 0 then
                self.bootOutput:setYScroll(-maxYScroll)
            end

            local lineDelay = math.ceil(getGameTime():getWorldAgeHours() * 3600) + ZombRand(1, 10)
            while elapsed < lineDelay do
                coroutine.yield()
                elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
            end
        end
    end)

    self.updateCoroutineFunc = function()
        if coroutine.status(self.terminalCoroutine) ~= "dead" then
            coroutine.resume(self.terminalCoroutine)
        else
            Events.OnTick.Remove(self.updateCoroutineFunc)
            self.updateCoroutineFunc = nil
            self.terminalCoroutine = nil
            self:onPrompt()
        end
    end
    Events.OnTick.Add(self.updateCoroutineFunc)
end

function linuxUI:onPrompt()
    self.bootOutput:setVisible(false)
    self.promptLabel:setVisible(true)
    self:setMainHelpVisible(false)
    self.internetButton:setVisible(self.isConnected ~= true)
    self.darkWebButton:setVisible(true)
    self.tradingButton:setVisible(true)
    self.localMarketButton:setVisible(true)
    if self.helpMainButton then
        self.helpMainButton:setVisible(true)
    end
    self.hackingIdButton:setVisible(true)
    self.contractsButton:setVisible(true)
    self.requestButton:setVisible(true)
    self.bettingButton:setVisible(true)
    self.mailButton:setVisible(true)
    self.conditionButton:setVisible(true)

    for field, feature in pairs({ darkWebButton = "DarkWeb", tradingButton = "Trading", localMarketButton = "LocalMarket",
        hackingIdButton = "Hacking", contractsButton = "Contracts", requestButton = "Requests", bettingButton = "Betting",
        mailButton = "Mail", conditionButton = "Repair" }) do
        if self[field] then self[field]:setEnable(PZLinuxConfig.IsEnabled(feature)) end
    end

    if PZLinuxSendClientCommandThrottled then
        PZLinuxSendClientCommandThrottled(PZLinuxModule, "RequestLocalMarket", {}, 5000)
    elseif sendClientCommand then
        sendClientCommand(PZLinuxModule, "RequestLocalMarket", {})
    end
end

function linuxUI:onInternet()
    if self.isConnected == false then
        CONNECTED_TO_INTERNET_TIME = math.ceil(getGameTime():getWorldAgeHours())
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()
        self.isConnected = true
        
        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 2
        PZLinuxLinuxMenuRequestTradingData()
    end
end

function linuxUI:onDarkWeb()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()

        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 3
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onTrading()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()
        
        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 4
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onWallet()
    self.promptLabel:setVisible(false)
    self:setMainHelpVisible(true, PZLinuxText("UI_PZLinux_MainHelp", "Bank, Local Market and Dark Web are the main PZLinux apps. Secondary tools remain listed on the right."))
end

function linuxUI:onLocalMarket()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()

        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 11
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onHackingId()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()
        
        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 6
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onContracts()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()
        
        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 7
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onRequest()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()
        
        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 8
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onBetting()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()
        
        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 9
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onMail()
    if self.isConnected == true then
        self.promptLabel:setVisible(false)
        self:setMainHelpVisible(false)
        self:onClose()
        
        local modData = getPlayer():getModData()
        modData.PZLinuxUIOpenMenu = 10
    else
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_ConnectFirst", "You need to connect first. Click on 'CONNECT'"))
    end
end

function linuxUI:onCondition()
    self.promptLabel:setVisible(false)
    self:setMainHelpVisible(false)
    self:onClose()
    
    local modData = PZLinuxGetModData()
    modData.PZLinuxUIOpenMenu = 20
end

function linuxUI:onHelpMain()
    self.promptLabel:setVisible(false)
    self:setMainHelpVisible(true, PZLinuxText("UI_PZLinux_MainHelp", "Bank, Local Market and Dark Web are the main PZLinux apps. Secondary tools remain listed on the right."))
end

function linuxUI:onConnect()
    self.isConnected = true
    self.notConnectButton:setVisible(false)
    self.connectButton:setVisible(true)
    self.internetButton:setVisible(false)
    if self.promptLabel then
        self.promptLabel:setVisible(true)
        self.promptLabel:setName(PZLinuxText("UI_PZLinux_WelcomeVersion", "Welcome to PZLinux %s.", PZLinuxVersion))
    end
end

-- UI
function linuxMenu_ShowUI(player)
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

    local ui = linuxUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)
    
    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    ui:addChild(centeredImage)
    ui.centeredImage = centeredImage
    ui:initialise()
    ui:addToUIManager()

    local getHourTime = math.ceil(getGameTime():getWorldAgeHours())
    if getHourTime < PZLinuxConfig.Get("ConnectionHours") then
        getHourTime = PZLinuxConfig.Get("ConnectionHours")
    end

    if getHourTime < CONNECTED_TO_INTERNET_TIME + PZLinuxConfig.Get("ConnectionHours") then
        ui.isConnected = true
        ui:onConnect()
    end

    if getHourTime < STAY_CONNECTED_TIME + PZLinuxConfig.Get("ConnectionHours") then
        ui:onPrompt()
    else
        ui:onBoot()
        STAY_CONNECTED_TIME = getHourTime
    end

    return ui
end

-- CONTEXT MENU
function linuxMenu_AddContext(player, context, worldobjects)
    if not PZLinuxConfig.IsEnabled() then return end
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoObject") then
            local sprite = obj:getSprite()
            local spriteName = sprite and sprite:getName() or nil
            if spriteName then
                if spriteName == "appliances_com_01_75"
                or spriteName == "appliances_com_01_74"
                or spriteName == "appliances_com_01_73"
                or spriteName == "appliances_com_01_72" then
                    local square = obj:getSquare()
                    if PZLinuxConfig.HasPower(square, "Computer") then
                        local x, y, z = square:getX(), square:getY(), square:getZ()

                        if not obj:getModData().statusCondition then
                            obj:getModData().statusCondition = ZombRand(1, 100)
                        end
                        if obj:getModData().statusCondition < 15 and PZLinuxConfig.IsEnabled("Repair") then
                            context:addOption(PZLinuxText("UI_PZLinux_FixComputer", "Fix the computer"), obj, linuxMenu_OnRepare, player, x, y, z, spriteName)
                        end

                        if obj:getModData().statusCondition > 0 then
                            context:addOption(PZLinuxText("UI_PZLinux_ContextMenu", "PZLinux"), obj, linuxMenu_OnUse, player, x, y, z, spriteName)
                        end
                        break
                    end
                end
            end
        end
    end
end

function linuxMenu_OnUse(obj, player, x, y, z, sprite, square)
    if not PZLinuxConfig.IsEnabled() then return end
    local playerSquare = getPlayer():getSquare()
    if not (math.abs(playerSquare:getX() - x) + math.abs(playerSquare:getY() - y) <= 1) then
        local freeSquare = getAdjacentFreeSquare(x, y, z, sprite)
        if freeSquare then
            ISTimedActionQueue.add(ISWalkToTimedAction:new(getPlayer(), freeSquare))
        end
    end
    PZLinuxGetModData().PZLinuxComputerCondition = obj:getModData().statusCondition
    ISTimedActionQueue.add(ISPZLinuxAction:new(getPlayer(), obj))
end

function linuxMenu_OnRepare(obj, player, x, y, z, sprite, square)
    if not PZLinuxRequireFeature("Repair", getSpecificPlayer(player)) then return end
    local playerSquare = getPlayer():getSquare()
    if not (math.abs(playerSquare:getX() - x) + math.abs(playerSquare:getY() - y) <= 1) then
        local freeSquare = getAdjacentFreeSquare(x, y, z, sprite)
        if freeSquare then
            ISTimedActionQueue.add(ISWalkToTimedAction:new(getPlayer(), freeSquare))
        end
    end
    ISTimedActionQueue.add(ISPZLinuxRepareAction:new(getPlayer(), obj))
end

Events.OnFillWorldObjectContextMenu.Add(linuxMenu_AddContext)
