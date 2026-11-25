ISMailBoxAction = ISBaseTimedAction:derive("ISMailBoxAction")

function ISMailBoxAction:isValid()
    return self.item ~= nil and self.item.getSquare ~= nil and self.item:getSquare() ~= nil
end

function ISMailBoxAction:waitToStart()
    if not self.item then return false end
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISMailBoxAction:update()
    if self.item then
        self.character:faceThisObject(self.item)
    end
end

function ISMailBoxAction:start()
    self.ui = MailBoxMenu_ShowUI(self.character)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISMailBoxAction:stop()
    if self.ui then
        self.ui:removeFromUIManager()
    end
    ISBaseTimedAction.stop(self)
end

function ISMailBoxAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISMailBoxAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = -1
    return o
end
