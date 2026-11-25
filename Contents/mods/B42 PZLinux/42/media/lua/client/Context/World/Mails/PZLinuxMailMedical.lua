local PZLINUX_MAIL_MEDICAL_FALLBACKS = {
    [1] = [[
Hello %s,
We're running out of medical supplies and the situation is getting worse by the hour. Wounds are getting infected, fevers won't break, and we can't keep people stable much longer. If you can help, please bring the following to this location as soon as possible:

Quantity : %d
Object : %s
Location : %s

Whatever you decide, thank you for reading this.
Stay alive out there.
- %s
]],
    [2] = [[
Hello %s,
I'm writing with shaking hands. We have survivors here, some hurt, some sick, and we're down to almost nothing. If you have any spare meds, please bring them quickly. Even a small amount could save lives.

Quantity : %d
Object : %s
Location : %s

We owe you, even if you can't make it.
- %s
]],
    [3] = [[
Hello %s,
We thought we could manage on bandages and luck. We were wrong. Pain is constant, infections are spreading, and we're out of proper medication. If you're still out there and able, please deliver:

Quantity : %d
Object : %s
Location : %s

No pressure, just... hope.
- %s
]],
}

local function PZLinuxMailMedicalFormat(seed, ...)
    local fallback = PZLINUX_MAIL_MEDICAL_FALLBACKS[seed] or ""
    return PZLinuxText("UI_PZLinux_MailMedical_" .. tostring(seed), fallback, ...)
end

local function PZLinuxMailMedicalLocationName(cityName)
    return PZLinuxText(
        "UI_PZLinux_Location_TrashCanIn",
        "In a trash can in %1",
        PZLinuxTranslateCityName(cityName)
    )
end

function PZLinuxMailGenerateBodyMedical(sender, id)
    local name = PZLinuxPrettifyName(getPlayer():getUsername())
    local seed = ZombRand(1, 4)

    local player = getPlayer()
    local loc = PZLinuxMailMedicalLocation()
    local _, _, mail = PZLinuxGetOrCreateMailEntry(player, id)
    if not mail then
        return ""
    end

    local changed = false
    if not mail.status then
        mail.status = 1
        changed = true
    end
    if not mail.type then
        mail.type = "medical"
        changed = true
    end
    if not mail.city then
        mail.city = loc.name
        changed = true
    end
    if mail.x == nil then
        mail.x = loc.x
        changed = true
    end
    if mail.y == nil then
        mail.y = loc.y
        changed = true
    end
    if mail.z == nil then
        mail.z = loc.z
        changed = true
    end
    if not mail.quantity then
        mail.quantity = PZLinuxMailMedicalAmount()
        changed = true
    end
    if not mail.object then
        mail.object = PZLinuxMailMedicalType()
        changed = true
    end
    if not mail.sender then
        mail.sender = sender
        changed = true
    end
    if not mail.seed then
        mail.seed = seed
        changed = true
    end

    if changed then
        PZLinuxSyncPlayerModData(player)
    end

    local displayName = PZLinuxGetItemDisplayName(mail.object, mail.object)

    if mail.seed == 1 then
        return PZLinuxMailMedicalFormat(1, name, mail.quantity, displayName, mail.city, mail.sender)
    end

    if mail.seed == 2 then
        return PZLinuxMailMedicalFormat(2, name, mail.quantity, displayName, mail.city, mail.sender)
    end

    return PZLinuxMailMedicalFormat(3, name, mail.quantity, displayName, mail.city, mail.sender)
end

function PZLinuxMailMedicalType()
    local ammoTypes = {
        "Base.Bandage",
        "Base.Bandaid",
        "Base.AlcoholWipes",
        "Base.Antibiotics",
        "Base.PillsAntiDep",
        "Base.PillsBeta",
        "Base.Pills",
    }
    local idx = ZombRand(#ammoTypes) + 1
    return ammoTypes[idx]
end

function PZLinuxMailMedicalAmount()
    local idx = ZombRand(1, 6)
    return idx
end

function PZLinuxMailMedicalLocation()
    local locations = {
        { name = PZLinuxMailMedicalLocationName("Echo Creek"), x = 3571, y = 10913, z = 0 },
        { name = PZLinuxMailMedicalLocationName("Echo Creek"), x = 3524, y = 10886, z = 0 },
        { name = PZLinuxMailMedicalLocationName("Rosewood"), x = 8147, y = 11492, z = 0 },
        { name = PZLinuxMailMedicalLocationName("Rosewood"), x = 8070, y = 11469, z = 0 },
        { name = PZLinuxMailMedicalLocationName("West Point"), x = 11421, y = 6772, z = 0 },
        { name = PZLinuxMailMedicalLocationName("West Point"), x = 12100, y = 6786, z = 0 },
        { name = PZLinuxMailMedicalLocationName("Riverside"), x = 6604, y = 5222, z = 0 },
        { name = PZLinuxMailMedicalLocationName("Riverside"), x = 6467, y = 5440, z = 0 },
        { name = PZLinuxMailMedicalLocationName("Brandenburg"), x = 2140, y = 6439, z = 0 },
        { name = PZLinuxMailMedicalLocationName("Brandenburg"), x = 2099, y = 6022, z = 0 },
    }
    local idx = ZombRand(#locations) + 1
    return locations[idx]
end
