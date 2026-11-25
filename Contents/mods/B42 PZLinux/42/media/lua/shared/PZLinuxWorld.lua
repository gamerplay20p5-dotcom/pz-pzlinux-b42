require "PZLinuxConfig"
PZLinuxWorld = PZLinuxWorld or {}
local World = PZLinuxWorld

function World.SpawnProtectWave(x, y, z)
    local created = 0
    for _ = 1, PZLinuxConfig.Get("ProtectWaveCount") do
        local radius, direction = ZombRand(20, 50), ZombRand(1, 5)
        local zx = x + ((direction == 1 or direction == 3) and radius or -radius)
        local zy = y + ((direction == 1 or direction == 4) and radius or -radius)
        if createZombie(zx, zy, z, nil, 0, IsoDirections.S) then created = created + 1 end
    end
    return created
end

function World.SpawnCargo(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object:getSprite() and object:getSprite():getName() == PZLinuxCargoBoxSprite then return object end
    end
    local object = IsoObject.new(square, PZLinuxCargoBoxSprite)
    square:AddTileObject(object)
    if isServer() then object:transmitCompleteItemToClients() end
    return object
end

function World.RemoveCargo(square)
    if not square then return false end
    for i = square:getObjects():size() - 1, 0, -1 do
        local object = square:getObjects():get(i)
        if object:getSprite() and object:getSprite():getName() == PZLinuxCargoBoxSprite then
            -- Correct B42.21 native API and multiplayer replication.
            square:transmitRemoveItemFromSquare(object)
            return true
        end
    end
    return false
end

function World.SpawnVehicle(player, script, square)
    if not player or not square or type(script) ~= "string" or script == "" then return nil end
    local vehicle = addVehicle(script, square:getX(), square:getY(), square:getZ())
    if not vehicle then return nil end
    local key = vehicle:createVehicleKey()
    if key then
        player:getInventory():AddItem(key)
        if PZLinuxNotifyAddedContainerItem then PZLinuxNotifyAddedContainerItem(player:getInventory(), key) end
    end
    vehicle:repair()
    return vehicle
end
