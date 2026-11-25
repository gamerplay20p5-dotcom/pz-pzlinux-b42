
require "TimedActions/ISBaseTimedAction"
ISDecapitateAction = ISBaseTimedAction:derive("ISDecapitateAction")

function ISDecapitateAction:isValid()
    return self.body ~= nil and self.body.getSquare ~= nil and self.body:getSquare() ~= nil
end

function ISDecapitateAction:waitToStart()
    if not self.body then return false end
    self.character:faceThisObject(self.body)
	return self.character:shouldBeTurning()
end

function ISDecapitateAction:update()
    if self.body then
        self.character:faceThisObject(self.body)
    end
end

function ISDecapitateAction:start()
    local globalVolume = getCore():getOptionSoundVolume() / 50
    getSoundManager():PlayWorldSound("decapitate", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function ISDecapitateAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISDecapitateAction:perform()
    if not self.body or not self.body:getSquare() then
        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
        ISBaseTimedAction.perform(self)
        return
    end

    local created = PZLinuxCreateOrRequestInventoryPackage(self.character, "Base.Bag_Mail", {
        displayName = "Cut target",
        deliveryType = "manhunt",
        contents = { "Base.CorpseMale" },
    })
    if not created then
        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
        ISBaseTimedAction.perform(self)
        return
    end

    local modData = PZLinuxGetModData(self.character)
    modData.PZLinuxContractManhunt = 3
    self.body:removeFromWorld()
    self.body:removeFromSquare()
    HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_DropBagMailbox", "Drop the bag in a mailbox"))
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.perform(self)
end

function ISDecapitateAction:new(character, body)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.body = body
    o.stopOnWalk = true
    o.maxTime = 350
    return o
end
