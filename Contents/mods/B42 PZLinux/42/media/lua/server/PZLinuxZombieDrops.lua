require "AAA_PZLinuxCompat"
local function isForceZombieItemSpawnEnabled()
    local modSandbox = SandboxVars and SandboxVars.PZLinux
    if not modSandbox then
        return true
    end

    local value = modSandbox.ForceItemZombieSpawn
    if value == nil then
        return true
    end

    return value == true
end

local function addCorpseDrop(container, fullType)
    if not container or type(fullType) ~= "string" or fullType == "" then
        return false
    end

    if PZLinuxSafeAddItem then
        return PZLinuxSafeAddItem(container, fullType) ~= nil
    end

    local ok, item = pcall(function()
        return container:AddItem(fullType)
    end)

    return ok and item ~= nil
end

local function onDeadBodySpawn(body)
    if not body or not body.isZombie or not body:isZombie() then
        return
    end

    if not PZLinuxConfig.IsEnabled() or not isForceZombieItemSpawnEnabled() then
        return
    end

    local container = body.getContainer and body:getContainer() or nil
    if not container then
        return
    end

    -- Mesma chance global de 0.5%, mas aplicada apenas quando o corpo existe.
    if ZombRand(10000) < PZLinuxConfig.Get("ZombieCardDropChance") * 100 then
        addCorpseDrop(container, "Base.IDcard")
        addCorpseDrop(container, "Base.CreditCard")
        if container.setDrawDirty then
            container:setDrawDirty(true)
        end
    end
end

Events.OnDeadBodySpawn.Add(onDeadBodySpawn)
