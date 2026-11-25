require "AAA_PZLinuxCompat"
ISATMAction = ISBaseTimedAction:derive("ISATMAction")

function ISATMAction:isValid()
    return PZLinuxConfig.IsEnabled("ATM") and self.item ~= nil and self.item:getSquare() ~= nil
        and PZLinuxConfig.HasPower(self.item:getSquare(), "ATM")
end

function ISATMAction:waitToStart()
    if not self.item then return false end
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISATMAction:update()
    if self.item then
        self.character:faceThisObject(self.item)
    end
end

function ISATMAction:start()
    self.ui = AtmMenu_ShowUI(self.character)
    PZLinuxGetModData(self.character).ATMIsPowered = 1
    PZLinuxSyncPlayerModData(self.character)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISATMAction:stop()
    PZLinuxGetModData(self.character).ATMIsPowered = 0
    if self.ui then
        self.ui:removeFromUIManager()
    end
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.stop(self)
end

function ISATMAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISATMAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = -1
    return o
end
