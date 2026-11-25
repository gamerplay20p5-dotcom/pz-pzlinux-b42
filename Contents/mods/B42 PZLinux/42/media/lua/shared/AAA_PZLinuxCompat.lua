require "PZLinuxConfig"
PZLinuxModule = "PZLinux"
PZLinuxCargoBoxSprite = "carpentry_01_19"

local unpackArgs = table.unpack or unpack
local PZLinuxLastPlayerSyncSignature = nil
local PZLinuxClientCommandNextAt = {}
local PZLinuxTradingGlobalRequestNextAt = 0
local PZLINUX_CITY_KEYS = {
    Irvington = "UI_PZLinux_City_Irvington",
    Ekron = "UI_PZLinux_City_Ekron",
    Brandenburg = "UI_PZLinux_City_Brandenburg",
    EchoCreek = "UI_PZLinux_City_EchoCreek",
    ["Echo Creek"] = "UI_PZLinux_City_EchoCreek",
    Riverside = "UI_PZLinux_City_Riverside",
    ["Fallas Lake"] = "UI_PZLinux_City_FallasLake",
    Rosewood = "UI_PZLinux_City_Rosewood",
    ["March Ridge"] = "UI_PZLinux_City_MarchRidge",
    Muldraugh = "UI_PZLinux_City_Muldraugh",
    ["West Point"] = "UI_PZLinux_City_WestPoint",
    ["Valley Station"] = "UI_PZLinux_City_ValleyStation",
    Louisville = "UI_PZLinux_City_Louisville",
}

local PZLINUX_DEFAULT_KEYS = {
    "PZLinuxUIOpenMenu",
    "PZLinuxIsPowered",
    "ATMIsPowered",
    "PZLinuxUISFX",
    "PZLinuxActiveContract",
    "PZLinuxContractKillZombie",
    "PZLinuxContractPickUp",
    "PZLinuxContractManhunt",
    "PZLinuxContractBlood",
    "PZLinuxContractCar",
    "PZLinuxContractCapture",
    "PZLinuxContractCargo",
    "PZLinuxContractProtect",
    "PZLinuxContractMedical",
    "PZLinuxContractWeapon",
    "PZLinuxContractSendComputer",
    "PZLinuxContractSendFridge",
    "PZLinuxContractInfoCount",
    "PZLinuxOnZombieDead",
    "PZLinuxOnZombieToKill",
    "PZLinuxOnItemRequestCar",
    "PZLinuxContractLocationX",
    "PZLinuxContractLocationY",
    "PZLinuxContractLocationZ",
    "PZLinuxComputerCondition",
    }

local function PZLinuxCloneSerializableValue(value, seen)
    local valueType = type(value)
    if valueType == "table" then
        seen = seen or {}
        if seen[value] then
            return seen[value]
        end

        local copy = {}
        seen[value] = copy

        for key, nestedValue in pairs(value) do
            local keyType = type(key)
            if keyType == "string" or keyType == "number" then
                local clonedValue = PZLinuxCloneSerializableValue(nestedValue, seen)
                if clonedValue ~= nil then
                    copy[key] = clonedValue
                end
            end
        end

        return copy
    end

    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return value
    end

    return nil
end

function PZLinuxCloneSerializableTable(value)
    if type(value) ~= "table" then
        return nil
    end

    return PZLinuxCloneSerializableValue(value, {})
end

local function PZLinuxNowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getTimestamp then
        return getTimestamp() * 1000
    end
    return os.time() * 1000
end

local function PZLinuxStableSerialize(value, depth, seen)
    depth = depth or 0
    if depth > 8 then
        return "<maxdepth>"
    end

    local valueType = type(value)
    if valueType == "table" then
        seen = seen or {}
        if seen[value] then
            return "<cycle>"
        end
        seen[value] = true

        local keys = {}
        for key in pairs(value) do
            table.insert(keys, key)
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)

        local parts = {}
        for i = 1, #keys do
            local key = keys[i]
            parts[#parts + 1] = tostring(key) .. "=" .. PZLinuxStableSerialize(value[key], depth + 1, seen)
        end

        seen[value] = nil
        return "{" .. table.concat(parts, ";") .. "}"
    end

    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    return ""
end

function PZLinuxSendClientCommandThrottled(module, command, args, cooldownMs)
    if not isClient() or not sendClientCommand then
        return false
    end

    cooldownMs = tonumber(cooldownMs) or 0
    local key = tostring(module or PZLinuxModule) .. ":" .. tostring(command)
    local now = PZLinuxNowMs()
    if cooldownMs > 0 and now < (PZLinuxClientCommandNextAt[key] or 0) then
        return false
    end

    sendClientCommand(module or PZLinuxModule, command, args or {})
    if cooldownMs > 0 then
        PZLinuxClientCommandNextAt[key] = now + cooldownMs
    end
    return true
end

local function PZLinuxClearTableEntries(target)
    if type(target) ~= "table" then
        return
    end

    for key in pairs(target) do
        target[key] = nil
    end
end

function PZLinuxIsPlayerSyncKey(key)
    if key == "pzlinux" or key == "playerWallet" or key == "ATMIsPowered" then
        return true
    end

    if type(key) ~= "string" then
        return false
    end

    return key:sub(1, 7) == "PZLinux" or key:sub(1, 6) == "ZLinux"
end

local PZLINUX_SERVER_OWNED_PLAYER_KEYS = {
    PZLinuxBankCoins = true,
    PZLinuxPendingLocalMarketListing = true,
    PZLinuxTradingPortfolio = true,
    playerWallet = true,
}

-- B42.20 MP: listings, trading assets and derived coin data are authoritative
-- on the server. PZLinuxBank remains writable for legacy betting, requests,
-- hacking and contract flows until each one has a dedicated command.
function PZLinuxIsClientWritablePlayerSyncKey(key)
    if not PZLinuxIsPlayerSyncKey(key) or PZLINUX_SERVER_OWNED_PLAYER_KEYS[key] then
        return false
    end

    return type(key) ~= "string" or key:sub(1, 6) ~= "ZLinux"
end

function PZLinuxBuildPlayerModDataSnapshot(playerObj)
    local md = PZLinuxGetModData(playerObj)
    if not md then
        return {}
    end

    local snapshot = {}
    for key, value in pairs(md) do
        if PZLinuxIsClientWritablePlayerSyncKey(key) then
            local clonedValue = type(value) == "table" and PZLinuxCloneSerializableTable(value) or PZLinuxCloneSerializableValue(value)
            if clonedValue ~= nil then
                snapshot[key] = clonedValue
            end
        end
    end

    return snapshot
end

function PZLinuxApplyPlayerModDataSnapshot(targetModData, snapshot)
    if type(targetModData) ~= "table" or type(snapshot) ~= "table" then
        return targetModData
    end

    for key in pairs(targetModData) do
        if PZLinuxIsClientWritablePlayerSyncKey(key) then
            targetModData[key] = nil
        end
    end

    for key, value in pairs(snapshot) do
        if PZLinuxIsClientWritablePlayerSyncKey(key) then
            if type(value) == "table" then
                targetModData[key] = PZLinuxCloneSerializableTable(value) or {}
            else
                targetModData[key] = value
            end
        end
    end

    return targetModData
end

function PZLinuxIsTradingGlobalTag(tag)
    return type(tag) == "string" and tag:match("^PZLinuxTrading") ~= nil
end

function PZLinuxApplyGlobalModDataSnapshot(tag, snapshot)
    if not PZLinuxIsTradingGlobalTag(tag) or type(snapshot) ~= "table" or not ModData or not ModData.getOrCreate then
        return nil
    end

    local target = ModData.getOrCreate(tag)
    if type(target) ~= "table" then
        return nil
    end

    PZLinuxClearTableEntries(target)
    local clonedSnapshot = PZLinuxCloneSerializableTable(snapshot) or {}
    for key, value in pairs(clonedSnapshot) do
        target[key] = value
    end

    return target
end

function PZLinuxRequestGlobalModData(tag)
    if isClient() and PZLinuxIsTradingGlobalTag(tag) and ModData and ModData.request then
        ModData.request(tag)
    end
end

function PZLinuxRequestTradingGlobalModData()
    if isClient() then
        local now = PZLinuxNowMs()
        if now < PZLinuxTradingGlobalRequestNextAt then
            return
        end
        PZLinuxTradingGlobalRequestNextAt = now + 10000
    end

    PZLinuxRequestGlobalModData("PZLinuxTrading")

    if type(PZLinuxTradingCompanyNameTable) ~= "table" then
        return
    end

    for _, company in ipairs(PZLinuxTradingCompanyNameTable) do
        if type(company) == "table" and type(company.code) == "string" and company.code ~= "" then
            PZLinuxRequestGlobalModData("PZLinuxTrading" .. company.code)
        end
    end
end

function PZLinuxGetPlayer(playerObj)
    return playerObj or getPlayer()
end

function PZLinuxGetModData(playerObj)
    local player = PZLinuxGetPlayer(playerObj)
    if not player then return nil end

    local md = player:getModData()
    md.pzlinux = md.pzlinux or {}
    md.pzlinux.player = md.pzlinux.player or {}
    md.pzlinux.mails = md.pzlinux.mails or {}
    md.pzlinux.mails.inbox = md.pzlinux.mails.inbox or {}
    md.pzlinux.mails.nextid = tonumber(md.pzlinux.mails.nextid) or 1
    md.pzlinux.player.reputation = tonumber(md.pzlinux.player.reputation) or 1
    md.playerWallet = md.playerWallet or {}

    for _, key in ipairs(PZLINUX_DEFAULT_KEYS) do
        if md[key] == nil then
            if key == "PZLinuxUISFX" then
                md[key] = 1
            elseif key == "PZLinuxComputerCondition" then
                md[key] = 100
            else
                md[key] = 0
            end
        end
    end

    md.PZLinuxContractNote = md.PZLinuxContractNote or ""
    md.PZLinuxContractLocationLabel = md.PZLinuxContractLocationLabel or ""
    md.PZLinuxContractInfo = md.PZLinuxContractInfo or ""
    md.PZLinuxOnItemRequestCarName = md.PZLinuxOnItemRequestCarName or ""
    md.PZLinuxActiveRequest = tonumber(md.PZLinuxActiveRequest) or 0
    md.PZLinuxOnItemBuyOnDarkWebStatus = tonumber(md.PZLinuxOnItemBuyOnDarkWebStatus) or 0
    md.PZLinuxOnItemRequest = type(md.PZLinuxOnItemRequest) == "table" and md.PZLinuxOnItemRequest or {}
    md.PZLinuxOnItemBuyOnDarkWeb = type(md.PZLinuxOnItemBuyOnDarkWeb) == "table" and md.PZLinuxOnItemBuyOnDarkWeb or {}
    md.PZLinuxOnItemRequestCount = type(md.PZLinuxOnItemRequestCount) == "table" and md.PZLinuxOnItemRequestCount or {}

    return md
end

function PZLinuxSyncPlayerModData(playerObj)
    local player = PZLinuxGetPlayer(playerObj)
    if not player then
        return false
    end

    if isClient() and sendClientCommand then
        local snapshot = PZLinuxBuildPlayerModDataSnapshot(player)
        local signature = PZLinuxStableSerialize(snapshot)
        if signature == PZLinuxLastPlayerSyncSignature then
            return true
        end

        PZLinuxLastPlayerSyncSignature = signature
        sendClientCommand(PZLinuxModule, "SyncPlayerData", {
            snapshot = snapshot,
        })
        return true
    end

    if player.transmitModData then
        player:transmitModData()
        return true
    end

    return false
end

function PZLinuxSyncGlobalModData(tag, dataTable)
    if not PZLinuxIsTradingGlobalTag(tag) then
        return false
    end

    local sourceTable = dataTable
    if type(sourceTable) ~= "table" then
        if not ModData or not ModData.getOrCreate then
            return false
        end

        sourceTable = ModData.getOrCreate(tag)
    end

    local snapshot = PZLinuxCloneSerializableTable(sourceTable) or {}
    if isClient() and sendClientCommand then
        if PZLinuxIsTradingGlobalTag(tag) then
            PZLinuxRequestTradingGlobalModData()
            PZLinuxSendClientCommandThrottled(PZLinuxModule, "RequestTradingData", {}, 10000)
            return true
        end

        sendClientCommand(PZLinuxModule, "SyncGlobalData", {
            tag = tag,
            data = snapshot,
        })
        return true
    end

    local applied = PZLinuxApplyGlobalModDataSnapshot(tag, snapshot)
    if applied and ModData and ModData.transmit then
        ModData.transmit(tag)
    end

    return applied ~= nil
end

local function PZLinuxAppendUniqueMailId(candidates, seen, value)
    if value == nil then
        return
    end

    local token = type(value) .. ":" .. tostring(value)
    if seen[token] then
        return
    end

    seen[token] = true
    table.insert(candidates, value)
end

function PZLinuxBuildMailIdCandidates(mailId)
    local candidates = {}
    local seen = {}
    PZLinuxAppendUniqueMailId(candidates, seen, mailId)

    local numericId = tonumber(mailId)
    if numericId ~= nil then
        PZLinuxAppendUniqueMailId(candidates, seen, numericId)
        PZLinuxAppendUniqueMailId(candidates, seen, tostring(numericId))

        if math.floor(numericId) == numericId then
            local integerId = math.floor(numericId)
            PZLinuxAppendUniqueMailId(candidates, seen, integerId)
            PZLinuxAppendUniqueMailId(candidates, seen, tostring(integerId))
            PZLinuxAppendUniqueMailId(candidates, seen, string.format("%.1f", numericId))
        end
    elseif type(mailId) == "string" and mailId ~= "" then
        PZLinuxAppendUniqueMailId(candidates, seen, tostring(mailId))
    end

    return candidates
end

function PZLinuxMailIdsMatch(leftId, rightId)
    if leftId == nil or rightId == nil then
        return false
    end

    if leftId == rightId then
        return true
    end

    local leftNumeric = tonumber(leftId)
    local rightNumeric = tonumber(rightId)
    if leftNumeric ~= nil and rightNumeric ~= nil and leftNumeric == rightNumeric then
        return true
    end

    return tostring(leftId) == tostring(rightId)
end

function PZLinuxResolveMailKey(mails, mailId)
    if type(mails) ~= "table" then
        return nil
    end

    for _, candidate in ipairs(PZLinuxBuildMailIdCandidates(mailId)) do
        if mails[candidate] ~= nil then
            return candidate
        end
    end

    return nil
end

function PZLinuxGetMailEntry(playerObj, mailId)
    local md = PZLinuxGetModData(playerObj)
    if not md then
        return nil, nil, nil, nil
    end

    local mails = md.pzlinux.mails
    local key = PZLinuxResolveMailKey(mails, mailId)
    local mail = key and mails[key] or nil
    if type(mail) ~= "table" then
        mail = nil
    end

    return md, mails, mail, key
end

function PZLinuxGetOrCreateMailEntry(playerObj, mailId)
    local md = PZLinuxGetModData(playerObj)
    if not md then
        return nil, nil, nil, nil
    end

    local mails = md.pzlinux.mails
    local key = PZLinuxResolveMailKey(mails, mailId)
    if not key then
        local numericId = tonumber(mailId)
        if numericId ~= nil then
            key = math.floor(numericId) == numericId and math.floor(numericId) or numericId
        else
            key = tostring(mailId or "")
        end

        if key == "" then
            return md, mails, nil, nil
        end

        mails[key] = mails[key] or {}
    end

    if type(mails[key]) ~= "table" then
        mails[key] = {}
    end

    return md, mails, mails[key], key
end

function PZLinuxCanMutateWorld()
    return not isClient()
end

function PZLinuxIsEquippedInventoryItem(playerObj, item)
    local player = PZLinuxGetPlayer(playerObj)
    if not player or not item then
        return false
    end

    local ok, equipped = pcall(function()
        return item.isEquipped and item:isEquipped()
    end)
    if ok and equipped then
        return true
    end

    ok, equipped = pcall(function()
        return player.isEquipped and player:isEquipped(item)
    end)
    if ok and equipped then
        return true
    end

    ok, equipped = pcall(function()
        return player.isEquippedClothing and player:isEquippedClothing(item)
    end)
    if ok and equipped then
        return true
    end

    ok, equipped = pcall(function()
        return player.getClothingItem_Back and player:getClothingItem_Back() == item
    end)
    if ok and equipped then
        return true
    end

    return false
end

function PZLinuxRequestWorldMutation(command, args)
    if isClient() then
        PZLinuxSendClientCommandThrottled(PZLinuxModule, command, args or {}, 1000)
        return false
    end
    return true
end

function PZLinuxGetHistoryExtremes(priceHistory)
    local count = priceHistory and #priceHistory or 0
    if count == 0 then
        return 0, 0, 0
    end

    local firstPrice = tonumber(priceHistory[1]) or 0
    local lastPrice = tonumber(priceHistory[count]) or firstPrice
    local previousPrice = tonumber(priceHistory[count - 1]) or lastPrice
    return firstPrice, lastPrice, previousPrice
end

function PZLinuxSafePercentDelta(currentValue, previousValue)
    currentValue = tonumber(currentValue) or 0
    previousValue = tonumber(previousValue) or 0
    if previousValue == 0 then
        return 0
    end

    return ((currentValue - previousValue) / previousValue) * 100
end

function PZLinuxGetScriptManager()
    if ScriptManager and ScriptManager.instance then
        return ScriptManager.instance
    end

    if getScriptManager then
        local ok, manager = pcall(getScriptManager)
        if ok then
            return manager
        end
    end

    return nil
end

function PZLinuxIsValidFullType(fullType)
    if type(fullType) ~= "string" or fullType == "" then
        return false
    end

    local scriptManager = PZLinuxGetScriptManager()
    if not scriptManager or not scriptManager.FindItem then
        return true
    end

    local ok, itemScript = pcall(function()
        return scriptManager:FindItem(fullType)
    end)

    return ok and itemScript ~= nil
end

function PZLinuxTranslateCityName(cityName)
    if type(cityName) ~= "string" or cityName == "" then
        return ""
    end

    local key = PZLINUX_CITY_KEYS[cityName]
    if not key then
        return cityName
    end

    return PZLinuxText(key, cityName)
end

function PZLinuxGetItemDisplayName(fullType, fallback)
    if type(fullType) ~= "string" or fullType == "" then
        return fallback or ""
    end

    local scriptManager = PZLinuxGetScriptManager()
    if scriptManager and scriptManager.FindItem then
        local ok, itemScript = pcall(function()
            return scriptManager:FindItem(fullType)
        end)

        if ok and itemScript and itemScript.getDisplayName then
            local okName, displayName = pcall(function()
                return itemScript:getDisplayName()
            end)

            if okName and type(displayName) == "string" and displayName:match("%S") then
                return displayName
            end
        end
    end

    return fallback or fullType
end

function PZLinuxSafeGetText(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    if getTextOrNull then
        local ok, translated = pcall(function()
            return getTextOrNull(key)
        end)
        if ok and type(translated) == "string" and translated ~= "" then
            return translated
        end
    end

    if getText then
        local ok, translated = pcall(function()
            return getText(key)
        end)
        if ok and type(translated) == "string" and translated ~= "" and translated ~= key then
            return translated
        end
    end

    return nil
end

function PZLinuxGetVehicleDisplayName(scriptName, fallback)
    if type(scriptName) ~= "string" or scriptName == "" then
        return fallback or ""
    end

    local scriptManager = PZLinuxGetScriptManager()
    if scriptManager and scriptManager.getVehicle then
        local ok, vehicleScript = pcall(function()
            return scriptManager:getVehicle(scriptName)
        end)

        if ok and vehicleScript then
            local vehicleName = vehicleScript.getName and vehicleScript:getName() or scriptName
            local key = "IGUI_VehicleName" .. tostring(vehicleName)
            local translated = PZLinuxSafeGetText(key)
            if translated then
                return translated
            end

            if type(vehicleName) == "string" and vehicleName ~= "" then
                return vehicleName
            end
        end
    end

    return fallback or scriptName
end

function PZLinuxSafeAddItem(container, fullType)
    if not container or type(fullType) ~= "string" or fullType == "" then
        return nil
    end

    if not PZLinuxIsValidFullType(fullType) then
        return nil
    end

    local ok, item = pcall(function()
        return container:AddItem(fullType)
    end)

    if not ok then
        return nil
    end

    return item
end

function PZLinuxSafeInstanceItem(fullType)
    if type(fullType) ~= "string" or fullType == "" then
        return nil
    end

    if not PZLinuxIsValidFullType(fullType) then
        return nil
    end

    if not instanceItem then
        return nil
    end

    local ok, item = pcall(function()
        return instanceItem(fullType)
    end)

    if not ok then
        return nil
    end

    return item
end

function PZLinuxSafeGetItemInventory(item)
    if not item or not item.getInventory then
        return nil
    end

    local ok, inventory = pcall(function()
        return item:getInventory()
    end)

    if not ok then
        return nil
    end

    return inventory
end

function PZLinuxSafeGetItemModData(item)
    if not item or not item.getModData then
        return nil
    end

    local ok, modData = pcall(function()
        return item:getModData()
    end)

    if not ok or type(modData) ~= "table" then
        return nil
    end

    return modData
end

function PZLinuxSafeSetItemName(item, displayName)
    if not item or type(displayName) ~= "string" or displayName == "" or not item.setName then
        return false
    end

    local ok = pcall(function()
        item:setName(displayName)
    end)

    return ok
end

function PZLinuxSafeRemoveItem(container, item)
    if not container or not item then
        return false
    end

    local itemID = nil
    if item.getID then
        local okID, resolvedID = pcall(function()
            return item:getID()
        end)
        if okID then
            itemID = resolvedID
        end
    end

    local ok = pcall(function()
        if container.DoRemoveItem then
            container:DoRemoveItem(item)
        elseif container.Remove then
            container:Remove(item)
        else
            error("container has no remove method")
        end
    end)

    if not ok then
        return false
    end

    local removed = false
    if itemID ~= nil and container.containsID then
        local okContains, stillContains = pcall(function()
            return container:containsID(itemID)
        end)
        if okContains then
            removed = not stillContains
        end
    end

    if not removed and itemID ~= nil and container.getItemWithID then
        local okLookup, itemInContainer = pcall(function()
            return container:getItemWithID(itemID)
        end)
        if okLookup then
            removed = itemInContainer == nil
        end
    end

    if not removed and item.getContainer then
        local okContainer, itemContainer = pcall(function()
            return item:getContainer()
        end)
        if okContainer then
            removed = itemContainer ~= container
        end
    end

    if not removed then
        return false
    end

    if sendRemoveItemFromContainer and (isClient() or isServer()) then
        pcall(function()
            sendRemoveItemFromContainer(container, item)
        end)
    end

    if container.setDirty then
        container:setDirty(true)
    end
    if container.setDrawDirty then
        container:setDrawDirty(true)
    end

    return true
end

function PZLinuxNotifyAddedContainerItem(container, item)
    if not container or not item then
        return false
    end

    if container.setDrawDirty then
        container:setDrawDirty(true)
    end

    if isServer() and sendAddItemToContainer then
        sendAddItemToContainer(container, item)
    end

    return true
end

local PZLINUX_COMPUTER_WORLD_SPRITES = {
    appliances_com_01_72 = true,
    appliances_com_01_73 = true,
    appliances_com_01_74 = true,
    appliances_com_01_75 = true,
}

local PZLINUX_FRIDGE_WORLD_SPRITES = {
    appliances_refrigeration_01_0 = true,
    appliances_refrigeration_01_1 = true,
    appliances_refrigeration_01_2 = true,
    appliances_refrigeration_01_3 = true,
    appliances_refrigeration_01_4 = true,
    appliances_refrigeration_01_5 = true,
    appliances_refrigeration_01_6 = true,
    appliances_refrigeration_01_7 = true,
    appliances_refrigeration_01_8 = true,
    appliances_refrigeration_01_9 = true,
    appliances_refrigeration_01_10 = true,
    appliances_refrigeration_01_11 = true,
    appliances_refrigeration_01_12 = true,
    appliances_refrigeration_01_13 = true,
    appliances_refrigeration_01_14 = true,
    appliances_refrigeration_01_15 = true,
    appliances_refrigeration_01_22 = true,
    appliances_refrigeration_01_23 = true,
    appliances_refrigeration_01_24 = true,
    appliances_refrigeration_01_25 = true,
    appliances_refrigeration_01_26 = true,
    appliances_refrigeration_01_27 = true,
    appliances_refrigeration_01_28 = true,
    appliances_refrigeration_01_29 = true,
    appliances_refrigeration_01_30 = true,
    appliances_refrigeration_01_31 = true,
    appliances_refrigeration_01_32 = true,
    appliances_refrigeration_01_33 = true,
    appliances_refrigeration_01_34 = true,
    appliances_refrigeration_01_35 = true,
    appliances_refrigeration_01_36 = true,
    appliances_refrigeration_01_37 = true,
    appliances_refrigeration_01_40 = true,
    appliances_refrigeration_01_41 = true,
    appliances_refrigeration_01_42 = true,
    appliances_refrigeration_01_43 = true,
}

function PZLinuxMatchesWorldSprite(item, spriteLookup)
    if not item or not spriteLookup or not instanceof(item, "Moveable") or not item.getWorldSprite then
        return false
    end

    local spriteName = item:getWorldSprite()
    return type(spriteName) == "string" and spriteLookup[spriteName] == true
end

function PZLinuxIsComputerMoveable(item)
    return PZLinuxMatchesWorldSprite(item, PZLINUX_COMPUTER_WORLD_SPRITES)
end

function PZLinuxIsFridgeMoveable(item)
    return PZLinuxMatchesWorldSprite(item, PZLINUX_FRIDGE_WORLD_SPRITES)
end

function PZLinuxCanContainerReceiveItem(container, playerObj, fullType)
    if not container or type(fullType) ~= "string" or fullType == "" then
        return false
    end

    if not container.hasRoomFor then
        return true
    end

    local probe = PZLinuxSafeInstanceItem(fullType)
    if not probe then
        return true
    end

    local player = PZLinuxGetPlayer(playerObj)
    local ok, canAdd = pcall(function()
        return container:hasRoomFor(player, probe)
    end)

    if not ok then
        return true
    end

    return canAdd
end

function PZLinuxMarkContractDeliveryItem(item, deliveryType)
    if type(deliveryType) ~= "string" or deliveryType == "" then
        return false
    end

    local modData = PZLinuxSafeGetItemModData(item)
    if not modData then
        return false
    end

    modData.PZLinuxDeliveryType = deliveryType
    modData.PZLinuxContractDelivery = true
    return true
end

function PZLinuxGetContractDeliveryType(item)
    if not item then
        return nil
    end

    local modData = PZLinuxSafeGetItemModData(item)
    if modData and type(modData.PZLinuxDeliveryType) == "string" and modData.PZLinuxDeliveryType ~= "" then
        return modData.PZLinuxDeliveryType
    end

    if not item.getFullType then
        return nil
    end

    local fullType = item:getFullType()
    if fullType == "Base.EmptyJar" and item.getFluidContainer then
        local ok, amount = pcall(function()
            local fluidContainer = item:getFluidContainer()
            if not fluidContainer or not fluidContainer.getAmount then
                return 0
            end
            return fluidContainer:getAmount()
        end)
        if ok and tonumber(amount) and tonumber(amount) > 0 then
            return "blood"
        end
    end

    if fullType == "Base.Bag_Mail" then
        local inventory = PZLinuxSafeGetItemInventory(item)
        if inventory and inventory.getItems then
            local items = inventory:getItems()
            for i = 0, items:size() - 1 do
                local containedItem = items:get(i)
                if containedItem and containedItem.getFullType and containedItem:getFullType() == "Base.CorpseMale" then
                    return "corpse"
                end
            end
        end
    end

    return nil
end

function PZLinuxHasMailboxContractToDeliver(modData)
    if type(modData) ~= "table" then
        return false
    end
    if (tonumber(modData.PZLinuxActiveContract) or 0) ~= 1 then
        return false
    end

    local hasCountedContract = tostring(modData.PZLinuxContractInfo or "") ~= ""
        and math.max(tonumber(modData.PZLinuxContractInfoCount) or 0, 0) > 0
        and (
            modData.PZLinuxContractMedical == 1
            or modData.PZLinuxContractCar == 1
            or modData.PZLinuxContractWeapon == 1
        )

    if hasCountedContract then
        return true
    end

    return modData.PZLinuxContractPickUp == 3
        or modData.PZLinuxContractSendComputer == 1
        or modData.PZLinuxContractSendFridge == 1
        or modData.PZLinuxContractManhunt == 3
        or modData.PZLinuxContractBlood == 3
        or modData.PZLinuxContractCapture == 3
end

function PZLinuxIsMailboxCountedContractItem(modData, item, totalCountForContract, remainingContractItems)
    return item
        and item.getFullType
        and item:getFullType() == modData.PZLinuxContractInfo
        and totalCountForContract
        and remainingContractItems > 0
        and (
            modData.PZLinuxContractMedical == 1
            or modData.PZLinuxContractCar == 1
            or modData.PZLinuxContractWeapon == 1
        )
end

function PZLinuxIsMailboxSingleContractItem(modData, item, contractDelivered)
    if contractDelivered or not item or not item.getFullType then
        return false
    end

    local fullType = item:getFullType()
    local isComputerMoveable = PZLinuxIsComputerMoveable(item)
    local isFridgeMoveable = PZLinuxIsFridgeMoveable(item)
    local deliveryType = PZLinuxGetContractDeliveryType(item)

    return (fullType == "Base.Bag_ProtectiveCaseSmall" and modData.PZLinuxContractPickUp == 3 and (deliveryType == nil or deliveryType == "pickup"))
        or (isComputerMoveable and modData.PZLinuxContractSendComputer == 1)
        or (isFridgeMoveable and modData.PZLinuxContractSendFridge == 1)
        or (fullType == "Base.Bag_Mail" and modData.PZLinuxContractManhunt == 3 and (deliveryType == "manhunt" or deliveryType == "corpse"))
        or (fullType == "Base.EmptyJar" and modData.PZLinuxContractBlood == 3 and (deliveryType == nil or deliveryType == "blood"))
        or (fullType == "Base.Bag_Mail" and modData.PZLinuxContractCapture == 3 and (deliveryType == "capture" or deliveryType == "corpse"))
end

function PZLinuxCompleteMailboxContract(playerObj)
    local player = PZLinuxGetPlayer(playerObj)
    local inventory = player and player.getInventory and player:getInventory() or nil
    local modData = PZLinuxGetModData(player)
    if not inventory or not modData or not PZLinuxHasMailboxContractToDeliver(modData) then
        return { ok = false, reason = "no_contract" }
    end

    local items = inventory:getItems()
    local remainingContractItems = math.max(tonumber(modData.PZLinuxContractInfoCount) or 0, 0)
    local totalCountForContract = false
    local contractDelivered = false
    local removedCount = 0

    if remainingContractItems > 0 and tostring(modData.PZLinuxContractInfo or "") ~= "" then
        local itemCount = 0
        for j = 0, items:size() - 1 do
            local item = items:get(j)
            if item and item.getFullType and item:getFullType() == modData.PZLinuxContractInfo then
                itemCount = itemCount + 1
            end
        end
        totalCountForContract = itemCount >= remainingContractItems
    end

    for j = items:size() - 1, 0, -1 do
        local item = items:get(j)
        if PZLinuxIsMailboxCountedContractItem(modData, item, totalCountForContract, remainingContractItems) and PZLinuxSafeRemoveItem(inventory, item) then
            remainingContractItems = remainingContractItems - 1
            removedCount = removedCount + 1
            if remainingContractItems <= 0 then
                modData.PZLinuxActiveContract = 9
                contractDelivered = true
                break
            end
        elseif PZLinuxIsMailboxSingleContractItem(modData, item, contractDelivered) and PZLinuxSafeRemoveItem(inventory, item) then
            modData.PZLinuxActiveContract = 9
            contractDelivered = true
            removedCount = removedCount + 1
            break
        end
    end

    if totalCountForContract then
        modData.PZLinuxContractInfoCount = math.max(0, remainingContractItems)
    end

    if not contractDelivered then
        return {
            ok = false,
            reason = totalCountForContract and "remove_failed" or "missing_items",
            removedCount = removedCount,
            remainingContractItems = remainingContractItems,
        }
    end

    return {
        ok = true,
        removedCount = removedCount,
        remainingContractItems = remainingContractItems,
    }
end

function PZLinuxBuildMailGiftContents()
    local contents = {}
    local bonusRand = ZombRand(1, 6)

    if type(PZLinuxDarkWebItemsTable) == "table" and #PZLinuxDarkWebItemsTable > 0 then
        for _ = 1, bonusRand do
            local entry = PZLinuxDarkWebItemsTable[ZombRand(#PZLinuxDarkWebItemsTable) + 1]
            if entry and entry.id and #entry.id > 0 then
                local one = entry.id[ZombRand(#entry.id) + 1]
                if type(one) == "string" and one ~= "" then
                    table.insert(contents, one)
                end
            end
        end
    end

    if bonusRand == 1 then
        local bonusTotal = ZombRand(1, 2000)
        table.insert(contents, "Base.Revolver")
        local coinStacks = PZLinuxEconomyBuildCoinStacks and PZLinuxEconomyBuildCoinStacks(bonusTotal) or {
            { fullType = "Base.Money", count = bonusTotal },
        }
        for _, stack in ipairs(coinStacks) do
            table.insert(contents, stack)
        end
    elseif bonusRand == 2 then
        table.insert(contents, "Base.Revolver")
    end

    return contents
end

local function PZLinuxBuildItemRestoreSnapshot(item)
    if not item or not item.getFullType then
        return nil
    end

    return {
        fullType = item:getFullType(),
        displayName = item.getName and item:getName() or nil,
        itemModData = PZLinuxCloneSerializableTable(PZLinuxSafeGetItemModData(item) or nil),
    }
end

local function PZLinuxRestoreItemSnapshots(inventory, snapshots)
    if not inventory or type(snapshots) ~= "table" then
        return
    end

    for _, snapshot in ipairs(snapshots) do
        if type(snapshot) == "table" and type(snapshot.fullType) == "string" and snapshot.fullType ~= "" then
            local restoredItem = PZLinuxSafeAddItem(inventory, snapshot.fullType)
            if restoredItem then
                if type(snapshot.displayName) == "string" and snapshot.displayName ~= "" then
                    PZLinuxSafeSetItemName(restoredItem, snapshot.displayName)
                end
                if type(snapshot.itemModData) == "table" then
                    local itemModData = PZLinuxSafeGetItemModData(restoredItem)
                    if itemModData then
                        for key, value in pairs(snapshot.itemModData) do
                            itemModData[key] = value
                        end
                    end
                end
                PZLinuxNotifyAddedContainerItem(inventory, restoredItem)
            end
        end
    end
end

function PZLinuxCompleteMailDelivery(playerObj, mailId)
    local player = PZLinuxGetPlayer(playerObj)
    local inventory = player and player.getInventory and player:getInventory() or nil
    local md, _, mail, resolvedKey = PZLinuxGetMailEntry(player, mailId)
    if not inventory or not md or not mail or tonumber(mail.status) ~= 2 then
        return { ok = false, reason = "invalid_mail" }
    end

    local requestedFullType = tostring(mail.object or "")
    local requestedQuantity = math.max(0, math.floor(tonumber(mail.quantity) or 0))
    if requestedFullType == "" or requestedQuantity <= 0 or not PZLinuxIsValidFullType(requestedFullType) then
        return { ok = false, reason = "invalid_mail_item" }
    end

    if not PZLinuxCanContainerReceiveItem(inventory, player, "Base.Present_ExtraLarge") then
        return { ok = false, reason = "no_room" }
    end

    local matches = PZLinuxCollectInventoryItemsByFullTypes(player, requestedFullType)
    if #matches < requestedQuantity then
        return { ok = false, reason = "missing_items", required = requestedQuantity, found = #matches }
    end

    local removedSnapshots = {}
    local removedCount = 0
    for i = 1, requestedQuantity do
        local item = matches[i]
        local snapshot = PZLinuxBuildItemRestoreSnapshot(item)
        if snapshot and PZLinuxSafeRemoveItem(inventory, item) then
            removedCount = removedCount + 1
            table.insert(removedSnapshots, snapshot)
        end
    end

    if removedCount < requestedQuantity then
        PZLinuxRestoreItemSnapshots(inventory, removedSnapshots)
        return { ok = false, reason = "remove_failed", required = requestedQuantity, removed = removedCount }
    end

    local createdItem = PZLinuxCreateInventoryPackage(inventory, "Base.Present_ExtraLarge", {
        displayName = "A gift to thank you",
        contents = PZLinuxBuildMailGiftContents(),
    })
    if not createdItem then
        PZLinuxRestoreItemSnapshots(inventory, removedSnapshots)
        return { ok = false, reason = "create_failed" }
    end

    mail.status = 10
    md.pzlinux.player.reputation = (tonumber(md.pzlinux.player.reputation) or 1) + 10

    return {
        ok = true,
        mailId = resolvedKey or mailId,
        removedCount = removedCount,
    }
end

function PZLinuxBuildPackageContentsFromBatch(batchWrapper)
    local packageContents = {}
    if type(batchWrapper) ~= "table" then
        return packageContents
    end

    local batch = batchWrapper[1]
    if type(batch) ~= "table" or type(batch.items) ~= "table" then
        return packageContents
    end

    for _, item in ipairs(batch.items) do
        if type(item) == "table" and type(item.name) == "string" and item.name ~= "" and PZLinuxIsValidFullType(item.name) then
            table.insert(packageContents, item.name)
        end
    end

    return packageContents
end

function PZLinuxNormalizeFullTypeList(itemIds)
    local normalized = {}
    local seen = {}

    local function append(fullType)
        if type(fullType) ~= "string" or fullType == "" or not PZLinuxIsValidFullType(fullType) then
            return
        end

        if seen[fullType] then
            return
        end

        seen[fullType] = true
        table.insert(normalized, fullType)
    end

    if type(itemIds) == "table" then
        for _, fullType in ipairs(itemIds) do
            append(fullType)
        end
    else
        append(itemIds)
    end

    return normalized
end

function PZLinuxIsItemInMainInventory(playerObj, item)
    local player = PZLinuxGetPlayer(playerObj)
    if not player or not item or not item.getContainer or not player.getInventory then
        return false
    end

    local ok, itemContainer = pcall(function()
        return item:getContainer()
    end)
    if not ok or not itemContainer then
        return false
    end

    local playerInventory = player:getInventory()
    if itemContainer == playerInventory then
        return true
    end

    local okContainingItem, containingItem = pcall(function()
        return itemContainer.getContainingItem and itemContainer:getContainingItem() or nil
    end)
    if okContainingItem and containingItem ~= nil then
        return false
    end

    local okOutermost, outermostContainer = pcall(function()
        return item.getOutermostContainer and item:getOutermostContainer() or nil
    end)
    if okOutermost and outermostContainer and outermostContainer ~= playerInventory then
        return false
    end

    return itemContainer == playerInventory
end

function PZLinuxDarkWebIsSellableItem(playerObj, item)
    return item
        and item.getFullType
        and PZLinuxIsItemInMainInventory(playerObj, item)
        and not PZLinuxIsEquippedInventoryItem(playerObj, item)
end

function PZLinuxInventoryItemMatchesFullTypes(playerObj, item, fullTypes)
    if not PZLinuxDarkWebIsSellableItem(playerObj, item) then
        return false
    end

    local normalized = PZLinuxNormalizeFullTypeList(fullTypes)
    if #normalized == 0 then
        return false
    end

    local itemFullType = item:getFullType()
    for _, fullType in ipairs(normalized) do
        if itemFullType == fullType then
            return true
        end
    end

    return false
end

function PZLinuxCollectInventoryItemsByFullTypes(playerObj, fullTypes)
    local player = PZLinuxGetPlayer(playerObj)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory then
        return {}
    end

    local matches = {}
    local items = inventory:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if PZLinuxInventoryItemMatchesFullTypes(player, item, fullTypes) then
            table.insert(matches, item)
        end
    end

    return matches
end

function PZLinuxCountInventoryItemsByFullTypes(playerObj, fullTypes)
    return #PZLinuxCollectInventoryItemsByFullTypes(playerObj, fullTypes)
end

function PZLinuxFindDarkWebItemEntryByFullTypes(fullTypes)
    local normalized = PZLinuxNormalizeFullTypeList(fullTypes)
    if #normalized == 0 or type(PZLinuxDarkWebItemsTable) ~= "table" then
        return nil
    end

    for _, entry in ipairs(PZLinuxDarkWebItemsTable) do
        local entryIds = PZLinuxNormalizeFullTypeList(entry and entry.id or nil)
        for _, fullType in ipairs(normalized) do
            for _, entryFullType in ipairs(entryIds) do
                if fullType == entryFullType then
                    return entry
                end
            end
        end
    end

    return nil
end

function PZLinuxCalculateDarkWebSellUnitPrice(playerObj, entry)
    if type(entry) ~= "table" then
        return 0
    end

    local player = PZLinuxGetPlayer(playerObj)
    local perkLevel = player and player.getPerkLevel and player:getPerkLevel(Perks.PlantScavenging) or 0
    local sellMinMultiplier = 0.25 + (0.025 * perkLevel)
    local sellMaxMultiplier = 0.50 + (0.025 * perkLevel)
    local sandbox = SandboxVars and SandboxVars.PZLinux or nil
    local sandboxMultiplier = sandbox and tonumber(sandbox.SalePriceMultiplier) or 1.0
    local basePrice = math.max(0, tonumber(entry.Price) or 0)
    if basePrice <= 0 then
        return 0
    end
    if PZLinuxEconomyNormalizeBasePrice then
        basePrice = PZLinuxEconomyNormalizeBasePrice(basePrice)
    end

    local worldAgeHours = getGameTime and getGameTime():getWorldAgeHours() or 0
    local worldDay = math.max(1, math.floor((tonumber(worldAgeHours) or 0) / 24) + 1)
    local normalizedIds = PZLinuxNormalizeFullTypeList(entry.id)
    local seedSource = table.concat(normalizedIds, "|") .. "|" .. tostring(player and player.getUsername and player:getUsername() or "player") .. "|" .. tostring(worldDay)

    local hash = 0
    for i = 1, #seedSource do
        hash = (hash * 33 + string.byte(seedSource, i)) % 2147483647
    end

    local spread = math.max(0, sellMaxMultiplier - sellMinMultiplier)
    local ratio = (hash % 10000) / 9999
    local priceMultiplier = sellMinMultiplier + (spread * ratio)
    local price = math.max(0, math.ceil(basePrice * priceMultiplier * sandboxMultiplier))
    if PZLinuxEconomyApplyDemandPrice and PZLinuxEconomyBuildItemDemandKey then
        price = PZLinuxEconomyApplyDemandPrice(price, PZLinuxEconomyBuildItemDemandKey(entry.id))
    end
    return price
end

function PZLinuxGetSuspiciousPackageAmount(item)
    local modData = PZLinuxSafeGetItemModData(item)
    if modData and tonumber(modData.PZLinuxSuspiciousPackageAmount) then
        return math.max(0, math.floor(tonumber(modData.PZLinuxSuspiciousPackageAmount) or 0))
    end

    if not item or not item.getName then
        return 0
    end

    local displayName = tostring(item:getName() or ""):gsub("%$", "")
    return math.max(0, math.floor(tonumber(displayName) or 0))
end

function PZLinuxCreateInventoryPackage(container, packageFullType, options)
    if not container or type(packageFullType) ~= "string" or packageFullType == "" then
        return nil
    end

    local packageItem = PZLinuxSafeAddItem(container, packageFullType)
    if not packageItem then
        return nil
    end

    options = options or {}

    if type(options.displayName) == "string" and options.displayName ~= "" then
        PZLinuxSafeSetItemName(packageItem, options.displayName)
    end

    if type(options.deliveryType) == "string" and options.deliveryType ~= "" then
        PZLinuxMarkContractDeliveryItem(packageItem, options.deliveryType)
    end

    if type(options.itemModData) == "table" then
        local itemModData = PZLinuxSafeGetItemModData(packageItem)
        if itemModData then
            for key, value in pairs(options.itemModData) do
                itemModData[key] = value
            end
        end
    end

    if type(options.contents) == "table" and #options.contents > 0 then
        local packageInventory = PZLinuxSafeGetItemInventory(packageItem)
        if not packageInventory then
            PZLinuxSafeRemoveItem(container, packageItem)
            return nil
        end

        for _, contentEntry in ipairs(options.contents) do
            local contentFullType = nil
            local contentCount = 1

            if type(contentEntry) == "string" then
                contentFullType = contentEntry
            elseif type(contentEntry) == "table" then
                contentFullType = tostring(contentEntry.fullType or contentEntry.name or "")
                contentCount = math.max(1, math.floor(tonumber(contentEntry.count) or 1))
            end

            if type(contentFullType) == "string" and contentFullType ~= "" and PZLinuxIsValidFullType(contentFullType) then
                if contentCount > 1 and packageInventory.AddItems then
                    local ok = pcall(function()
                        packageInventory:AddItems(contentFullType, contentCount)
                    end)
                    if not ok then
                        for _ = 1, contentCount do
                            PZLinuxSafeAddItem(packageInventory, contentFullType)
                        end
                    end
                else
                    for _ = 1, contentCount do
                        PZLinuxSafeAddItem(packageInventory, contentFullType)
                    end
                end
            end
        end
    end

    PZLinuxNotifyAddedContainerItem(container, packageItem)

    return packageItem
end

function PZLinuxCreateOrRequestInventoryPackage(playerObj, packageFullType, options)
    local player = PZLinuxGetPlayer(playerObj)
    if not player or not player.getInventory then
        return false
    end

    local inventory = player:getInventory()
    if not PZLinuxCanContainerReceiveItem(inventory, player, packageFullType) then
        return false
    end

    options = options or {}
    if isClient() then
        local args = {
            packageType = packageFullType,
            displayName = options.displayName,
            deliveryType = options.deliveryType,
            itemModData = type(options.itemModData) == "table" and options.itemModData or nil,
            contents = {},
        }

        if type(options.contents) == "table" then
            for _, contentEntry in ipairs(options.contents) do
                if type(contentEntry) == "string" and PZLinuxIsValidFullType(contentEntry) then
                    table.insert(args.contents, contentEntry)
                elseif type(contentEntry) == "table" then
                    local fullType = tostring(contentEntry.fullType or contentEntry.name or "")
                    local count = math.max(1, math.floor(tonumber(contentEntry.count) or 1))
                    if fullType ~= "" and PZLinuxIsValidFullType(fullType) then
                        table.insert(args.contents, {
                            fullType = fullType,
                            count = count,
                        })
                    end
                end
            end
        end

        sendClientCommand(PZLinuxModule, "CreateInventoryPackage", args)
        return true
    end

    return PZLinuxCreateInventoryPackage(inventory, packageFullType, options) ~= nil
end

function PZLinuxCreateOrRequestItemStacks(playerObj, itemStacks)
    local player = PZLinuxGetPlayer(playerObj)
    if not player or not player.getInventory or type(itemStacks) ~= "table" then
        return false
    end

    if isClient() then
        -- Inventory stacks are created only by authoritative server features.
        -- A generic client command would allow arbitrary item IDs/counts.
        return false
    end

    local inventory = player:getInventory()
    local createdAny = false
    for _, entry in ipairs(itemStacks) do
        local fullType = type(entry) == "table" and tostring(entry.fullType or "") or ""
        local count = math.max(0, math.floor(tonumber(type(entry) == "table" and entry.count or 0) or 0))
        if fullType ~= "" and count > 0 and PZLinuxIsValidFullType(fullType) then
            for _ = 1, count do
                local item = PZLinuxSafeAddItem(inventory, fullType)
                if item then
                    if type(entry.displayName) == "string" and entry.displayName ~= "" then
                        PZLinuxSafeSetItemName(item, entry.displayName)
                    end
                    if type(entry.itemModData) == "table" then
                        local itemModData = PZLinuxSafeGetItemModData(item)
                        if itemModData then
                            for key, value in pairs(entry.itemModData) do
                                itemModData[key] = value
                            end
                        end
                    end
                    PZLinuxNotifyAddedContainerItem(inventory, item)
                    createdAny = true
                end
            end
        end
    end

    return createdAny
end

function PZLinuxResetContractState(playerObj)
    local md = PZLinuxGetModData(playerObj)
    if not md then return nil end

    md.PZLinuxContractLocationX = 0
    md.PZLinuxContractLocationY = 0
    md.PZLinuxContractLocationZ = 0
    md.PZLinuxContractLocationLabel = ""
    md.PZLinuxOnZombieDead = 0
    md.PZLinuxActiveContract = 0
    md.PZLinuxContractNote = ""
    md.PZLinuxContractInfo = ""
    md.PZLinuxContractInfoCount = 0
    md.PZLinuxContractKillZombie = 0
    md.PZLinuxContractPickUp = 0
    md.PZLinuxContractManhunt = 0
    md.PZLinuxContractBlood = 0
    md.PZLinuxContractCar = 0
    md.PZLinuxContractCapture = 0
    md.PZLinuxContractCargo = 0
    md.PZLinuxContractProtect = 0
    md.PZLinuxContractMedical = 0
    md.PZLinuxContractWeapon = 0
    md.PZLinuxContractSendComputer = 0
    md.PZLinuxContractSendFridge = 0

    return md
end

function PZLinuxBuildContractDisplayText(playerObj)
    local md = PZLinuxGetModData(playerObj)
    if not md then
        return ""
    end

    local lines = {}
    if md.PZLinuxContractLocationLabel ~= "" then
        table.insert(lines, md.PZLinuxContractLocationLabel)
    end

    if md.PZLinuxContractNote ~= "" then
        table.insert(lines, md.PZLinuxContractNote)
    end

    if (tonumber(md.PZLinuxContractKillZombie) or 0) == 1 then
        local targetKills = tonumber(md.PZLinuxOnZombieToKill) or 0
        if targetKills > 0 then
            table.insert(lines, PZLinuxText("UI_PZLinux_ZombiesToKill", "Zombies to kill: %s", tostring(targetKills)))
        end
    end

    local totalKills = tonumber(md.PZLinuxOnZombieDead) or 0
    if totalKills > 0 then
        table.insert(lines, PZLinuxText("UI_PZLinux_TotalZombiesKilled", "Total zombies killed: %s", tostring(totalKills)))
    end

    return table.concat(lines, "\n")
end

local function PZLinuxEscapeTextReplacement(value)
    return tostring(value == nil and "" or value):gsub("%%", "%%%%")
end

local function PZLinuxApplyTextArgs(text, args)
    local result = tostring(text or "")
    if type(args) ~= "table" or #args == 0 then
        return result
    end

    for i, value in ipairs(args) do
        local replacement = PZLinuxEscapeTextReplacement(value)
        result = result:gsub("%%" .. tostring(i) .. "%$[a-zA-Z]", replacement)
        result = result:gsub("%%" .. tostring(i), replacement)
    end

    if result:find("%%s") then
        local ok, formatted = pcall(function()
            return string.format(result, unpackArgs(args))
        end)
        if ok and formatted then
            result = formatted
        end
    end

    return result
end

function PZLinuxText(key, fallback, ...)
    local args = { ... }
    local translated = PZLinuxSafeGetText(key)
    if not translated and fallback then
        return PZLinuxApplyTextArgs(fallback, args)
    end

    return PZLinuxApplyTextArgs(translated or tostring(key or ""), args)
end

function PZLinuxTextLines(key, fallbackLines, ...)
    local fallbackText = ""
    if type(fallbackLines) == "table" then
        fallbackText = table.concat(fallbackLines, "\n")
    elseif fallbackLines ~= nil then
        fallbackText = tostring(fallbackLines)
    end

    local args = { ... }
    local translated
    if #args > 0 then
        translated = PZLinuxText(key, fallbackText, unpackArgs(args))
    else
        translated = PZLinuxText(key, fallbackText)
    end
    translated = tostring(translated or ""):gsub("\r\n", "\n")

    local lines = {}
    for line in (translated .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end

    if #lines == 0 then
        lines[1] = ""
    end

    return lines
end

local function PZLinuxBootstrapPlayer()
    local player = getPlayer()
    if player then
        PZLinuxGetModData(player)
    end
end

Events.OnGameStart.Add(PZLinuxBootstrapPlayer)
