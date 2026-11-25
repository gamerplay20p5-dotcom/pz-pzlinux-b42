
require "TimedActions/ISBaseTimedAction"
ISBloodAction = ISBaseTimedAction:derive("ISBloodAction")

function ISBloodAction:isValid()
    return self.body ~= nil and self.body.getSquare ~= nil and self.body:getSquare() ~= nil
end

function ISBloodAction:waitToStart()
    if not self.body then return false end
    self.character:faceThisObject(self.body)
	return self.character:shouldBeTurning()
end

function ISBloodAction:update()
    if self.body then
        self.character:faceThisObject(self.body)
    end
end

function ISBloodAction:start()
    local globalVolume = getCore():getOptionSoundVolume() / 50
    getSoundManager():PlayWorldSound("blood", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function ISBloodAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISBloodAction:perform()
    local created = PZLinuxCreateOrRequestInventoryPackage(self.character, "Base.EmptyJar", {
        displayName = "Blood for contract",
        deliveryType = "blood",
    })
    if not created then
        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
        ISBaseTimedAction.perform(self)
        return
    end

    local modData = PZLinuxGetModData(self.character)
    modData.PZLinuxContractBlood = 3
    HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_DropBloodJar", "Drop the blood jar in a mailbox"))
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.perform(self)
end

function ISBloodAction:new(character, body)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.body = body
    o.stopOnWalk = true
    o.maxTime = 350
    return o
end
