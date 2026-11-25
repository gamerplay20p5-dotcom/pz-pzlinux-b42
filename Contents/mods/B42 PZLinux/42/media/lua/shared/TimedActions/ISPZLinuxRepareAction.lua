require "AAA_PZLinuxCompat"
ISPZLinuxRepareAction = ISBaseTimedAction:derive("ISPZLinuxRepareAction")

function ISPZLinuxRepareAction:isValid()
    if not PZLinuxConfig.IsEnabled("Repair") or not self.item or not self.item:getSquare() then return false end
    local items = self.character:getInventory():getItems()
    for j = items:size() - 1, 0, -1 do
        local item = items:get(j)
        if item and item:getFullType() == "Base.ElectronicsScrap" then
            return true
        end
    end
    HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_NeedElectronicParts", "I need electronic parts"))
    return false
end

function ISPZLinuxRepareAction:waitToStart()
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISPZLinuxRepareAction:update()
    self.character:faceThisObject(self.item)
end

function ISPZLinuxRepareAction:start()
    local globalVolume = getCore():getOptionSoundVolume() / 50
    getSoundManager():PlayWorldSound("screw", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISPZLinuxRepareAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISPZLinuxRepareAction:perform()
    if not self:isValid() then ISBaseTimedAction.perform(self); return end
    local items = self.character:getInventory():getItems()
    local consumed = false
    for j = items:size() - 1, 0, -1 do
        local item = items:get(j)
        if item and item:getFullType() == "Base.ElectronicsScrap" then
            consumed = PZLinuxSafeRemoveItem(self.character:getInventory(), item)
            break
        end
    end
    if not consumed then ISBaseTimedAction.perform(self); return end
    self.item:getModData().statusCondition = (tonumber(self.item:getModData().statusCondition) or 0) + ZombRand(5,11) * (self.character:getPerkLevel(Perks.Electricity) + 1) * PZLinuxConfig.Get("RepairMultiplier")
    if self.item:getModData().statusCondition > 100 then self.item:getModData().statusCondition = 100 end
    if self.item.transmitModData then self.item:transmitModData() end
    addXp(self.character, Perks.Electricity, PZLinuxConfig.Get("RepairXP"))
    ISBaseTimedAction.perform(self)
end

function ISPZLinuxRepareAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = PZLinuxConfig.Get("RepairTime")
    return o
end
