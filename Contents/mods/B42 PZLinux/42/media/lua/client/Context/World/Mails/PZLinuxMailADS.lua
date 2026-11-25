local PZLINUX_MAIL_ADS_FALLBACKS = {
    [1] = [[
Hello %s,
Still fighting zombies with junk gear?
Upgrade NOW with our PRE-APOC SURVIVAL KIT.
Batteries included. Morals not included.
Order today. Survive tomorrow.
Click before we're eaten.
- %s
]],
    [2] = [[
Hello %s,
Is your base cold?
Is your generator loud?
Try our SILENT TECH SOLUTIONS today!
No warranty after the apocalypse.
Limited stock. Very limited lives.

Regards,
%s
]],
    [3] = [[
Doctors hate this ONE trick!
Hack, trade, survive smarter than others.
Earn money from your bunker!
100%% legit*
*legit-ish.

- %s
]],
    [4] = [[
%s!
Got skills? Got nerves?
We've got "jobs" no one else wants.
High risk. Questionable ethics.
Great rewards.
Reply fast.

- %s
]],
    [5] = [[
Hello survivor, %s
Tired of receiving our emails?
To unsubscribe, simply reply with
YOUR PASSWORD and BASE LOCATION.
Easy. Fast. Totally safe.*

- %s
]],
    [6] = [[
%s, Generators fail. Friends betray.
But our gear NEVER lets you down.*
Buy now. Regret later.
Or regret dying.
Your choice.

- %s
]],
    [7] = [[
This is not spam.
This is an OPPORTUNITY.
Miss it and someone else gets richer.
Reply "YES" to proceed.
Reply "NO" to stay poor.

- %s
]],
    [8] = [[
You have been selected for a
VERY LEGAL business opportunity.
High profit. Low questions.
Moral compass not required.
Apply before midnight.

- %s
]],
    [9] = [[
Relax %s. We don't judge.
In fact, we PAY for that.
Discreet jobs available now.
Delete this message after reading.
Or don't. We already copied it.

- %s
]],
    [10] = [[
Food is temporary.
Ammo is limited.
Knowledge is power.
Subscribe today.
Unsubscribe never.

- %s
]],
    [11] = [[
Hello lucky survivor!
You've won a FREE survival reward!
Just reply to claim it now.
Hurry, zombies are faster than emails.
- Rewards Team*
%s
]],
    [12] = [[
Hello %s, Your name was randomly selected.*
You won rare equipment and cash!
Claim within 24 hours.
After that, we keep it.
*Very random.
%s
]],
    [13] = [[
Unbelievable news!
You won our APOCALYPSE LOTTERY.
Prizes include gear, money, or mystery boxes.
Reply "CLAIM" to proceed.
Good luck. You'll need it.
%s
]],
    [14] = [[
Hello name_in_database[893]! That's right.
No effort. No skill. Lorem Ipsum!
Just pure luck.
Claim your reward now.
Before someone else does.
%s
]],
    [15] = [[
Hi %s. We appreciate loyal survivors like you.
Enjoy this exclusive reward.
Click to receive your prize.
No refunds. No survivors.
- Customer Care
%s
]],
    [16] = [[
You were selected for a hidden giveaway.
Very few survivors qualify.
Very few survive either.
Claim now.
Discretion advised.
%s
]],
    [17] = [[
1 survivor.
1000 zombies.
And YOU won a prize.
Don't ask how.
Just take it.
%s
]],
    [18] = [[
Hello USER_0001, %s
Our system detected a WIN event.
Prize: ???
Location: UNKNOWN
Proceed anyway? Y/N
%s
]],
    [19] = [[
Hi Knox Country,
You have been selected for SELECT * FROM rewards;
If error persists, blame the apocalypse.
Do not reply.
Actually, reply.
- %s
]],
    [20] = [[
Nothing beats a Knox 2 holiday and right now you can save 50 pounds per person.
That's 200 pounds off for a family of 4. We've got millions of free child place holidays available with 22kg of baggage included.
Book now with Knox 2 holidays. Package holidays you can trust!
- %s
]],
}

local function PZLinuxMailADSFormat(seed, ...)
    local fallback = PZLINUX_MAIL_ADS_FALLBACKS[seed] or ""
    return PZLinuxText("UI_PZLinux_MailADS_" .. tostring(seed), fallback, ...)
end

function PZLinuxMailGenerateBodyADS(sender, id)
    local name = PZLinuxPrettifyName(getPlayer():getUsername())
    local seed = ZombRand(1, 21)

    local player = getPlayer()
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
        mail.type = "ads"
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

    if mail.seed == 1 then return PZLinuxMailADSFormat(1, name, mail.sender) end
    if mail.seed == 2 then return PZLinuxMailADSFormat(2, name, mail.sender) end
    if mail.seed == 3 then return PZLinuxMailADSFormat(3, mail.sender) end
    if mail.seed == 4 then return PZLinuxMailADSFormat(4, name, mail.sender) end
    if mail.seed == 5 then return PZLinuxMailADSFormat(5, name, mail.sender) end
    if mail.seed == 6 then return PZLinuxMailADSFormat(6, name, mail.sender) end
    if mail.seed == 7 then return PZLinuxMailADSFormat(7, mail.sender) end
    if mail.seed == 8 then return PZLinuxMailADSFormat(8, mail.sender) end
    if mail.seed == 9 then return PZLinuxMailADSFormat(9, name, mail.sender) end
    if mail.seed == 10 then return PZLinuxMailADSFormat(10, mail.sender) end
    if mail.seed == 11 then return PZLinuxMailADSFormat(11, mail.sender) end
    if mail.seed == 12 then return PZLinuxMailADSFormat(12, name, mail.sender) end
    if mail.seed == 13 then return PZLinuxMailADSFormat(13, mail.sender) end
    if mail.seed == 14 then return PZLinuxMailADSFormat(14, mail.sender) end
    if mail.seed == 15 then return PZLinuxMailADSFormat(15, name, mail.sender) end
    if mail.seed == 16 then return PZLinuxMailADSFormat(16, mail.sender) end
    if mail.seed == 17 then return PZLinuxMailADSFormat(17, mail.sender) end
    if mail.seed == 18 then return PZLinuxMailADSFormat(18, mail.sender, name) end
    if mail.seed == 19 then return PZLinuxMailADSFormat(19, name) end
    if mail.seed == 20 then return PZLinuxMailADSFormat(20, mail.sender) end

    return ""
end
