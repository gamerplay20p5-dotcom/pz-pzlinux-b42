require "AAA_PZLinuxCompat"
require "PZLinuxTradingCore"
require "PZLinuxEconomy"

local MODULE = PZLinuxModule or "PZLinux"

local function playWorldUiSound(player, soundName)
    if not player or type(soundName) ~= "string" or soundName == "" then
        return
    end

    local square = player.getSquare and player:getSquare() or nil
    if not square then
        return
    end

    local volume = getCore():getOptionSoundVolume() / 50
    local sound = getSoundManager():PlayWorldSound(soundName, false, square, 0, 20, 1, true)
    if sound and sound.setVolume then
        sound:setVolume(volume)
    end
end

local onEconomyDemandData

local function onDarkWebSaleResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    onEconomyDemandData(args)

    if args and args.ok then
        local modData = PZLinuxGetModData(player)
        if modData and tonumber(args.balance) ~= nil then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
            modData.PZLinuxBankCoins = nil
        end
        local darkWeb = PZLinuxDarkWebInstance
        if darkWeb and not darkWeb.isClosing then
            if darkWeb.titleLabel then
                darkWeb.titleLabel:setName(PZLinuxText(
                    "UI_PZLinux_BankBalance",
                    "Bank Balance: %s",
                    PZLinuxFormatCurrency(args.balance or 0)
                ))
            end
            if darkWeb.mode == "sell" and darkWeb.onSell then
                darkWeb:onSell()
            end
        end
        playWorldUiSound(player, "sold")
        HaloTextHelper.addGoodText(player, PZLinuxText(
            "UI_PZLinux_DarkWebSaleCredited",
            "Sale credited to your bank: %1",
            PZLinuxFormatCurrency(args.totalPrice or 0)
        ))
        addXp(player, Perks.PlantScavenging, 3)
        return
    end

    playWorldUiSound(player, "error")

    local reason = args and tostring(args.reason or "") or ""
    if reason == "create_failed" then
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_ItemCreationFailed", "The contract item could not be created."))
    elseif reason == "delivery_failed" then
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_DeliveryFailed", "Delivery failed. Free some inventory space and try again."))
    else
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_NotInMainInventory", "The item is not in my main inventory"))
    end
end

local function onDarkWebCatalogData(args)
    if PZLinuxDarkWebOnCatalogData then
        PZLinuxDarkWebOnCatalogData(args or {})
    end
end

local function onDarkWebPurchaseResult(args)
    if PZLinuxDarkWebOnPurchaseResult then
        PZLinuxDarkWebOnPurchaseResult(args or {})
    end
end

local function onDarkWebDeliveryResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    if args and args.ok then
        playWorldUiSound(player, "done")
        HaloTextHelper.addGoodText(player, PZLinuxText(
            "UI_PZLinux_DarkWebDeliveryCollected",
            "Dark Web order collected from the mailbox"
        ))
        return
    end

    local reason = args and tostring(args.reason or "") or ""
    if reason == "no_delivery" then
        return
    end

    playWorldUiSound(player, "error")
    if reason == "stolen" then
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_OrderStolen", "Your order has been stolen during delivery!"))
    else
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_DeliveryFailed", "Delivery failed. Free some inventory space and try again."))
    end
end

local function onCashInSuspiciousPackagesResult(args)
    local player = getPlayer()
    if not player or not (args and args.ok) then
        return
    end

    local modData = PZLinuxGetModData(player)
    if modData and tonumber(args.balance) ~= nil then
        modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
    end

    playWorldUiSound(player, "sold")
end

local function onMailboxContractResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    if args and args.ok then
        HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_ContractDeliveryAccepted", "Contract delivery accepted"))
        return
    end

    playWorldUiSound(player, "error")
    HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_ContractDeliveryRejected", "The server did not validate this contract delivery."))
end

local function onMailDeliveryResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    if args and args.ok then
        local _, _, mail = PZLinuxGetMailEntry(player, args.mailId)
        if mail then
            if mail.x ~= nil and mail.y ~= nil and contractsRemoveDrawOnMap then
                contractsRemoveDrawOnMap(mail.x, mail.y)
                contractsRemoveDrawOnMap(mail.x + 20, mail.y)
            end
            mail.status = 10
        end

        playWorldUiSound(player, "done")
        HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_MailCompleted", "Mail completed successfully!"))
        HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_MailGift", "You received a gift for your help!"))
        HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_ReputationUp", "Reputation increased to +10"))
        player:getStats():add(CharacterStat.BOREDOM, -2)
        player:getStats():add(CharacterStat.UNHAPPINESS, -4)
        return
    end

    playWorldUiSound(player, "error")
    HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_DeliveryFailed", "Delivery failed. Free some inventory space and try again."))
end

local function applyTradingMarketSnapshot(args)
    if args and type(args.market) == "table" and PZLinuxTradingApplyMarketSnapshot then
        PZLinuxTradingApplyMarketSnapshot(args.market)
    end

    if PZLinuxTradingOnMarketData then
        PZLinuxTradingOnMarketData(args or {})
    end
end

local function onTradingData(args)
    applyTradingMarketSnapshot(args)
end

function onEconomyDemandData(args)
    if args and type(args.demand) == "table" and PZLinuxEconomyApplyDemandSnapshot then
        PZLinuxEconomyApplyDemandSnapshot(args.demand)
    end
end

local function onCoinConvertResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    if args and tonumber(args.balance) ~= nil then
        local modData = PZLinuxGetModData(player)
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
        end
    end

    if PZLinuxConverterInstance and PZLinuxConverterInstance.onConvertResult then
        PZLinuxConverterInstance:onConvertResult(args or {})
        return
    end

    if PZLinuxAtmConverterInstance and PZLinuxAtmConverterInstance.onConvertResult then
        PZLinuxAtmConverterInstance:onConvertResult(args or {})
        return
    end

    if args and args.ok then
        playWorldUiSound(player, "sold")
        HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_ConvertOk", "Money converted"))
    else
        playWorldUiSound(player, "error")
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_ConvertFailed", "Not enough money"))
    end
end

local function applyBankBalance(args)
    local player = getPlayer()
    if not player then
        return nil
    end

    if args and tonumber(args.balance) ~= nil then
        local modData = PZLinuxGetModData(player)
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
            modData.PZLinuxBankCoins = nil
        end
    end

    return player
end

local function onBankBalanceResult(args)
    applyBankBalance(args)
    if PZLinuxAtmInstance and PZLinuxAtmInstance.onBankBalanceResult then
        PZLinuxAtmInstance:onBankBalanceResult(args or {})
    end
end

local function onBankWithdrawalResult(args)
    local player = applyBankBalance(args)
    if not player then
        return
    end

    if PZLinuxAtmInstance and PZLinuxAtmInstance.onWithdrawalResult then
        PZLinuxAtmInstance:onWithdrawalResult(args or {})
        return
    end

    if args and args.ok then
        playWorldUiSound(player, "sold")
        HaloTextHelper.addGoodText(player, PZLinuxText(
            "UI_PZLinux_WithdrawalOk",
            "Withdrawal completed: %1",
            PZLinuxFormatCurrency(args.amount or 0)
        ))
    else
        playWorldUiSound(player, "error")
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_WithdrawalFailed", "Withdrawal failed"))
    end
end

local function onBankDepositResult(args)
    local player = applyBankBalance(args)
    if not player then
        return
    end

    if PZLinuxAtmInstance and PZLinuxAtmInstance.onDepositResult then
        PZLinuxAtmInstance:onDepositResult(args or {})
        return
    end

    if args and args.ok then
        playWorldUiSound(player, "sold")
        HaloTextHelper.addGoodText(player, PZLinuxText(
            "UI_PZLinux_DepositMoneyOk",
            "Deposit completed: %1",
            PZLinuxFormatCurrency(args.amount or 0)
        ))
    else
        playWorldUiSound(player, "error")
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_DepositMoneyFailed", "Not enough money"))
    end
end

local function onTradingOrderResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    onEconomyDemandData(args)
    applyTradingMarketSnapshot(args)

    if args and args.ok then
        local modData = PZLinuxGetModData(player)
        if modData then
            if tonumber(args.balance) ~= nil then
                modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
            end

            local code = tostring(args.code or "")
            if code ~= "" and tonumber(args.walletQuantity) ~= nil then
                modData["ZLinuxPlayerWallet" .. code] = math.max(0, math.floor(tonumber(args.walletQuantity) or 0))
            end

            if type(args.portfolio) == "table" then
                modData.PZLinuxTradingPortfolio = PZLinuxCloneSerializableTable(args.portfolio) or {}
            end

            if PZLinuxTradingRecordWalletHistory then
                PZLinuxTradingRecordWalletHistory(modData)
            end
        end

        if tostring(args.action or "") == "sell" then
            local totalPrice = tonumber(args.totalPrice) or 0
            if totalPrice >= 5000 then
                player:getStats():add(CharacterStat.UNHAPPINESS, -10)
                player:getStats():add(CharacterStat.STRESS, -0.5)
            elseif totalPrice >= 1000 then
                player:getStats():add(CharacterStat.UNHAPPINESS, -5)
                player:getStats():add(CharacterStat.STRESS, -0.1)
            end
        end

        playWorldUiSound(player, "sold")
        HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_TradingOrderCompleted", "Order completed"))
    else
        playWorldUiSound(player, "error")

        local reason = args and tostring(args.reason or "") or ""
        if reason == "not_enough_money" then
            HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_NotEnoughMoney", "Not enough money"))
        elseif reason == "not_enough_assets" then
            HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_NotEnoughAssets", "Not enough assets"))
        else
            HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_TradingOrderFailed", "Order failed"))
        end
    end

    if PZLinuxTradingOnOrderResult then
        PZLinuxTradingOnOrderResult(args or {})
    end
end

local CLIENT_COMMANDS = {
    DarkWebSaleResult = onDarkWebSaleResult,
    DarkWebCatalogData = onDarkWebCatalogData,
    DarkWebPurchaseResult = onDarkWebPurchaseResult,
    DarkWebDeliveryResult = onDarkWebDeliveryResult,
    CashInSuspiciousPackagesResult = onCashInSuspiciousPackagesResult,
    MailboxContractResult = onMailboxContractResult,
    MailDeliveryResult = onMailDeliveryResult,
    TradingData = onTradingData,
    EconomyDemandData = onEconomyDemandData,
    CoinConvertResult = onCoinConvertResult,
    BankBalanceResult = onBankBalanceResult,
    BankWithdrawalResult = onBankWithdrawalResult,
    BankDepositResult = onBankDepositResult,
    TradingOrderResult = onTradingOrderResult,
}

local function onServerCommand(module, command, args)
    if module ~= MODULE then
        return
    end

    local handler = CLIENT_COMMANDS[command]
    if handler then
        handler(args or {})
    end
end

Events.OnServerCommand.Add(onServerCommand)
