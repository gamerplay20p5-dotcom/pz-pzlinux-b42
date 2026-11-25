
require "TimedActions/ISBaseTimedAction"
ISCaptureAction = ISBaseTimedAction:derive("ISCaptureAction")

function ISCaptureAction:isValid()
    return self.zombie ~= nil and self.zombie.getSquare ~= nil and self.zombie:getSquare() ~= nil
end

function ISCaptureAction:waitToStart()
    if not self.zombie then return false end
    self.character:faceThisObject(self.zombie)
	return self.character:shouldBeTurning()
end

function ISCaptureAction:update()
    if self.zombie then
        self.character:faceThisObject(self.zombie)
    end
end

function ISCaptureAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "medium")
    self.character:reportEvent("EventLootItem")
end

function ISCaptureAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISCaptureAction:perform()
    if not self.zombie or not self.zombie:getSquare() then
        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
        ISBaseTimedAction.perform(self)
        return
    end

    local created = PZLinuxCreateOrRequestInventoryPackage(self.character, "Base.Bag_Mail", {
        displayName = "Zombie captured alive",
        deliveryType = "capture",
        contents = { "Base.CorpseMale" },
    })
    if not created then
        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
        ISBaseTimedAction.perform(self)
        return
    end

    local modData = PZLinuxGetModData(self.character)
    modData.PZLinuxContractCapture = 3
    self.zombie:removeFromWorld()
    self.zombie:removeFromSquare()
    HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_DropBagMailbox", "Drop the bag in a mailbox"))
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.perform(self)
end

function ISCaptureAction:new(character, zombie)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.zombie = zombie
    o.stopOnWalk = true
    o.maxTime = 100
    return o
end
