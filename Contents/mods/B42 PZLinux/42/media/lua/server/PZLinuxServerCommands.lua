if isClient() then return end

require "PZLinuxTradingCore"
require "PZLinuxEconomy"
require "PZLinuxWorld"

local MODULE = PZLinuxModule or "PZLinux"

local function isPlayerNear(player, x, y, z, maxDistance)
    if not player or x == nil or y == nil or z == nil then
        return false
    end

    if math.abs((tonumber(player:getZ()) or 0) - z) > 1 then
        return false
    end

    local dx = (tonumber(player:getX()) or 0) - x
    local dy = (tonumber(player:getY()) or 0) - y
    local distance = math.max(1, tonumber(maxDistance) or 55)
    return (dx * dx + dy * dy) <= distance * distance
end

local function asNumber(value)
    local numberValue = tonumber(value)
    if numberValue == nil or numberValue ~= numberValue or numberValue == math.huge or numberValue == -math.huge then
        return nil
    end

    return math.floor(numberValue)
end

local function getSquareFromArgs(args)
    if not args then return nil end

    local x = asNumber(args.x)
    local y = asNumber(args.y)
    local z = asNumber(args.z)
    if x == nil or y == nil or z == nil then
        return nil
    end

    return getCell():getGridSquare(x, y, z), x, y, z
end

local function syncPlayer(player)
    if player and player.transmitModData then
        player:transmitModData()
    end
end

local function replyToPlayer(player, command, payload)
    if player and sendServerCommand then
        sendServerCommand(player, MODULE, command, payload or {})
    end
end

local function spawnManhuntZombie(player, args)
    local square, x, y, z = getSquareFromArgs(args)
    local modData = PZLinuxGetModData(player)
    if not modData or x ~= tonumber(modData.PZLinuxContractLocationX) or y ~= tonumber(modData.PZLinuxContractLocationY)
        or z ~= tonumber(modData.PZLinuxContractLocationZ) then return end
    if not square or not isPlayerNear(player, x, y, z, 55)
        or tonumber(modData.PZLinuxActiveContract) ~= 1
        or tonumber(modData.PZLinuxContractManhunt) ~= 1
    then
        return
    end

    local zombie = createZombie(x, y, z, nil, 0, IsoDirections.S)
    if zombie then
        zombie:setUseless(true)
        zombie:setSitAgainstWall(true)
        modData.PZLinuxContractManhunt = 2
        syncPlayer(player)
    end
end

local function spawnProtectWave(player, args)
    local square, x, y, z = getSquareFromArgs(args)
    local modData = PZLinuxGetModData(player)
    if not modData or x ~= tonumber(modData.PZLinuxContractLocationX) or y ~= tonumber(modData.PZLinuxContractLocationY)
        or z ~= tonumber(modData.PZLinuxContractLocationZ) then return end
    if not square or not isPlayerNear(player, x, y, z, 55)
        or tonumber(modData.PZLinuxActiveContract) ~= 1
        or tonumber(modData.PZLinuxContractProtect) ~= 1
    then
        return
    end

    if PZLinuxWorld.SpawnProtectWave(x, y, z) == 0 then return end
    modData.PZLinuxContractProtect = 2

    syncPlayer(player)
end

local function spawnRequestVehicle(player, args)
    local square, x, y, z = getSquareFromArgs(args)
    local modData = PZLinuxGetModData(player)
    if not modData or x ~= tonumber(modData.PZLinuxRequestLocationX) or y ~= tonumber(modData.PZLinuxRequestLocationY)
        or z ~= tonumber(modData.PZLinuxRequestLocationZ) then return end
    local requestedScript = tostring(modData.PZLinuxOnItemRequestCarName or "")
    if not square or not isPlayerNear(player, x, y, z, 55)
        or tonumber(modData.PZLinuxOnItemRequestCar) ~= 1
        or requestedScript == ""
        or tostring(args and args.script or "") ~= requestedScript
    then
        return
    end

    local vehicle = PZLinuxWorld.SpawnVehicle(player, requestedScript, square)
    if not vehicle then return end

    modData.PZLinuxOnItemRequestCar = 0
    modData.PZLinuxOnItemRequestCarName = ""
    syncPlayer(player)
end

local function spawnCargoBox(player, args)
    local square, x, y, z = getSquareFromArgs(args)
    local modData = PZLinuxGetModData(player)
    if not modData or x ~= tonumber(modData.PZLinuxContractLocationX) or y ~= tonumber(modData.PZLinuxContractLocationY)
        or z ~= tonumber(modData.PZLinuxContractLocationZ) then return end
    if not square or not isPlayerNear(player, x, y, z, 55)
        or tonumber(modData.PZLinuxActiveContract) ~= 1
        or tonumber(modData.PZLinuxContractCargo) ~= 1
    then
        return
    end

    if not PZLinuxWorld.SpawnCargo(square) then return end

    modData.PZLinuxContractCargo = 2
    syncPlayer(player)
end

local function removeCargoBox(player, args)
    local square, x, y, z = getSquareFromArgs(args)
    local modData = PZLinuxGetModData(player)
    if not modData or x ~= tonumber(modData.PZLinuxContractLocationX) or y ~= tonumber(modData.PZLinuxContractLocationY)
        or z ~= tonumber(modData.PZLinuxContractLocationZ) then return end
    if not square or isPlayerNear(player, x, y, z, 50)
        or tonumber(modData.PZLinuxContractCargo) ~= 3
    then
        return
    end

    PZLinuxWorld.RemoveCargo(square)

    modData.PZLinuxContractCargo = 4
    syncPlayer(player)
end

local function createInventoryPackage(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local inventory = player:getInventory()
    if not inventory then
        return
    end

    local packageType = tostring(args.packageType or "")
    local deliveryType = tostring(args.deliveryType or "")
    local modData = PZLinuxGetModData(player)
    local options = { contents = {} }
    local queue = nil
    local queueIndex = nil

    if deliveryType == "blood" and packageType == "Base.EmptyJar"
        and tonumber(modData.PZLinuxContractBlood) == 1
    then
        options.displayName = "Blood for contract"
        options.deliveryType = "blood"
    elseif deliveryType == "capture" and packageType == "Base.Bag_Mail"
        and tonumber(modData.PZLinuxContractCapture) == 1
    then
        options.displayName = "Zombie captured alive"
        options.deliveryType = "capture"
        options.contents = { "Base.CorpseMale" }
    elseif deliveryType == "manhunt" and packageType == "Base.Bag_Mail"
        and tonumber(modData.PZLinuxContractManhunt) == 2
    then
        options.displayName = "Cut target"
        options.deliveryType = "manhunt"
        options.contents = { "Base.CorpseMale" }
    elseif deliveryType == "pickup" and packageType == "Base.Bag_ProtectiveCaseSmall"
        and tonumber(modData.PZLinuxContractPickUp) == 1
    then
        options.displayName = "Contract case"
        options.deliveryType = "pickup"
        options.contents = { "Base.Note" }
        local bonusRoll = ZombRand(1, 6)
        if bonusRoll == 1 then
            options.contents[#options.contents + 1] = "Base.Revolver"
            local bonusTotal = ZombRand(1, 2000)
            local stacks = PZLinuxEconomyBuildCoinStacks and PZLinuxEconomyBuildCoinStacks(bonusTotal) or {
                { fullType = "Base.Money", count = bonusTotal },
            }
            for _, stack in ipairs(stacks) do
                options.contents[#options.contents + 1] = stack
            end
        elseif bonusRoll == 2 then
            options.contents[#options.contents + 1] = "Base.Revolver"
        end
    elseif packageType == "Base.Parcel_Large" then
        if tonumber(modData.PZLinuxActiveRequest) == 1
            and type(modData.PZLinuxOnItemRequest) == "table"
            and #modData.PZLinuxOnItemRequest > 0
        then
            queue = modData.PZLinuxOnItemRequest
            queueIndex = #queue
        elseif tonumber(modData.PZLinuxOnItemBuyOnDarkWebStatus) == 1
            and type(modData.PZLinuxOnItemBuyOnDarkWeb) == "table"
            and #modData.PZLinuxOnItemBuyOnDarkWeb > 0
        then
            queue = modData.PZLinuxOnItemBuyOnDarkWeb
            queueIndex = #queue
        end

        if queue and queueIndex then
            options.contents = PZLinuxBuildPackageContentsFromBatch(queue[queueIndex])
        end
        if #options.contents == 0 then
            return
        end
    else
        return
    end

    local created = PZLinuxCreateInventoryPackage(inventory, packageType, options)
    if not created then
        return
    end

    if deliveryType == "blood" then
        modData.PZLinuxContractBlood = 3
    elseif deliveryType == "capture" then
        modData.PZLinuxContractCapture = 3
    elseif deliveryType == "manhunt" then
        modData.PZLinuxContractManhunt = 3
    elseif deliveryType == "pickup" then
        modData.PZLinuxContractPickUp = 3
    elseif queue and queueIndex then
        table.remove(queue, queueIndex)
        if queue == modData.PZLinuxOnItemRequest and #queue == 0 then
            modData.PZLinuxActiveRequest = 0
        elseif queue == modData.PZLinuxOnItemBuyOnDarkWeb and #queue == 0 then
            modData.PZLinuxOnItemBuyOnDarkWebStatus = 0
        end
    end

    syncPlayer(player)
end

local function syncPlayerData(player, args)
    if not player or type(args) ~= "table" or type(args.snapshot) ~= "table" then
        return
    end

    local modData = PZLinuxGetModData(player)
    if not modData then
        return
    end

    PZLinuxApplyPlayerModDataSnapshot(modData, args.snapshot)
    syncPlayer(player)
end

local function syncGlobalData(player, args)
    if type(args) ~= "table" or type(args.tag) ~= "string" or type(args.data) ~= "table" then
        return
    end

    if PZLinuxIsTradingGlobalTag(args.tag) then
        PZLinuxTradingEnsureMarketFresh(true)
        replyToPlayer(player, "TradingData", {
            market = PZLinuxTradingBuildMarketSnapshot(),
        })
        return
    end

    PZLinuxSyncGlobalModData(args.tag, args.data)
end

local function requestTradingData(player)
    PZLinuxTradingEnsureMarketFresh(true)
    replyToPlayer(player, "TradingData", {
        market = PZLinuxTradingBuildMarketSnapshot(),
    })
end

local function requestEconomyDemand(player)
    replyToPlayer(player, "EconomyDemandData", {
        demand = PZLinuxEconomyBuildDemandSnapshot(),
    })
end

local function recordEconomyDemand(player, args)
    if type(args) ~= "table" then
        return
    end

    local key = tostring(args.key or "")
    local quantity = math.max(1, math.min(100, math.floor(tonumber(args.quantity) or 1)))
    if #key > 256 or not (
        key:sub(1, 5) == "item:"
        or key:sub(1, 8) == "request:"
        or key:sub(1, 8) == "trading:"
        or key:sub(1, 12) == "localmarket:"
        or key:sub(1, 8) == "darkweb:"
    ) then
        return
    end

    PZLinuxEconomyRecordDemand(key, args.direction, quantity, true)
    requestEconomyDemand(player)
end

local function convertCoins(player, args)
    local source = tostring(args and args.source or "inventory")
    local result
    if source == "bank" and PZLinuxEconomyConvertBankCoins then
        result = PZLinuxEconomyConvertBankCoins(player, args and args.action)
    else
        result = PZLinuxEconomyConvertCoins(player, args and args.action)
    end
    if result and result.ok then
        syncPlayer(player)
    end

    replyToPlayer(player, "CoinConvertResult", result or { ok = false, reason = "unknown" })
end

local function ensureServerBankBalance(modData)
    if type(modData) ~= "table" then
        return 0
    end

    if tonumber(modData.PZLinuxBank) == nil then
        modData.PZLinuxBank = PZLinuxConfig.NewBankBalance()
    end

    modData.PZLinuxBank = math.max(0, math.floor(tonumber(modData.PZLinuxBank) or 0))
    return modData.PZLinuxBank
end

local function requestBankBalance(player)
    local modData = PZLinuxGetModData(player)
    local balance = ensureServerBankBalance(modData)
    syncPlayer(player)
    replyToPlayer(player, "BankBalanceResult", {
        ok = true,
        balance = balance,
    })
end

local function withdrawBankCoins(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local amount = PZLinuxConfig.Amount(args.amount)
    local modData = PZLinuxGetModData(player)
    local balance = ensureServerBankBalance(modData)
    if amount > PZLinuxConfig.Get("MaxCashTransaction") then
        replyToPlayer(player, "BankWithdrawalResult", { ok = false, reason = "transaction_limit", balance = balance }); return
    end
    if amount <= 0 then
        replyToPlayer(player, "BankWithdrawalResult", {
            ok = false,
            reason = "invalid_amount",
            balance = balance,
        })
        return
    end

    if amount > balance then
        replyToPlayer(player, "BankWithdrawalResult", {
            ok = false,
            reason = "not_enough_money",
            balance = balance,
        })
        return
    end

    if not PZLinuxEconomyGiveCoinValue(player, amount) then
        replyToPlayer(player, "BankWithdrawalResult", {
            ok = false,
            reason = "create_failed",
            balance = balance,
        })
        return
    end

    modData.PZLinuxBank = balance - amount
    modData.PZLinuxBankCoins = nil
    syncPlayer(player)
    replyToPlayer(player, "BankWithdrawalResult", {
        ok = true,
        amount = amount,
        balance = modData.PZLinuxBank,
    })
end

local function depositBankCoins(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local amount = PZLinuxConfig.Amount(args.amount)
    local modData = PZLinuxGetModData(player)
    local balance = ensureServerBankBalance(modData)
    if amount > PZLinuxConfig.Get("MaxCashTransaction") then
        replyToPlayer(player, "BankDepositResult", { ok = false, reason = "transaction_limit", balance = balance }); return
    end
    if amount <= 0 then
        replyToPlayer(player, "BankDepositResult", {
            ok = false,
            reason = "invalid_amount",
            balance = balance,
        })
        return
    end

    local result = PZLinuxEconomyRemoveCoinValueFromInventory(player, amount)
    if not result or not result.ok or tonumber(result.removedValue) ~= amount then
        replyToPlayer(player, "BankDepositResult", {
            ok = false,
            reason = "not_enough_money",
            balance = balance,
        })
        return
    end

    modData.PZLinuxBank = balance + amount
    modData.PZLinuxBankCoins = nil
    syncPlayer(player)
    replyToPlayer(player, "BankDepositResult", {
        ok = true,
        amount = amount,
        balance = modData.PZLinuxBank,
    })
end

local function executeTradingOrder(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local action = tostring(args.action or "")
    local code = tostring(args.code or "")
    local quantity = math.max(0, math.floor(tonumber(args.quantity) or 0))
    if (action ~= "buy" and action ~= "sell") or code == "" or quantity <= 0 then
        replyToPlayer(player, "TradingOrderResult", { ok = false, reason = "invalid_order" })
        return
    end

    local company = PZLinuxTradingGetCompany(code)
    if not company then
        replyToPlayer(player, "TradingOrderResult", { ok = false, reason = "invalid_company" })
        return
    end

    PZLinuxTradingEnsureMarketFresh(true)

    local unitPrice = PZLinuxTradingGetCurrentPrice(code, company.price)
    if unitPrice <= 0 then
        replyToPlayer(player, "TradingOrderResult", { ok = false, reason = "invalid_price" })
        return
    end

    local modData = PZLinuxGetModData(player)
    if not modData then
        replyToPlayer(player, "TradingOrderResult", { ok = false, reason = "missing_player_data" })
        return
    end

    local walletKey = "ZLinuxPlayerWallet" .. code
    local walletQuantity = math.max(0, math.floor(tonumber(modData[walletKey]) or 0))
    local previousWalletQuantity = walletQuantity
    local balance = ensureServerBankBalance(modData)
    local totalPrice = unitPrice * quantity

    if action == "buy" then
        if balance < totalPrice then
            replyToPlayer(player, "TradingOrderResult", {
                ok = false,
                reason = "not_enough_money",
                balance = balance,
                walletQuantity = walletQuantity,
                code = code,
                unitPrice = unitPrice,
            })
            return
        end

        balance = balance - totalPrice
        walletQuantity = walletQuantity + quantity
    else
        if walletQuantity < quantity then
            replyToPlayer(player, "TradingOrderResult", {
                ok = false,
                reason = "not_enough_assets",
                balance = balance,
                walletQuantity = walletQuantity,
                code = code,
                unitPrice = unitPrice,
            })
            return
        end

        walletQuantity = walletQuantity - quantity
        balance = balance + totalPrice
    end

    modData.PZLinuxBank = balance
    modData[walletKey] = walletQuantity
    local portfolioPosition = PZLinuxTradingApplyPortfolioOrder(modData, action, code, quantity, unitPrice, previousWalletQuantity)
    PZLinuxTradingApplyCompanyImpact(code, action == "buy" and "up" or "down", true)
    PZLinuxEconomyRecordDemand(PZLinuxEconomyBuildTradingDemandKey(code), action == "buy" and "up" or "down", quantity, true)
    PZLinuxTradingRecordWalletHistory(modData)
    syncPlayer(player)

    replyToPlayer(player, "TradingOrderResult", {
        ok = true,
        action = action,
        code = code,
        quantity = quantity,
        unitPrice = unitPrice,
        totalPrice = totalPrice,
        balance = balance,
        walletQuantity = walletQuantity,
        portfolio = PZLinuxCloneSerializableTable(modData.PZLinuxTradingPortfolio) or {},
        portfolioPosition = PZLinuxCloneSerializableTable(portfolioPosition) or {},
        market = PZLinuxTradingBuildMarketSnapshot(),
        demand = PZLinuxEconomyBuildDemandSnapshot(),
    })
end

local function applyTradingCompanyImpact(player, args)
    if type(args) ~= "table" then
        return
    end

    local tagOrCode = tostring(args.tag or args.code or "")
    local direction = tostring(args.direction or "up")
    if direction ~= "down" then
        direction = "up"
    end

    local companyCode = tagOrCode
    if companyCode:sub(1, #"PZLinuxTrading") == "PZLinuxTrading" then
        companyCode = companyCode:sub(#"PZLinuxTrading" + 1)
    end
    if not PZLinuxTradingGetCompany(companyCode) then
        return
    end

    PZLinuxTradingEnsureMarketFresh(false)
    PZLinuxTradingApplyCompanyImpact(tagOrCode, direction, true)
    replyToPlayer(player, "TradingData", {
        market = PZLinuxTradingBuildMarketSnapshot(),
    })
end

local function processDarkWebSale(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local inventory = player:getInventory()
    local itemIds = PZLinuxNormalizeFullTypeList(args.itemIds)
    if not inventory or #itemIds == 0 then
        replyToPlayer(player, "DarkWebSaleResult", { ok = false, reason = "invalid_item" })
        return
    end

    local entry = PZLinuxFindDarkWebItemEntryByFullTypes(itemIds)
    if not entry then
        replyToPlayer(player, "DarkWebSaleResult", { ok = false, reason = "invalid_item" })
        return
    end

    local itemsToSell = PZLinuxCollectInventoryItemsByFullTypes(player, itemIds)
    if #itemsToSell == 0 then
        replyToPlayer(player, "DarkWebSaleResult", { ok = false, reason = "no_item" })
        return
    end

    local unitPrice = math.max(0, math.floor(tonumber(PZLinuxCalculateDarkWebSellUnitPrice(player, entry)) or 0))
    if unitPrice <= 0 then
        replyToPlayer(player, "DarkWebSaleResult", { ok = false, reason = "invalid_price" })
        return
    end

    local modData = PZLinuxGetModData(player)
    if type(modData) ~= "table" then
        replyToPlayer(player, "DarkWebSaleResult", { ok = false, reason = "bank_unavailable" })
        return
    end

    local removedCount = 0
    for _, item in ipairs(itemsToSell) do
        if PZLinuxSafeRemoveItem(inventory, item) then
            removedCount = removedCount + 1
        end
    end

    if removedCount <= 0 then
        replyToPlayer(player, "DarkWebSaleResult", { ok = false, reason = "no_item" })
        return
    end

    local totalPrice = unitPrice * removedCount
    local demandKey = PZLinuxEconomyBuildItemDemandKey(itemIds)
    modData.PZLinuxBank = math.max(0, math.floor(tonumber(modData.PZLinuxBank) or 0)) + totalPrice
    modData.PZLinuxBankCoins = nil
    syncPlayer(player)

    PZLinuxEconomyRecordDemand(demandKey, "down", removedCount, true)

    replyToPlayer(player, "DarkWebSaleResult", {
        ok = true,
        removedCount = removedCount,
        totalPrice = totalPrice,
        balance = modData.PZLinuxBank,
        demand = PZLinuxEconomyBuildDemandSnapshot(),
    })
end

local function cashInSuspiciousPackages(player)
    if not player then
        return
    end

    local inventory = player:getInventory()
    if not inventory then
        return
    end

    local items = inventory:getItems()
    local totalAmount = 0
    local removedCount = 0
    for index = items:size() - 1, 0, -1 do
        local item = items:get(index)
        if item and item:getFullType() == "Base.SuspiciousPackage" then
            local amount = PZLinuxGetSuspiciousPackageAmount(item)
            if amount > 0 and PZLinuxSafeRemoveItem(inventory, item) then
                totalAmount = totalAmount + amount
                removedCount = removedCount + 1
            end
        end
    end

    if removedCount <= 0 or totalAmount <= 0 then
        replyToPlayer(player, "CashInSuspiciousPackagesResult", { ok = false, reason = "no_packages" })
        return
    end

    local modData = PZLinuxGetModData(player)
    modData.PZLinuxBank = math.max(0, math.floor(tonumber(modData.PZLinuxBank) or 0)) + totalAmount
    syncPlayer(player)

    replyToPlayer(player, "CashInSuspiciousPackagesResult", {
        ok = true,
        totalAmount = totalAmount,
        removedCount = removedCount,
        balance = modData.PZLinuxBank,
    })
end

local function completeMailboxContract(player)
    if not player then
        return
    end

    local result = PZLinuxCompleteMailboxContract(player)
    if result and result.ok then
        syncPlayer(player)
    end

    replyToPlayer(player, "MailboxContractResult", result or { ok = false, reason = "unknown" })
end

local function completeMailDelivery(player, args)
    if not player or type(args) ~= "table" then
        return
    end

    local result = PZLinuxCompleteMailDelivery(player, args.mailId)
    if result and result.ok then
        syncPlayer(player)
    end

    replyToPlayer(player, "MailDeliveryResult", result or { ok = false, reason = "unknown" })
end

local COMMANDS = {
    SpawnManhuntZombie = spawnManhuntZombie,
    SpawnProtectWave = spawnProtectWave,
    SpawnRequestVehicle = spawnRequestVehicle,
    SpawnCargoBox = spawnCargoBox,
    RemoveCargoBox = removeCargoBox,
    CreateInventoryPackage = createInventoryPackage,
    SyncPlayerData = syncPlayerData,
    SyncGlobalData = syncGlobalData,
    RequestTradingData = requestTradingData,
    RequestEconomyDemand = requestEconomyDemand,
    RecordEconomyDemand = recordEconomyDemand,
    ConvertCoins = convertCoins,
    RequestBankBalance = requestBankBalance,
    WithdrawBankCoins = withdrawBankCoins,
    DepositBankCoins = depositBankCoins,
    ExecuteTradingOrder = executeTradingOrder,
    ApplyTradingCompanyImpact = applyTradingCompanyImpact,
    ProcessDarkWebSale = processDarkWebSale,
    CashInSuspiciousPackages = cashInSuspiciousPackages,
    CompleteMailboxContract = completeMailboxContract,
    CompleteMailDelivery = completeMailDelivery,
}

local COMMAND_FEATURES = {
    SpawnManhuntZombie = "Contracts", SpawnProtectWave = "Contracts", SpawnCargoBox = "Contracts",
    SpawnRequestVehicle = "Requests", ConvertCoins = "CurrencyConversion", ExecuteTradingOrder = "Trading",
    ApplyTradingCompanyImpact = "Trading", ProcessDarkWebSale = "DarkWeb", WithdrawBankCoins = "ATM", DepositBankCoins = "ATM",
}
local RESULT_COMMANDS = { ConvertCoins = "CoinConvertResult", ExecuteTradingOrder = "TradingOrderResult",
    ProcessDarkWebSale = "DarkWebSaleResult", WithdrawBankCoins = "BankWithdrawalResult", DepositBankCoins = "BankDepositResult" }

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player or (args ~= nil and type(args) ~= "table") then return end
    local feature = COMMAND_FEATURES[command]
    if not PZLinuxConfig.IsEnabled(feature) then
        if RESULT_COMMANDS[command] then replyToPlayer(player, RESULT_COMMANDS[command], { ok = false, reason = "disabled" }) end
        return
    end

    local handler = COMMANDS[command]
    if handler then
        handler(player, args or {})
    end
end

Events.OnClientCommand.Add(onClientCommand)
