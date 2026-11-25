-- StreetMailBox UI - by Raixxar 
-- Updated : 25/01/26

require "PZLinuxDarkWebCatalog"

StreetMailBoxUI = ISPanel:derive("StreetMailBoxUI")

-- CONSTRUCTOR
function StreetMailBoxUI:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0.05, g=0.05, b=0.05, a=0}
    o.borderColor     = {r=0.2, g=0.2, b=0.2, a=0}
    o.width           = width
    o.height          = height
    o.player          = player
    o.isClosing       = false
    o.mode            = "main"
    return o
end

-- INIT
function StreetMailBoxUI:initialise()
    ISPanel.initialise(self)
    self:showLoginMenu()
end

function StreetMailBoxUI:showLoginMenu()
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

    self.titleLabel = ISLabel:new(self.width * 0.225, self.width * 0.43, self.width * 0.1, "", 0.8, 1, 0.8, 1, UIFont.Small, true)
    self.titleLabel:setVisible(true)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    self.closeButton = ISButton:new(self.width * 0.443, self.height * 0.467, self.width * 0.1, self.height * 0.055, PZLinuxText("UI_PZLinux_Leave", "LEAVE"), self, self.onClose)
    self.closeButton.backgroundColor = {r=0.5, g=0.5, b=0.5, a=1}
    self.closeButton:setVisible(true)
    self.closeButton:initialise()
    self.topBar:addChild(self.closeButton)

    local loginButtonName = PZLinuxText("UI_PZLinux_SendTakePackage", "SEND/TAKE THE PACKAGE")
    self.loginButton = ISButton:new(self.width * 0.195, self.height * 0.375, self.width * 0.6, self.height * 0.027, loginButtonName, self, self.onSendPackage)
    self.loginButton:setVisible(true)
    self.loginButton:initialise()
    self.topBar:addChild(self.loginButton)

    self.depositCoinsButton = ISButton:new(self.width * 0.195, self.height * 0.410, self.width * 0.6, self.height * 0.027, PZLinuxText("UI_PZLinux_DepositCoins", "DEPOSIT MONEY"), self, self.onDepositCoins)
    self.depositCoinsButton:setVisible(true)
    self.depositCoinsButton:initialise()
    self.topBar:addChild(self.depositCoinsButton)
end

function StreetMailBoxUI:onDepositCoins()
    if PZLinuxDepositCoinsFromMailbox then
        PZLinuxDepositCoinsFromMailbox()
    elseif sendClientCommand then
        sendClientCommand(PZLinuxModule, "DepositCoins", { amount = "all" })
    end
end

function StreetMailBoxUI:onSendPackage()
    local playerObj = getPlayer()
    local inventory = playerObj:getInventory()
    local items = inventory:getItems()
    local modData = PZLinuxGetModData(playerObj)
    if type(modData.PZLinuxPendingLocalMarketListing) == "table" then
        if isClient() then
            sendClientCommand(PZLinuxModule, "CompleteLocalMarketItemListing", {})
        elseif PZLinuxCompletePendingLocalMarketItemListing then
            PZLinuxCompletePendingLocalMarketItemListing(playerObj)
        end
        return
    end
    local totalCountForContract = false
    local remainingContractItems = math.max(tonumber(modData.PZLinuxContractInfoCount) or 0, 0)
    local contractDelivered = false
    local didMutateContractState = false
    local didMutateRequestState = false
    local suspiciousPackages = PZLinuxCollectInventoryItemsByFullTypes(playerObj, "Base.SuspiciousPackage")
    local hasSuspiciousPackages = #suspiciousPackages > 0

    if PZLinuxHasMailboxContractToDeliver(modData) then
        if isClient() then
            sendClientCommand(PZLinuxModule, "CompleteMailboxContract", {})
            return
        end

        local result = PZLinuxCompleteMailboxContract(playerObj)
        contractDelivered = result and result.ok
        didMutateContractState = result and result.ok
        remainingContractItems = result and result.remainingContractItems or remainingContractItems
    end

    if hasSuspiciousPackages then
        -- B42.20 MP: removal and bank credit are both resolved by the server.
        sendClientCommand(PZLinuxModule, "CashInSuspiciousPackages", {})
    end

    if modData.PZLinuxActiveRequest == 1 and modData.PZLinuxOnItemRequest then
        local requestDeliveryComplete = true
        while #modData.PZLinuxOnItemRequest > 0 do
            local lastBatchWrapper = modData.PZLinuxOnItemRequest[#modData.PZLinuxOnItemRequest]
            local packageContents = PZLinuxBuildPackageContentsFromBatch(lastBatchWrapper)
            local created = PZLinuxCreateOrRequestInventoryPackage(playerObj, "Base.Parcel_Large", {
                contents = packageContents,
            })
            if not created then
                HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_DeliveryFailed", "Delivery failed. Free some inventory space and try again."))
                requestDeliveryComplete = false
                break
            end
            table.remove(modData.PZLinuxOnItemRequest, #modData.PZLinuxOnItemRequest)
            didMutateRequestState = true
        end
        if requestDeliveryComplete then
            modData.PZLinuxActiveRequest = 0
            didMutateRequestState = true
        end
    end

    if modData.PZLinuxOnItemBuyOnDarkWebStatus == 1 and modData.PZLinuxOnItemBuyOnDarkWebStatus then
        if PZLinuxDarkWebHasDirectDelivery(modData) then
            if isClient() then
                sendClientCommand(PZLinuxModule, "ClaimDarkWebDeliveries", {
                    canBeStolen = false,
                })
            elseif PZLinuxDarkWebServerClaimDeliveries then
                PZLinuxDarkWebServerClaimDeliveries(playerObj, {
                    canBeStolen = false,
                })
            end
            return
        end

        local darkWebDeliveryComplete = true
        while #modData.PZLinuxOnItemBuyOnDarkWeb > 0 do
            local lastBatchWrapper = modData.PZLinuxOnItemBuyOnDarkWeb[#modData.PZLinuxOnItemBuyOnDarkWeb]
            local packageContents = PZLinuxBuildPackageContentsFromBatch(lastBatchWrapper)
            local created = PZLinuxCreateOrRequestInventoryPackage(playerObj, "Base.Parcel_Large", {
                contents = packageContents,
            })
            if not created then
                HaloTextHelper.addBadText(playerObj, PZLinuxText("UI_PZLinux_DeliveryFailed", "Delivery failed. Free some inventory space and try again."))
                darkWebDeliveryComplete = false
                break
            end
            table.remove(modData.PZLinuxOnItemBuyOnDarkWeb, #modData.PZLinuxOnItemBuyOnDarkWeb)
            didMutateRequestState = true
        end
        if darkWebDeliveryComplete then
            modData.PZLinuxOnItemBuyOnDarkWebStatus = 0
            didMutateRequestState = true
        end
    end

    if didMutateContractState or didMutateRequestState then
        PZLinuxSyncPlayerModData(playerObj)
    end
end

function StreetMailBoxUI:onClose()
    self.isClosing = true
    self:removeFromUIManager()
    getPlayer():StopAllActionQueue()
end

function StreetMailBoxMenu_ShowUI(player)
    local texture = getTexture("media/ui/streetMailBox.png")
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

    local uiStreetMailBox = StreetMailBoxUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)
    
    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH

    uiStreetMailBox:addChild(centeredImage)
    uiStreetMailBox.centeredImage = centeredImage
    uiStreetMailBox:initialise()
    uiStreetMailBox:addToUIManager()

    return uiStreetMailBox
end

function StreetMailBoxMenu_AddContext(player, context, worldobjects)
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoObject") then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() then
                if string.find(sprite:getName(), "street_decoration_01_9")
                or string.find(sprite:getName(), "street_decoration_01_8")
                or string.find(sprite:getName(), "street_decoration_01_11")
                or string.find(sprite:getName(), "street_decoration_01_10") then
                    local square = obj:getSquare()
                    if square then
                        local x, y, z = square:getX(), square:getY(), square:getZ()
                        context:addOption(PZLinuxText("UI_PZLinux_Mailbox", "MailBox"), obj, StreetMailBoxMenu_OnUse, player, x, y, z, sprite:getName())
                        break
                    end
                end
            end
        end
    end
end

function StreetMailBoxMenu_OnUse(obj, player, x, y, z, sprite)
    local playerSquare = getPlayer():getSquare()
    if not (math.abs(playerSquare:getX() - x) + math.abs(playerSquare:getY() - y) <= 1) then
        local freeSquare = getAdjacentFreeSquare(x, y, z, sprite)
        if freeSquare then
            ISTimedActionQueue.add(ISWalkToTimedAction:new(getPlayer(), freeSquare))
        end
    end
    ISTimedActionQueue.add(ISStreetMailBoxAction:new(getPlayer(), obj))
end

Events.OnFillWorldObjectContextMenu.Add(StreetMailBoxMenu_AddContext)
