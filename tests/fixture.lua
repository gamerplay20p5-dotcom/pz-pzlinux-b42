local source = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local root = source:match("^(.*)/tests/fixture.lua$") .. "/Contents/mods/B42 PZLinux/42/media/lua/"
local Fixture = {}
local function list(items)
    return { size = function() return #items end, get = function(_, index) return items[index + 1] end,
        isEmpty = function() return #items == 0 end }
end

function Fixture.new(mode)
    local world = { mode = mode or "sp", now = 10000, hour = 0, loaded = {}, handlers = {}, stores = {},
        settings = {}, sent = {}, requests = {}, items = {}, nextID = 0, squareLoaded = true, zombies = {}, vehicles = {} }
    local env = setmetatable({}, { __index = _G }); world.env = env
    env.isClient = function() return world.mode == "client" end
    env.isServer = function() return world.mode == "server" end
    env.SandboxVars = { PZLinux = world.settings, AllowExteriorGenerator = true }
    env.getTimestampMs = function() return world.now end
    env.getTimestamp = function() return math.floor(world.now / 1000) end
    env.getGameTime = function() return { getWorldAgeHours = function() return world.hour end } end
    env.getText = function(key) return key end
    env.getTextOrNull = function() return nil end
    env.Events = setmetatable({}, { __index = function(events, name)
        world.handlers[name] = world.handlers[name] or {}
        local event = { Add = function(fn) table.insert(world.handlers[name], fn) end,
            Remove = function(fn) for i = #world.handlers[name], 1, -1 do
                if world.handlers[name][i] == fn then table.remove(world.handlers[name], i) end end end }
        rawset(events, name, event); return event
    end })
    function world:fire(name, ...) for _, fn in ipairs(self.handlers[name] or {}) do fn(...) end end
    env.ModData = { getOrCreate = function(key) world.stores[key] = world.stores[key] or {}; return world.stores[key] end,
        transmit = function() end, request = function() end }
    env.ZombRand = function(a, b)
        if world.random ~= nil then return world.random end
        return b and a or 0
    end
    local inventory = {}
    world.inventory = inventory
    function inventory:getItems() return list(world.items) end
    function inventory:getAllTypeRecurse(fullType)
        local result = {}; for _, item in ipairs(world.items) do if item.fullType == fullType then result[#result + 1] = item end end
        return list(result)
    end
    function inventory:AddItem(value)
        if type(value) == "string" then
            world.addCount = (world.addCount or 0) + 1
            if world.failAddAt == world.addCount then return nil end
            world.nextID = world.nextID + 1
            local item = { fullType = value, id = world.nextID, data = {} }
            function item:getFullType() return self.fullType end
            function item:getID() return self.id end
            function item:getContainer() return self.container end
            function item:getModData() return self.data end
            function item:getName() return self.fullType end
            function item:setActualWeight() end
            function item:setWeight() end
            function item:setCustomWeight() end
            value = item
        end
        value.container = self; world.items[#world.items + 1] = value; return value
    end
    function inventory:DoRemoveItem(item)
        world.removeCount = (world.removeCount or 0) + 1
        if world.failRemoveAt == world.removeCount then return end
        for i, value in ipairs(world.items) do if value == item then table.remove(world.items, i); item.container = nil; return end end
    end
    function inventory:containsID(id) return self:getItemWithID(id) ~= nil end
    function inventory:getItemWithID(id) for _, item in ipairs(world.items) do if item.id == id then return item end end end
    function inventory:setDirty() end
    function inventory:setDrawDirty() end
    local player = { data = {}, x = 10, y = 10, z = 0 }
    world.player = player
    function player:getModData() return self.data end
    function player:getInventory() return inventory end
    function player:getUsername() return "Alice" end
    function player:getX() return self.x end
    function player:getY() return self.y end
    function player:getZ() return self.z end
    function player:getPlayerNum() return 0 end
    function player:getPerkLevel() return 0 end
    function player:transmitModData() world.playerSyncs = (world.playerSyncs or 0) + 1 end
    env.getPlayer = function() return player end
    env.getSpecificPlayer = function() return player end
    env.getOnlinePlayers = function() return list({ player }) end
    env.sendAddItemToContainer = function() end
    env.sendRemoveItemFromContainer = function() end
    env.sendClientCommand = function(...)
        local args = { ... }; world.requests[#world.requests + 1] = #args == 4
            and { command = args[3], args = args[4] } or { command = args[2], args = args[3] }
    end
    env.sendServerCommand = function(_, _, command, args) world.sent[#world.sent + 1] = { command = command, args = args } end
    env.getScriptManager = function() return {
        FindItem = function(_, fullType) if world.invalidType == fullType then return nil end
            return { DoParam = function() end } end,
        getAllItems = function() return list({}) end,
    } end
    env.getSandboxOptions = function() return { getElecShutModifier = function() return world.shutoff or 0 end,
        getTimeSinceApo = function() return 1 end } end
    env.HaloTextHelper = { addBadText = function() end, addGoodText = function() end }
    env.Perks = { Electricity = "Electricity", PlantScavenging = "PlantScavenging" }
    env.IsoDirections = { S = "S" }
    env.CharacterStat = { BOREDOM = "boredom", UNHAPPINESS = "unhappiness", STRESS = "stress" }
    env.ISPanel = {}
    function env.ISPanel:derive() local class = { __index = self }; return setmetatable(class, { __index = self }) end
    env.ISBaseTimedAction = env.ISPanel:derive()
    env.ISBaseTimedAction.new = function(self, character) return setmetatable({ character = character }, { __index = self }) end
    env.ISBaseTimedAction.perform = function() end
    env.addXp = function() end
    local square = { objects = {}, x = 10, y = 10, z = 0 }
    world.square = square
    function square:getX() return self.x end
    function square:getY() return self.y end
    function square:getZ() return self.z end
    function square:haveElectricity() return world.power == true end
    function square:isOutside() return world.outside == true end
    function square:getObjects() return list(self.objects) end
    function square:AddTileObject(object) self.objects[#self.objects + 1] = object end
    function square:transmitRemoveItemFromSquare(object)
        world.removals = (world.removals or 0) + 1
        for i, value in ipairs(self.objects) do if value == object then table.remove(self.objects, i); return end end
    end
    function player:getSquare() return square end
    env.getCell = function() return {
        getGridSquare = function() if world.squareLoaded then return square end end,
        getVehicles = function() return list(world.vehicles) end,
    } end
    env.IsoObject = { new = function(_, sprite)
        return { getSprite = function() return { getName = function() return sprite end } end,
            transmitCompleteItemToClients = function() world.replications = (world.replications or 0) + 1 end }
    end }
    env.createZombie = function()
        if world.failZombie then return nil end
        local zombie = { setUseless = function() end, setSitAgainstWall = function() end }
        world.zombies[#world.zombies + 1] = zombie; return zombie
    end
    env.addVehicle = function(script)
        if world.failVehicle then return nil end
        local vehicle = { script = script, createVehicleKey = function() return "Base.Key_Blank" end, repair = function() end }
        world.vehicles[#world.vehicles + 1] = vehicle; return vehicle
    end
    local native = { ["TimedActions/ISBaseTimedAction"] = true, ["Vehicles/ISUI/ISUI3DScene"] = true }
    env.require = function(name)
        if world.loaded[name] or native[name] then return true end
        for _, side in ipairs({ "shared", "server", "client" }) do
            local path = root .. side .. "/" .. name .. ".lua"
            local f = io.open(path, "r")
            if f then f:close(); world.loaded[name] = true; return assert(loadfile(path, "t", env))() or true end
        end
        error("Unresolved module: " .. name)
    end
    function world:load(name) return env.require(name) end
    function world:add(fullType, count) for _ = 1, count or 1 do inventory:AddItem(fullType) end; self.addCount = 0 end
    function world:count(fullType) local count = 0; for _, item in ipairs(self.items) do if item.fullType == fullType then count = count + 1 end end; return count end
    function world:command(name, args) self:fire("OnClientCommand", "PZLinux", name, player, args or {}) end
    function world:reply(name) for i = #self.sent, 1, -1 do if self.sent[i].command == name then return self.sent[i].args end end end
    function world:target(prefix) player.data[prefix .. "X"], player.data[prefix .. "Y"], player.data[prefix .. "Z"] = 10, 10, 0 end
    return world, env
end
return Fixture
