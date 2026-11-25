require "AAA_PZLinuxCompat"

PZLinuxEconomy = PZLinuxEconomy or {}

PZLinuxEconomy.DemandTag = "PZLinuxEconomyDemand"
PZLinuxEconomy.Money = "Base.Money"
PZLinuxEconomy.MoneyBundle = "Base.MoneyBundle"
PZLinuxEconomy.CopperCoin = "Base.CobreCoin"
PZLinuxEconomy.SilverCoin = "Base.SilverCoin"
PZLinuxEconomy.GoldCoin = "Base.GoldCoin"

PZLinuxEconomy.LegacyCoinValues = {
    [PZLinuxEconomy.GoldCoin] = 10000,
    [PZLinuxEconomy.SilverCoin] = 100,
    [PZLinuxEconomy.CopperCoin] = 1,
}

-- The numeric bank balance never changes denomination when Sandbox is changed.
local currencySignature
function PZLinuxEconomyRefreshCurrency()
    local coinMode = PZLinuxConfig.Get("CurrencyMode") == 2
    local alternate = PZLinuxConfig.Get("AcceptAlternateCurrency")
    local signature = tostring(coinMode) .. tostring(alternate)
    if currencySignature == signature then return end
    currencySignature = signature
    local money = {
        { key = "bundle", fullType = PZLinuxEconomy.MoneyBundle, value = 100, label = "$100" },
        { key = "money", fullType = PZLinuxEconomy.Money, value = 1, label = "$" },
    }
    local coins = {
        { key = "gold", fullType = PZLinuxEconomy.GoldCoin, value = 10000, label = "G" },
        { key = "silver", fullType = PZLinuxEconomy.SilverCoin, value = 100, label = "S" },
        { key = "copper", fullType = PZLinuxEconomy.CopperCoin, value = 1, label = "C" },
    }
    PZLinuxEconomy.Coins = coinMode and coins or money
    PZLinuxEconomy.CurrencyTypes = {}
    for _, currency in ipairs(PZLinuxEconomy.Coins) do table.insert(PZLinuxEconomy.CurrencyTypes, currency) end
    if alternate then
        for _, currency in ipairs(coinMode and money or coins) do table.insert(PZLinuxEconomy.CurrencyTypes, currency) end
    end
    table.sort(PZLinuxEconomy.CurrencyTypes, function(a, b) return a.value > b.value end)
    local copper = coinMode and PZLinuxEconomy.CopperCoin or PZLinuxEconomy.Money
    local silver = coinMode and PZLinuxEconomy.SilverCoin or PZLinuxEconomy.MoneyBundle
    local gold = coinMode and PZLinuxEconomy.GoldCoin or PZLinuxEconomy.MoneyBundle
    PZLinuxEconomy.Conversions = {
        copper_to_silver = { from = copper, fromCount = 100, to = silver, toCount = 1 },
        silver_to_gold = { from = coinMode and silver or copper, fromCount = 100, to = gold, toCount = 1 },
        gold_to_silver = { from = gold, fromCount = 1, to = coinMode and silver or copper, toCount = 100 },
        silver_to_copper = { from = silver, fromCount = 1, to = copper, toCount = 100 },
    }
end
PZLinuxEconomyRefreshCurrency()

local function patchCoinScriptWeights()
    local scriptManager = PZLinuxGetScriptManager and PZLinuxGetScriptManager() or (getScriptManager and getScriptManager())
    if not scriptManager or not scriptManager.FindItem then
        return
    end

    for fullType in pairs(PZLinuxEconomy.LegacyCoinValues) do
        local ok, scriptItem = pcall(function()
            return scriptManager:FindItem(fullType)
        end)
        if ok and scriptItem and scriptItem.DoParam then
            pcall(function()
                scriptItem:DoParam("Weight = 0")
            end)
        end
    end
end

function PZLinuxEconomyNormalizeCoinWeight(item)
    if not item or not item.getFullType or not PZLinuxEconomy.LegacyCoinValues[item:getFullType()] then
        return false
    end

    if item.setActualWeight then
        pcall(function() item:setActualWeight(0) end)
    end
    if item.setWeight then
        pcall(function() item:setWeight(0) end)
    end
    if item.setCustomWeight then
        pcall(function() item:setCustomWeight(true) end)
    end
    return true
end

local function normalizeAmount(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return 0 end
    return math.max(0, math.floor(number))
end

local function getNowHour()
    if getGameTime then
        local ok, hours = pcall(function()
            return getGameTime():getWorldAgeHours()
        end)
        if ok then
            return math.floor(tonumber(hours) or 0)
        end
    end
    return 0
end

local function markContainerDirty(container)
    if not container then
        return
    end

    if container.setDirty then
        pcall(function()
            container:setDirty(true)
        end)
    end

    if container.setDrawDirty then
        pcall(function()
            container:setDrawDirty(true)
        end)
    end
end

local function getInventory(playerObj)
    local player = PZLinuxGetPlayer(playerObj)
    if not player or not player.getInventory then
        return nil
    end

    local ok, inventory = pcall(function()
        return player:getInventory()
    end)

    if ok then
        return inventory
    end

    return nil
end

local function addItemsToContainer(container, fullType, count)
    count = normalizeAmount(count)
    if not container or count <= 0 or not PZLinuxIsValidFullType(fullType) then return false end
    local created = {}
    for _ = 1, count do
        local item = PZLinuxSafeAddItem(container, fullType)
        if not item then
            for _, previous in ipairs(created) do PZLinuxSafeRemoveItem(container, previous) end
            return false
        end
        created[#created + 1] = item
    end
    for _, item in ipairs(created) do PZLinuxNotifyAddedContainerItem(container, item) end
    markContainerDirty(container)
    return true
end

local function collectItemsByFullType(inventory, fullType, limit)
    local found = {}
    if not inventory or not inventory.getItems or not fullType then
        return found
    end

    local maxCount = normalizeAmount(limit)
    local seen = {}

    local function addFound(item)
        if not item or not item.getFullType or item:getFullType() ~= fullType then
            return false
        end

        local key = item
        if item.getID then
            local okID, id = pcall(function() return item:getID() end)
            if okID and id ~= nil then key = id end
        end

        if seen[key] then return false end
        seen[key] = true
        found[#found + 1] = item
        return maxCount > 0 and #found >= maxCount
    end

    if inventory.getAllTypeRecurse then
        local ok, items = pcall(function()
            return inventory:getAllTypeRecurse(fullType)
        end)

        if ok and items then
            local size = items.size and items:size() or 0
            for index = 0, size - 1 do
                if addFound(items:get(index)) then
                    return found
                end
            end
        end
    end

    local items = inventory:getItems()
    if not items then
        return found
    end

    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if addFound(item) then
            break
        end
    end

    return found
end

local function getItemContainer(item, fallback)
    if item and item.getContainer then
        local ok, container = pcall(function()
            return item:getContainer()
        end)
        if ok and container then
            return container
        end
    end

    return fallback
end

local function restoreRemoved(removed)
    for _, entry in ipairs(removed or {}) do
        local ok, item = pcall(function() return entry.container:AddItem(entry.item) end)
        if ok and item then PZLinuxNotifyAddedContainerItem(entry.container, item) end
        markContainerDirty(entry.container)
    end
end

local function removeItems(inventory, items)
    local removed = {}
    for _, item in ipairs(items or {}) do
        local container = getItemContainer(item, inventory)
        if not PZLinuxSafeRemoveItem(container, item) then
            restoreRemoved(removed)
            return 0, {}
        end
        removed[#removed + 1] = { item = item, container = container }
    end
    markContainerDirty(inventory)
    return #removed, removed
end

function PZLinuxEconomyIsCoin(fullType)
    PZLinuxEconomyRefreshCurrency()
    for _, currency in ipairs(PZLinuxEconomy.CurrencyTypes) do
        if currency.fullType == fullType then return true end
    end
    return false
end

local function normalizePlayerCoinWeights(_, player)
    player = PZLinuxGetPlayer(player)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory then
        return
    end

    for fullType in pairs(PZLinuxEconomy.LegacyCoinValues) do
        for _, item in ipairs(collectItemsByFullType(inventory, fullType)) do
            PZLinuxEconomyNormalizeCoinWeight(item)
        end
    end
end

patchCoinScriptWeights()
if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(patchCoinScriptWeights)
end
if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(normalizePlayerCoinWeights)
end

function PZLinuxEconomyGetCoinValue(fullType)
    PZLinuxEconomyRefreshCurrency()
    fullType = tostring(fullType or "")
    if PZLinuxEconomy.LegacyCoinValues[fullType] then
        return PZLinuxEconomy.LegacyCoinValues[fullType]
    end
    for _, coin in ipairs(PZLinuxEconomy.Coins) do
        if coin.fullType == fullType then
            return coin.value
        end
    end
    return 0
end

function PZLinuxEconomyBreakdown(value)
    PZLinuxEconomyRefreshCurrency()
    local remaining = normalizeAmount(value)
    local result = { value = remaining, gold = 0, silver = 0, copper = 0, bundle = 0, money = 0 }
    for _, currency in ipairs(PZLinuxEconomy.Coins) do
        result[currency.key] = math.floor(remaining / currency.value)
        remaining = remaining - result[currency.key] * currency.value
    end
    if PZLinuxConfig.Get("CurrencyMode") == 1 then result.gold, result.silver = result.bundle, result.money end
    return result
end

function PZLinuxCurrencyText(key, fallback, ...)
    return PZLinuxText(key .. (PZLinuxConfig.Get("CurrencyMode") == 2 and "_Coins" or ""), fallback, ...)
end

function PZLinuxFormatCurrency(value)
    return (PZLinuxConfig.Get("CurrencyMode") == 2 and "C " or "$") .. tostring(normalizeAmount(value))
end

function PZLinuxEconomyBuildCoinStacks(value)
    local counts = PZLinuxEconomyBreakdown(value)
    local stacks = {}
    for _, currency in ipairs(PZLinuxEconomy.Coins) do
        if counts[currency.key] > 0 then stacks[#stacks + 1] = { fullType = currency.fullType, count = counts[currency.key] } end
    end
    return stacks
end

function PZLinuxEconomyGiveCoinValue(playerObj, value)
    if isClient() then return false end
    local inventory = getInventory(playerObj)
    if not inventory then return false end
    local created = {}
    for _, stack in ipairs(PZLinuxEconomyBuildCoinStacks(value)) do
        for _ = 1, stack.count do
            local item = PZLinuxSafeAddItem(inventory, stack.fullType)
            if not item then
                for _, previous in ipairs(created) do PZLinuxSafeRemoveItem(inventory, previous) end
                return false
            end
            created[#created + 1] = item
        end
    end
    for _, item in ipairs(created) do PZLinuxNotifyAddedContainerItem(inventory, item) end
    markContainerDirty(inventory)
    return true
end

function PZLinuxEconomyGetInventoryCoinCounts(playerObj)
    PZLinuxEconomyRefreshCurrency()
    local inventory = getInventory(playerObj)
    local counts = { bundle = 0, money = 0, copper = 0, silver = 0, gold = 0, value = 0 }
    if not inventory then
        return counts
    end

    for _, currency in ipairs(PZLinuxEconomy.CurrencyTypes) do
        local items = collectItemsByFullType(inventory, currency.fullType)
        local count = #items
        counts[currency.key] = count
        counts.value = counts.value + (count * currency.value)
        if currency.fullType == PZLinuxEconomy.MoneyBundle then
            counts.bundle = count
        elseif currency.fullType == PZLinuxEconomy.Money then
            counts.money = count
        end
    end

    if PZLinuxConfig.Get("CurrencyMode") == 1 then
        counts.gold, counts.silver, counts.copper = counts.bundle, counts.money, 0
    end

    return counts
end

local function getCoinKeyByFullType(fullType)
    fullType = tostring(fullType or "")
    for _, coin in ipairs(PZLinuxEconomy.Coins) do
        if coin.fullType == fullType then
            return coin.key
        end
    end
    return nil
end

local function storeBankCounts(modData, counts)
    if type(modData) ~= "table" or type(counts) ~= "table" then return counts end
    local value = 0
    for _, currency in ipairs(PZLinuxEconomy.Coins) do
        counts[currency.key] = normalizeAmount(counts[currency.key])
        value = value + counts[currency.key] * currency.value
    end
    counts.value = value
    counts.currencyMode = PZLinuxConfig.Get("CurrencyMode")
    if PZLinuxConfig.Get("CurrencyMode") == 1 then counts.gold, counts.silver, counts.copper = counts.bundle, counts.money, 0 end
    modData.PZLinuxBank = value
    modData.PZLinuxBankCoins = PZLinuxCloneSerializableTable(counts)
    return counts
end

function PZLinuxEconomyGetBankCoinCounts(playerObj)
    PZLinuxEconomyRefreshCurrency()
    local player = PZLinuxGetPlayer(playerObj)
    local modData = PZLinuxGetModData(player)
    local value = math.max(0, math.floor(tonumber(modData and modData.PZLinuxBank) or 0))
    if type(modData) ~= "table" then
        return { copper = 0, silver = 0, gold = 0, value = 0 }
    end

    local previous = modData.PZLinuxBankCoins
    if type(previous) == "table" and previous.currencyMode == PZLinuxConfig.Get("CurrencyMode") then
        local previousValue = 0
        for _, currency in ipairs(PZLinuxEconomy.Coins) do
            previousValue = previousValue + normalizeAmount(previous[currency.key]) * currency.value
        end
        if previousValue == value then return storeBankCounts(modData, PZLinuxCloneSerializableTable(previous)) end
    end
    return storeBankCounts(modData, PZLinuxEconomyBreakdown(value))
end

function PZLinuxEconomyConvertBankCoins(playerObj, action)
    if not PZLinuxConfig.IsEnabled("CurrencyConversion") then return { ok = false, reason = "disabled" } end
    PZLinuxEconomyRefreshCurrency()
    local conversion = PZLinuxEconomy.Conversions[tostring(action or "")]
    if not conversion then
        return { ok = false, reason = "invalid_conversion" }
    end

    local player = PZLinuxGetPlayer(playerObj)
    local modData = PZLinuxGetModData(player)
    if not player or not modData then
        return { ok = false, reason = "missing_bank" }
    end

    modData.PZLinuxBank = math.max(0, math.floor(tonumber(modData.PZLinuxBank) or 0))
    local counts = PZLinuxEconomyGetBankCoinCounts(player)
    local fromKey = getCoinKeyByFullType(conversion.from)
    local toKey = getCoinKeyByFullType(conversion.to)
    local fromCount = math.max(1, math.floor(tonumber(conversion.fromCount) or 1))
    local toCount = math.max(1, math.floor(tonumber(conversion.toCount) or 1))
    if not fromKey or not toKey then
        return { ok = false, reason = "invalid_coin_type", source = "bank", balance = modData.PZLinuxBank, counts = counts }
    end

    if math.max(0, math.floor(tonumber(counts[fromKey]) or 0)) < fromCount then
        return {
            ok = false,
            reason = "not_enough_money",
            source = "bank",
            balance = modData.PZLinuxBank,
            counts = counts,
        }
    end

    counts[fromKey] = counts[fromKey] - fromCount
    counts[toKey] = counts[toKey] + toCount
    counts = storeBankCounts(modData, counts)

    return {
        ok = true,
        action = action,
        source = "bank",
        balance = modData.PZLinuxBank,
        counts = counts,
    }
end

function PZLinuxEconomyTransferCoinsToMainInventory(playerObj)
    local player = PZLinuxGetPlayer(playerObj)
    if not player or not ISInventoryPaneContextMenu or not ISInventoryPaneContextMenu.getContainers then
        return
    end

    local containers = ISInventoryPaneContextMenu.getContainers(player)
    if not containers then
        return
    end

    for index = 1, containers:size() do
        local container = containers:get(index - 1)
        if container and container.getItems then
            local items = container:getItems()
            for itemIndex = items:size() - 1, 0, -1 do
                local item = items:get(itemIndex)
                if item and item.getFullType and PZLinuxEconomyIsCoin(item:getFullType()) then
                    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
                end
            end
        end
    end
end

function PZLinuxEconomyRemoveCoinValueFromInventory(playerObj, value)
    PZLinuxEconomyRefreshCurrency()
    local amount = normalizeAmount(value)
    if amount <= 0 then
        return { ok = false, removedValue = 0, change = 0 }
    end

    local inventory = getInventory(playerObj)
    if not inventory then
        return { ok = false, removedValue = 0, change = 0 }
    end

    local buckets = {}
    local totalValue = 0
    for _, currency in ipairs(PZLinuxEconomy.CurrencyTypes) do
        local items = collectItemsByFullType(inventory, currency.fullType)
        buckets[currency.key] = { def = currency, items = items }
        totalValue = totalValue + (#items * currency.value)
    end

    if totalValue < amount then
        return { ok = false, removedValue = 0, change = 0, available = totalValue }
    end

    local selected = {}
    local selectedValue = 0
    local remaining = amount

    local function takeCoin(bucket)
        local item = table.remove(bucket.items)
        if item then
            selected[#selected + 1] = item
            selectedValue = selectedValue + bucket.def.value
            remaining = math.max(0, remaining - bucket.def.value)
            return true
        end
        return false
    end

    for _, currency in ipairs(PZLinuxEconomy.CurrencyTypes) do
        local bucket = buckets[currency.key]
        while remaining >= currency.value and #bucket.items > 0 do
            takeCoin(bucket)
        end
    end

    if remaining > 0 then
        local bestBucket = nil
        for index = #PZLinuxEconomy.CurrencyTypes, 1, -1 do
            local currency = PZLinuxEconomy.CurrencyTypes[index]
            local bucket = buckets[currency.key]
            if #bucket.items > 0 and currency.value >= remaining then
                bestBucket = bucket
                break
            end
        end

        if not bestBucket then
            for _, currency in ipairs(PZLinuxEconomy.CurrencyTypes) do
                local bucket = buckets[currency.key]
                if #bucket.items > 0 then
                    bestBucket = bucket
                    break
                end
            end
        end

        if bestBucket then
            takeCoin(bestBucket)
        end
    end

    if selectedValue < amount then
        return { ok = false, removedValue = 0, change = 0, available = totalValue }
    end

    local removedCount, removed = removeItems(inventory, selected)
    if removedCount < #selected then
        return { ok = false, removedValue = 0, change = 0, available = totalValue }
    end

    local change = math.max(0, selectedValue - amount)
    if change > 0 and not PZLinuxEconomyGiveCoinValue(playerObj, change) then
        restoreRemoved(removed)
        return { ok = false, removedValue = 0, change = 0, reason = "create_failed" }
    end

    return {
        ok = true,
        removedValue = amount,
        change = change,
        available = totalValue,
    }
end

function PZLinuxEconomyConvertCoins(playerObj, action)
    if not PZLinuxConfig.IsEnabled("CurrencyConversion") then return { ok = false, reason = "disabled" } end
    PZLinuxEconomyRefreshCurrency()
    local conversion = PZLinuxEconomy.Conversions[tostring(action or "")]
    if not conversion then
        return { ok = false, reason = "invalid_conversion" }
    end

    local player = PZLinuxGetPlayer(playerObj)
    local inventory = getInventory(player)
    if not player or not inventory then
        return { ok = false, reason = "missing_inventory" }
    end

    local items = collectItemsByFullType(inventory, conversion.from, conversion.fromCount)
    if #items < conversion.fromCount then
        return { ok = false, reason = "not_enough_money" }
    end

    local removedCount, removed = removeItems(inventory, items)
    if removedCount < conversion.fromCount then
        return { ok = false, reason = "remove_failed" }
    end

    if not addItemsToContainer(inventory, conversion.to, conversion.toCount) then
        restoreRemoved(removed)
        return { ok = false, reason = "create_failed" }
    end

    return {
        ok = true,
        action = action,
        counts = PZLinuxEconomyGetInventoryCoinCounts(player),
    }
end

local function getDemandData()
    if ModData and ModData.getOrCreate then
        local data = ModData.getOrCreate(PZLinuxEconomy.DemandTag)
        data.items = type(data.items) == "table" and data.items or {}
        return data
    end

    PZLinuxEconomy.LocalDemandData = PZLinuxEconomy.LocalDemandData or { items = {} }
    return PZLinuxEconomy.LocalDemandData
end

local function transmitDemandData(data)
    if isServer() and ModData and ModData.transmit and data then
        ModData.transmit(PZLinuxEconomy.DemandTag)
    end
end

function PZLinuxEconomyApplyDemandSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    local data = getDemandData()
    data.items = PZLinuxCloneSerializableTable(snapshot.items or snapshot) or {}
    return true
end

function PZLinuxEconomyBuildDemandSnapshot()
    local data = getDemandData()
    return PZLinuxCloneSerializableTable(data) or { items = {} }
end

function PZLinuxEconomyBuildItemDemandKey(itemIds)
    local ids = PZLinuxNormalizeFullTypeList and PZLinuxNormalizeFullTypeList(itemIds) or {}
    if #ids == 0 then
        if type(itemIds) == "string" and itemIds ~= "" then
            ids = { itemIds }
        else
            ids = { "unknown" }
        end
    end
    table.sort(ids)
    return "item:" .. table.concat(ids, "|")
end

function PZLinuxEconomyBuildRequestDemandKey(requestId)
    return "request:" .. tostring(requestId or "unknown")
end

function PZLinuxEconomyBuildTradingDemandKey(code)
    return "trading:" .. tostring(code or "unknown")
end

local function normalizeDemandEntry(entry)
    entry = type(entry) == "table" and entry or {}
    entry.multiplier = tonumber(entry.multiplier) or 1.0
    entry.lastHour = tonumber(entry.lastHour) or getNowHour()
    entry.buys = normalizeAmount(entry.buys)
    entry.sells = normalizeAmount(entry.sells)
    return entry
end

function PZLinuxEconomyGetDemandMultiplier(key)
    if not PZLinuxConfig.IsEnabled("Demand") then return 1 end
    key = tostring(key or "")
    if key == "" then
        return 1.0
    end

    local data = getDemandData()
    local entry = normalizeDemandEntry(data.items[key])
    local nowHour = getNowHour()
    local elapsed = math.max(0, nowHour - (tonumber(entry.lastHour) or nowHour))
    if elapsed > 0 then
        entry.multiplier = math.max(PZLinuxConfig.Get("DemandMinimum"), (tonumber(entry.multiplier) or 1.0) - (elapsed * PZLinuxConfig.Get("DemandDecayPerHour")))
        entry.lastHour = nowHour
        data.items[key] = entry
    end

    local minimum = PZLinuxConfig.Get("DemandMinimum")
    return math.max(minimum, math.min(math.max(minimum, PZLinuxConfig.Get("DemandMaximum")), tonumber(entry.multiplier) or 1.0))
end

function PZLinuxEconomyRecordDemand(key, direction, quantity, transmit)
    if not PZLinuxConfig.IsEnabled("Demand") then return false end
    key = tostring(key or "")
    if key == "" then
        return false
    end

    local data = getDemandData()
    local entry = normalizeDemandEntry(data.items[key])
    local qty = math.max(1, normalizeAmount(quantity))
    local multiplier = PZLinuxEconomyGetDemandMultiplier(key)

    if tostring(direction or "up") == "down" then
        entry.sells = (tonumber(entry.sells) or 0) + qty
        entry.multiplier = math.max(PZLinuxConfig.Get("DemandMinimum"), multiplier - (qty * PZLinuxConfig.Get("DemandSellStep")))
    else
        entry.buys = (tonumber(entry.buys) or 0) + qty
        entry.multiplier = math.min(math.max(PZLinuxConfig.Get("DemandMinimum"), PZLinuxConfig.Get("DemandMaximum")), multiplier + (qty * PZLinuxConfig.Get("DemandBuyStep")))
    end

    entry.lastHour = getNowHour()
    data.items[key] = entry

    if isClient() and transmit and sendClientCommand then
        sendClientCommand(PZLinuxModule or "PZLinux", "RecordEconomyDemand", {
            key = key,
            direction = direction,
            quantity = qty,
        })
    elseif transmit then
        transmitDemandData(data)
    end

    return true
end

function PZLinuxEconomyNormalizeBasePrice(price)
    local value = math.max(1, math.floor(tonumber(price) or 1))

    if value >= 5000 and value < 10000 then
        return 10000
    end

    if value >= 10000 then
        return math.ceil(value / 1000) * 1000
    end

    if value >= 100 then
        return math.ceil(value / 10) * 10
    end

    return value
end

function PZLinuxEconomyApplyDemandPrice(price, key)
    local value = PZLinuxEconomyNormalizeBasePrice(price)
    local multiplier = PZLinuxEconomyGetDemandMultiplier(key)
    return PZLinuxEconomyNormalizeBasePrice(math.max(1, math.ceil(value * multiplier)))
end
