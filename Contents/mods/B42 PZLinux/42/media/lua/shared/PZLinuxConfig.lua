-- Shared settings are read at use time: SandboxVars may not exist at load time.
PZLinuxConfig = PZLinuxConfig or {}
local Config = PZLinuxConfig
Config.Version = "0.3.0-b42.21"
Config.Definitions = {
    Enabled = { default = true },
    ATMEnabled = { default = true },
    DarkWebEnabled = { default = true },
    LocalMarketEnabled = { default = true },
    VehicleTradingEnabled = { default = true },
    ContractsEnabled = { default = true },
    RequestsEnabled = { default = true },
    MailEnabled = { default = true },
    TradingEnabled = { default = true },
    BettingEnabled = { default = true },
    HackingEnabled = { default = true },
    RepairEnabled = { default = true },
    CurrencyConversionEnabled = { default = true },
    CurrencyMode = { default = 1, min = 1, max = 2, integer = true },
    AcceptAlternateCurrency = { default = true },
    StartingBalanceMin = { default = 500, min = 0, max = 10000000, integer = true },
    StartingBalanceMax = { default = 3999, min = 0, max = 10000000, integer = true },
    MaxCashTransaction = { default = 100000, min = 1, max = 1000000, integer = true },
    ComputerRequiresPower = { default = true },
    ATMRequiresPower = { default = true },
    ComputerFuelPerMinute = { default = 0.0003, min = 0, max = 1 },
    ATMFuelPerMinute = { default = 0.0002, min = 0, max = 1 },
    ConnectionHours = { default = 24, min = 1, max = 8760, integer = true },
    ComputerWearMultiplier = { default = 1, min = 0, max = 100 },
    RepairMultiplier = { default = 1, min = 0.1, max = 100 },
    RepairTime = { default = 430, min = 1, max = 10000, integer = true },
    RepairXP = { default = 3, min = 0, max = 100 },
    PurchasePriceMultiplier = { default = 1, min = 0.1, max = 100 },
    SalePriceMultiplier = { default = 1, min = 0.1, max = 100 },
    ContractRewardMultiplier = { default = 1, min = 0, max = 100 },
    ContractRefreshHours = { default = 168, min = 1, max = 8760, integer = true },
    ProtectWaveCount = { default = 30, min = 1, max = 80, integer = true },
    HackingRewardMultiplier = { default = 1, min = 0, max = 100 },
    HackingMinElectricity = { default = 0, min = 0, max = 10, integer = true },
    BettingMaxStake = { default = 100000, min = 1, max = 10000000, integer = true },
    BettingPayoutMultiplier = { default = 1, min = 0, max = 100 },
    MailMinHours = { default = 48, min = 1, max = 8760, integer = true },
    MailMaxHours = { default = 720, min = 1, max = 8760, integer = true },
    DarkWebRefreshHours = { default = 24, min = 1, max = 8760, integer = true },
    DarkWebMaxOffers = { default = 2, min = 1, max = 20, integer = true },
    DarkWebDeliveryTheftChance = { default = 10, min = 0, max = 100 },
    DarkWebSharedCatalogEnabled = { default = true },
    TradingVolatilityMultiplier = { default = 1, min = 0, max = 10 },
    ContractTradingImpactEnabled = { default = true },
    ContractTradingImpactMaxPercent = { default = 1, min = 0, max = 100 },
    DemandEnabled = { default = true },
    DemandMinimum = { default = 0.75, min = 0.1, max = 10 },
    DemandMaximum = { default = 2.5, min = 0.1, max = 10 },
    DemandBuyStep = { default = 0.02, min = 0, max = 1 },
    DemandSellStep = { default = 0.01, min = 0, max = 1 },
    DemandDecayPerHour = { default = 0.005, min = 0, max = 1 },
    ForceItemZombieSpawn = { default = true },
    ZombieCardDropChance = { default = 0.5, min = 0, max = 100 },
    EnableAutoHack = { default = true },
    AutoHackAdminOnly = { default = false },
}

function Config.Get(name)
    local definition = Config.Definitions[name]
    assert(definition, "Unknown PZLinux setting: " .. tostring(name))
    local value = SandboxVars and SandboxVars.PZLinux and SandboxVars.PZLinux[name]
    if type(definition.default) == "boolean" then
        if value == nil then return definition.default end
        return value == true
    end
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = definition.default end
    value = math.max(definition.min, math.min(definition.max, value))
    if definition.integer then value = math.floor(value) end
    return value
end

function Config.IsEnabled(feature)
    if not Config.Get("Enabled") then return false end
    if feature == "VehicleTrading" and not Config.Get("LocalMarketEnabled") then return false end
    local name = tostring(feature or "") .. "Enabled"
    return not Config.Definitions[name] or Config.Get(name)
end

function Config.NewBankBalance()
    local minimum = Config.Get("StartingBalanceMin")
    local maximum = math.max(minimum, Config.Get("StartingBalanceMax"))
    if minimum == maximum then return minimum end
    return ZombRand(minimum, maximum + 1)
end

function Config.Amount(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return 0 end
    return math.max(0, math.floor(value))
end

function Config.HasPower(square, feature)
    if not Config.Get(feature == "ATM" and "ATMRequiresPower" or "ComputerRequiresPower") then return true end
    if not square then return false end
    -- Local generators power indoor terminals regardless of AllowExteriorGenerator.
    local outside = square.isOutside and square:isOutside()
    if square:haveElectricity() and (not outside or (SandboxVars and SandboxVars.AllowExteriorGenerator)) then return true end
    local options = getSandboxOptions()
    local shutoff = options:getElecShutModifier()
    local days = getGameTime():getWorldAgeHours() / 24 + (options:getTimeSinceApo() - 1) * 30
    return shutoff > -1 and days < shutoff
end

function PZLinuxRequireFeature(feature, player)
    if Config.IsEnabled(feature) then return true end
    if player and HaloTextHelper and HaloTextHelper.addBadText then
        HaloTextHelper.addBadText(player, getText("UI_PZLinux_FeatureDisabled"))
    end
    return false
end
