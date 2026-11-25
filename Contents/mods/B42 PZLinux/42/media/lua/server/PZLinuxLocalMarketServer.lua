if isClient() then return end

require "AAA_PZLinuxCompat"
require "PZLinuxEconomy"
require "PZLinuxLocalMarket"

local MODULE = PZLinuxModule or "PZLinux"

-- Server do Mercado Local.
-- Toda validacao importante fica aqui: dinheiro, dono do item/carro,
-- entrega, cancelamento e persistencia no ModData global.

-- Envia uma resposta direcionada para um jogador.
local function replyToPlayer(player, command, payload)
    if player and sendServerCommand then
        sendServerCommand(player, MODULE, command, payload or {})
    end
end

-- Sincroniza modData do jogador depois de mudar banco/pending/etc.
local function syncPlayer(player)
    if player and player.transmitModData then
        player:transmitModData()
    end
end

-- Banco de dados persistente do mercado. Em server real usa ModData global;
-- em fallback local usa uma tabela em memoria.
local function getMarketData()
    if ModData and ModData.getOrCreate then
        local data = ModData.getOrCreate(PZLinuxLocalMarket.DataTag)
        data.listings = type(data.listings) == "table" and data.listings or {}
        data.pendingCredits = type(data.pendingCredits) == "table" and data.pendingCredits or {}
        data.saleNotices = type(data.saleNotices) == "table" and data.saleNotices or {}
        return data
    end
    PZLinuxLocalMarket.LocalData = PZLinuxLocalMarket.LocalData or { listings = {}, pendingCredits = {}, saleNotices = {} }
    return PZLinuxLocalMarket.LocalData
end

-- Replica o ModData global para clients.
local function transmitMarketData()
    if ModData and ModData.transmit then
        ModData.transmit(PZLinuxLocalMarket.DataTag)
    end
end

-- Garante que o jogador tenha saldo inicial e que ele sempre seja inteiro.
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

-- Busca vendedor online para creditar venda imediatamente quando possivel.
local function findOnlinePlayer(username)
    if not username or not getOnlinePlayers then
        return nil
    end
    local players = getOnlinePlayers()
    if not players then
        return nil
    end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        local playerUsername = PZLinuxLocalMarket.getUsername(player)
        if playerUsername and playerUsername:lower() == tostring(username):lower() then
            return player
        end
    end
    return nil
end

-- Creditos pendentes existem para vendas feitas quando o vendedor estava offline.
-- Ao abrir/atualizar o mercado, o server aplica esse valor no banco dele.
local function applyPendingCredits(player)
    local username = PZLinuxLocalMarket.getUsername(player)
    if not username then
        return 0
    end

    local data = getMarketData()
    local pending = math.max(0, math.floor(tonumber(data.pendingCredits[username]) or 0))
    if pending <= 0 then
        return 0
    end

    local modData = PZLinuxGetModData(player)
    ensureBankBalance(modData)
    modData.PZLinuxBank = modData.PZLinuxBank + pending
    data.pendingCredits[username] = nil
    syncPlayer(player)
    transmitMarketData()
    return pending
end

-- Guarda aviso de venda para ser mostrado quando o vendedor voltar.
local function queueSaleNotice(username, notice)
    if not username or type(notice) ~= "table" then
        return
    end

    local data = getMarketData()
    data.saleNotices[username] = type(data.saleNotices[username]) == "table" and data.saleNotices[username] or {}
    table.insert(data.saleNotices[username], notice)
end

-- Entrega e limpa avisos de venda pendentes do jogador.
local function takeSaleNotices(player)
    local username = PZLinuxLocalMarket.getUsername(player)
    if not username then
        return {}
    end

    local data = getMarketData()
    local notices = data.saleNotices[username]
    if type(notices) ~= "table" or #notices == 0 then
        return {}
    end

    data.saleNotices[username] = nil
    transmitMarketData()
    return notices
end

-- Estrutura simples enviada ao client para mostrar halo/notice de venda.
local function buildSaleNotice(listing, buyer, price)
    if type(listing) ~= "table" then
        return nil
    end

    return {
        itemName = tostring(listing.name or listing.fullType or "item"),
        buyer = tostring(buyer or "?"),
        amount = math.max(0, math.floor(tonumber(price) or 0)),
        listingType = tostring(listing.type or "item"),
        time = os.time(),
    }
end

-- Credita o vendedor. Online recebe agora; offline recebe pendingCredits.
local function creditSeller(username, amount, notice)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not username or amount <= 0 then
        return
    end

    local onlinePlayer = findOnlinePlayer(username)
    if onlinePlayer then
        local modData = PZLinuxGetModData(onlinePlayer)
        ensureBankBalance(modData)
        modData.PZLinuxBank = modData.PZLinuxBank + amount
        syncPlayer(onlinePlayer)
        if notice then
            notice.balance = modData.PZLinuxBank
            replyToPlayer(onlinePlayer, "LocalMarketSellerNotice", notice)
        end
        return
    end

    local data = getMarketData()
    data.pendingCredits[username] = math.max(0, math.floor(tonumber(data.pendingCredits[username]) or 0)) + amount
    queueSaleNotice(username, notice)
end

-- Snapshot enviado ao client: clones serializaveis dos anuncios atuais.
local function buildSnapshot()
    local data = getMarketData()
    local listings = {}
    for _, listing in pairs(data.listings) do
        if type(listing) == "table" and listing.id and listing.seller then
            table.insert(listings, PZLinuxLocalMarket.cloneTable(listing) or listing)
        end
    end
    table.sort(listings, function(left, right)
        return tostring(left.createdAt or "") > tostring(right.createdAt or "")
    end)
    return { listings = listings }
end

-- Envia estado completo do mercado mais saldo e avisos do jogador.
local function sendMarketData(player)
    local pendingCredit = applyPendingCredits(player)
    local snapshot = buildSnapshot()
    local modData = PZLinuxGetModData(player)
    snapshot.pendingCredit = pendingCredit
    snapshot.balance = ensureBankBalance(modData)
    snapshot.saleNotices = takeSaleNotices(player)
    replyToPlayer(player, "LocalMarketData", snapshot)
end

-- Resposta padrao para qualquer acao do mercado, seguida de refresh dos dados.
local function sendResult(player, ok, reason, extra)
    local payload = extra or {}
    payload.ok = ok == true
    payload.reason = reason
    replyToPlayer(player, "LocalMarketResult", payload)
    replyToPlayer(player, "LocalMarketData", buildSnapshot())
end

-- Helpers de inventario usados para impedir venda de containers com conteudo
-- ou itens que nao estejam no inventario principal.
local function countInventoryItems(container)
    if not container or not container.getItems then
        return 0
    end
    local ok, items = pcall(function()
        return container:getItems()
    end)
    if not ok or not items then
        return 0
    end
    return items:size()
end

local function itemHasContainedItems(item)
    local itemInventory = PZLinuxSafeGetItemInventory and PZLinuxSafeGetItemInventory(item) or nil
    return itemInventory and countInventoryItems(itemInventory) > 0
end

local function itemIsInMainInventory(item, inventory)
    if not item or not inventory or not item.getContainer then
        return false
    end
    local ok, container = pcall(function()
        return item:getContainer()
    end)
    return ok and container == inventory
end

-- Captura estado do item antes de remove-lo do vendedor. Isso permite entregar
-- o mesmo item ao comprador e restaurar condicao, ammo, modData, nome custom etc.
local function snapshotItem(item)
    if not item or not item.getFullType then
        return nil
    end

    local fullType = item:getFullType()
    local snapshot = {
        fullType = fullType,
        displayName = PZLinuxLocalMarket.getItemDisplayName(item, fullType),
        itemModData = PZLinuxLocalMarket.cloneTable(PZLinuxSafeGetItemModData(item) or nil),
    }

    if item.getConditionMax then
        local ok, conditionMax = pcall(function()
            return item:getConditionMax()
        end)
        if ok then
            snapshot.conditionMax = math.max(0, math.floor(tonumber(conditionMax) or 0))
        end
    end

    -- Ainda guardamos modelScript/icon no snapshot para compatibilidade com
    -- anuncios antigos/UI futura, mas o client atual nao renderiza item 3D.
    local function readModel(methodName)
        if not item[methodName] then
            return nil
        end
        local ok, value = pcall(function()
            return item[methodName](item)
        end)
        if ok and value and tostring(value) ~= "" then
            return tostring(value)
        end
        return nil
    end

    snapshot.modelScript = readModel("getWorldStaticModel") or readModel("getStaticModel")

    local scriptItem = item.getScriptItem and item:getScriptItem() or nil
    if not snapshot.modelScript and scriptItem then
        if scriptItem.getWorldStaticModel then
            snapshot.modelScript = tostring(scriptItem:getWorldStaticModel() or "")
        end
        if (not snapshot.modelScript or snapshot.modelScript == "") and scriptItem.getStaticModel then
            snapshot.modelScript = tostring(scriptItem:getStaticModel() or "")
        end
    end

    if scriptItem and scriptItem.getIcon then
        snapshot.icon = tostring(scriptItem:getIcon() or "")
    end

    if item.getCondition then
        local ok, condition = pcall(function()
            return item:getCondition()
        end)
        if ok then
            snapshot.condition = math.max(0, math.floor(tonumber(condition) or 0))
        end
    end

    if item.getUsedDelta then
        local ok, usedDelta = pcall(function()
            return item:getUsedDelta()
        end)
        if ok then
            snapshot.usedDelta = tonumber(usedDelta) or nil
        end
    end

    if item.getCurrentAmmoCount then
        local ok, currentAmmo = pcall(function()
            return item:getCurrentAmmoCount()
        end)
        if ok then
            snapshot.currentAmmo = math.max(0, math.floor(tonumber(currentAmmo) or 0))
        end
    end

    if item.isRoundChambered then
        local ok, roundChambered = pcall(function()
            return item:isRoundChambered()
        end)
        if ok then
            snapshot.roundChambered = roundChambered == true
        end
    end

    if item.isJammed then
        local ok, jammed = pcall(function()
            return item:isJammed()
        end)
        if ok then
            snapshot.jammed = jammed == true
        end
    end

    return snapshot
end

-- Reaplica o snapshot em um item criado no inventario do comprador/vendedor.
local function applyItemSnapshot(item, snapshot)
    if not item or type(snapshot) ~= "table" then
        return
    end

    if type(snapshot.displayName) == "string" and snapshot.displayName ~= "" then
        PZLinuxSafeSetItemName(item, snapshot.displayName)
    end

    if type(snapshot.itemModData) == "table" then
        local itemModData = PZLinuxSafeGetItemModData(item)
        if itemModData then
            for key, value in pairs(snapshot.itemModData) do
                itemModData[key] = value
            end
        end
    end

    if snapshot.condition ~= nil and item.setCondition then
        pcall(function()
            item:setCondition(math.max(0, math.floor(tonumber(snapshot.condition) or 0)))
        end)
    end

    if snapshot.usedDelta ~= nil and item.setUsedDelta then
        pcall(function()
            item:setUsedDelta(tonumber(snapshot.usedDelta) or 0)
        end)
    end

    if snapshot.currentAmmo ~= nil and item.setCurrentAmmoCount then
        pcall(function()
            item:setCurrentAmmoCount(math.max(0, math.floor(tonumber(snapshot.currentAmmo) or 0)))
        end)
    end

    if snapshot.roundChambered ~= nil and item.setRoundChambered then
        pcall(function()
            item:setRoundChambered(snapshot.roundChambered == true)
        end)
    end

    if snapshot.jammed ~= nil and item.setJammed then
        pcall(function()
            item:setJammed(snapshot.jammed == true)
        end)
    end
end

-- Cria o item de volta no inventario do jogador e restaura seus dados.
local function restoreItemToPlayer(player, snapshot)
    if not player or type(snapshot) ~= "table" or not snapshot.fullType then
        return nil
    end

    local inventory = player:getInventory()
    if not inventory then
        return nil
    end

    if PZLinuxCanContainerReceiveItem and not PZLinuxCanContainerReceiveItem(inventory, player, snapshot.fullType) then
        return nil
    end

    local item = PZLinuxSafeAddItem(inventory, snapshot.fullType)
    if not item then
        return nil
    end

    applyItemSnapshot(item, snapshot)
    if PZLinuxNotifyAddedContainerItem then
        PZLinuxNotifyAddedContainerItem(inventory, item)
    end
    return item
end

-- Compatibilidade com anuncios antigos que tinham item unico em listing.item.
local function getListingItemSnapshots(listing)
    if type(listing) ~= "table" then
        return {}
    end
    if type(listing.items) == "table" and #listing.items > 0 then
        return listing.items
    end
    if type(listing.item) == "table" then
        return { listing.item }
    end
    return {}
end

-- Restaura varios itens; se qualquer um falhar, desfaz os ja adicionados.
local function restoreSnapshotsToPlayer(player, snapshots)
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory then
        return false
    end

    local addedItems = {}
    for _, snapshot in ipairs(snapshots or {}) do
        local item = restoreItemToPlayer(player, snapshot)
        if not item then
            for _, addedItem in ipairs(addedItems) do
                PZLinuxSafeRemoveItem(inventory, addedItem)
            end
            return false
        end
        addedItems[#addedItems + 1] = item
    end
    return true
end

-- Rollback critico: usado se remover item do vendedor falhar no meio do processo.
local function rollbackRemovedSnapshots(player, snapshots)
    if not restoreSnapshotsToPlayer(player, snapshots) then
        print("PZLinuxLocalMarket: critical rollback failure for " .. tostring(PZLinuxLocalMarket.getUsername(player)))
    end
end

-- Localiza veiculo carregado no mundo pelo VGID do JeevesClaims.
local function findVehicleByVGID(vgid)
    if not vgid or not getCell then
        return nil
    end

    local cell = getCell()
    local vehicles = {}
    if JeevesClaims and JeevesClaims.listCellVehicles then
        vehicles = JeevesClaims.listCellVehicles(cell)
    elseif cell and cell.getVehicles then
        local rawVehicles = cell:getVehicles()
        if rawVehicles then
            for index = 0, rawVehicles:size() - 1 do
                table.insert(vehicles, rawVehicles:get(index))
            end
        end
    end

    for _, vehicle in ipairs(vehicles) do
        if vehicle and vehicle.getModData then
            local vehicleData = vehicle:getModData()
            if vehicleData and tostring(vehicleData.JC_VID or "") == tostring(vgid) then
                return vehicle
            end
        end
    end
    return nil
end

-- O client pode mandar VGID ou vehicleId. Esta funcao resolve para BaseVehicle.
local function findVehicleByArgs(args)
    if type(args) ~= "table" then
        return nil, nil
    end

    local vgid = tostring(args.vgid or "")
    if vgid ~= "" then
        local vehicle = findVehicleByVGID(vgid)
        if vehicle then
            return vehicle, vgid
        end
    end

    local vehicleId = tonumber(args.vehicleId)
    if vehicleId == nil or vehicleId < 0 or not getVehicleById then
        return nil, nil
    end

    local ok, vehicle = pcall(function()
        return getVehicleById(vehicleId)
    end)
    if not ok or not vehicle then
        return nil, nil
    end

    if JeevesClaims and JeevesClaims.getVehicleVGID then
        return vehicle, JeevesClaims.getVehicleVGID(vehicle)
    end

    local vehicleData = vehicle.getModData and vehicle:getModData() or nil
    return vehicle, vehicleData and vehicleData.JC_VID or nil
end

-- Registro persistente de donos de veiculo usado pelo sistema de claims.
local function getVehicleRegistry()
    if ModData and ModData.getOrCreate then
        return ModData.getOrCreate(PZLinuxLocalMarket.VehicleRegistryTag)
    end
    return nil
end

-- Normaliza chave do dono no registry para lidar com diferenca de caixa/nome.
local function findRegistryOwnerKey(registry, username)
    if type(registry) ~= "table" or not username then
        return username
    end
    if registry[username] then
        return username
    end
    for key, _ in pairs(registry) do
        if JeevesClaims and JeevesClaims.isSameUsername and JeevesClaims.isSameUsername(key, username) then
            return key
        end
        if tostring(key):lower() == tostring(username):lower() then
            return key
        end
    end
    return username
end

-- Conta claims atuais para respeitar limite do JeevesClaims.
local function getVehicleClaimCount(username)
    local registry = getVehicleRegistry()
    local ownerKey = findRegistryOwnerKey(registry, username)
    local list = registry and registry[ownerKey] or nil
    local count = 0
    if type(list) == "table" then
        for _, _ in pairs(list) do
            count = count + 1
        end
    end
    return count
end

-- Transfere o claim do veiculo do vendedor para o comprador e sincroniza markers.
local function transferVehicleClaim(vehicle, vgid, seller, buyer)
    if not vehicle or not vgid or not seller or not buyer then
        return false
    end
    if not JeevesClaims or not JeevesClaims.setVehicleOwner then
        return false
    end

    local registry = getVehicleRegistry()
    if type(registry) == "table" then
        local sellerKey = findRegistryOwnerKey(registry, seller)
        local buyerKey = findRegistryOwnerKey(registry, buyer)
        if registry[sellerKey] then
            registry[sellerKey][tostring(vgid)] = nil
        end
        registry[buyerKey] = registry[buyerKey] or {}
        registry[buyerKey][tostring(vgid)] = {
            x = vehicle.getX and math.floor(vehicle:getX()) or 0,
            y = vehicle.getY and math.floor(vehicle:getY()) or 0,
            z = vehicle.getZ and math.floor(vehicle:getZ()) or 0,
            name = PZLinuxLocalMarket.getVehicleDisplayName(vehicle),
        }
        if ModData and ModData.transmit then
            ModData.transmit(PZLinuxLocalMarket.VehicleRegistryTag)
        end
    end

    JeevesClaims.setVehicleOwner(vehicle, buyer)
    if vehicle.transmitModData then
        pcall(function() vehicle:transmitModData() end)
    end
    if JeevesClaims.syncVehicleMarkersForUser then
        JeevesClaims.syncVehicleMarkersForUser(seller)
        JeevesClaims.syncVehicleMarkersForUser(buyer)
    end
    return true
end

-- Impede anunciar o mesmo carro duas vezes.
local function isListingVehicleAlreadyListed(vgid)
    local data = getMarketData()
    for _, listing in pairs(data.listings) do
        if type(listing) == "table" and listing.type == "vehicle" and listing.vehicle and tostring(listing.vehicle.vgid or "") == tostring(vgid) then
            return true
        end
    end
    return false
end

local function requestLocalMarket(player)
    sendMarketData(player)
end

-- Impacta a economia dinamica quando itens/veiculos saem ou entram no mercado.
local function recordLocalMarketItemDemand(fullType, direction, quantity)
    if not PZLinuxEconomyRecordDemand or not PZLinuxEconomyBuildItemDemandKey then
        return
    end

    PZLinuxEconomyRecordDemand(PZLinuxEconomyBuildItemDemandKey(fullType), direction, quantity, true)
end

local function recordLocalMarketVehicleDemand(vehicleInfo, direction)
    if not PZLinuxEconomyRecordDemand then
        return
    end

    local key = tostring(vehicleInfo and (vehicleInfo.scriptFullName or vehicleInfo.scriptName or vehicleInfo.vgid) or "unknown")
    PZLinuxEconomyRecordDemand("localmarket:vehicle:" .. key, direction, 1, true)
end

-- Deposita dinheiro fisico do inventario no banco PZLinux.
local function depositCoins(player, args)
    if not player then
        return
    end

    local requestedAmount = nil
    if type(args) == "table" and tostring(args.amount or "") ~= "all" then
        requestedAmount = math.floor(tonumber(args.amount) or 0)
    end

    local counts = PZLinuxEconomyGetInventoryCoinCounts(player)
    local amount = requestedAmount and math.min(requestedAmount, counts.value) or counts.value
    if amount <= 0 then
        replyToPlayer(player, "DepositCoinsResult", { ok = false, reason = "no_money" })
        return
    end

    local result = PZLinuxEconomyRemoveCoinValueFromInventory(player, amount)
    if not result or not result.ok then
        replyToPlayer(player, "DepositCoinsResult", { ok = false, reason = "remove_failed", available = counts.value })
        return
    end

    local modData = PZLinuxGetModData(player)
    ensureBankBalance(modData)
    modData.PZLinuxBank = modData.PZLinuxBank + amount
    syncPlayer(player)

    replyToPlayer(player, "DepositCoinsResult", {
        ok = true,
        amount = amount,
        balance = modData.PZLinuxBank,
    })
end

-- Primeiro passo da venda de item: valida e grava um "pending listing".
-- O item real so sai do inventario quando o jogador deposita na mailbox.
local function listLocalMarketItem(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local seller = PZLinuxLocalMarket.getUsername(player)
    local fullType = tostring(args.fullType or "")
    local price = PZLinuxLocalMarket.normalizePrice(args.price)
    local quantity = PZLinuxLocalMarket.normalizeQuantity(args.quantity)
    local description = PZLinuxLocalMarket.sanitizeDescription(args.description)
    if not seller or fullType == "" or price <= 0 or PZLinuxLocalMarket.isCoin(fullType) then
        sendResult(player, false, "invalid_item")
        return
    end

    local matches = PZLinuxCollectInventoryItemsByFullTypes(player, fullType)
    local inventory = player:getInventory()
    local candidates = {}
    for _, candidate in ipairs(matches) do
        if candidate
            and candidate.getFullType
            and candidate:getFullType() == fullType
            and itemIsInMainInventory(candidate, inventory)
            and not PZLinuxIsEquippedInventoryItem(player, candidate)
            and not itemHasContainedItems(candidate)
        then
            candidates[#candidates + 1] = candidate
            if #candidates >= quantity then
                break
            end
        end
    end

    local item = candidates[1]
    if not item or #candidates < quantity then
        sendResult(player, false, "item_not_available")
        return
    end

    local category = PZLinuxLocalMarket.classifyItem(item, fullType)
    if args.category then
        local requestedCategory = PZLinuxLocalMarket.normalizeCategory(args.category)
        if requestedCategory ~= "vehicles" then
            category = requestedCategory
        end
    end

    local modData = PZLinuxGetModData(player)
    modData.PZLinuxPendingLocalMarketListing = {
        type = "item",
        category = category,
        seller = seller,
        fullType = fullType,
        price = price,
        quantity = quantity,
        description = description,
        preparedAt = os.time(),
    }
    syncPlayer(player)
    sendResult(player, true, nil, {
        pending = true,
        quantity = quantity,
        fullType = fullType,
    })
end

-- Segundo passo da venda de item: remove os itens, salva snapshots e publica.
local function completePendingLocalMarketItem(player)
    if not player then
        return
    end

    local modData = PZLinuxGetModData(player)
    local pending = modData and modData.PZLinuxPendingLocalMarketListing or nil
    if type(pending) ~= "table" or pending.type ~= "item" then
        sendResult(player, false, "no_pending_listing")
        return
    end

    local seller = PZLinuxLocalMarket.getUsername(player)
    local fullType = tostring(pending.fullType or "")
    local price = PZLinuxLocalMarket.normalizePrice(pending.price)
    local quantity = PZLinuxLocalMarket.normalizeQuantity(pending.quantity)
    if not seller or fullType == "" or price <= 0 or quantity <= 0 then
        sendResult(player, false, "invalid_item")
        return
    end

    local inventory = player:getInventory()
    local matches = PZLinuxCollectInventoryItemsByFullTypes(player, fullType)
    local items = {}
    for _, candidate in ipairs(matches) do
        if candidate
            and candidate.getFullType
            and candidate:getFullType() == fullType
            and itemIsInMainInventory(candidate, inventory)
            and not PZLinuxIsEquippedInventoryItem(player, candidate)
            and not itemHasContainedItems(candidate)
        then
            items[#items + 1] = candidate
            if #items >= quantity then
                break
            end
        end
    end
    if not inventory or #items < quantity then
        sendResult(player, false, "item_not_available", { required = quantity, available = #items })
        return
    end

    local snapshots = {}
    for _, item in ipairs(items) do
        local snapshot = snapshotItem(item)
        if not snapshot then
            sendResult(player, false, "invalid_item")
            return
        end
        snapshots[#snapshots + 1] = snapshot
    end

    -- Remove depois de criar todos os snapshots. Se algo falhar no meio,
    -- rollback tenta devolver o que ja saiu.
    local removedSnapshots = {}
    for index, item in ipairs(items) do
        if not PZLinuxSafeRemoveItem(inventory, item) then
            rollbackRemovedSnapshots(player, removedSnapshots)
            sendResult(player, false, "remove_failed")
            return
        end
        removedSnapshots[#removedSnapshots + 1] = snapshots[index]
    end

    local data = getMarketData()
    local id = PZLinuxLocalMarket.buildListingId(seller)
    local listing = {
        id = id,
        type = "item",
        category = PZLinuxLocalMarket.normalizeCategory(pending.category),
        seller = seller,
        name = snapshots[1].displayName or fullType,
        fullType = fullType,
        price = price,
        unitPrice = price,
        quantity = #snapshots,
        description = PZLinuxLocalMarket.sanitizeDescription(pending.description),
        createdAt = os.time(),
        item = snapshots[1],
        items = snapshots,
    }

    local ok, err = pcall(function()
        data.listings[id] = listing
        transmitMarketData()
    end)
    if not ok then
        data.listings[id] = nil
        rollbackRemovedSnapshots(player, removedSnapshots)
        print("PZLinuxLocalMarket: listing persistence failed: " .. tostring(err))
        sendResult(player, false, "listing_save_failed")
        return
    end

    modData.PZLinuxPendingLocalMarketListing = nil
    recordLocalMarketItemDemand(fullType, "down", #snapshots)
    syncPlayer(player)
    sendResult(player, true, nil, {
        submitted = true,
        listingId = id,
        quantity = #snapshots,
    })
end

PZLinuxCompletePendingLocalMarketItemListing = completePendingLocalMarketItem

-- Venda de veiculo nao remove objeto do mundo; ela publica o claim do carro.
local function listLocalMarketVehicle(player, args)
    if not player or type(args) ~= "table" then
        return
    end
    if not JeevesClaims or not JeevesClaims.getVehicleOwner or not JeevesClaims.getVehicleVGID then
        sendResult(player, false, "jeeves_missing")
        return
    end

    local seller = PZLinuxLocalMarket.getUsername(player)
    local price = PZLinuxLocalMarket.normalizePrice(args.price)
    local description = PZLinuxLocalMarket.sanitizeDescription(args.description)
    local title = PZLinuxLocalMarket.sanitizeDescription(args.title)
    local ownerName = PZLinuxLocalMarket.sanitizeDescription(args.ownerName)
    local vehicle, vgid = findVehicleByArgs(args)
    if not seller or not vehicle or not vgid or price <= 0 then
        sendResult(player, false, "vehicle_not_available")
        return
    end

    if not PZLinuxConfig.IsEnabled("VehicleTrading") then sendResult(player, false, "disabled"); return end
    local owner = JeevesClaims.getVehicleOwner(vehicle)
    if not JeevesClaims.isSameUsername(owner, seller) then
        sendResult(player, false, "vehicle_not_owned")
        return
    end

    if isListingVehicleAlreadyListed(vgid) then
        sendResult(player, false, "vehicle_already_listed")
        return
    end

    local vehicleSnapshot = PZLinuxLocalMarket.getVehicleSnapshot(vehicle)
    vehicleSnapshot.vgid = tostring(vgid)
    if title == "" then
        title = vehicleSnapshot.name
    end
    if ownerName == "" then
        ownerName = seller
    end

    local data = getMarketData()
    local id = PZLinuxLocalMarket.buildListingId(seller)
    data.listings[id] = {
        id = id,
        type = "vehicle",
        category = "vehicles",
        seller = seller,
        name = title,
        title = title,
        ownerName = ownerName,
        price = price,
        description = description,
        createdAt = os.time(),
        vehicle = vehicleSnapshot,
    }
    recordLocalMarketVehicleDemand(vehicleSnapshot, "down")
    transmitMarketData()
    sendResult(player, true, nil, { listingId = id })
end

-- Compra item ou veiculo. Cada tipo tem fluxo proprio:
-- item = cria item no comprador e remove quantidade do anuncio;
-- veiculo = transfere claim do JeevesClaims.
local function buyLocalMarketListing(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local buyer = PZLinuxLocalMarket.getUsername(player)
    local listingId = tostring(args.listingId or "")
    local data = getMarketData()
    local listing = data.listings[listingId]
    if not buyer or not listing then
        sendResult(player, false, "listing_missing")
        return
    end
    if tostring(listing.seller or ""):lower() == buyer:lower() then
        sendResult(player, false, "own_listing")
        return
    end

    local snapshots = getListingItemSnapshots(listing)
    local requestedQuantity = listing.type == "item"
        and PZLinuxLocalMarket.normalizeQuantity(args.quantity, #snapshots)
        or 1
    local unitPrice = PZLinuxLocalMarket.normalizePrice(listing.unitPrice or listing.price)
    local price = unitPrice * requestedQuantity
    local modData = PZLinuxGetModData(player)
    local balance = ensureBankBalance(modData)
    if price <= 0 or balance < price then
        sendResult(player, false, "not_enough_money", { balance = balance })
        return
    end

    if listing.type == "item" then
        local delivery = {}
        for index = 1, requestedQuantity do
            delivery[#delivery + 1] = snapshots[index]
        end
        if #delivery == 0 or not restoreSnapshotsToPlayer(player, delivery) then
            sendResult(player, false, "delivery_failed")
            return
        end

        modData.PZLinuxBank = balance - price
        creditSeller(listing.seller, price, buildSaleNotice(listing, buyer, price))
        for _ = 1, requestedQuantity do
            table.remove(snapshots, 1)
        end
        if #snapshots == 0 then
            data.listings[listingId] = nil
        else
            listing.items = snapshots
            listing.item = snapshots[1]
            listing.quantity = #snapshots
        end
        recordLocalMarketItemDemand(listing.fullType or (delivery[1] and delivery[1].fullType), "up", requestedQuantity)
        syncPlayer(player)
        transmitMarketData()
        sendResult(player, true, nil, {
            balance = modData.PZLinuxBank,
            quantity = requestedQuantity,
            remaining = #snapshots,
        })
        return
    end

    if listing.type == "vehicle" then
        if not PZLinuxConfig.IsEnabled("VehicleTrading") then sendResult(player, false, "disabled"); return end
        if not JeevesClaims or not JeevesClaims.getVehicleOwner then
            sendResult(player, false, "jeeves_missing")
            return
        end

        local vehicleInfo = listing.vehicle or {}
        local vgid = tostring(vehicleInfo.vgid or "")
        local vehicle = findVehicleByVGID(vgid)
        if not vehicle then
            sendResult(player, false, "vehicle_unloaded")
            return
        end

        local owner = JeevesClaims.getVehicleOwner(vehicle)
        if not JeevesClaims.isSameUsername(owner, listing.seller) then
            data.listings[listingId] = nil
            transmitMarketData()
            sendResult(player, false, "vehicle_owner_changed")
            return
        end

        local maxClaims = JeevesClaims.getMaxVehicleClaims and JeevesClaims.getMaxVehicleClaims() or 0
        if maxClaims > 0 and getVehicleClaimCount(buyer) >= maxClaims then
            sendResult(player, false, "vehicle_claim_limit")
            return
        end

        if not transferVehicleClaim(vehicle, vgid, listing.seller, buyer) then
            sendResult(player, false, "transfer_failed")
            return
        end

        modData.PZLinuxBank = balance - price
        creditSeller(listing.seller, price, buildSaleNotice(listing, buyer, price))
        data.listings[listingId] = nil
        recordLocalMarketVehicleDemand(vehicleInfo, "up")
        syncPlayer(player)
        transmitMarketData()
        sendResult(player, true, nil, { balance = modData.PZLinuxBank })
        return
    end

    sendResult(player, false, "invalid_listing")
end

-- Cancela anuncio. Itens voltam para o vendedor; veiculo so remove o anuncio.
local function cancelLocalMarketListing(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local username = PZLinuxLocalMarket.getUsername(player)
    local listingId = tostring(args.listingId or "")
    local data = getMarketData()
    local listing = data.listings[listingId]
    if not username or not listing then
        sendResult(player, false, "listing_missing")
        return
    end

    local isAdmin = JeevesClaims and JeevesClaims.isAdmin and JeevesClaims.isAdmin(player)
    if tostring(listing.seller or ""):lower() ~= username:lower() and not isAdmin then
        sendResult(player, false, "not_owner")
        return
    end

    if listing.type == "item" and tostring(listing.seller or ""):lower() == username:lower() then
        if not restoreSnapshotsToPlayer(player, getListingItemSnapshots(listing)) then
            sendResult(player, false, "restore_failed")
            return
        end
    end

    data.listings[listingId] = nil
    transmitMarketData()
    sendResult(player, true, nil)
end

-- Mapa de comandos aceitos do client para handlers server-side.
local COMMANDS = {
    RequestLocalMarket = requestLocalMarket,
    DepositCoins = depositCoins,
    ListLocalMarketItem = listLocalMarketItem,
    CompleteLocalMarketItemListing = completePendingLocalMarketItem,
    ListLocalMarketVehicle = listLocalMarketVehicle,
    BuyLocalMarketListing = buyLocalMarketListing,
    CancelLocalMarketListing = cancelLocalMarketListing,
}

-- Roteador unico do modulo PZLinux.
local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player or (args ~= nil and type(args) ~= "table") then return end
    local handler = COMMANDS[command]
    if not handler then return end
    -- Cancelling a saved listing and returning escrow remains available.
    if command ~= "CancelLocalMarketListing" and not PZLinuxConfig.IsEnabled("LocalMarket") then
        sendResult(player, false, "disabled"); return
    end
    handler(player, args or {})
end

Events.OnClientCommand.Add(onClientCommand)
