local afflictionScript = {}
afflictionScript.affliction = {}

-- Track affliction states per character for detecting changes
-- Structure: afflictionScript.characterStates[character][afflictionId] = {strength = X, lastUpdate = time}
afflictionScript.characterStates = setmetatable({}, { __mode = "k" }) -- Weak keys so dead characters get garbage collected

-- Thresholds for OnThreshold callbacks (percentages of max strength)
afflictionScript.defaultThresholds = {25, 50, 75, 100}

-- Metatable: When new entries are added, automatically assign a Prefab if not provided.
setmetatable(afflictionScript.affliction, {
    __newindex = function(t, key, value)
        if type(value) == "table" then
            if value.Prefab == nil then
                local prefab = AfflictionPrefab.Prefabs[key]
                if prefab then
                    value.Prefab = prefab
                end
            end
        end
        rawset(t, key, value)
    end
})

-- Helper function to add affliction scripts with multiple hooks
function afflictionScript.AddAffliction(afflictionIdentifier, hooks)
    if type(hooks) ~= "table" then
        error("afflictionScript.AddAffliction: hooks must be a table")
    end
    
    local afflictionData = {
        Prefab = AfflictionPrefab.Prefabs[afflictionIdentifier]
    }
    
    -- Copy all hook functions and settings
    for hookType, hookValue in pairs(hooks) do
        afflictionData[hookType] = hookValue
    end
    
    afflictionScript.affliction[afflictionIdentifier] = afflictionData
end

-- Helper function to check if an affliction has a specific hook
function afflictionScript.HasHook(afflictionIdentifier, hookType)
    return afflictionScript.affliction[afflictionIdentifier] and afflictionScript.affliction[afflictionIdentifier][hookType] ~= nil
end

-- Get or create character state tracking
local function getCharacterState(character)
    if not afflictionScript.characterStates[character] then
        afflictionScript.characterStates[character] = {}
    end
    return afflictionScript.characterStates[character]
end

-- Get previous affliction state for a character
local function getPreviousState(character, afflictionId)
    local charState = getCharacterState(character)
    return charState[afflictionId]
end

-- Update affliction state for a character
local function updateState(character, afflictionId, strength)
    local charState = getCharacterState(character)
    local prevState = charState[afflictionId]
    
    charState[afflictionId] = {
        strength = strength,
        lastUpdate = Timer.GetTime(),
        previousStrength = prevState and prevState.strength or 0
    }
    
    return prevState
end

-- Check if a threshold was crossed
local function checkThresholdCrossed(prevStrength, newStrength, maxStrength, thresholds)
    local crossedThresholds = {}
    
    for _, threshold in ipairs(thresholds) do
        local thresholdValue = (threshold / 100) * maxStrength
        
        -- Check if we crossed this threshold (going up)
        if prevStrength < thresholdValue and newStrength >= thresholdValue then
            table.insert(crossedThresholds, {threshold = threshold, direction = "up", value = thresholdValue})
        end
        
        -- Check if we crossed this threshold (going down)
        if prevStrength >= thresholdValue and newStrength < thresholdValue then
            table.insert(crossedThresholds, {threshold = threshold, direction = "down", value = thresholdValue})
        end
    end
    
    return crossedThresholds
end

--[[ 
Types of affliction hooks:

OnUpdate - Called every time the affliction updates (be careful with performance!)
OnApply - Called when affliction is first applied (strength goes from 0 to > 0)
OnRemove - Called when affliction is removed (strength goes to 0 or below)
OnIncrease - Called when affliction strength increases
OnDecrease - Called when affliction strength decreases
OnThreshold - Called when affliction crosses a threshold (default: 25%, 50%, 75%, 100%)
OnPeriodic - Called at a custom interval while affliction is active

Configuration options:
Thresholds = {25, 50, 75, 100} -- Custom thresholds for OnThreshold
PeriodicInterval = 1.0 -- Interval in seconds for OnPeriodic

Hook parameters:
- affliction: The affliction instance
- character: The affected character
- characterHealth: The character's health component
- limb: The affected limb (can be nil for whole-body afflictions)
- prevStrength: Previous strength value (for change detection)

Example usage:
afflictionScript.AddAffliction("burn", {
    OnApply = function(affliction, character, characterHealth, limb)
        print(character.Name .. " started burning!")
    end,
    OnUpdate = function(affliction, character, characterHealth, limb, prevStrength)
        -- Called every update
    end,
    OnThreshold = function(affliction, character, characterHealth, limb, threshold, direction)
        if threshold == 50 and direction == "up" then
            print(character.Name .. " is now 50% burned!")
        end
    end,
    OnRemove = function(affliction, character, characterHealth, limb)
        print(character.Name .. " stopped burning!")
    end,
    Thresholds = {10, 25, 50, 75, 90, 100} -- Custom thresholds
})
]]

--------------------------------
--       Base Hooks           --
--------------------------------

-- Periodic tracking for OnPeriodic hooks
afflictionScript.periodicTimers = setmetatable({}, { __mode = "k" })

-- Main affliction update hook
Hook.Add("afflictionUpdate", "AfflictionScript.OnUpdate", function(affliction, characterHealth, limb)
    if not affliction or not characterHealth then return end
    
    local character = characterHealth.Character
    if not character then return end
    
    local afflictionId = tostring(affliction.Identifier)
    local scriptData = afflictionScript.affliction[afflictionId]
    
    -- If no script registered for this affliction, skip
    if not scriptData then return end
    
    local currentStrength = affliction.Strength
    local maxStrength = affliction.Prefab.MaxStrength or 100
    local prevState = getPreviousState(character, afflictionId)
    local prevStrength = prevState and prevState.strength or 0
    
    -- Determine what changed
    local isNewAffliction = prevStrength <= 0 and currentStrength > 0
    local isRemoved = prevStrength > 0 and currentStrength <= 0
    local isIncreased = currentStrength > prevStrength
    local isDecreased = currentStrength < prevStrength
    
    -- OnApply - affliction just started
    if isNewAffliction and scriptData.OnApply then
        scriptData.OnApply(affliction, character, characterHealth, limb)
    end
    
    -- OnRemove - affliction just ended
    if isRemoved and scriptData.OnRemove then
        scriptData.OnRemove(affliction, character, characterHealth, limb)
    end
    
    -- OnIncrease - strength went up
    if isIncreased and scriptData.OnIncrease then
        scriptData.OnIncrease(affliction, character, characterHealth, limb, prevStrength)
    end
    
    -- OnDecrease - strength went down
    if isDecreased and scriptData.OnDecrease then
        scriptData.OnDecrease(affliction, character, characterHealth, limb, prevStrength)
    end
    
    -- OnThreshold - check threshold crossings
    if scriptData.OnThreshold then
        local thresholds = scriptData.Thresholds or afflictionScript.defaultThresholds
        local crossedThresholds = checkThresholdCrossed(prevStrength, currentStrength, maxStrength, thresholds)
        
        for _, crossed in ipairs(crossedThresholds) do
            scriptData.OnThreshold(affliction, character, characterHealth, limb, crossed.threshold, crossed.direction)
        end
    end
    
    -- OnUpdate - always called (use sparingly for performance)
    if scriptData.OnUpdate then
        scriptData.OnUpdate(affliction, character, characterHealth, limb, prevStrength)
    end
    
    -- Update state tracking
    updateState(character, afflictionId, currentStrength)
end)

-- Think hook for OnPeriodic callbacks
local periodicCounter = 0
Hook.Add("think", "AfflictionScript.Periodic", function()
    periodicCounter = periodicCounter + 1
    
    -- Only check every 6 frames (~10 times per second)
    if periodicCounter < 6 then return end
    periodicCounter = 0
    
    local currentTime = Timer.GetTime()
    
    -- Iterate through all characters with tracked afflictions
    for character, charState in pairs(afflictionScript.characterStates) do
        if character and not character.Removed and not character.IsDead then
            for afflictionId, state in pairs(charState) do
                local scriptData = afflictionScript.affliction[afflictionId]
                
                if scriptData and scriptData.OnPeriodic and state.strength > 0 then
                    local interval = scriptData.PeriodicInterval or 1.0
                    local lastPeriodic = afflictionScript.periodicTimers[character] and afflictionScript.periodicTimers[character][afflictionId] or 0
                    
                    if currentTime - lastPeriodic >= interval then
                        -- Get current affliction instance
                        local affliction = character.CharacterHealth.GetAffliction(afflictionId, true)
                        if affliction and affliction.Strength > 0 then
                            scriptData.OnPeriodic(affliction, character, character.CharacterHealth, nil)
                        end
                        
                        -- Update timer
                        if not afflictionScript.periodicTimers[character] then
                            afflictionScript.periodicTimers[character] = {}
                        end
                        afflictionScript.periodicTimers[character][afflictionId] = currentTime
                    end
                end
            end
        end
    end
end)

-- Clean up dead characters
Hook.Add("characterDeath", "AfflictionScript.Cleanup", function(character)
    afflictionScript.characterStates[character] = nil
    afflictionScript.periodicTimers[character] = nil
end)

--------------------------------
--    Helper Functions        --
--------------------------------

afflictionScript.HF = {}

-- Get affliction strength for a character
afflictionScript.HF.GetStrength = function(character, afflictionId)
    local affliction = character.CharacterHealth.GetAffliction(afflictionId, true)
    return affliction and affliction.Strength or 0
end

-- Check if character has affliction above a threshold
afflictionScript.HF.HasAffliction = function(character, afflictionId, minStrength)
    minStrength = minStrength or 0
    return afflictionScript.HF.GetStrength(character, afflictionId) > minStrength
end

-- Get all characters with a specific affliction
afflictionScript.HF.GetCharactersWithAffliction = function(afflictionId, minStrength)
    minStrength = minStrength or 0
    local characters = {}
    
    for _, character in pairs(Character.CharacterList) do
        if character and not character.Removed and not character.IsDead then
            if afflictionScript.HF.HasAffliction(character, afflictionId, minStrength) then
                table.insert(characters, character)
            end
        end
    end
    
    return characters
end

--------------------------------
--    Affliction Scripts      --
--------------------------------

-- Example: Burn affliction tracking
--[[
afflictionScript.AddAffliction("burn", {
    OnApply = function(affliction, character, characterHealth, limb)
        print(character.Name .. " started burning!")
    end,
    OnThreshold = function(affliction, character, characterHealth, limb, threshold, direction)
        if threshold == 50 and direction == "up" then
            print(character.Name .. " is severely burned!")
        end
    end,
    OnRemove = function(affliction, character, characterHealth, limb)
        print(character.Name .. " stopped burning")
    end
})
]]

-- Example: Husk infection with periodic checks
--[[
afflictionScript.AddAffliction("huskinfection", {
    OnApply = function(affliction, character, characterHealth, limb)
        print(character.Name .. " has been infected with husk!")
    end,
    OnThreshold = function(affliction, character, characterHealth, limb, threshold, direction)
        if threshold == 100 and direction == "up" then
            print(character.Name .. " is about to turn into a husk!")
        end
    end,
    OnPeriodic = function(affliction, character, characterHealth, limb)
        -- Called every second while infected
        if affliction.Strength > 50 then
            print(character.Name .. " is feeling the husk taking over...")
        end
    end,
    PeriodicInterval = 5.0, -- Check every 5 seconds
    Thresholds = {25, 50, 75, 90, 100}
})
]]

afflictionScript.AddAffliction("mudraptorvirus", {
    OnPeriodic = function(affliction, character, characterHealth, limb)
        if affliction.Strength >= 99 and not character.IsDead then
            local client = Neurologics.FindClientCharacter(character)
            if not client then return end
            local originalName = character.Name
            local mudraptor = Entity.Spawner.AddCharacterToSpawnQueue("mudraptor_hatchling", character.WorldPosition, function(mudraptor)
                mudraptor.TeamID = character.TeamID
                client.SetClientCharacter(mudraptor)
                HF.SetAffliction(mudraptor, "mudraptorgrowthhatchling", 1, nil, nil) -- this will make sure the mudraptor hatchling grows into a mudraptor
                local prefab = AfflictionPrefab.Prefabs["mudraptorvirus"]
                character.Kill(CauseOfDeathType.Unknown, affliction)
                
                -- Assign MudraptorServant role to the newly transformed player
                Neurologics.AssignMudraptorServantRole(client, mudraptor, originalName)
            end)
            local explosion = ItemPrefab.GetItemPrefab("surgeryexplosion")
            Entity.Spawner.AddItemToSpawnQueue(explosion, character.WorldPosition, nil, nil, function(item)
                item.Use(0)
            end)
        end
    end
})

afflictionScript.AddAffliction("mudraptorgrowthhatchling", {
    OnPeriodic = function(affliction, character, characterHealth, limb)
        if affliction.Strength >= 100 then
            local client = Neurologics.FindClientCharacter(character)
            if not client then return end
            -- Get the existing role before transforming
            local existingRole = Neurologics.RoleManager.GetRole(character)
            local mudraptor = Entity.Spawner.AddCharacterToSpawnQueue("mudraptor", character.WorldPosition, function(mudraptor)
                mudraptor.TeamID = character.TeamID
                client.SetClientCharacter(mudraptor)
                HF.SetAffliction(mudraptor, "mudraptorgrowth", 1, nil, nil)
                
                -- Transfer the MudraptorServant role to the new body
                if existingRole and existingRole.Name == "MudraptorServant" then
                    Neurologics.RoleManager.TransferRole(mudraptor, existingRole)
                end
                
                Entity.Spawner.AddEntityToRemoveQueue(character)
            end)
            local explosion = ItemPrefab.GetItemPrefab("surgeryexplosion")
            Entity.Spawner.AddItemToSpawnQueue(explosion, character.WorldPosition, nil, nil, function(item)
                item.Use(0)
            end)
        end
    end
})

afflictionScript.AddAffliction("mudraptorgrowth", {
    OnPeriodic = function(affliction, character, characterHealth, limb)
        if affliction.Strength >= 100 then
            local client = Neurologics.FindClientCharacter(character)
            if not client then return end
            -- Get the existing role before transforming
            local existingRole = Neurologics.RoleManager.GetRole(character)
            local mudraptor = Entity.Spawner.AddCharacterToSpawnQueue("mudraptor_veteran", character.WorldPosition, function(mudraptor)
                mudraptor.TeamID = character.TeamID
                client.SetClientCharacter(mudraptor)
                HF.SetAffliction(mudraptor, "mudraptorgrowthveteran", 1, nil, nil)
                
                -- Transfer the MudraptorServant role to the new body
                if existingRole and existingRole.Name == "MudraptorServant" then
                    Neurologics.RoleManager.TransferRole(mudraptor, existingRole)
                end
                
                Entity.Spawner.AddEntityToRemoveQueue(character)
            end)
            local explosion = ItemPrefab.GetItemPrefab("surgeryexplosion")
            Entity.Spawner.AddItemToSpawnQueue(explosion, character.WorldPosition, nil, nil, function(item)
                item.Use(0)
            end)
        end
    end
})

afflictionScript.AddAffliction("javiervirus", {
    OnPeriodic = function(affliction, character, characterHealth, limb)
        if affliction.Strength >= 100 then
            local client = Neurologics.FindClientCharacter(character)
            if not client then return end
            local javier = NCS.SpawnCharacterWithClient("javier", character.WorldPosition, 1, client, nil, nil, character)
            Entity.Spawner.AddEntityToRemoveQueue(character)
            HF.SetAffliction(javier, "javier_carrier", 1)
        end
    end
})

afflictionScript.AddAffliction("javier_carrier", {
    PeriodicInterval = 1.0,
    OnPeriodic = function(affliction, character, characterHealth, limb)
        if affliction.Strength >= 1 and math.random() < 0.005 then
            Game.Explode(character.WorldPosition, 100, 50, 50, 50, 0, 0, 0)
        end
    end
})


return afflictionScript
