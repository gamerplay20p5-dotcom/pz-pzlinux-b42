require "PZLinuxConfig"
if PZLinuxUtilsLoaded then
    return
end
PZLinuxUtilsLoaded = true

function isNearTarget(x, y, z, targetX, targetY, targetZ)
    return math.max(math.abs(x - targetX), math.abs(y - targetY)) <= 5 and z == targetZ
end

function isNearTargetCapture(x, y, z, targetX, targetY, targetZ)
    return math.max(math.abs(x - targetX), math.abs(y - targetY)) <= 2 and z == targetZ
end

function getAdjacentFreeSquare(x, y, z, sprite)
    local square = getCell():getGridSquare(x, y, z)
    if not square then return nil end

    local directions = {
        {x - 1, y, z},
        {x + 1, y, z},
        {x, y - 1, z},
        {x, y + 1, z}
    }

    if sprite == "location_business_bank_01_67" then directions = { {x, y + 1, z} } end
    if sprite == "location_business_bank_01_66" then directions = { {x + 1, y, z} } end
    if sprite == "location_business_bank_01_65" then directions = { {x, y - 1, z} } end
    if sprite == "location_business_bank_01_64" then directions = { {x - 1, y, z} } end
    if sprite == "appliances_com_01_75" then directions = { {x - 1, y, z} } end 
    if sprite == "appliances_com_01_74" then directions = { {x, y - 1, z} } end
    if sprite == "appliances_com_01_73" then directions = { {x + 1, y, z} } end
    if sprite == "appliances_com_01_72" then directions = { {x, y + 1, z} } end
    if sprite == "location_business_bank_01_67" then directions = { {x, y - 1, z} } end
    if sprite == "location_business_bank_01_66" then directions = { {x - 1, y, z} } end
    if sprite == "location_business_bank_01_65" then directions = { {x, y + 1, z} } end
    if sprite == "location_business_bank_01_64" then directions = { {x + 1, y, z} } end
    if sprite == "street_decoration_01_8" then directions = { {x, y + 1, z} } end
    if sprite == "street_decoration_01_9" then directions = { {x + 1, y, z} } end
    if sprite == "street_decoration_01_10" then directions = { {x, y - 1, z} } end
    if sprite == "street_decoration_01_11" then directions = { {x - 1, y, z} } end
    if sprite == "street_decoration_01_18" then directions = { {x + 1, y, z} } end
    if sprite == "street_decoration_01_19" then directions = { {x, y + 1, z} } end
    if sprite == "street_decoration_01_20" then directions = { {x - 1, y, z} } end
    if sprite == "street_decoration_01_21" then directions = { {x, y - 1, z} } end

    for _, coord in ipairs(directions) do
        local freeSquare = getCell():getGridSquare(coord[1], coord[2], coord[3])
        if freeSquare and freeSquare:isFree(false) then
            return freeSquare
        end
    end
    return nil
end

function reverseString(str)
    return str:reverse()
end

function generatePseudo(playerName)
    local reversedName = reverseString(playerName)
    local position = 3

    if #reversedName > position then
        local symbol = "_"
        reversedName = reversedName:sub(1, position) .. symbol .. reversedName:sub(position + 1)
    end

    return "<" .. reversedName .. "> "
end

function bagContainsCorpse(bag)
    if not bag then return false end
    local inv = bag.getInventory and bag:getInventory() or nil
    if not inv or not inv.getItems then
        return false
    end
    for i = 0, inv:getItems():size() - 1 do
        local item = inv:getItems():get(i)
        if item and item.getFullType and item:getFullType() == "Base.CorpseMale" then
            return true
        end
    end
    return false
end

function contractsDrawOnMap(x, y, message)
    ISWorldMap.ShowWorldMap(0)
    ISWorldMap.HideWorldMap(0)
    WorldMapVisited.getInstance():setVisitedInCells(x, y, x + 10, y + 10)
    local mapSymbol = ISWorldMap_instance.mapAPI:getSymbolsAPI():addTexture("Circle", x, y)
    local mapText = ISWorldMap_instance.mapAPI:getSymbolsAPI():addTranslatedText(message, UIFont.SdfCaveat, x + 20, y)
    mapSymbol:setRGBA(0, 0, 0, 1.0)
    mapSymbol:setAnchor(0.5, 0.5)
    mapText:setRGBA(0, 0, 0, 1.0)
end

function contractsRemoveDrawOnMap(x, y)
    ISWorldMap.ShowWorldMap(0)
    ISWorldMap.HideWorldMap(0)
    local count = ISWorldMap_instance.mapAPI:getSymbolsAPI():getSymbolCount()
    for i = 0, count - 1 do
        local symbol = ISWorldMap_instance.mapAPI:getSymbolsAPI():getSymbolByIndex(i)
        if symbol then
            local wx = math.floor(symbol:getWorldX())
            if wx == math.floor(x) then
                local wy = math.floor(symbol:getWorldY())
                if wy == math.floor(y) then
                    ISWorldMap_instance.mapAPI:getSymbolsAPI():removeSymbolByIndex(i)
                    break
                end
            end
        end
    end
end

function getNearbyGenerator(square, consommation)
    if not square then return nil end
    local cell = getWorld():getCell()
    local generator = nil

    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if instanceof(obj, "IsoGenerator") and obj:isActivated() then
            generator = obj
            break
        end
    end

    if not generator then
        for z = -1, 1 do
            for x = -20, 20 do
                for y = -20, 20 do
                    local checkSquare = cell:getGridSquare(square:getX() + x, square:getY() + y, square:getZ() + z)
                    if checkSquare then
                        for i = 0, checkSquare:getObjects():size() - 1 do
                            local obj = checkSquare:getObjects():get(i)
                            if instanceof(obj, "IsoGenerator") and obj:isActivated() then
                                generator = obj
                                break
                            end
                        end
                    end
                    if generator then break end
                end
                if generator then break end
            end
        end
    end

    if generator and consommation then
        local fuelAmount = generator:getFuel()
        if fuelAmount > consommation then
            generator:setFuel(fuelAmount - consommation)
        else
            generator:setFuel(0)
            generator:setActivated(false)
        end
    end

    if generator and consommation and generator.sync then generator:sync() end
    return generator
end

local PZLinuxPreviousGeneratorGetRichText = nil
local PZLinuxGeneratorPatchInstalled = false

local function PZLinuxGeneratorInfoWindowGetRichText(object, displayStats)
    local text = ""
    if PZLinuxPreviousGeneratorGetRichText then
        local ok, result = pcall(PZLinuxPreviousGeneratorGetRichText, object, displayStats)
        if ok and type(result) == "string" then
            text = result
        end
    end

    if not displayStats or not object or not object.isActivated or not object:isActivated() then
        return text
    end

    local modData = PZLinuxGetModData()
    if not modData then
        return text
    end

    if PZLinuxConfig.IsEnabled() and PZLinuxConfig.Get("ComputerRequiresPower") and tonumber(modData.PZLinuxIsPowered) == 1 then
        text = text .. " <LINE> " .. PZLinuxText("UI_PZLinux_PowerItem_Computer", "Desktop Computer") .. string.format(" (%.4f /min)", PZLinuxConfig.Get("ComputerFuelPerMinute"))
    end
    if PZLinuxConfig.IsEnabled("ATM") and PZLinuxConfig.Get("ATMRequiresPower") and tonumber(modData.ATMIsPowered) == 1 then
        text = text .. " <LINE> " .. PZLinuxText("UI_PZLinux_PowerItem_ATM", "ATM") .. string.format(" (%.4f /min)", PZLinuxConfig.Get("ATMFuelPerMinute"))
    end
    return text
end

local function PZLinuxPatchGeneratorInfoWindow()
    if PZLinuxGeneratorPatchInstalled then
        return
    end
    if not ISGeneratorInfoWindow or type(ISGeneratorInfoWindow.getRichText) ~= "function" then
        return
    end

    PZLinuxPreviousGeneratorGetRichText = ISGeneratorInfoWindow.getRichText
    ISGeneratorInfoWindow.getRichText = PZLinuxGeneratorInfoWindowGetRichText
    PZLinuxGeneratorPatchInstalled = true
end

PZLinuxPatchGeneratorInfoWindow()
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(PZLinuxPatchGeneratorInfoWindow)
end

function PZLinuxUseFuel()
    local player = getPlayer()
    if not player then return end

    local square = player:getSquare()
    local modData = PZLinuxGetModData(player)
    local consumption = 0
    if PZLinuxConfig.IsEnabled() and PZLinuxConfig.Get("ComputerRequiresPower") and tonumber(modData.PZLinuxIsPowered) == 1 then
        consumption = consumption + PZLinuxConfig.Get("ComputerFuelPerMinute")
    end
    if PZLinuxConfig.IsEnabled("ATM") and PZLinuxConfig.Get("ATMRequiresPower") and tonumber(modData.ATMIsPowered) == 1 then
        consumption = consumption + PZLinuxConfig.Get("ATMFuelPerMinute")
    end
    if consumption > 0 then
        getNearbyGenerator(square, consumption)
    end
end
Events.EveryOneMinute.Add(PZLinuxUseFuel)

function PZLinuxUtils_waitSeconds(minS, maxS, sfxMul, selfRef)
    local mul = sfxMul or 1
    local start = math.ceil(getGameTime():getWorldAgeHours() * 3600)
    local delay = start + ZombRand(minS, maxS) * mul

    local elapsed = start
    while elapsed < delay do
        if selfRef and selfRef.isClosing then return false end
        coroutine.yield()
        elapsed = math.ceil(getGameTime():getWorldAgeHours() * 3600)
    end
    return true
end

function PZLinuxPrettifyName(name)
    if not name then return "" end
    return name:gsub("(%l)(%u)", "%1 %2")
end

function PZLinuxGetTerminalSafeArea(width, height)
    local safe = {
        x = math.floor(width * 0.15),
        y = math.floor(height * 0.15),
        w = math.floor(width * 0.68),
        h = math.floor(height * 0.515),
    }
    safe.right = safe.x + safe.w
    safe.bottom = safe.y + safe.h
    safe.gap = math.max(6, math.floor(safe.h * 0.018))
    safe.rowH = math.max(22, math.floor(safe.h * 0.052))
    safe.buttonH = math.max(24, math.floor(safe.h * 0.064))
    safe.controlW = math.max(24, math.floor(width * 0.032))
    safe.controlGap = math.max(4, math.floor(width * 0.006))
    return safe
end

function PZLinuxStyleTerminalButton(button, selected)
    if not button then return end
    button.textColor = { r = 0, g = 1, b = 0, a = 1 }
    button.backgroundColor = selected
        and { r = 0, g = 0.45, b = 0, a = 0.72 }
        or { r = 0, g = 0, b = 0, a = 0.56 }
    button.borderColor = { r = 0, g = 0.65, b = 0, a = 0.78 }
end

function PZLinuxSetElementBounds(element, x, y, w, h)
    if not element then return end
    if element.setX then element:setX(math.floor(x)) end
    if element.setY then element:setY(math.floor(y)) end
    if w and element.setWidth then element:setWidth(math.floor(w)) end
    if h and element.setHeight then element:setHeight(math.floor(h)) end
end

function PZLinuxLayoutTerminalControls(ui)
    if not ui then return nil end
    local safe = PZLinuxGetTerminalSafeArea(ui.width or 0, ui.height or 0)
    ui.pzSafe = safe

    if ui.stopButton then
        ui.stopButton:setVisible(false)
    end

    if ui.titleLabel then
        PZLinuxSetElementBounds(ui.titleLabel, safe.x, safe.y + 2, safe.w - ((safe.controlW + safe.controlGap) * 3) - safe.gap, safe.rowH)
    end

    local function placeControl(button, index, title)
        if not button then return end
        PZLinuxSetElementBounds(
            button,
            safe.right - (index * safe.controlW) - ((index - 1) * safe.controlGap),
            safe.y,
            safe.controlW,
            safe.rowH
        )
        if title and button.setTitle then
            button:setTitle(title)
        end
        PZLinuxStyleTerminalButton(button)
    end

    placeControl(ui.closeButton, 1, "x")
    placeControl(ui.minimizeButton, 2, "-")
    placeControl(ui.minimizeBackButton, 2, "-")
    placeControl(ui.skipAnimationButton, 3, "SFX")

    return safe
end

function PZLinuxCreateTerminalSfxButton(ui, callback, enabled)
    if not ui then return nil end
    local safe = ui.pzSafe or PZLinuxGetTerminalSafeArea(ui.width or 0, ui.height or 0)
    local button = ISButton:new(
        safe.right - (safe.controlW * 3) - (safe.controlGap * 2),
        safe.y,
        safe.controlW,
        safe.rowH,
        "SFX",
        ui,
        callback
    )
    button.textColor = { r = 1, g = 1, b = 1, a = 1 }
    button.backgroundColor = enabled
        and { r = 0, g = 1, b = 0, a = 0.5 }
        or { r = 1, g = 0, b = 0, a = 0.5 }
    button.borderColor = { r = 0, g = 1, b = 0, a = 0.5 }
    button:setVisible(true)
    button:initialise()
    return button
end
