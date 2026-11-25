local path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/"):match("^(.*)/regression.lua$")
local Fixture = dofile(path .. "/fixture.lua")
local passed, failed = 0, 0
local function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function economy(mode)
    local w, e = Fixture.new(mode); w:load("PZLinuxEconomy"); return w, e
end
local function server()
    local w, e = economy("server"); w:load("ISPZLinuxVariablesTables"); w:load("PZLinuxServerCommands"); return w, e
end

test("missing Sandbox keeps previous defaults", function()
    local w, e = economy(); e.SandboxVars = nil
    eq(e.PZLinuxConfig.Get("CurrencyMode"), 1); eq(e.PZLinuxConfig.Get("StartingBalanceMin"), 500)
end)
test("settings reject nonfinite numbers and clamp bounds", function()
    local w, e = economy()
    w.settings.CurrencyMode = math.huge; eq(e.PZLinuxConfig.Get("CurrencyMode"), 1)
    w.settings.DemandBuyStep = 0/0; eq(e.PZLinuxConfig.Get("DemandBuyStep"), 0.02)
    w.settings.ProtectWaveCount = 999; eq(e.PZLinuxConfig.Get("ProtectWaveCount"), 80)
end)
test("global and individual module switches compose", function()
    local w, e = economy(); w.settings.LocalMarketEnabled = false
    eq(e.PZLinuxConfig.IsEnabled("VehicleTrading"), false); eq(e.PZLinuxConfig.IsEnabled("Trading"), true)
    w.settings.Enabled = false; eq(e.PZLinuxConfig.IsEnabled("Trading"), false)
end)
test("initial balance uses inclusive configured bounds and reversed bounds safely", function()
    local w, e = economy(); w.settings.StartingBalanceMin = 42; w.settings.StartingBalanceMax = 42
    eq(e.PZLinuxConfig.NewBankBalance(), 42)
    w.settings.StartingBalanceMin = 50; eq(e.PZLinuxConfig.NewBankBalance(), 50)
end)
test("indoor generator and configurable no-power mode work after grid shutdown", function()
    local w, e = economy(); eq(e.PZLinuxConfig.HasPower(w.square, "Computer"), false)
    w.power = true; e.SandboxVars.AllowExteriorGenerator = false
    eq(e.PZLinuxConfig.HasPower(w.square, "Computer"), true)
    w.power = false; w.settings.ATMRequiresPower = false; eq(e.PZLinuxConfig.HasPower(w.square, "ATM"), true)
end)
test("default withdrawals use vanilla bundles and cash", function()
    local w, e = economy(); assert(e.PZLinuxEconomyGiveCoinValue(w.player, 12345))
    eq(w:count("Base.MoneyBundle"), 123); eq(w:count("Base.Money"), 45); eq(w:count("Base.CobreCoin"), 0)
end)
test("coin mode creates exact gold silver copper denominations", function()
    local w, e = economy(); w.settings.CurrencyMode = 2
    assert(e.PZLinuxEconomyGiveCoinValue(w.player, 12345))
    eq(w:count("Base.GoldCoin"), 1); eq(w:count("Base.SilverCoin"), 23); eq(w:count("Base.CobreCoin"), 45)
    eq(e.PZLinuxEconomyGetInventoryCoinCounts(w.player).value, 12345)
end)
test("currency can change after load without changing saved bank value", function()
    local w, e = economy(); w.player.data.PZLinuxBank = 12345
    eq(e.PZLinuxEconomyGetBankCoinCounts(w.player).bundle, 123)
    w.settings.CurrencyMode = 2
    eq(e.PZLinuxEconomyGetBankCoinCounts(w.player).gold, 1); eq(w.player.data.PZLinuxBank, 12345)
    w.settings.CurrencyMode = 1
    eq(e.PZLinuxEconomyGetBankCoinCounts(w.player).value, 12345)
end)
test("alternate legacy currency remains depositable by default", function()
    local w, e = economy(); w:add("Base.GoldCoin"); w:add("Base.CobreCoin", 7)
    eq(e.PZLinuxEconomyGetInventoryCoinCounts(w.player).value, 10007)
    assert(e.PZLinuxEconomyRemoveCoinValueFromInventory(w.player, 10007).ok)
    eq(#w.items, 0)
end)
test("strict currency mode leaves the alternate family's items untouched", function()
    local w, e = economy(); w.settings.AcceptAlternateCurrency = false; w:add("Base.CobreCoin", 5)
    eq(e.PZLinuxEconomyGetInventoryCoinCounts(w.player).value, 0)
    eq(e.PZLinuxEconomyRemoveCoinValueFromInventory(w.player, 1).ok, false); eq(#w.items, 5)
    w.settings.CurrencyMode = 2; eq(e.PZLinuxEconomyGetInventoryCoinCounts(w.player).value, 5)
end)
test("payments return change using the selected currency", function()
    local w, e = economy(); w.settings.CurrencyMode = 2; w:add("Base.MoneyBundle")
    local result = e.PZLinuxEconomyRemoveCoinValueFromInventory(w.player, 60)
    eq(result.ok, true); eq(result.change, 40); eq(w:count("Base.CobreCoin"), 40)
end)
test("partial physical currency creation is rolled back", function()
    local w, e = economy(); w.failAddAt = 2
    eq(e.PZLinuxEconomyGiveCoinValue(w.player, 250), false); eq(#w.items, 0)
end)
test("failed change creation restores the original payment", function()
    local w, e = economy(); w:add("Base.MoneyBundle"); w.failAddAt = 1
    eq(e.PZLinuxEconomyRemoveCoinValueFromInventory(w.player, 50).ok, false)
    eq(w:count("Base.MoneyBundle"), 1); eq(w:count("Base.Money"), 0)
end)
test("partial removal restores previously removed currency", function()
    local w, e = economy(); w:add("Base.Money", 3); w.failRemoveAt = 2
    eq(e.PZLinuxEconomyRemoveCoinValueFromInventory(w.player, 3).ok, false); eq(w:count("Base.Money"), 3)
end)
test("coin inventory conversion conserves value and handles all directions", function()
    local w, e = economy(); w.settings.CurrencyMode = 2; w:add("Base.CobreCoin", 100)
    assert(e.PZLinuxEconomyConvertCoins(w.player, "copper_to_silver").ok); eq(w:count("Base.SilverCoin"), 1)
    assert(e.PZLinuxEconomyConvertCoins(w.player, "silver_to_copper").ok); eq(w:count("Base.CobreCoin"), 100)
    eq(e.PZLinuxEconomyGetInventoryCoinCounts(w.player).value, 100)
end)
test("failed conversion restores the exact input currency", function()
    local w, e = economy(); w:add("Base.MoneyBundle"); w.failAddAt = 2
    eq(e.PZLinuxEconomyConvertCoins(w.player, "gold_to_silver").ok, false)
    eq(w:count("Base.MoneyBundle"), 1); eq(w:count("Base.Money"), 0)
end)
test("bank conversion preserves numeric balances in both modes", function()
    local w, e = economy(); w.player.data.PZLinuxBank = 100
    assert(e.PZLinuxEconomyConvertBankCoins(w.player, "gold_to_silver").ok)
    assert(e.PZLinuxEconomyConvertBankCoins(w.player, "copper_to_silver").ok); eq(w.player.data.PZLinuxBank, 100)
    w.settings.CurrencyMode = 2
    assert(e.PZLinuxEconomyConvertBankCoins(w.player, "copper_to_silver").ok == false)
    assert(e.PZLinuxEconomyConvertBankCoins(w.player, "silver_to_copper").ok); eq(w.player.data.PZLinuxBank, 100)
    assert(e.PZLinuxEconomyConvertBankCoins(w.player, "copper_to_silver").ok); eq(w.player.data.PZLinuxBank, 100)
end)
test("disabling conversions rejects direct conversion calls", function()
    local w, e = economy(); w.settings.CurrencyConversionEnabled = false; w:add("Base.Money", 100)
    eq(e.PZLinuxEconomyConvertCoins(w.player, "copper_to_silver").reason, "disabled"); eq(#w.items, 100)
end)
test("demand options change price pressure without deleting saved demand", function()
    local w, e = economy(); w.settings.DemandBuyStep = 0.1
    e.PZLinuxEconomyRecordDemand("item:test", "up", 2)
    eq(e.PZLinuxEconomyGetDemandMultiplier("item:test"), 1.2)
    w.settings.DemandEnabled = false; eq(e.PZLinuxEconomyGetDemandMultiplier("item:test"), 1)
    w.settings.DemandEnabled = true; eq(e.PZLinuxEconomyGetDemandMultiplier("item:test"), 1.2)
end)
test("zero volatility freezes random trading price changes", function()
    local w, e = server(); w.settings.TradingVolatilityMultiplier = 0
    eq(e.PZLinuxTradingNextPrice(100, 30), 100)
end)
test("server cash operations preserve existing balance and use configured currency", function()
    local w, e = server(); w.player.data.PZLinuxBank = 1000; w.settings.CurrencyMode = 2
    w:command("WithdrawBankCoins", { amount = 125 }); eq(w.player.data.PZLinuxBank, 875)
    eq(w:count("Base.SilverCoin"), 1); eq(w:count("Base.CobreCoin"), 25)
    w:command("DepositBankCoins", { amount = 125 }); eq(w.player.data.PZLinuxBank, 1000); eq(#w.items, 0)
end)
test("server enforces cash transaction limit without mutation", function()
    local w, e = server(); w.player.data.PZLinuxBank = 1000; w.settings.MaxCashTransaction = 10
    w:command("WithdrawBankCoins", { amount = 11 }); eq(w.player.data.PZLinuxBank, 1000); eq(#w.items, 0)
    eq(w:reply("BankWithdrawalResult").reason, "transaction_limit")
end)
test("failed server withdrawal never debits a saved balance", function()
    local w, e = server(); w.player.data.PZLinuxBank = 1000; w.failAddAt = 2
    w:command("WithdrawBankCoins", { amount = 250 }); eq(w.player.data.PZLinuxBank, 1000); eq(#w.items, 0)
end)
test("disabled modules reject direct server commands", function()
    local w, e = server(); w.settings.ATMEnabled = false
    w:command("WithdrawBankCoins", { amount = 1 }); eq(w:reply("BankWithdrawalResult").reason, "disabled")
    w.settings.TradingEnabled = false
    w:command("ExecuteTradingOrder", { action = "buy", code = "test", quantity = 1 })
    eq(w:reply("TradingOrderResult").reason, "disabled")
end)
test("server ignores malformed command payloads", function()
    local w, e = server(); w:fire("OnClientCommand", "PZLinux", "WithdrawBankCoins", w.player, true)
    eq(#w.sent, 0)
end)
test("cargo spawn is replicated once and idempotent", function()
    local w, e = server(); w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractCargo = 1
    w:target("PZLinuxContractLocation")
    w:command("SpawnCargoBox", { x = 10, y = 10, z = 0 })
    eq(w.player.data.PZLinuxContractCargo, 2); eq(#w.square.objects, 1); eq(w.replications, 1)
    e.PZLinuxWorld.SpawnCargo(w.square); eq(#w.square.objects, 1); eq(w.replications, 1)
end)
test("unloaded cargo target remains pending", function()
    local w, e = server(); w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractCargo = 1
    w:target("PZLinuxContractLocation"); w.squareLoaded = false
    w:command("SpawnCargoBox", { x = 10, y = 10, z = 0 }); eq(w.player.data.PZLinuxContractCargo, 1)
end)
test("world requests cannot move the saved target to arbitrary coordinates", function()
    local w, e = server(); w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractCargo = 1
    w:target("PZLinuxContractLocation")
    w:command("SpawnCargoBox", { x = 11, y = 10, z = 0 }); eq(#w.square.objects, 0)
end)
test("cargo removal uses the native replicated removal API", function()
    local w, e = server(); e.PZLinuxWorld.SpawnCargo(w.square)
    w.player.data.PZLinuxContractCargo = 3; w:target("PZLinuxContractLocation"); w.player.x = 100
    w:command("RemoveCargoBox", { x = 10, y = 10, z = 0 })
    eq(w.player.data.PZLinuxContractCargo, 4); eq(w.removals, 1); eq(#w.square.objects, 0)
end)
test("failed manhunt spawn stays pending and can retry", function()
    local w, e = server(); w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractManhunt = 1
    w:target("PZLinuxContractLocation"); w.failZombie = true
    w:command("SpawnManhuntZombie", { x = 10, y = 10, z = 0 }); eq(w.player.data.PZLinuxContractManhunt, 1)
    w.failZombie = false; w:command("SpawnManhuntZombie", { x = 10, y = 10, z = 0 })
    eq(w.player.data.PZLinuxContractManhunt, 2); eq(#w.zombies, 1)
end)
test("failed request vehicle stays pending until a real spawn succeeds", function()
    local w, e = server(); w.player.data.PZLinuxOnItemRequestCar = 1; w.player.data.PZLinuxOnItemRequestCarName = "Base.CarNormal"
    w:target("PZLinuxRequestLocation"); w.failVehicle = true
    local args = { x = 10, y = 10, z = 0, script = "Base.CarNormal" }
    w:command("SpawnRequestVehicle", args); eq(w.player.data.PZLinuxOnItemRequestCar, 1)
    w.failVehicle = false; w:command("SpawnRequestVehicle", args)
    eq(w.player.data.PZLinuxOnItemRequestCar, 0); eq(#w.vehicles, 1); eq(w:count("Base.Key_Blank"), 1)
end)
test("protection wave uses authoritative Sandbox size instead of client count", function()
    local w, e = server(); w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractProtect = 1
    w.settings.ProtectWaveCount = 3; w:target("PZLinuxContractLocation")
    w:command("SpawnProtectWave", { x = 10, y = 10, z = 0, count = 80 }); eq(#w.zombies, 3)
end)
test("MP client requests do not consume pending cargo or vehicle state", function()
    local w, e = economy("client"); w:load("Context/World/Events/PZLinuxOnEvents")
    w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractCargo = 1; w:target("PZLinuxContractLocation")
    w.player.data.PZLinuxOnItemRequestCar = 1; w:target("PZLinuxRequestLocation")
    w:fire("OnPlayerMove", w.player)
    eq(w.player.data.PZLinuxContractCargo, 1); eq(w.player.data.PZLinuxOnItemRequestCar, 1)
    eq(#w.requests, 2); w:fire("OnPlayerMove", w.player); eq(#w.requests, 2)
end)
test("SP retries cargo when the square becomes available", function()
    local w, e = economy(); w:load("Context/World/Events/PZLinuxOnEvents")
    w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractCargo = 1; w:target("PZLinuxContractLocation")
    w.squareLoaded = false; w:fire("OnPlayerMove", w.player); eq(w.player.data.PZLinuxContractCargo, 1)
    w.squareLoaded = true; w:fire("OnPlayerMove", w.player); eq(w.player.data.PZLinuxContractCargo, 2)
end)
test("another player's zombie kills do not advance personal objectives", function()
    local w, e = economy(); w:load("Context/World/Events/PZLinuxOnEvents")
    w.player.data.PZLinuxContractKillZombie = 1; w.player.data.PZLinuxOnZombieToKill = 1
    w:fire("OnZombieDead", { getAttackedBy = function() return {} end }); eq(w.player.data.PZLinuxOnZombieDead, nil)
    w:fire("OnZombieDead", { getAttackedBy = function() return w.player end }); eq(w.player.data.PZLinuxActiveContract, 9)
end)
test("outside power respects the vanilla exterior generator switch", function()
    local w, e = economy(); w.power = true; w.outside = true; e.SandboxVars.AllowExteriorGenerator = false
    eq(e.PZLinuxConfig.HasPower(w.square, "Computer"), false)
    e.SandboxVars.AllowExteriorGenerator = true; eq(e.PZLinuxConfig.HasPower(w.square, "Computer"), true)
end)
test("failed protection wave does not consume the pending contract", function()
    local w, e = server(); w.player.data.PZLinuxActiveContract = 1; w.player.data.PZLinuxContractProtect = 1
    w:target("PZLinuxContractLocation"); w.failZombie = true
    w:command("SpawnProtectWave", { x = 10, y = 10, z = 0 }); eq(w.player.data.PZLinuxContractProtect, 1)
end)
test("SP ATM applies the same cash cap before creating items", function()
    local w, e = economy(); w:load("Context/World/ISContextAtmMenu")
    w.settings.MaxCashTransaction = 10; w.player.data.PZLinuxBank = 1000
    local ui = { amountFieldWithdrawal = { getText = function() return "11" end } }
    e.AtmUI.onWithdrawalSend(ui); eq(#w.items, 0); eq(w.player.data.PZLinuxBank, 1000)
end)
test("nonfinite cash inputs cannot create or deposit currency", function()
    local w, e = server(); w.player.data.PZLinuxBank = 1000
    w:command("WithdrawBankCoins", { amount = math.huge }); eq(w.player.data.PZLinuxBank, 1000)
    w:command("DepositBankCoins", { amount = 0/0 }); eq(w.player.data.PZLinuxBank, 1000); eq(#w.items, 0)
end)
test("disabled direct UI entry points and existing-window purchases return safely", function()
    local w, e = economy(); w:load("ISPZLinuxVariablesTables")
    w:load("Context/World/Features/PZLinuxTrading"); w:load("Context/World/Features/PZLinuxBetting")
    w.settings.TradingEnabled, w.settings.BettingEnabled = false, false
    eq(e.tradingMenu_ShowUI(w.player), nil)
    e.tradingUI.onTradingBuy({}, "unused", 10, 2)
    e.bettingUI.onStartSlots({}); eq(#w.items, 0)
end)
test("repair requires successful scrap consumption and uses the configured multiplier", function()
    local w, e = economy(); w:load("TimedActions/ISPZLinuxRepareAction")
    w.settings.RepairMultiplier = 2
    local computer = { data = { statusCondition = 20 }, getSquare = function() return w.square end }
    function computer:getModData() return self.data end
    local action = e.ISPZLinuxRepareAction:new(w.player, computer)
    action:perform(); eq(computer.data.statusCondition, 20)
    w:add("Base.ElectronicsScrap"); w.failRemoveAt = 1
    action:perform(); eq(computer.data.statusCondition, 20)
    w.failRemoveAt = nil; action:perform(); eq(computer.data.statusCondition, 30); eq(#w.items, 0)
end)
test("mail schedule clamps an inverted maximum to the configured minimum", function()
    local w, e = economy(); w:load("Context/World/Events/PZLinuxOnEvents")
    w.settings.MailMinHours, w.settings.MailMaxHours, w.hour = 10, 5, 100
    w:fire("EveryTenMinutes"); eq(w.player.data.pzlinux.mails.nextat, 110)
end)
test("Dark Web catalog uses configured offer count and renewal interval", function()
    local w, e = server(); w:load("PZLinuxDarkWebServer")
    w.settings.DarkWebMaxOffers, w.settings.DarkWebRefreshHours, w.hour = 3, 6, 10
    w:fire("EveryHours")
    local catalog = w.stores.PZLinuxDarkWebCatalog
    eq(#catalog.offers, 3); eq(catalog.refreshAtHour, 16)
    local cycle = catalog.cycle
    w.hour = 15; w:fire("EveryHours"); eq(catalog.cycle, cycle)
    w.hour = 16; w:fire("EveryHours"); eq(catalog.cycle, cycle + 1)
end)
test("disabled Dark Web rejects new purchases without charging the bank", function()
    local w, e = server(); w:load("PZLinuxDarkWebServer")
    w.settings.DarkWebEnabled = false; w.player.data.PZLinuxBank = 10000000
    w:command("BuyDarkWebOffer", { offerId = "fake" })
    eq(w:reply("DarkWebPurchaseResult").reason, "disabled"); eq(w.player.data.PZLinuxBank, 10000000)
end)
test("zero theft chance preserves paid deliveries even after disabling purchases", function()
    local w, e = server(); w:load("PZLinuxDarkWebServer")
    w.settings.DarkWebEnabled = false; w.settings.DarkWebDeliveryTheftChance = 0
    w.player.data.PZLinuxOnItemBuyOnDarkWeb = { { { directDelivery = true, items = { { name = "Base.Hammer", count = 1 } } } } }
    w:command("ClaimDarkWebDeliveries", { canBeStolen = true })
    eq(w:count("Base.Hammer"), 1); eq(#w.player.data.PZLinuxOnItemBuyOnDarkWeb, 0)
end)
test("full theft chance removes only deliveries eligible for theft", function()
    local w, e = server(); w:load("PZLinuxDarkWebServer"); w.settings.DarkWebDeliveryTheftChance = 100
    w.player.data.PZLinuxOnItemBuyOnDarkWeb = { { { directDelivery = true, items = { { name = "Base.Hammer", count = 1 } } } } }
    w:command("ClaimDarkWebDeliveries", { canBeStolen = true })
    eq(w:reply("DarkWebDeliveryResult").reason, "stolen"); eq(w:count("Base.Hammer"), 0)
end)
test("disabling Local Market leaves other module commands independent", function()
    local w, e = server(); w:load("PZLinuxLocalMarketServer"); w.settings.LocalMarketEnabled = false
    w:command("RequestBankBalance"); eq(w:reply("BankBalanceResult").ok, true)
    eq(w:reply("LocalMarketResult"), nil)
    w:command("ListLocalMarketItem", {}); eq(w:reply("LocalMarketResult").reason, "disabled")
end)
test("Dark Web rejects malformed payloads without running handlers", function()
    local w, e = server(); w:load("PZLinuxDarkWebServer")
    w:fire("OnClientCommand", "PZLinux", "BuyDarkWebOffer", w.player, true); eq(#w.sent, 0)
end)
print(string.format("%d passed, %d failed (simulated native boundaries; no engine playtest)", passed, failed))
if failed > 0 then os.exit(1) end
