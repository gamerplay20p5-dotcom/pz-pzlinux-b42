
require "TimedActions/ISBaseTimedAction"
ISProtectBuildingAction = ISBaseTimedAction:derive("ISProtectBuildingAction")

function ISProtectBuildingAction:isValid()
    return self.item ~= nil and self.item.getSquare ~= nil and self.item:getSquare() ~= nil
end

function ISProtectBuildingAction:waitToStart()
    if not self.item then return false end
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISProtectBuildingAction:update()
    if self.item then
        self.character:faceThisObject(self.item)
    end
end

function ISProtectBuildingAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISProtectBuildingAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISProtectBuildingAction:perform()
    local modData = PZLinuxGetModData(self.character)
    modData.PZLinuxContractProtect = 3
    modData.PZLinuxActiveContract = 9
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.perform(self)
end

function ISProtectBuildingAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.stopOnWalk = true
    o.maxTime = 1000
    return o
end
