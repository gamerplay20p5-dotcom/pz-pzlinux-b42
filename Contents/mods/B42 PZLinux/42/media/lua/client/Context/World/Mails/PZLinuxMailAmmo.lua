local PZLINUX_MAIL_AMMO_FALLBACKS = {
    [1] = [[
Hello %s,
For several weeks now, we have been facing relentless waves of zombies, and our ammunition supplies are critically low. If these attacks continue at this pace, we won't survive much longer. Could you provide us with these supplies? They could mean the difference between holding our ground or being overrun. Please deliver the ammunition.

Quantity : %d
Object : %s
Location : %s

Stay safe, and thank you for considering our request.

Sincerely,
%s
]],
    [2] = [[
Hello %s,
We are reaching out because the situation here has become critical. Several survivors spoke highly of you, and we hope they were right. Zombie activity has increased drastically in our area, and we are almost out of ammunition. If you can deliver it to the location below, you may save more lives than you realize.

Quantity : %d
Object : %s
Location : %s

We know this is dangerous. Whatever you decide, thank you for reading this.

Regards,
%s
]],
    [3] = [[
Hello %s,
We don't know how long we can keep this place secured, but we were told you might listen. Every night, the dead come closer, and every day our ammunition runs lower. We are doing everything we can, but it's no longer enough. Please bring it to the following location as soon as possible:

Quantity : %d
Object : %s
Location : %s

No matter your answer, we appreciate you taking the time to read this.
Stay alive out there.

- %s
]],
}

local function PZLinuxMailAmmoFormat(seed, ...)
    local fallback = PZLINUX_MAIL_AMMO_FALLBACKS[seed] or ""
    return PZLinuxText("UI_PZLinux_MailAmmo_" .. tostring(seed), fallback, ...)
end

local function PZLinuxMailAmmoLocationName(cityName)
    return PZLinuxText(
        "UI_PZLinux_Location_TrashCanIn",
        "In a trash can in %1",
        PZLinuxTranslateCityName(cityName)
    )
end

function PZLinuxMailGenerateBodyAmmo(sender, id)
    local name = PZLinuxPrettifyName(getPlayer():getUsername())
    local seed = ZombRand(1, 4)

    local player = getPlayer()
    local loc = PZLinuxMailAmmoLocation()
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
        mail.type = "ammo"
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
        mail.quantity = PZLinuxMailAmmoAmount()
        changed = true
    end
    if not mail.object then
        mail.object = PZLinuxMailAmmoType()
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
        return PZLinuxMailAmmoFormat(1, name, mail.quantity, displayName, mail.city, mail.sender)
    end

    if mail.seed == 2 then
        return PZLinuxMailAmmoFormat(2, name, mail.quantity, displayName, mail.city, mail.sender)
    end

    return PZLinuxMailAmmoFormat(3, name, mail.quantity, displayName, mail.city, mail.sender)
end

function PZLinuxMailAmmoType()
    local ammoTypes = {"Base.308Box", "Base.Bullets38Box", "Base.Bullets44Box", "Base.Bullets45Box", "Base.556Box", "Base.Bullets9mmBox", "Base.ShotgunShellsBox" }
    local idx = ZombRand(#ammoTypes) + 1
    return ammoTypes[idx]
end

function PZLinuxMailAmmoAmount()
    local idx = ZombRand(1, 6)
    return idx
end

function PZLinuxMailAmmoLocation()
    local locations = {
        { name = PZLinuxMailAmmoLocationName("Ekron"), x = 683, y = 9920, z = 0 },
        { name = PZLinuxMailAmmoLocationName("March Ridge"), x = 10178, y = 12668, z = 0 },
        { name = PZLinuxMailAmmoLocationName("March Ridge"), x = 10048, y = 12776, z = 0 },
        { name = PZLinuxMailAmmoLocationName("Irvington"), x = 2579, y = 14473, z = 0 },
        { name = PZLinuxMailAmmoLocationName("Irvington"), x = 3100, y = 14489, z = 0 },
        { name = PZLinuxMailAmmoLocationName("Muldraugh"), x = 10635, y = 10041, z = 0 },
        { name = PZLinuxMailAmmoLocationName("Muldraugh"), x = 10644, y = 9767, z = 0 },
    }
    local idx = ZombRand(#locations) + 1
    return locations[idx]
end
