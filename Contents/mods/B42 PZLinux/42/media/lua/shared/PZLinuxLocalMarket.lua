require "AAA_PZLinuxCompat"
require "PZLinuxEconomy"

-- Core compartilhado do Mercado Local.
-- Este arquivo NAO deve criar UI: ele carrega tanto no client quanto no server.
-- Aqui ficam apenas regras puras, nomes, categorias e snapshots usados pelos dois lados.
PZLinuxLocalMarket = PZLinuxLocalMarket or {}

-- Tags usadas pelo ModData global. O server salva os anuncios nessas chaves.
PZLinuxLocalMarket.DataTag = PZLinuxLocalMarket.DataTag or "PZLinuxLocalMarket"
PZLinuxLocalMarket.VehicleRegistryTag = PZLinuxLocalMarket.VehicleRegistryTag or "PZLinuxLocalMarketVehicles"
PZLinuxLocalMarket.MaxDescriptionLength = PZLinuxLocalMarket.MaxDescriptionLength or 180

-- Cada categoria usa chave de traducao, mas mantem fallback para nao quebrar
-- caso alguma traducao falte no JSON.
local CATEGORY_KEYS = {
    all = { key = "UI_PZLinux_All", fallback = "All" },
    items = { key = "UI_PZLinux_LocalMarketItems", fallback = "Items" },
    food = { key = "UI_PZLinux_LocalMarketFood", fallback = "Food" },
    weapons = { key = "UI_PZLinux_LocalMarketWeapons", fallback = "Weapons" },
    vehicles = { key = "UI_PZLinux_LocalMarketVehicles", fallback = "Vehicles" },
}

local VALID_CATEGORIES = {
    all = true,
    items = true,
    food = true,
    weapons = true,
    vehicles = true,
}

-- Classificacao simples por palavras-chave. Isso evita depender demais de
-- classes Java especificas, que podem variar entre itens vanilla/modded.
local FOOD_KEYWORDS = {
    "food",
    "drink",
    "water",
    "canned",
    "meat",
    "fish",
    "fruit",
    "vegetable",
    "mushroom",
    "berry",
    "bread",
    "soup",
    "stew",
    "rice",
    "pasta",
    "wine",
    "beer",
    "soda",
    "juice",
}

local WEAPON_KEYWORDS = {
    "weapon",
    "ammo",
    "bullet",
    "shell",
    "magazine",
    "pistol",
    "revolver",
    "rifle",
    "shotgun",
    "gun",
    "axe",
    "knife",
    "machete",
    "sword",
    "spear",
    "crowbar",
    "sledgehammer",
    "bat",
}

-- Wrapper de texto seguro: tenta PZLinuxText, depois getText, e por ultimo fallback.
local function marketText(key, fallback, ...)
    local args = { ... }
    local unpackArgs = table.unpack or unpack
    if PZLinuxText then
        return PZLinuxText(key, fallback, unpackArgs(args))
    end
    if getText then
        local ok, text = pcall(function()
            return getText(key, unpackArgs(args))
        end)
        if ok and text and text ~= key then
            return text
        end
    end
    return fallback
end

-- Limpa texto vindo de input do jogador antes de salvar no ModData.
local function sanitizeString(value)
    local text = tostring(value or "")
    text = text:gsub("[%c]", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

-- Copia apenas tipos serializaveis. O ModData nao deve receber objetos Java,
-- funcoes ou userdata, porque isso pode quebrar persistencia/sync.
local function cloneValue(value, seen)
    local valueType = type(value)
    if valueType ~= "table" then
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            return value
        end
        return nil
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, nestedValue in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            local cloned = cloneValue(nestedValue, seen)
            if cloned ~= nil then
                copy[key] = cloned
            end
        end
    end
    return copy
end

-- Chamada defensiva para getters Java/Lua. Mods diferentes podem remover ou
-- trocar metodos, entao pcall evita derrubar o mercado por um item/veiculo ruim.
local function callStringGetter(object, methodName)
    if not object or not object[methodName] then
        return nil
    end
    local ok, value = pcall(function()
        return object[methodName](object)
    end)
    if ok and value ~= nil and tostring(value) ~= "" then
        return tostring(value)
    end
    return nil
end

-- Igual ao getter de string, mas normaliza para number.
local function callNumberGetter(object, methodName)
    if not object or not object[methodName] then
        return nil
    end
    local ok, value = pcall(function()
        return object[methodName](object)
    end)
    if ok and tonumber(value) ~= nil then
        return tonumber(value)
    end
    return nil
end

-- Usado na classificacao por palavras-chave.
local function textContainsAny(text, keywords)
    text = tostring(text or ""):lower()
    for _, keyword in ipairs(keywords) do
        if text:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

-- API publica usada pelo server antes de enviar dados ao client.
function PZLinuxLocalMarket.cloneTable(value)
    return cloneValue(value, {})
end

-- Preco e quantidade sempre sao inteiros positivos para evitar exploit/NaN.
function PZLinuxLocalMarket.normalizePrice(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return 0 end
    return math.max(0, math.floor(number))
end

function PZLinuxLocalMarket.normalizeQuantity(value, maxQuantity)
    local quantity = math.max(1, math.floor(tonumber(value) or 1))
    if maxQuantity ~= nil then
        quantity = math.min(quantity, math.max(1, math.floor(tonumber(maxQuantity) or 1)))
    end
    return quantity
end

function PZLinuxLocalMarket.sanitizeDescription(value)
    local text = sanitizeString(value)
    local maxLength = math.max(1, math.floor(tonumber(PZLinuxLocalMarket.MaxDescriptionLength) or 180))
    if #text > maxLength then
        text = text:sub(1, maxLength)
    end
    return text
end

-- Normaliza singular/plural e protege contra categoria desconhecida.
function PZLinuxLocalMarket.normalizeCategory(category)
    local value = tostring(category or "items"):lower()
    if value == "item" then
        value = "items"
    elseif value == "weapon" then
        value = "weapons"
    elseif value == "vehicle" then
        value = "vehicles"
    end
    if not VALID_CATEGORIES[value] then
        value = "items"
    end
    return value
end

-- Texto final da categoria que aparece na UI.
function PZLinuxLocalMarket.categoryText(category)
    local normalized = PZLinuxLocalMarket.normalizeCategory(category)
    local entry = CATEGORY_KEYS[normalized] or CATEGORY_KEYS.items
    return marketText(entry.key, entry.fallback)
end

-- Dinheiro fisico e moedas legadas nao podem ser anunciados como itens normais no mercado.
function PZLinuxLocalMarket.isCoin(fullType)
    if PZLinuxEconomyIsCoin then
        return PZLinuxEconomyIsCoin(fullType)
    end
    local value = tostring(fullType or "")
    return value == "Base.Money" or value == "Base.MoneyBundle"
        or value == "Base.CobreCoin" or value == "Base.SilverCoin" or value == "Base.GoldCoin"
end

-- Nome estavel do jogador. Em multiplayer usa username; em singleplayer cai
-- para displayName quando necessario.
function PZLinuxLocalMarket.getUsername(player)
    if not player then
        return nil
    end
    local username = callStringGetter(player, "getUsername")
    if username and username ~= "" then
        return username
    end
    username = callStringGetter(player, "getDisplayName")
    if username and username ~= "" then
        return username
    end
    username = callStringGetter(player, "getDescriptor")
    if username and username ~= "" then
        return username
    end
    return nil
end

-- Nome exibido do item no anuncio e no historico de venda.
function PZLinuxLocalMarket.getItemDisplayName(item, fallback)
    local name = callStringGetter(item, "getDisplayName")
    if name then
        return name
    end
    name = callStringGetter(item, "getName")
    if name then
        return name
    end
    return tostring(fallback or marketText("UI_PZLinux_UnknownItem", "Unknown Item"))
end

-- Decide em qual aba o item aparece. Primeiro usa sinais obvios no nome/tipo,
-- depois tenta categoria do script item.
function PZLinuxLocalMarket.classifyItem(item, fullType)
    local typeName = tostring(fullType or (item and item.getFullType and item:getFullType()) or ""):lower()
    local category = callStringGetter(item, "getCategory")
    local displayName = PZLinuxLocalMarket.getItemDisplayName(item, typeName)
    local combined = typeName .. " " .. tostring(category or ""):lower() .. " " .. tostring(displayName or ""):lower()

    if textContainsAny(combined, WEAPON_KEYWORDS) then
        return "weapons"
    end
    if textContainsAny(combined, FOOD_KEYWORDS) then
        return "food"
    end

    local scriptItem = item and item.getScriptItem and item:getScriptItem() or nil
    local scriptCategory = callStringGetter(scriptItem, "getTypeString") or callStringGetter(scriptItem, "getDisplayCategory")
    scriptCategory = tostring(scriptCategory or ""):lower()
    if scriptCategory == "weapon" or scriptCategory == "weapons" then
        return "weapons"
    end
    if scriptCategory == "food" or scriptCategory == "drainable" then
        return "food"
    end

    return "items"
end

-- Nome legivel do veiculo para listagem. Preferimos VehicleScript fullName
-- porque costuma ser mais amigavel do que o scriptName cru.
function PZLinuxLocalMarket.getVehicleDisplayName(vehicle)
    local script = vehicle and vehicle.getScript and vehicle:getScript() or nil
    local name = callStringGetter(script, "getFullName")
        or callStringGetter(script, "getName")
        or callStringGetter(vehicle, "getScriptName")
        or callStringGetter(vehicle, "getName")
    return sanitizeString(name or marketText("UI_PZLinux_LocalMarketVehicle", "Vehicle"))
end

-- ID unico do anuncio. Inclui vendedor, timestamp e aleatorio para reduzir
-- colisao mesmo se dois anuncios forem criados no mesmo segundo.
function PZLinuxLocalMarket.buildListingId(username)
    local safeUser = sanitizeString(username or "seller"):gsub("[^%w_%-]", "_")
    local now = os.time and os.time() or 0
    local randomPart = ZombRand and ZombRand(100000, 999999) or math.random(100000, 999999)
    return string.format("%s-%s-%s", safeUser, tostring(now), tostring(randomPart))
end

-- Snapshot serializavel do veiculo. O server guarda somente dados simples para
-- a UI e para transferencia futura; o objeto BaseVehicle real nunca vai ao ModData.
function PZLinuxLocalMarket.getVehicleSnapshot(vehicle)
    local snapshot = {
        name = PZLinuxLocalMarket.getVehicleDisplayName(vehicle),
    }

    if not vehicle then
        return snapshot
    end

    snapshot.vehicleId = callNumberGetter(vehicle, "getId")
    snapshot.x = callNumberGetter(vehicle, "getX")
    snapshot.y = callNumberGetter(vehicle, "getY")
    snapshot.z = callNumberGetter(vehicle, "getZ")

    local script = vehicle.getScript and vehicle:getScript() or nil
    snapshot.scriptName = callStringGetter(vehicle, "getScriptName") or callStringGetter(script, "getName")
    snapshot.scriptFullName = callStringGetter(script, "getFullName") or snapshot.scriptName
    snapshot.engineCondition = callNumberGetter(vehicle, "getEngineCondition")
    snapshot.engineQuality = callNumberGetter(vehicle, "getEngineQuality")
    snapshot.engineLoudness = callNumberGetter(vehicle, "getEngineLoudness")
    snapshot.mass = callNumberGetter(vehicle, "getMass")

    if vehicle.getModData then
        local modData = vehicle:getModData()
        if type(modData) == "table" then
            snapshot.vgid = modData.JC_VID or modData.vgid or snapshot.vgid
        end
    end

    -- Calcula condicao media e pecas ausentes lendo as partes atuais do carro.
    if vehicle.getPartCount and vehicle.getPartByIndex then
        local ok, count = pcall(function()
            return vehicle:getPartCount()
        end)
        if ok and tonumber(count) then
            local missing = 0
            local totalCondition = 0
            local conditionCount = 0
            for index = 0, tonumber(count) - 1 do
                local part = vehicle:getPartByIndex(index)
                if part then
                    if part.getCondition then
                        local condition = tonumber(part:getCondition())
                        if condition then
                            totalCondition = totalCondition + condition
                            conditionCount = conditionCount + 1
                        end
                    end
                    if part.getInventoryItem and not part:getInventoryItem() then
                        missing = missing + 1
                    end
                end
            end
            snapshot.missingParts = missing
            if conditionCount > 0 then
                snapshot.condition = math.floor(totalCondition / conditionCount)
            end
        end
    end

    return snapshot
end
