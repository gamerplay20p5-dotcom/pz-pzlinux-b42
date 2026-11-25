
require "TimedActions/ISBaseTimedAction"
ISTakeTheCargoAction = ISBaseTimedAction:derive("ISTakeTheCargoAction")

function ISTakeTheCargoAction:isValid()
    return self.item ~= nil and self.item.getSquare ~= nil and self.item:getSquare() ~= nil
end

function ISTakeTheCargoAction:waitToStart()
    if not self.item then return false end
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISTakeTheCargoAction:update()
    if self.item then
        self.character:faceThisObject(self.item)
    end
end

function ISTakeTheCargoAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISTakeTheCargoAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISTakeTheCargoAction:perform()
    local modData = PZLinuxGetModData(self.character)
    modData.PZLinuxContractCargo = 3
    modData.PZLinuxActiveContract = 9
    testHelicopter()
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.perform(self)
end

function ISTakeTheCargoAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.stopOnWalk = true
    o.maxTime = 1000
    return o
end
