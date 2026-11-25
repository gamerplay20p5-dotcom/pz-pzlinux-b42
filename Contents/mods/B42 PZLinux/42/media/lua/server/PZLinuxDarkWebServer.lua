if isClient() then return end

require "PZLinuxDarkWebCatalog"

local Catalog = PZLinuxDarkWebCatalog
local MODULE = PZLinuxModule or "PZLinux"

local function getCatalogData()
    if not ModData or not ModData.getOrCreate then
        return nil
    end

    local data = ModData.getOrCreate(Catalog.GlobalTag)
    data.offers = type(data.offers) == "table" and data.offers or {}
    return data
end

local function getCurrentCycle()
    local worldAgeHours = getGameTime and getGameTime():getWorldAgeHours() or 0
    return math.max(0, math.floor((tonumber(worldAgeHours) or 0) / PZLinuxConfig.Get("DarkWebRefreshHours")))
end

local function getCurrentHour()
    local worldAgeHours = getGameTime and getGameTime():getWorldAgeHours() or 0
    return math.max(0, math.floor(tonumber(worldAgeHours) or 0))
end

local function buildSnapshot()
    local data = getCatalogData()
    if not data then
        return {
            version = Catalog.Version,
            cycle = getCurrentCycle(),
            offers = {},
        }
    end

    return {
        version = Catalog.Version,
        cycle = math.max(0, math.floor(tonumber(data.cycle) or getCurrentCycle())),
        refreshAtHour = math.max(0, math.floor(tonumber(data.refreshAtHour) or (getCurrentHour() + PZLinuxConfig.Get("DarkWebRefreshHours")))),
        offers = PZLinuxCloneSerializableTable(data.offers) or {},
    }
end

local function transmitCatalog()
    if ModData and ModData.transmit then
        ModData.transmit(Catalog.GlobalTag)
    end
end

local function replyToPlayer(player, command, payload)
    if isServer() and player and sendServerCommand then
        sendServerCommand(player, MODULE, command, payload or {})
        return
    end

    if command == "DarkWebCatalogData" and PZLinuxDarkWebOnCatalogData then
        PZLinuxDarkWebOnCatalogData(payload or {})
    elseif command == "DarkWebPurchaseResult" and PZLinuxDarkWebOnPurchaseResult then
        PZLinuxDarkWebOnPurchaseResult(payload or {})
    elseif command == "DarkWebDeliveryResult" and PZLinuxDarkWebOnDeliveryResult then
        PZLinuxDarkWebOnDeliveryResult(payload or {})
    end
end

local function broadcastCatalog()
    local snapshot = buildSnapshot()
    if not isServer() or not getOnlinePlayers then
        replyToPlayer(getPlayer and getPlayer() or nil, "DarkWebCatalogData", snapshot)
        return
    end

    local players = getOnlinePlayers()
    if not players then
        return
    end

    for index = 0, players:size() - 1 do
        replyToPlayer(players:get(index), "DarkWebCatalogData", snapshot)
    end
end

local function syncPlayer(player)
    if player and player.transmitModData then
        player:transmitModData()
    end
end

local function ensureBankBalance(modData)
    if type(modData) ~= "table" then
        return 0
    end
    if tonumber(modData.PZLinuxBank) == nil then
        modData.PZLinuxBank = PZLinuxConfig.NewBankBalance()
    end
    modData.PZLinuxBank = math.max(0, math.floor(tonumber(modData.PZLinuxBank) or 0))
    return modData.PZLinuxBank
end

local function buildDefinitionCandidates()
    local candidates = {}
    for _, definition in ipairs(Catalog.Definitions) do
        if definition.kind == "box" or PZLinuxIsValidFullType(definition.fullType) then
            candidates[#candidates + 1] = definition
        end
    end
    return candidates
end

local function refreshCatalog()
    if not Catalog.IsSharedEnabled() then
        return false
    end

    local data = getCatalogData()
    if not data then
        return false
    end

    local nowHour = getCurrentHour()
    local refreshAtHour = tonumber(data.refreshAtHour)
    if tonumber(data.version) == Catalog.Version
        and refreshAtHour ~= nil
        and nowHour < refreshAtHour
    then
        return false
    end

    local cycle = math.max(0, math.floor(tonumber(data.cycle) or (getCurrentCycle() - 1))) + 1
    local candidates = buildDefinitionCandidates()
    local offers = {}
    local offerCount = math.min(PZLinuxConfig.Get("DarkWebMaxOffers"), #candidates)
    for slot = 1, offerCount do
        local candidateIndex = ZombRand(#candidates) + 1
        local definition = table.remove(candidates, candidateIndex)
        offers[#offers + 1] = {
            id = tostring(cycle) .. ":" .. tostring(slot) .. ":" .. definition.key,
            definitionKey = definition.key,
            price = Catalog.GetOfferPrice(definition),
        }
    end

    data.version = Catalog.Version
    data.cycle = cycle
    data.refreshAtHour = nowHour + PZLinuxConfig.Get("DarkWebRefreshHours")
    data.offers = offers
    transmitCatalog()
    return true
end

local function findOffer(data, offerId)
    if type(data) ~= "table" or type(data.offers) ~= "table" then
        return nil, nil
    end

    local wantedId = tostring(offerId or "")
    for index, offer in ipairs(data.offers) do
        if type(offer) == "table" and tostring(offer.id or "") == wantedId then
            return offer, index
        end
    end
    return nil, nil
end

local function queueDirectDelivery(modData, offer, contents)
    if type(modData) ~= "table" or type(contents) ~= "table" or #contents == 0 then
        return false
    end

    modData.PZLinuxOnItemBuyOnDarkWeb = type(modData.PZLinuxOnItemBuyOnDarkWeb) == "table"
        and modData.PZLinuxOnItemBuyOnDarkWeb
        or {}

    local batch = {
        directDelivery = true,
        offerId = tostring(offer.id or ""),
        items = {},
    }
    for _, entry in ipairs(contents) do
        local fullType = type(entry) == "table" and tostring(entry.fullType or "") or ""
        local count = math.max(0, math.floor(tonumber(type(entry) == "table" and entry.count or 0) or 0))
        if fullType ~= "" and count > 0 and PZLinuxIsValidFullType(fullType) then
            batch.items[#batch.items + 1] = {
                name = fullType,
                count = count,
            }
        end
    end

    if #batch.items == 0 then
        return false
    end

    modData.PZLinuxOnItemBuyOnDarkWebStatus = 1
    table.insert(modData.PZLinuxOnItemBuyOnDarkWeb, { batch })
    return true
end

function PZLinuxDarkWebServerRequestCatalog(player)
    if not Catalog.IsSharedEnabled() then
        replyToPlayer(player, "DarkWebCatalogData", {
            version = Catalog.Version,
            cycle = getCurrentCycle(),
            offers = {},
            disabled = true,
        })
        return
    end

    if refreshCatalog() then
        broadcastCatalog()
    else
        replyToPlayer(player, "DarkWebCatalogData", buildSnapshot())
    end
end

function PZLinuxDarkWebServerBuyOffer(player, args)
    if not PZLinuxConfig.IsEnabled("DarkWeb") then
        replyToPlayer(player, "DarkWebPurchaseResult", { ok = false, reason = "disabled" }); return
    end
    if not player or type(args) ~= "table" then
        return
    end

    if not Catalog.IsSharedEnabled() then
        replyToPlayer(player, "DarkWebPurchaseResult", { ok = false, reason = "disabled" })
        return
    end

    local changed = refreshCatalog()
    if changed then
        broadcastCatalog()
    end

    local data = getCatalogData()
    local offer, offerIndex = findOffer(data, args.offerId)
    if not offer then
        replyToPlayer(player, "DarkWebPurchaseResult", {
            ok = false,
            reason = "offer_unavailable",
            catalog = buildSnapshot(),
        })
        return
    end

    local definition = Catalog.GetDefinition(offer.definitionKey)
    if not definition then
        replyToPlayer(player, "DarkWebPurchaseResult", {
            ok = false,
            reason = "invalid_offer",
            catalog = buildSnapshot(),
        })
        return
    end

    local modData = PZLinuxGetModData(player)
    local balance = ensureBankBalance(modData)
    local price = Catalog.GetOfferPrice(definition)
    if balance < price then
        replyToPlayer(player, "DarkWebPurchaseResult", {
            ok = false,
            reason = "not_enough_money",
            balance = balance,
            catalog = buildSnapshot(),
        })
        return
    end

    local contents = Catalog.RollContents(definition)
    if #contents == 0 or not queueDirectDelivery(modData, offer, contents) then
        replyToPlayer(player, "DarkWebPurchaseResult", {
            ok = false,
            reason = "create_failed",
            balance = balance,
            catalog = buildSnapshot(),
        })
        return
    end

    modData.PZLinuxBank = balance - price
    table.remove(data.offers, offerIndex)
    syncPlayer(player)
    transmitCatalog()
    PZLinuxEconomyRecordDemand(Catalog.GetDemandKey(definition), "up", 1, true)

    local snapshot = buildSnapshot()
    replyToPlayer(player, "DarkWebPurchaseResult", {
        ok = true,
        offerId = tostring(offer.id or ""),
        balance = modData.PZLinuxBank,
        catalog = snapshot,
    })
    broadcastCatalog()
end

local getDirectDeliveryStacks = Catalog.GetDirectDeliveryStacks

function PZLinuxDarkWebServerClaimDeliveries(player, args)
    if not player then
        return
    end

    local modData = PZLinuxGetModData(player)
    local queue = modData and modData.PZLinuxOnItemBuyOnDarkWeb or nil
    if type(queue) ~= "table" or #queue == 0 then
        replyToPlayer(player, "DarkWebDeliveryResult", { ok = false, reason = "no_delivery" })
        return
    end

    local canBeStolen = type(args) == "table" and args.canBeStolen == true
    if canBeStolen and ZombRand(10000) < PZLinuxConfig.Get("DarkWebDeliveryTheftChance") * 100 then
        for index = #queue, 1, -1 do
            if getDirectDeliveryStacks(queue[index]) then
                table.remove(queue, index)
            end
        end
        modData.PZLinuxOnItemBuyOnDarkWebStatus = #queue > 0 and 1 or 0
        syncPlayer(player)
        replyToPlayer(player, "DarkWebDeliveryResult", { ok = false, reason = "stolen" })
        return
    end

    local deliveredBatches = 0
    local deliveredItems = 0
    for index = #queue, 1, -1 do
        local stacks = getDirectDeliveryStacks(queue[index])
        if stacks then
            local itemCount = 0
            for _, stack in ipairs(stacks) do
                itemCount = itemCount + stack.count
            end

            if PZLinuxCreateOrRequestItemStacks(player, stacks) == true then
                table.remove(queue, index)
                deliveredBatches = deliveredBatches + 1
                deliveredItems = deliveredItems + itemCount
            end
        end
    end

    modData.PZLinuxOnItemBuyOnDarkWebStatus = #queue > 0 and 1 or 0
    syncPlayer(player)
    replyToPlayer(player, "DarkWebDeliveryResult", {
        ok = deliveredBatches > 0,
        reason = deliveredBatches > 0 and nil or "create_failed",
        deliveredBatches = deliveredBatches,
        deliveredItems = deliveredItems,
    })
end

local COMMANDS = {
    RequestDarkWebCatalog = function(player)
        PZLinuxDarkWebServerRequestCatalog(player)
    end,
    BuyDarkWebOffer = PZLinuxDarkWebServerBuyOffer,
    ClaimDarkWebDeliveries = PZLinuxDarkWebServerClaimDeliveries,
}

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player or (args ~= nil and type(args) ~= "table") then return end

    local handler = COMMANDS[command]
    if handler then
        handler(player, args or {})
    end
end

local function onEveryHour()
    if refreshCatalog() then
        broadcastCatalog()
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.EveryHours.Add(onEveryHour)
