require "PZLinuxWorld"
require "AAA_PZLinuxCompat"

local function distanceSqTo(player, x, y)
    local dx, dy = player:getX() - x, player:getY() - y
    return dx * dx + dy * dy
end

local function OnZombieDead(zombie)
    if not PZLinuxConfig.IsEnabled("Contracts") then return end
    local player = getPlayer()
    if not player or not zombie then return end
    -- Deaths caused by another survivor do not advance this player's contract.
    if zombie.getAttackedBy and zombie:getAttackedBy() ~= player then return end
    local md = PZLinuxGetModData(player)
    md.PZLinuxOnZombieDead = (tonumber(md.PZLinuxOnZombieDead) or 0) + 1
    if md.PZLinuxContractKillZombie == 1 and md.PZLinuxOnZombieDead >= (tonumber(md.PZLinuxOnZombieToKill) or 0)
        and md.PZLinuxActiveContract ~= 10 then md.PZLinuxActiveContract = 9 end
    if md.PZLinuxContractProtect == 2 and md.PZLinuxOnZombieDead >= 10 then md.PZLinuxContractProtect = 3 end
end
Events.OnZombieDead.Add(OnZombieDead)

local function request(command, args)
    PZLinuxSendClientCommandThrottled(PZLinuxModule, command, args, 2000)
end

local function checkAndSpawnZombie(player)
    if not player or not PZLinuxConfig.IsEnabled("Contracts") then return end
    local md = PZLinuxGetModData(player)
    if md.PZLinuxActiveContract ~= 1 or md.PZLinuxContractManhunt ~= 1 then return end
    local x, y, z = tonumber(md.PZLinuxContractLocationX) or 0, tonumber(md.PZLinuxContractLocationY) or 0, tonumber(md.PZLinuxContractLocationZ) or 0
    if distanceSqTo(player, x, y) >= 2500 then return end
    if isClient() then request("SpawnManhuntZombie", { x = x, y = y, z = z }); return end
    if not getCell():getGridSquare(x, y, z) then return end
    local zombie = createZombie(x, y, z, nil, 0, IsoDirections.S)
    if not zombie then return end
    zombie:setUseless(true); zombie:setSitAgainstWall(true)
    md.PZLinuxContractManhunt = 2
    PZLinuxSyncPlayerModData(player)
end
Events.OnPlayerMove.Add(checkAndSpawnZombie)

local function checkAndSpawnVehicle(player)
    if not player or not PZLinuxConfig.IsEnabled("Requests") then return end
    local md = PZLinuxGetModData(player)
    if md.PZLinuxOnItemRequestCar ~= 1 then return end
    local x, y, z = tonumber(md.PZLinuxRequestLocationX) or 0, tonumber(md.PZLinuxRequestLocationY) or 0, tonumber(md.PZLinuxRequestLocationZ) or 0
    if distanceSqTo(player, x, y) >= 2500 then return end
    if isClient() then
        request("SpawnRequestVehicle", { x = x, y = y, z = z, script = md.PZLinuxOnItemRequestCarName }); return
    end
    if not PZLinuxWorld.SpawnVehicle(player, md.PZLinuxOnItemRequestCarName, getCell():getGridSquare(x, y, z)) then return end
    md.PZLinuxOnItemRequestCar, md.PZLinuxOnItemRequestCarName = 0, ""
    PZLinuxSyncPlayerModData(player)
end
Events.OnPlayerMove.Add(checkAndSpawnVehicle)

local function checkAndSpawnBox(player)
    if not player or not PZLinuxConfig.IsEnabled("Contracts") then return end
    local md = PZLinuxGetModData(player)
    local x, y, z = tonumber(md.PZLinuxContractLocationX) or 0, tonumber(md.PZLinuxContractLocationY) or 0, tonumber(md.PZLinuxContractLocationZ) or 0
    local distance = distanceSqTo(player, x, y)
    if md.PZLinuxContractCargo == 1 and distance < 2500 then
        if isClient() then request("SpawnCargoBox", { x = x, y = y, z = z }); return end
        if not PZLinuxWorld.SpawnCargo(getCell():getGridSquare(x, y, z)) then return end
        md.PZLinuxContractCargo = 2
        PZLinuxSyncPlayerModData(player)
    elseif md.PZLinuxContractCargo == 3 and distance > 2500 then
        if isClient() then request("RemoveCargoBox", { x = x, y = y, z = z }); return end
        local square = getCell():getGridSquare(x, y, z)
        if not square then return end
        PZLinuxWorld.RemoveCargo(square)
        md.PZLinuxContractCargo = 4
        PZLinuxSyncPlayerModData(player)
    end
end
Events.OnPlayerMove.Add(checkAndSpawnBox)

local nextContractCompletionCheckMs = 0

local function contractCompletedPlaySound()
    if not PZLinuxConfig.IsEnabled("Contracts") then return end
    local nowMs = getTimestampMs and getTimestampMs() or 0
    if nowMs > 0 and nowMs < nextContractCompletionCheckMs then
        return
    end
    nextContractCompletionCheckMs = nowMs + 250

    local player = getPlayer()
    if not player then return end

    local modData = PZLinuxGetModData(player)
    if modData.PZLinuxActiveContract ~= 9 then
        return
    end

    local globalVolume = getCore():getOptionSoundVolume() / 50
    getSoundManager():PlayWorldSound("done", false, player:getSquare(), 0, 20, 1, true):setVolume(globalVolume)
    HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_ContractCompleted", "Contract completed"))
    modData.PZLinuxActiveContract = 10

    player:getStats():add(CharacterStat.BOREDOM, -5)
    player:getStats():add(CharacterStat.UNHAPPINESS, -5)
    player:getStats():add(CharacterStat.STRESS, -2)

    modData.pzlinux.player.reputation = (tonumber(modData.pzlinux.player.reputation) or 1) + 10
    HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_ReputationUp", "Reputation increased to +10"))
    PZLinuxSyncPlayerModData(player)
end
Events.OnTick.Add(contractCompletedPlaySound)

Events.OnGameStart.Add(function()
    local player = getPlayer()
    if not player then return end

    local modData = PZLinuxGetModData(player)
    if modData.PZLinuxContractManhunt == 2 then
        modData.PZLinuxContractManhunt = 1
        PZLinuxSyncPlayerModData(player)
    end
end)

local function scheduleNextMail(player)
    local monthHours = PZLinuxConfig.Get("MailMaxHours")
    local md = PZLinuxGetModData(player)
    local now = getGameTime():getWorldAgeHours()
    local playerRep = math.min(tonumber(md.pzlinux.player.reputation) or 1, 200)
    local minimum = PZLinuxConfig.Get("MailMinHours")
    local maximum = math.max(minimum, monthHours - playerRep)
    local delay = minimum == maximum and minimum or ZombRand(minimum, maximum + 1)

    if not md.pzlinux.mails.nextat or md.pzlinux.mails.nextat <= now then
        md.pzlinux.mails.nextat = now + delay
    end
end

local function formatMailDate()
    local gameTime = getGameTime()
    return string.format(
        "%04d-%02d-%02d %02d:%02d",
        gameTime:getYear(),
        gameTime:getMonth() + 1,
        gameTime:getDay(),
        gameTime:getHour(),
        gameTime:getMinutes()
    )
end

local function popRandomMail(player)
    local md = PZLinuxGetModData(player)
    local idx = ZombRand(#PZLinuxMailTable) + 1
    local mailTemplate = PZLinuxMailTable[idx]
    local subject = mailTemplate.baseName

    if mailTemplate.key then
        subject = PZLinuxText(mailTemplate.key, mailTemplate.baseName)
    end

    local mailId = md.pzlinux.mails.nextid
    local senderName = PZLinuxGenerateRandomName()

    table.insert(md.pzlinux.mails.inbox, 1, {
        id = mailId,
        name = subject,
        type = mailTemplate.type,
        date = formatMailDate(),
        from = senderName,
        read = false
    })

    local _, _, mail = PZLinuxGetOrCreateMailEntry(player, mailId)
    if mail then
        mail.type = mail.type or mailTemplate.type
        mail.sender = mail.sender or senderName
    end

    md.pzlinux.mails.nextid = md.pzlinux.mails.nextid + 1
end

local function mailTick()
    if not PZLinuxConfig.IsEnabled("Mail") then return end
    local player = getPlayer()
    if not player then return end

    local md = PZLinuxGetModData(player)
    local now = getGameTime():getWorldAgeHours()
    md.pzlinux.player.reputation = math.max(1, (tonumber(md.pzlinux.player.reputation) or 1) - 0.001)

    if not md.pzlinux.mails.nextat then
        scheduleNextMail(player)
        PZLinuxSyncPlayerModData(player)
        return
    end

    if now >= md.pzlinux.mails.nextat then
        popRandomMail(player)
        scheduleNextMail(player)
        PZLinuxSyncPlayerModData(player)
    end
end
Events.EveryTenMinutes.Add(mailTick)
