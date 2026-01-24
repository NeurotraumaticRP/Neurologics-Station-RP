-- Trait System
-- Applies randomized traits to player characters at round start and mid-round spawn.
-- Traits can grant afflictions (one-time or permanent), talents, and reactive behaviors.

-- Trait definitions table
Neurologics.Traits = {}

-- Per-character state tracking: {character = {traits = {traitName = state}, ...}}
Neurologics.TraitState = {}

-- Frame counter for think loop optimization
local traitThinkFrameCounter = 0

--------------------------------------------------------------------------------
-- TRAIT DEFINITION SCHEMA
--------------------------------------------------------------------------------
--[[
All fields are optional with sensible defaults:

Neurologics.Traits["ExampleTrait"] = {
    -- OPTIONAL: Weight for random selection (default: 10)
    weight = 10,
    
    -- OPTIONAL: Type category (default: "neutral")
    -- Can be: "positive", "negative", "neutral"
    type = "neutral",
    
    -- OPTIONAL: Afflictions to apply
    -- Format: {identifier, strength, permanent}
    -- permanent = true means it will be reapplied continuously
    afflictions = {
        {"affliction_id", 100, false},
    },
    
    -- OPTIONAL: Talents to grant
    talents = {"talent_id"},
    
    -- OPTIONAL CALLBACKS:
    -- OnApply(character, state) - Called once when trait is first applied
    -- OnStart(client, character, state) - Called on round start for characters with this trait
    -- OnDamaged(character, state, attacker, damage) - Called when character takes damage
    -- OnThink(character, state) - Called periodically (~6 times/second)
    -- OnDeath(character, state) - Called when character dies
}
]]

--------------------------------------------------------------------------------
-- TRAIT DEFINITIONS
--------------------------------------------------------------------------------

Neurologics.Traits["MissingLeftLeg"] = {
    type = "negative",
    OnStart = function(client, character, state)
        NT.SurgicallyAmputateLimb(character, "lleg")
    end,
}

Neurologics.Traits["MissingRightLeg"] = {
    type = "negative",
    OnStart = function(client, character, state)
        NT.SurgicallyAmputateLimb(character, "rleg")
    end,
}

Neurologics.Traits["MissingLeftArm"] = {
    type = "negative",
    OnStart = function(client, character, state)
        NT.SurgicallyAmputateLimb(character, "larm")
    end,
}

Neurologics.Traits["MissingRightArm"] = {
    type = "negative",
    OnStart = function(client, character, state)
        NT.SurgicallyAmputateLimb(character, "rarm")
    end,
}

Neurologics.Traits["AngerIssues"] = {
    cooldown = 60, -- custom field for this trait
    OnDamaged = function(character, state, attacker, damage)
        -- Check cooldown
        if state.lastTrigger and Timer.GetTime() - state.lastTrigger < 60 then
            return
        end
        state.lastTrigger = Timer.GetTime()
        
        -- Apply steroid affliction with strength 15
        HF.SetAffliction(character, "yoursteroids", 15)
        Neurologics.Log("[Traits] AngerIssues triggered for " .. character.Name)
    end,
}

Neurologics.Traits["QuickLearner"] = {
    type = "positive",
    talents = {"egghead"},
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Get trait property with default fallback
local function getTraitProperty(trait, property, default)
    if trait[property] ~= nil then
        return trait[property]
    end
    return default
end

--------------------------------------------------------------------------------
-- CORE FUNCTIONS
--------------------------------------------------------------------------------

-- Apply a specific trait to a character
Neurologics.ApplyTrait = function(character, traitName)
    if not character or character.IsDead or character.Removed then return false end
    
    local trait = Neurologics.Traits[traitName]
    if not trait then
        Neurologics.Error("[Traits] Trait not found: " .. tostring(traitName))
        return false
    end
    
    -- Check if trait is disabled in config
    local config = Neurologics.Config.TraitConfig
    if config and config.DisabledTraits then
        for _, disabled in ipairs(config.DisabledTraits) do
            if disabled == traitName then
                Neurologics.Debug("[Traits] Trait is disabled: " .. traitName)
                return false
            end
        end
    end
    
    -- Initialize character state if needed
    if not Neurologics.TraitState[character] then
        Neurologics.TraitState[character] = { traits = {} }
    end
    
    -- Check if character already has this trait
    if Neurologics.TraitState[character].traits[traitName] then
        Neurologics.Debug("[Traits] Character already has trait: " .. traitName)
        return false
    end
    
    -- Create trait state for this character
    local state = {}
    Neurologics.TraitState[character].traits[traitName] = state
    
    -- Apply one-time afflictions
    local afflictions = getTraitProperty(trait, "afflictions", {})
    for _, afflictionData in ipairs(afflictions) do
        local afflictionId = afflictionData[1]
        local strength = afflictionData[2] or 100
        local permanent = afflictionData[3] or false
        
        -- Mark permanent afflictions in state
        if permanent then
            if not state.permanentAfflictions then
                state.permanentAfflictions = {}
            end
            table.insert(state.permanentAfflictions, {afflictionId, strength})
        end
        
        -- Apply the affliction
        local afflictionPrefab = AfflictionPrefab.Prefabs[afflictionId]
        if afflictionPrefab then
            character.CharacterHealth.ApplyAffliction(
                character.AnimController.MainLimb,
                afflictionPrefab.Instantiate(strength)
            )
            Neurologics.Debug("[Traits] Applied affliction: " .. afflictionId .. " (" .. strength .. ")")
        else
            Neurologics.Error("[Traits] Affliction prefab not found: " .. afflictionId)
        end
    end
    
    -- Apply talents
    local talents = getTraitProperty(trait, "talents", {})
    for _, talentId in ipairs(talents) do
        character.GiveTalent(Identifier(talentId), true)
        Neurologics.Debug("[Traits] Gave talent: " .. talentId)
    end
    
    -- Call OnApply if defined
    if trait.OnApply then
        trait.OnApply(character, state)
    end
    
    Neurologics.Log("[Traits] Applied trait '" .. traitName .. "' to " .. character.Name)
    return true
end

-- Roll random traits for a character based on configured chance
Neurologics.RollTraits = function(character)
    if not character or character.IsDead or character.Removed then return end
    
    local config = Neurologics.Config.TraitConfig
    if not config or not config.Enabled then return end
    
    local baseChance = config.BaseChance or 0.15
    local appliedTraits = {}
    
    -- Build weighted pool of available traits
    local availableTraits = {}
    for traitName, trait in pairs(Neurologics.Traits) do
        -- Check if trait is disabled
        local disabled = false
        if config.DisabledTraits then
            for _, disabledName in ipairs(config.DisabledTraits) do
                if disabledName == traitName then
                    disabled = true
                    break
                end
            end
        end
        
        if not disabled then
            table.insert(availableTraits, {name = traitName, trait = trait})
        end
    end
    
    if #availableTraits == 0 then return end
    
    -- Keep rolling while we pass the base chance
    while math.random() < baseChance do
        -- Filter out already applied traits
        local eligibleTraits = {}
        for _, entry in ipairs(availableTraits) do
            local alreadyApplied = false
            for _, applied in ipairs(appliedTraits) do
                if applied == entry.name then
                    alreadyApplied = true
                    break
                end
            end
            if not alreadyApplied then
                table.insert(eligibleTraits, entry)
            end
        end
        
        if #eligibleTraits == 0 then break end
        
        -- Weighted random selection (default weight: 10)
        local totalWeight = 0
        for _, entry in ipairs(eligibleTraits) do
            totalWeight = totalWeight + getTraitProperty(entry.trait, "weight", 10)
        end
        
        local roll = math.random() * totalWeight
        local cumulative = 0
        local selectedTrait = nil
        
        for _, entry in ipairs(eligibleTraits) do
            cumulative = cumulative + getTraitProperty(entry.trait, "weight", 10)
            if roll <= cumulative then
                selectedTrait = entry.name
                break
            end
        end
        
        if selectedTrait then
            if Neurologics.ApplyTrait(character, selectedTrait) then
                table.insert(appliedTraits, selectedTrait)
            end
        end
    end
    
    if #appliedTraits > 0 then
        Neurologics.Log("[Traits] " .. character.Name .. " received traits: " .. table.concat(appliedTraits, ", "))
    end
    
    return appliedTraits
end

-- Check if a character has a specific trait
Neurologics.HasTrait = function(character, traitName)
    if not character or not Neurologics.TraitState[character] then
        return false
    end
    return Neurologics.TraitState[character].traits[traitName] ~= nil
end

-- Get all traits for a character
Neurologics.GetCharacterTraits = function(character)
    if not character or not Neurologics.TraitState[character] then
        return {}
    end
    
    local traitNames = {}
    for traitName, _ in pairs(Neurologics.TraitState[character].traits) do
        table.insert(traitNames, traitName)
    end
    return traitNames
end

-- Get trait state for a character's specific trait
Neurologics.GetTraitState = function(character, traitName)
    if not character or not Neurologics.TraitState[character] then
        return nil
    end
    return Neurologics.TraitState[character].traits[traitName]
end

-- Clear all traits for a character
Neurologics.ClearCharacterTraits = function(character)
    if character then
        Neurologics.TraitState[character] = nil
    end
end

--------------------------------------------------------------------------------
-- HOOKS
--------------------------------------------------------------------------------

-- Round start: Apply traits to all player characters and call OnStart
--[[Hook.Add("roundStart", "Neurologics.Traits.RoundStart", function()
    local config = Neurologics.Config.TraitConfig
    if not config or not config.Enabled then return end
    
    -- Small delay to ensure characters are fully initialized
    Timer.Wait(function()
        for _, client in pairs(Client.ClientList) do
            if client.Character and not client.Character.IsDead and client.Character.IsHuman then
                Neurologics.RollTraits(client.Character)
                
                -- Call OnStart for all traits this character has
                local charState = Neurologics.TraitState[client.Character]
                if charState then
                    for traitName, state in pairs(charState.traits) do
                        local trait = Neurologics.Traits[traitName]
                        if trait and trait.OnStart then
                            trait.OnStart(client, client.Character, state)
                        end
                    end
                end
            end
        end
    end, 1000)
end)

-- Mid-round spawn: Apply traits to newly spawned players
Hook.Add("Neurologics.midroundspawn", "Neurologics.Traits.MidRoundSpawn", function(client, character)
    local config = Neurologics.Config.TraitConfig
    if not config or not config.Enabled then return end
    
    if character and not character.IsDead and character.IsHuman then
        -- Small delay to ensure character is fully initialized
        Timer.Wait(function()
            if character and not character.Removed and not character.IsDead then
                Neurologics.RollTraits(character)
                
                -- Call OnStart for all traits this character has (also for mid-round spawns)
                local charState = Neurologics.TraitState[character]
                if charState and client then
                    for traitName, state in pairs(charState.traits) do
                        local trait = Neurologics.Traits[traitName]
                        if trait and trait.OnStart then
                            trait.OnStart(client, character, state)
                        end
                    end
                end
            end
        end, 500)
    end
end)]]--

-- Character damage: Call OnDamaged for reactive traits
Hook.Add("characterDamage", "Neurologics.Traits.Damage", function(character, attackResult)
    if not Game.RoundStarted then return end
    if not character or character.IsDead then return end
    
    local charState = Neurologics.TraitState[character]
    if not charState then return end
    
    local attacker = attackResult.Attacker
    local damage = attackResult.Damage or 0
    
    -- Call OnDamaged for each trait that has it
    for traitName, state in pairs(charState.traits) do
        local trait = Neurologics.Traits[traitName]
        if trait and trait.OnDamaged then
            trait.OnDamaged(character, state, attacker, damage)
        end
    end
end)

-- Think loop: Apply permanent afflictions and call OnThink
Hook.Add("think", "Neurologics.Traits.Think", function()
    if not Game.RoundStarted then return end
    
    traitThinkFrameCounter = traitThinkFrameCounter + 1
    
    -- Run every 10 frames (~6 times per second at 60fps)
    if traitThinkFrameCounter < 10 then return end
    traitThinkFrameCounter = 0
    
    for character, charState in pairs(Neurologics.TraitState) do
        -- Check if character is still valid
        if not character or character.Removed or character.IsDead then
            Neurologics.TraitState[character] = nil
        else
            for traitName, state in pairs(charState.traits) do
                local trait = Neurologics.Traits[traitName]
                if trait then
                    -- Apply permanent afflictions
                    if state.permanentAfflictions then
                        for _, afflictionData in ipairs(state.permanentAfflictions) do
                            local afflictionId = afflictionData[1]
                            local strength = afflictionData[2]
                            
                            local afflictionPrefab = AfflictionPrefab.Prefabs[afflictionId]
                            if afflictionPrefab then
                                character.CharacterHealth.ApplyAffliction(
                                    character.AnimController.MainLimb,
                                    afflictionPrefab.Instantiate(strength)
                                )
                            end
                        end
                    end
                    
                    -- Call OnThink if defined
                    if trait.OnThink then
                        trait.OnThink(character, state)
                    end
                end
            end
        end
    end
end)

-- Character death: Clean up trait state
Hook.Add("characterDeath", "Neurologics.Traits.Death", function(character)
    if character then
        -- Call OnDeath for each trait
        local charState = Neurologics.TraitState[character]
        if charState then
            for traitName, state in pairs(charState.traits) do
                local trait = Neurologics.Traits[traitName]
                if trait and trait.OnDeath then
                    trait.OnDeath(character, state)
                end
            end
        end
        
        Neurologics.TraitState[character] = nil
    end
end)

-- Register cleanup callback for round end
Neurologics.RegisterCleanup("Traits", function()
    Neurologics.TraitState = {}
end)

print("[Neurologics] Traits system loaded")

return Neurologics.Traits
