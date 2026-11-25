local function isPZLinuxMailRecord(mailId, mail)
    if type(mail) ~= "table" then
        return false
    end

    return mailId ~= "inbox" and mailId ~= "nextid" and mailId ~= "nextat"
end

function completeMailAmmo_AddContext(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    local md = PZLinuxGetModData(playerObj)
    if not (md.pzlinux and md.pzlinux.mails) then return end
        
    for _, obj in ipairs(worldobjects) do
        local square = obj.getSquare and obj:getSquare() or nil
        if square then
            local x, y, z = square:getX(), square:getY(), square:getZ()
            for id, mail in pairs(md.pzlinux.mails) do
                if isPZLinuxMailRecord(id, mail) and tonumber(mail.status) == 2 then
                    local targetX = tonumber(mail.x)
                    local targetY = tonumber(mail.y)
                    local targetZ = tonumber(mail.z)
                    if targetX and targetY and targetZ and isNearTarget(x, y, z, targetX, targetY, targetZ) then
                        context:addOption(PZLinuxText("UI_PZLinux_DepositRequestedMail", "Deposit the requested items from the email"), obj, completeMailMenu_OnUse, playerObj, id, x, y, z)
                        return
                    end
                end
            end
        end
    end
end

function completeMailMenu_OnUse(obj, player, id, x, y, z)
    local _, _, mail, resolvedKey = PZLinuxGetMailEntry(player, id)
    if not mail or tonumber(mail.status) ~= 2 then return end
    
    local playerSquare = player:getSquare()
    local spriteName = obj and obj.getSprite and obj:getSprite() and obj:getSprite():getName() or nil
    if not (math.abs(playerSquare:getX() - x) + math.abs(playerSquare:getY() - y) <= 1) then
        local freeSquare = getAdjacentFreeSquare(x, y, z, spriteName)
        if freeSquare then
            ISTimedActionQueue.add(ISWalkToTimedAction:new(player, freeSquare))
        end
    end
    ISTimedActionQueue.add(ISDropTheMailAction:new(player, obj, resolvedKey or id))
end

Events.OnFillWorldObjectContextMenu.Add(completeMailAmmo_AddContext)
