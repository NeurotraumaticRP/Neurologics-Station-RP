-- Attack Tracking System
-- Tracks direct weapon/melee attacks between characters
-- Memory is cleared at round end to prevent leaks

local AT = {}

-- Data structure: { attackerID = { victimID = timestamp } }
AT.Attacks = {}
AT.LastCleanup = 0
AT.CleanupInterval = 300 -- Clean up entries older than 5 minutes

-- Register an attack between attacker and victim
AT.RegisterAttack = function(attacker, victim)
    if not attacker or not victim then return end
    
    local attackerID = attacker.ID
    local victimID = victim.ID
    
    if not AT.Attacks[attackerID] then
        AT.Attacks[attackerID] = {}
    end
    
    AT.Attacks[attackerID][victimID] = Timer.GetTime()
    
    Neurologics.Debug(string.format("Attack registered: %s -> %s", 
        attacker.Name or "Unknown", 
        victim.Name or "Unknown"))
end

-- Check if attacker has attacked victim
-- sinceTimeSeconds: optional, check if attack happened within this time (nil = any time)
Neurologics.PlayerHasAttacked = function(attacker, victim, sinceTimeSeconds)
    if not attacker or not victim then return false end
    
    local attackerID = attacker.ID
    local victimID = victim.ID
    
    if not AT.Attacks[attackerID] or not AT.Attacks[attackerID][victimID] then
        return false
    end
    
    local attackTime = AT.Attacks[attackerID][victimID]
    
    -- If no time constraint, just return true
    if not sinceTimeSeconds then
        return true
    end
    
    -- Check if attack happened within the specified time
    local currentTime = Timer.GetTime()
    local timeSinceAttack = currentTime - attackTime
    
    return timeSinceAttack <= sinceTimeSeconds
end

-- Remove old attack records (older than CleanupInterval)
AT.Cleanup = function()
    local currentTime = Timer.GetTime()
    
    if currentTime < AT.LastCleanup + 60 then
        return -- Only cleanup once per minute
    end
    
    local removedCount = 0
    
    for attackerID, victims in pairs(AT.Attacks) do
        for victimID, timestamp in pairs(victims) do
            if currentTime - timestamp > AT.CleanupInterval then
                AT.Attacks[attackerID][victimID] = nil
                removedCount = removedCount + 1
            end
        end
        
        -- Remove empty attacker entries
        if next(AT.Attacks[attackerID]) == nil then
            AT.Attacks[attackerID] = nil
        end
    end
    
    if removedCount > 0 then
        Neurologics.Debug(string.format("AttackTracker: Cleaned up %d old attack records", removedCount))
    end
    
    AT.LastCleanup = currentTime
end

-- Clear all attack data (called on round end)
AT.Clear = function()
    AT.Attacks = {}
    AT.LastCleanup = 0
    Neurologics.Log("AttackTracker: All attack data cleared")
end

-- Hook into character damage to track attacks
Hook.Add("characterDamage", "Neurologics.AttackTracker.Track", function(character, attackResult)
    if not Game.RoundStarted then return end
    
    local attacker = attackResult.Attacker
    local affliction = attackResult.Affliction
    
    -- Only track direct weapon/melee attacks
    if not attacker or not affliction then return end
    
    -- Filter out environmental damage
    local afflictionID = tostring(affliction.Prefab.Identifier)
    local directAttackTypes = {
        "lacerations", "gunshotwound", "bitewounds", "blunttrauma",
        "bleeding", "damage", "burn" -- burn can be from flamethrower
    }
    
    local isDirect = false
    for _, damageType in ipairs(directAttackTypes) do
        if afflictionID:find(damageType) then
            isDirect = true
            break
        end
    end
    
    -- Skip environmental damage
    if not isDirect then return end
    
    -- Skip if attacker and victim are the same (self-damage)
    if attacker.ID == character.ID then return end
    
    AT.RegisterAttack(attacker, character)
end)

-- Periodic cleanup hook
Hook.Add("think", "Neurologics.AttackTracker.Cleanup", function()
    if Game.RoundStarted then
        AT.Cleanup()
    end
end)

-- Register cleanup callback
Neurologics.RegisterCleanup("AttackTracker", function()
    AT.Clear()
end)

Neurologics.AttackTracker = AT

return AT

