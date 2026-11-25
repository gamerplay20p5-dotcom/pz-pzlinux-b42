
require "TimedActions/ISBaseTimedAction"
ISDropTheMailAction = ISBaseTimedAction:derive("ISDropTheMailAction")

function ISDropTheMailAction:isValid()
    return self.item ~= nil and self.item.getSquare ~= nil and self.item:getSquare() ~= nil
end

function ISDropTheMailAction:waitToStart()
    if not self.item then return false end
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISDropTheMailAction:update()
    if self.item then
        self.character:faceThisObject(self.item)
    end
end

function ISDropTheMailAction:start()
    local globalVolume = getCore():getOptionSoundVolume() / 50
    getSoundManager():PlayWorldSound("openCloseCabinet", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISDropTheMailAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISDropTheMailAction:perform()
    if isClient() then
        sendClientCommand(PZLinuxModule, "CompleteMailDelivery", {
            mailId = self.id,
        })
        ISBaseTimedAction.perform(self)
        return
    end

    local result = PZLinuxCompleteMailDelivery(self.character, self.id)
    if not (result and result.ok) then
        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_DeliveryFailed", "Delivery failed. Free some inventory space and try again."))
        ISBaseTimedAction.perform(self)
        return
    end

    HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_MailCompleted", "Mail completed successfully!"))
    HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_MailGift", "You received a gift for your help!"))
    getPlayer():getStats():add(CharacterStat.BOREDOM, -2)
    getPlayer():getStats():add(CharacterStat.UNHAPPINESS, -4)

    local globalVolume = getCore():getOptionSoundVolume() / 50
    getSoundManager():PlayWorldSound("done", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)

    local md, _, mail = PZLinuxGetMailEntry(self.character, self.id)
    if mail then
        if mail.x ~= nil and mail.y ~= nil then
            contractsRemoveDrawOnMap(mail.x, mail.y)
            contractsRemoveDrawOnMap(mail.x + 20, mail.y)
        end
    end
    if md then
        HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_ReputationUp", "Reputation increased to +10"))
        PZLinuxSyncPlayerModData(self.character)
    end
    ISBaseTimedAction.perform(self)
end

function ISDropTheMailAction:new(character, item, id)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.stopOnWalk = true
    o.maxTime = 250
    o.id = id
    return o
end
