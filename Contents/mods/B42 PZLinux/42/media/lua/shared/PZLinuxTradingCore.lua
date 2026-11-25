require "PZLinuxConfig"
PZLinuxTradingCore = PZLinuxTradingCore or {}

local HISTORY_KEY = "dataName"
local META_TAG = "PZLinuxTrading"
local MAX_HISTORY = 48
local PORTFOLIO_KEY = "PZLinuxTradingPortfolio"

local function floorNumber(value, fallback)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return fallback or 0
    end
    return math.floor(numberValue)
end

local function randomInt(minValue, maxValue)
    minValue = math.max(1, math.floor(tonumber(minValue) or 1))
    maxValue = math.max(minValue, math.floor(tonumber(maxValue) or minValue))
    if maxValue <= minValue then
        return minValue
    end

    return ZombRand(minValue, maxValue + 1)
end

local function getPZLinuxSandbox()
    if SandboxVars and SandboxVars.PZLinux then
        return SandboxVars.PZLinux
    end
    return {}
end

function PZLinuxTradingIsContractImpactEnabled()
    return getPZLinuxSandbox().ContractTradingImpactEnabled ~= false
end

function PZLinuxTradingGetContractImpactMaxPercent()
    local value = tonumber(getPZLinuxSandbox().ContractTradingImpactMaxPercent)
    if value == nil then
        value = 1
    end

    if value < 0 then
        value = 0
    elseif value > 100 then
        value = 100
    end

    return value
end

local function randomContractImpactPercent(maxPercent)
    local maxValue = tonumber(maxPercent) or 1
    if maxValue <= 0 then
        return 0
    end

    local basisPoints = math.max(1, math.floor(maxValue * 100))
    return randomInt(1, basisPoints) / 100
end

local function roundNumber(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function trimHistory(history)
    while #history > MAX_HISTORY do
        table.remove(history, 1)
    end
end

function PZLinuxTradingGetCompany(code)
    if type(PZLinuxTradingCompanyNameTable) ~= "table" then
        return nil
    end

    local wantedCode = tostring(code or "")
    for _, company in ipairs(PZLinuxTradingCompanyNameTable) do
        if type(company) == "table" and tostring(company.code or "") == wantedCode then
            return company
        end
    end

    return nil
end

function PZLinuxTradingGetCompanyTag(code)
    local companyCode = type(code) == "table" and code.code or code
    companyCode = tostring(companyCode or "")
    if companyCode == "" then
        return nil
    end
    return META_TAG .. companyCode
end

function PZLinuxTradingResolveLastPrice(priceHistory, fallbackPrice)
    local firstPrice, lastPrice, secondLastPrice = PZLinuxGetHistoryExtremes(priceHistory)
    local safeFallback = math.max(1, floorNumber(fallbackPrice, 1))

    if tonumber(lastPrice) == nil or tonumber(lastPrice) <= 0 then
        lastPrice = safeFallback
    end
    if tonumber(firstPrice) == nil or tonumber(firstPrice) <= 0 then
        firstPrice = lastPrice
    end
    if tonumber(secondLastPrice) == nil or tonumber(secondLastPrice) <= 0 then
        secondLastPrice = lastPrice
    end

    return tonumber(firstPrice) or lastPrice, tonumber(lastPrice) or safeFallback, tonumber(secondLastPrice) or lastPrice
end

function PZLinuxTradingNextPrice(lastPrice, volatilityPercent)
    local currentPrice = math.max(1, floorNumber(lastPrice, 1))
    local volatility = math.max(1, floorNumber(volatilityPercent, 5)) * PZLinuxConfig.Get("TradingVolatilityMultiplier")
    if volatility == 0 then return currentPrice end
    local direction = ZombRand(1, 4)

    if direction == 1 then
        local lowPrice = currentPrice - math.floor(currentPrice * volatility / 100)
        return randomInt(math.max(1, lowPrice), currentPrice + 2)
    elseif direction == 3 then
        local highPrice = currentPrice + math.floor(currentPrice * volatility / 100)
        return randomInt(currentPrice, math.max(currentPrice + 1, highPrice))
    end

    return currentPrice
end

function PZLinuxTradingGetHistory(code)
    local tag = PZLinuxTradingGetCompanyTag(code)
    if not tag or not ModData or not ModData.getOrCreate then
        return nil, nil
    end

    local companyData = ModData.getOrCreate(tag)
    companyData[HISTORY_KEY] = type(companyData[HISTORY_KEY]) == "table" and companyData[HISTORY_KEY] or {}
    return companyData[HISTORY_KEY], companyData
end

function PZLinuxTradingSeedHistory(company)
    if type(company) ~= "table" or type(company.code) ~= "string" then
        return nil
    end

    local history, companyData = PZLinuxTradingGetHistory(company.code)
    if not history then
        return nil
    end

    local _, lastPrice = PZLinuxTradingResolveLastPrice(history, company.price)
    if #history == 0 then
        lastPrice = math.max(1, floorNumber(company.price, 1))
    end

    while #history < MAX_HISTORY do
        local volatility = randomInt(5, 25)
        lastPrice = PZLinuxTradingNextPrice(lastPrice, volatility)
        table.insert(history, lastPrice)
    end

    trimHistory(history)
    return companyData
end

function PZLinuxTradingGetCurrentPrice(code, fallbackPrice)
    local company = PZLinuxTradingGetCompany(code)
    local history = nil
    if company then
        history = PZLinuxTradingGetHistory(company.code)
    end

    local _, lastPrice = PZLinuxTradingResolveLastPrice(history or {}, fallbackPrice or (company and company.price) or 1)
    return math.max(1, floorNumber(lastPrice, 1))
end

function PZLinuxTradingEnsureMarketInitialized(transmit)
    if not ModData or not ModData.getOrCreate then
        return false
    end

    local globalData = ModData.getOrCreate(META_TAG)
    globalData.PZLinuxTrading = 1

    local nowHour = getGameTime and math.floor(getGameTime():getWorldAgeHours()) or 0
    if tonumber(globalData.lastUpdateHour) == nil then
        globalData.lastUpdateHour = nowHour
    end

    if type(PZLinuxTradingCompanyNameTable) == "table" then
        for _, company in ipairs(PZLinuxTradingCompanyNameTable) do
            local companyData = PZLinuxTradingSeedHistory(company)
            if transmit and companyData then
                PZLinuxSyncGlobalModData(PZLinuxTradingGetCompanyTag(company.code), companyData)
            end
        end
    end

    if transmit then
        PZLinuxSyncGlobalModData(META_TAG, globalData)
    end

    return true
end

function PZLinuxTradingAdvanceMarket(hours, transmit)
    if not PZLinuxTradingEnsureMarketInitialized(false) then
        return false
    end

    local steps = math.max(0, math.min(floorNumber(hours, 0), MAX_HISTORY))
    if steps <= 0 then
        return true
    end

    if type(PZLinuxTradingCompanyNameTable) == "table" then
        for _, company in ipairs(PZLinuxTradingCompanyNameTable) do
            local history, companyData = PZLinuxTradingGetHistory(company.code)
            if history then
                local _, lastPrice = PZLinuxTradingResolveLastPrice(history, company.price)
                for _ = 1, steps do
                    lastPrice = PZLinuxTradingNextPrice(lastPrice, 5)
                    table.insert(history, lastPrice)
                    trimHistory(history)
                end

                if transmit then
                    PZLinuxSyncGlobalModData(PZLinuxTradingGetCompanyTag(company.code), companyData)
                end
            end
        end
    end

    local globalData = ModData.getOrCreate(META_TAG)
    if transmit then
        PZLinuxSyncGlobalModData(META_TAG, globalData)
    end

    return true
end

function PZLinuxTradingEnsureMarketFresh(transmit)
    if not PZLinuxTradingEnsureMarketInitialized(false) then
        return false
    end

    local globalData = ModData.getOrCreate(META_TAG)
    local nowHour = getGameTime and math.floor(getGameTime():getWorldAgeHours()) or 0
    local lastUpdateHour = floorNumber(globalData.lastUpdateHour, nowHour)
    local deltaHours = math.max(0, nowHour - lastUpdateHour)

    if deltaHours > 0 then
        PZLinuxTradingAdvanceMarket(deltaHours, transmit)
        globalData.lastUpdateHour = nowHour
    end

    if transmit then
        if type(PZLinuxTradingCompanyNameTable) == "table" then
            for _, company in ipairs(PZLinuxTradingCompanyNameTable) do
                local _, companyData = PZLinuxTradingGetHistory(company.code)
                if companyData then
                    PZLinuxSyncGlobalModData(PZLinuxTradingGetCompanyTag(company.code), companyData)
                end
            end
        end
        PZLinuxSyncGlobalModData(META_TAG, globalData)
    end

    return true
end

function PZLinuxTradingBuildMarketSnapshot()
    local snapshot = {}
    if not ModData or not ModData.getOrCreate then
        return snapshot
    end

    snapshot[META_TAG] = PZLinuxCloneSerializableTable(ModData.getOrCreate(META_TAG)) or {}

    if type(PZLinuxTradingCompanyNameTable) == "table" then
        for _, company in ipairs(PZLinuxTradingCompanyNameTable) do
            local tag = PZLinuxTradingGetCompanyTag(company.code)
            if tag then
                snapshot[tag] = PZLinuxCloneSerializableTable(ModData.getOrCreate(tag)) or {}
            end
        end
    end

    return snapshot
end

function PZLinuxTradingApplyCompanyImpact(tagOrCode, direction, transmit)
    if type(tagOrCode) ~= "string" or tagOrCode == "" then
        return false
    end

    local code = tagOrCode
    if tagOrCode:sub(1, #META_TAG) == META_TAG then
        code = tagOrCode:sub(#META_TAG + 1)
    end

    local company = PZLinuxTradingGetCompany(code)
    if not company then
        return false
    end

    if not PZLinuxTradingIsContractImpactEnabled() then
        return false
    end

    local impactMaxPercent = PZLinuxTradingGetContractImpactMaxPercent()
    if impactMaxPercent <= 0 then
        return false
    end

    PZLinuxTradingEnsureMarketInitialized(false)

    local history, companyData = PZLinuxTradingGetHistory(code)
    if not history or not companyData then
        return false
    end

    local _, lastPrice = PZLinuxTradingResolveLastPrice(history, company.price)
    local impactPercent = randomContractImpactPercent(impactMaxPercent)
    if impactPercent <= 0 then
        return false
    end

    local newPrice = lastPrice
    if direction == "down" then
        newPrice = math.max(1, roundNumber(lastPrice - (lastPrice * impactPercent / 100)))
    else
        newPrice = math.max(1, roundNumber(lastPrice + (lastPrice * impactPercent / 100)))
    end

    if newPrice == lastPrice then
        return false
    end

    table.insert(history, newPrice)
    trimHistory(history)

    if transmit then
        PZLinuxSyncGlobalModData(PZLinuxTradingGetCompanyTag(code), companyData)
        PZLinuxSyncGlobalModData(META_TAG, ModData.getOrCreate(META_TAG))
    end

    return true
end

function PZLinuxTradingApplyMarketSnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    for tag, data in pairs(snapshot) do
        if PZLinuxIsTradingGlobalTag(tag) and type(data) == "table" then
            PZLinuxApplyGlobalModDataSnapshot(tag, data)
        end
    end

    return true
end

function PZLinuxTradingGetPortfolio(modData)
    if type(modData) ~= "table" then
        return nil
    end

    modData[PORTFOLIO_KEY] = type(modData[PORTFOLIO_KEY]) == "table" and modData[PORTFOLIO_KEY] or {}
    return modData[PORTFOLIO_KEY]
end

function PZLinuxTradingNormalizePortfolioPosition(modData, code, walletQuantity, fallbackPrice)
    local portfolio = PZLinuxTradingGetPortfolio(modData)
    if not portfolio then
        return { quantity = 0, avgPrice = 0, invested = 0 }
    end

    local companyCode = tostring(code or "")
    if companyCode == "" then
        return { quantity = 0, avgPrice = 0, invested = 0 }
    end

    local quantity = math.max(0, floorNumber(walletQuantity, 0))
    local position = type(portfolio[companyCode]) == "table" and portfolio[companyCode] or {}
    local avgPrice = tonumber(position.avgPrice or position.averagePrice or position.buyPrice) or 0

    if quantity <= 0 then
        portfolio[companyCode] = nil
        return { quantity = 0, avgPrice = 0, invested = 0 }
    end

    if avgPrice <= 0 then
        avgPrice = math.max(1, floorNumber(fallbackPrice, 1))
    end

    position.quantity = quantity
    position.avgPrice = avgPrice
    position.invested = avgPrice * quantity
    portfolio[companyCode] = position
    return position
end

function PZLinuxTradingApplyPortfolioOrder(modData, action, code, quantity, unitPrice, walletQuantityBefore)
    local companyCode = tostring(code or "")
    local orderQuantity = math.max(0, floorNumber(quantity, 0))
    local price = math.max(1, floorNumber(unitPrice, 1))
    if type(modData) ~= "table" or companyCode == "" or orderQuantity <= 0 then
        return { quantity = 0, avgPrice = 0, invested = 0 }
    end

    local walletKey = "ZLinuxPlayerWallet" .. companyCode
    local oldQuantity = math.max(0, floorNumber(walletQuantityBefore, floorNumber(modData[walletKey], 0)))
    local position = PZLinuxTradingNormalizePortfolioPosition(modData, companyCode, oldQuantity, price)
    local portfolio = PZLinuxTradingGetPortfolio(modData)

    if action == "buy" then
        local newQuantity = oldQuantity + orderQuantity
        local oldInvested = (tonumber(position.avgPrice) or price) * oldQuantity
        local newInvested = oldInvested + (price * orderQuantity)
        local avgPrice = newQuantity > 0 and (newInvested / newQuantity) or 0
        position.quantity = newQuantity
        position.avgPrice = avgPrice
        position.invested = avgPrice * newQuantity
        portfolio[companyCode] = position
        return position
    end

    if action == "sell" then
        local newQuantity = math.max(0, oldQuantity - orderQuantity)
        if newQuantity <= 0 then
            portfolio[companyCode] = nil
            return { quantity = 0, avgPrice = 0, invested = 0 }
        end

        position.quantity = newQuantity
        position.invested = (tonumber(position.avgPrice) or price) * newQuantity
        portfolio[companyCode] = position
        return position
    end

    return position
end

function PZLinuxTradingGetPortfolioStats(modData, code, currentPrice)
    local companyCode = tostring(code or "")
    if type(modData) ~= "table" or companyCode == "" then
        return { quantity = 0, avgPrice = 0, currentPrice = 0, value = 0, invested = 0, profit = 0, profitPercent = 0 }
    end

    local walletKey = "ZLinuxPlayerWallet" .. companyCode
    local quantity = math.max(0, floorNumber(modData[walletKey], 0))
    local price = math.max(1, floorNumber(currentPrice, 1))
    local position = PZLinuxTradingNormalizePortfolioPosition(modData, companyCode, quantity, price)
    local avgPrice = tonumber(position.avgPrice) or 0
    local invested = avgPrice * quantity
    local value = price * quantity
    local profit = value - invested
    local profitPercent = invested > 0 and (profit * 100 / invested) or 0

    return {
        quantity = quantity,
        avgPrice = avgPrice,
        currentPrice = price,
        value = value,
        invested = invested,
        profit = profit,
        profitPercent = profitPercent,
    }
end

function PZLinuxTradingRecordWalletHistory(modData)
    if type(modData) ~= "table" then
        return 0
    end

    modData.playerWallet = type(modData.playerWallet) == "table" and modData.playerWallet or {}

    local totalWalletBalance = 0
    if type(PZLinuxTradingCompanyNameTable) == "table" then
        for _, company in ipairs(PZLinuxTradingCompanyNameTable) do
            local playerWallet = "ZLinuxPlayerWallet" .. tostring(company.code or "")
            local totalTokenQuantity = math.max(0, floorNumber(modData[playerWallet], 0))
            local lastPrice = PZLinuxTradingGetCurrentPrice(company.code, company.price)
            totalWalletBalance = totalWalletBalance + (lastPrice * totalTokenQuantity)
        end
    end

    table.insert(modData.playerWallet, totalWalletBalance)
    if #modData.playerWallet > MAX_HISTORY then
        table.remove(modData.playerWallet, 1)
    end

    return totalWalletBalance
end
