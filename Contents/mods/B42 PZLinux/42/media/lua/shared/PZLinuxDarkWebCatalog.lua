require "AAA_PZLinuxCompat"
require "PZLinuxEconomy"

PZLinuxDarkWebCatalog = PZLinuxDarkWebCatalog or {}

local Catalog = PZLinuxDarkWebCatalog

Catalog.GlobalTag = "PZLinuxDarkWebCatalog"
Catalog.Version = 1
Catalog.CycleHours = 24
Catalog.MaxOffers = 2
Catalog.LargeBoxFullType = "Base.Parcel_Large"
Catalog.GoldValue = 10000

Catalog.Definitions = {
    {
        key = "arm_box",
        nameKey = "UI_PZLinux_DarkWebArmBox",
        fallbackName = "Arm Box",
        kind = "box",
        pool = "firearm",
        minCount = 1,
        maxCount = 1,
        priceGold = 350,
    },
    {
        key = "white_arm_box",
        nameKey = "UI_PZLinux_DarkWebWhiteArmBox",
        fallbackName = "WhiteArm - Box",
        kind = "box",
        pool = "melee",
        minCount = 1,
        maxCount = 1,
        priceGold = 350,
    },
    {
        key = "food_box",
        nameKey = "UI_PZLinux_DarkWebFoodBox",
        fallbackName = "Food Box",
        kind = "box",
        pool = "food",
        minCount = 1,
        maxCount = 5,
        priceGold = 5,
    },
    {
        key = "medicinal_box",
        nameKey = "UI_PZLinux_DarkWebMedicinalBox",
        fallbackName = "Medicinal Box",
        kind = "box",
        pool = "medical",
        minCount = 1,
        maxCount = 5,
        priceGold = 200,
    },
    {
        key = "tool_box",
        nameKey = "UI_PZLinux_DarkWebToolBox",
        fallbackName = "Ferramenta",
        kind = "box",
        pool = "tool",
        minCount = 1,
        maxCount = 1,
        priceGold = 250,
    },
    {
        key = "craft_box",
        nameKey = "UI_PZLinux_DarkWebCraftBox",
        fallbackName = "Craft Box",
        kind = "box",
        pool = "craft",
        minCount = 1,
        maxCount = 1,
        priceGold = 150,
    },
    {
        key = "saw",
        nameKey = "UI_PZLinux_DarkWebSaw",
        fallbackName = "Serra",
        kind = "item",
        fullType = "Base.Saw",
        priceGold = 250,
    },
    {
        key = "wrench",
        nameKey = "UI_PZLinux_DarkWebWrench",
        fallbackName = "Chave Inglesa",
        kind = "item",
        fullType = "Base.Wrench",
        priceGold = 200,
    },
    {
        key = "welding_mask",
        nameKey = "UI_PZLinux_DarkWebWeldingMask",
        fallbackName = "Mascara de Solda",
        kind = "item",
        fullType = "Base.WeldingMask",
        priceGold = 250,
    },
    {
        key = "blow_torch",
        nameKey = "UI_PZLinux_DarkWebBlowTorch",
        fallbackName = "Macarico",
        kind = "item",
        fullType = "Base.BlowTorch",
        priceGold = 250,
    },
    {
        key = "sledgehammer",
        nameKey = "UI_PZLinux_DarkWebSledgehammer",
        fallbackName = "Marreta Mao",
        kind = "item",
        fullType = "Base.Sledgehammer",
        priceGold = 300,
    },
    {
        key = "rubber_hose",
        nameKey = "UI_PZLinux_DarkWebRubberHose",
        fallbackName = "Mangueira de Borracha",
        kind = "item",
        fullType = "Base.RubberHose",
        priceGold = 500,
    },
    {
        key = "battery_charger",
        nameKey = "UI_PZLinux_DarkWebBatteryCharger",
        fallbackName = "Carregador de Bateria",
        kind = "item",
        fullType = "Base.CarBatteryCharger",
        priceGold = 1000,
    },
    {
        key = "engine_parts",
        nameKey = "UI_PZLinux_DarkWebEngineParts",
        fallbackName = "Peca de Reposicao",
        kind = "item",
        fullType = "Base.EngineParts",
        priceGold = 150,
    },
    {
        key = "standard_battery",
        nameKey = "UI_PZLinux_DarkWebStandardBattery",
        fallbackName = "Bateria Popular",
        kind = "item",
        fullType = "Base.CarBattery1",
        priceGold = 100,
    },
    {
        key = "sport_battery",
        nameKey = "UI_PZLinux_DarkWebSportBattery",
        fallbackName = "Bateria Esportivo",
        kind = "item",
        fullType = "Base.CarBattery3",
        priceGold = 95,
    },
    {
        key = "heavy_battery",
        nameKey = "UI_PZLinux_DarkWebHeavyBattery",
        fallbackName = "Bateria Pesado",
        kind = "item",
        fullType = "Base.CarBattery2",
        priceGold = 100,
    },
}

local FALLBACK_POOLS = {
    firearm = {
        "Base.Pistol",
        "Base.Pistol2",
        "Base.Pistol3",
        "Base.Revolver",
        "Base.Revolver_Short",
        "Base.Revolver_Long",
        "Base.Shotgun",
        "Base.DoubleBarrelShotgun",
        "Base.VarmintRifle",
        "Base.HuntingRifle",
    },
    melee = {
        "Base.Axe",
        "Base.BaseballBat",
        "Base.Crowbar",
        "Base.HuntingKnife",
        "Base.Katana",
        "Base.KitchenKnife",
        "Base.Machete",
        "Base.Sledgehammer",
        "Base.SpearLong",
    },
    food = {
        "Base.TinnedBeans",
        "Base.CannedCorn",
        "Base.CannedPeas",
        "Base.CannedSardines",
        "Base.Cereal",
        "Base.Chocolate",
        "Base.Crisps",
        "Base.TunaTin",
    },
    medical = {
        "Base.AlcoholWipes",
        "Base.Bandage",
        "Base.Disinfectant",
        "Base.Pills",
        "Base.Antibiotics",
        "Base.SutureNeedle",
    },
    tool = {
        "Base.BlowTorch",
        "Base.Hammer",
        "Base.Saw",
        "Base.Screwdriver",
        "Base.Wrench",
    },
    craft = {
        "Base.Log",
        "Base.Plank",
        "Base.SharpedStone",
        "Base.Stone2",
        "Base.Twine",
        "Base.WoodenStick2",
    },
}

local DEFINITION_BY_KEY = {}
for _, definition in ipairs(Catalog.Definitions) do
    DEFINITION_BY_KEY[definition.key] = definition
end

local cachedPools = nil

local function getSandbox()
    return SandboxVars and SandboxVars.PZLinux or {}
end

local function safeCall(object, methodName, fallback)
    if not object or type(methodName) ~= "string" then
        return fallback
    end

    local method = object[methodName]
    if not method then
        return fallback
    end

    local ok, value = pcall(method, object)
    if ok then
        return value
    end

    return fallback
end

local function appendUnique(pool, seen, fullType)
    if type(fullType) ~= "string" or fullType == "" or seen[fullType] then
        return
    end
    if not PZLinuxIsValidFullType(fullType) then
        return
    end

    seen[fullType] = true
    pool[#pool + 1] = fullType
end

local function isUnsafeWeaponCategory(category)
    return category == "explosives"
        or category == "junkweapon"
        or category == "materialweapon"
        or category == "fishing"
end

local function isCraftCategory(category)
    return category == "material"
        or category == "materialcrafted"
        or category == "naturalitem"
        or category == "crafting"
end

local function buildPools()
    local pools = {
        firearm = {},
        melee = {},
        food = {},
        medical = {},
        tool = {},
        craft = {},
    }
    local seen = {
        firearm = {},
        melee = {},
        food = {},
        medical = {},
        tool = {},
        craft = {},
    }

    local scriptManager = PZLinuxGetScriptManager()
    local allItems = scriptManager and scriptManager.getAllItems and scriptManager:getAllItems() or nil
    if allItems then
        for index = 0, allItems:size() - 1 do
            local item = allItems:get(index)
            local fullType = tostring(safeCall(item, "getFullName", "") or "")
            local itemType = string.lower(tostring(safeCall(item, "getItemType", "") or ""))
            local category = string.lower(tostring(safeCall(item, "getDisplayCategory", "") or ""))
            local obsolete = safeCall(item, "getObsolete", false) == true
            local canSpawn = safeCall(item, "canSpawnAsLoot", false) == true
            local isBaseItem = string.sub(fullType, 1, 5) == "Base."
            local isBrokenPart = string.find(string.lower(fullType), "broken", 1, true) ~= nil
                or string.find(string.lower(fullType), "barehands", 1, true) ~= nil
                or string.find(string.lower(fullType), "_head", 1, true) ~= nil

            if isBaseItem and canSpawn and not obsolete and not isBrokenPart then
                local ranged = safeCall(item, "isRanged", false) == true
                local weapon = string.find(itemType, "weapon", 1, true) ~= nil
                local medical = safeCall(item, "isMedicalLoot", false) == true
                local tool = safeCall(item, "isToolLoot", false) == true

                if weapon and ranged then
                    appendUnique(pools.firearm, seen.firearm, fullType)
                elseif weapon and not ranged and not isUnsafeWeaponCategory(category) then
                    appendUnique(pools.melee, seen.melee, fullType)
                end

                if string.find(itemType, "food", 1, true) then
                    appendUnique(pools.food, seen.food, fullType)
                end
                if medical then
                    appendUnique(pools.medical, seen.medical, fullType)
                end
                if tool and not ranged then
                    appendUnique(pools.tool, seen.tool, fullType)
                end
                if isCraftCategory(category) then
                    appendUnique(pools.craft, seen.craft, fullType)
                end
            end
        end
    end

    for poolKey, fallbackItems in pairs(FALLBACK_POOLS) do
        if #pools[poolKey] == 0 then
            for _, fullType in ipairs(fallbackItems) do
                appendUnique(pools[poolKey], seen[poolKey], fullType)
            end
        end
    end

    return pools
end

function Catalog.IsSharedEnabled()
    return PZLinuxConfig.IsEnabled("DarkWeb") and PZLinuxConfig.Get("DarkWebSharedCatalogEnabled")
end

function Catalog.GetDefinition(key)
    return DEFINITION_BY_KEY[tostring(key or "")]
end

function Catalog.GetPrice(definition)
    if type(definition) ~= "table" then
        return 0
    end

    local multiplier = math.max(0.1, tonumber(getSandbox().PurchasePriceMultiplier) or 1)
    local gold = math.max(0, tonumber(definition.priceGold) or 0)
    return math.max(1, math.floor((gold * Catalog.GoldValue * multiplier) + 0.5))
end

function Catalog.GetDemandKey(definition)
    if type(definition) == "table" then
        return "darkweb:" .. tostring(definition.key or "unknown")
    end
    return "darkweb:" .. tostring(definition or "unknown")
end

function Catalog.GetOfferPrice(definition)
    local price = Catalog.GetPrice(definition)
    if PZLinuxEconomyApplyDemandPrice then
        price = PZLinuxEconomyApplyDemandPrice(price, Catalog.GetDemandKey(definition))
    end
    return math.max(1, math.floor((tonumber(price) or 1) + 0.5))
end

function Catalog.GetPools()
    if not cachedPools then
        cachedPools = buildPools()
    end
    return cachedPools
end

function Catalog.ResetPools()
    cachedPools = nil
end

function Catalog.GetDisplayName(offerOrDefinition)
    local definition = offerOrDefinition
    if type(offerOrDefinition) == "table" and offerOrDefinition.definitionKey then
        definition = Catalog.GetDefinition(offerOrDefinition.definitionKey)
    end
    if type(definition) ~= "table" then
        return PZLinuxText("UI_PZLinux_UnknownItem", "Unknown Item")
    end

    return PZLinuxText(definition.nameKey, definition.fallbackName)
end

function Catalog.GetIconFullType(definition)
    if type(definition) ~= "table" then
        return Catalog.LargeBoxFullType
    end
    if definition.kind == "box" then
        return Catalog.LargeBoxFullType
    end
    return definition.fullType or Catalog.LargeBoxFullType
end

function Catalog.RollContents(definition)
    if type(definition) ~= "table" then
        return {}
    end

    if definition.kind == "item" then
        if PZLinuxIsValidFullType(definition.fullType) then
            return {
                {
                    fullType = definition.fullType,
                    count = 1,
                },
            }
        end
        return {}
    end

    local pools = Catalog.GetPools()
    local pool = pools[definition.pool] or {}
    if #pool == 0 then
        return {}
    end

    local minCount = math.max(1, math.floor(tonumber(definition.minCount) or 1))
    local maxCount = math.max(minCount, math.floor(tonumber(definition.maxCount) or minCount))
    local rollCount = minCount
    if maxCount > minCount then
        rollCount = ZombRand(minCount, maxCount + 1)
    end

    local counts = {}
    local order = {}
    for _ = 1, rollCount do
        local fullType = pool[ZombRand(#pool) + 1]
        if fullType then
            if not counts[fullType] then
                counts[fullType] = 0
                order[#order + 1] = fullType
            end
            counts[fullType] = counts[fullType] + 1
        end
    end

    local contents = {}
    for _, fullType in ipairs(order) do
        contents[#contents + 1] = {
            fullType = fullType,
            count = counts[fullType],
        }
    end
    return contents
end

function Catalog.BuildClientOffer(offer)
    if type(offer) ~= "table" then
        return nil
    end

    local definition = Catalog.GetDefinition(offer.definitionKey)
    if not definition then
        return nil
    end

    return {
        id = tostring(offer.id or ""),
        definitionKey = definition.key,
        displayName = Catalog.GetDisplayName(definition),
        item = {
            id = Catalog.GetIconFullType(definition),
        },
        itemKey = Catalog.GetDemandKey(definition),
        price = Catalog.GetOfferPrice(definition),
        transactionType = "Buy",
        transactionQty = 1,
        shared = true,
    }
end

function Catalog.GetDirectDeliveryStacks(batchWrapper)
    if type(batchWrapper) ~= "table" then
        return nil
    end

    local batch = batchWrapper[1]
    if type(batch) ~= "table" or batch.directDelivery ~= true or type(batch.items) ~= "table" then
        return nil
    end

    local stacks = {}
    for _, entry in ipairs(batch.items) do
        local fullType = type(entry) == "table" and tostring(entry.name or entry.fullType or "") or ""
        local count = math.max(0, math.floor(tonumber(type(entry) == "table" and entry.count or 0) or 0))
        if fullType ~= "" and count > 0 and PZLinuxIsValidFullType(fullType) then
            stacks[#stacks + 1] = {
                fullType = fullType,
                count = count,
            }
        end
    end

    return #stacks > 0 and stacks or nil
end

function Catalog.HasDirectDelivery(modData)
    if type(modData) ~= "table" or type(modData.PZLinuxOnItemBuyOnDarkWeb) ~= "table" then
        return false
    end

    for _, batchWrapper in ipairs(modData.PZLinuxOnItemBuyOnDarkWeb) do
        if Catalog.GetDirectDeliveryStacks(batchWrapper) then
            return true
        end
    end
    return false
end

function PZLinuxDarkWebHasDirectDelivery(modData)
    return Catalog.HasDirectDelivery(modData)
end
