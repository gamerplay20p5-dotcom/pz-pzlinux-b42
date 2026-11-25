ISStreetMailBoxAction = ISBaseTimedAction:derive("ISStreetMailBoxAction")

function ISStreetMailBoxAction:isValid()
    return self.item ~= nil and self.item.getSquare ~= nil and self.item:getSquare() ~= nil
end

function ISStreetMailBoxAction:waitToStart()
    if not self.item then return false end
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISStreetMailBoxAction:update()
    if self.item then
        self.character:faceThisObject(self.item)
    end
end

function ISStreetMailBoxAction:start()
    self.ui = StreetMailBoxMenu_ShowUI(self.character)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISStreetMailBoxAction:stop()
    if self.ui then
        self.ui:removeFromUIManager()
    end
    ISBaseTimedAction.stop(self)
end

function ISStreetMailBoxAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISStreetMailBoxAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = -1
    return o
end
