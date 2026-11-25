
require "TimedActions/ISBaseTimedAction"
ISTakeThePackageAction = ISBaseTimedAction:derive("ISTakeThePackageAction")

function ISTakeThePackageAction:isValid()
    return self.item ~= nil and self.item.getSquare ~= nil and self.item:getSquare() ~= nil
end

function ISTakeThePackageAction:waitToStart()
    if not self.item then return false end
    self.character:faceThisObject(self.item)
	return self.character:shouldBeTurning()
end

function ISTakeThePackageAction:update()
    if self.item then
        self.character:faceThisObject(self.item)
    end
end

function ISTakeThePackageAction:start()
    local globalVolume = getCore():getOptionSoundVolume() / 50
    getSoundManager():PlayWorldSound("openCloseCabinet", false, getPlayer():getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Medium")
    self.character:reportEvent("EventLootItem")
end

function ISTakeThePackageAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISTakeThePackageAction:perform()
    local contents = {}
    local bonusRand = ZombRand(1,6)
    if bonusRand == 1 then
        local bonusTotal = ZombRand(1,2000)
        table.insert(contents, "Base.Note")
        table.insert(contents, "Base.Revolver")
        local coinStacks = PZLinuxEconomyBuildCoinStacks and PZLinuxEconomyBuildCoinStacks(bonusTotal) or {
            { fullType = "Base.Money", count = bonusTotal },
        }
        for _, stack in ipairs(coinStacks) do
            table.insert(contents, stack)
        end
    else
        table.insert(contents, "Base.Note")
    end

    if bonusRand == 2 then
        table.insert(contents, "Base.Revolver")
    end

    local created = PZLinuxCreateOrRequestInventoryPackage(self.character, "Base.Bag_ProtectiveCaseSmall", {
        displayName = "Contract case",
        deliveryType = "pickup",
        contents = contents,
    })
    if not created then
        HaloTextHelper.addBadText(getPlayer(), PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
        ISBaseTimedAction.perform(self)
        return
    end

    local modData = PZLinuxGetModData(self.character)
    modData.PZLinuxContractPickUp = 3
    HaloTextHelper.addGoodText(getPlayer(), PZLinuxText("UI_PZLinux_DropContractCase", "Drop the contract case in a mailbox"))
    PZLinuxSyncPlayerModData(self.character)
    ISBaseTimedAction.perform(self)
end

function ISTakeThePackageAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.stopOnWalk = true
    o.maxTime = 250
    return o
end
