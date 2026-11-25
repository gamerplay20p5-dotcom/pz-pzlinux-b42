require "AAA_PZLinuxCompat"
ISPZLinuxAction = ISBaseTimedAction:derive("ISPZLinuxAction")

function ISPZLinuxAction:isValid()
    return PZLinuxConfig.IsEnabled() and self.item and self.item:getSquare() ~= nil
        and PZLinuxConfig.HasPower(self.item:getSquare(), "Computer")
end

function ISPZLinuxAction:waitToStart()
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISPZLinuxAction:update()
    self.character:faceThisObject(self.item)
    local modData = self.character:getModData()

    if modData.PZLinuxUIOpenMenu == 1 then 
        self.ui = linuxMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 2 then
        self.ui = connectMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 3 then
        self.ui = darkWebMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 4 then
        self.ui = tradingMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 5 then
        self.ui = linuxMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 6 then
        self.ui = hackingMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 7 then
        self.ui = contractsMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 8 then
        self.ui = requestMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 9 then
        self.ui = bettingMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 10 then
        self.ui = mailMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 11 then
        if localMarketMenu_ShowUI then
            self.ui = localMarketMenu_ShowUI(self.character)
        else
            self.ui = linuxMenu_ShowUI(self.character)
        end
        modData.PZLinuxUIOpenMenu = 0
    end

    if modData.PZLinuxUIOpenMenu == 20 then
        self.ui = conditionMenu_ShowUI(self.character)
        modData.PZLinuxUIOpenMenu = 0
    end
end

function ISPZLinuxAction:start()
    self.item:getModData().statusCondition = math.max(0, (tonumber(self.item:getModData().statusCondition) or 100) - (ZombRand(1,5)/2) * PZLinuxConfig.Get("ComputerWearMultiplier"))
    if self.item.transmitModData then self.item:transmitModData() end
    local modData = PZLinuxGetModData(self.character)
    modData.PZLinuxUIOpenMenu = 0
    modData.PZLinuxIsPowered = 1
    PZLinuxSyncPlayerModData(self.character)
    self.ui = linuxMenu_ShowUI(self.character)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISPZLinuxAction:stop()
    if self.ui then
        self.ui:removeFromUIManager()
    end
    PZLinuxGetModData(self.character).PZLinuxIsPowered = 0
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.stop(self)
end

function ISPZLinuxAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISPZLinuxAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = -1
    return o
end
