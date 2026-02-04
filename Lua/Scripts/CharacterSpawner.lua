-- Define the CharacterSpawner table and character prefab storage
NCS = NCS or {}

if not NCS then
    NCS = {}
end

if not NCS.Char then -- this should fix overwriting the original CharacterSpawner
    NCS.Char = {}
end

-- Track NCS-spawned characters for role assignment
NCS.SpawnedCharacters = {}

-- Track characters with permanent afflictions
NCS.PermaAfflictionCharacters = {}
NCS.PermaAfflictionFrameCounter = 0

-- Spawns a character from a prefab
-- traits: optional array of trait names to apply in addition to prefab traits
NCS.SpawnCharacter = function(prefabKey, position, team, objectives, traits)
    prefabKey = string.lower(prefabKey)
    local charPrefab = NCS.Char[prefabKey]
    if not charPrefab then
        print("[Neurologics/CharacterSpawner] Character not found")
        print("[Neurologics/CharacterSpawner] Prefab key: " .. prefabKey)
        print("[Neurologics/CharacterSpawner] Prefab keys: " .. table.concat(NCS.Char, ", "))
        return
    end

    if not charPrefab.Prefix then
        return
    end

    if not team then
        team = charPrefab.Team
    end

    -- Get species from prefab or default to human
    local species = charPrefab.Species or "human"
    local info = CharacterInfo(Identifier(species))

    info.TeamID = team
    -- Use static Name if provided, otherwise use Prefix + generated name
    if charPrefab.Name then
        info.Name = charPrefab.Name
    elseif charPrefab.Prefix and info.Name then
        info.Name = charPrefab.Prefix .. " " .. info.Name
    elseif info.Name then
        info.Name = info.Name
    end
    -- Only assign jobs to humans - creatures like mudraptors don't have jobs
    if species == "human" and charPrefab.BaseJob then
        info.Job = Job(JobPrefab.Get(charPrefab.BaseJob), true)
    end

    local character = Character.Create(info, position, info.Name, 0, false, true)
    
    -- Track this as an NCS-spawned character
    NCS.SpawnedCharacters[character] = true
    
    -- Remove the character's inventory
    NCS.RemoveCharacterInventory(character)

    -- Add each item from the prefab's inventory to the character
    for _, item in pairs(charPrefab.Inventory or {}) do
        NCS.AddItemToCharacter(
            character,
            item.id,
            item.count,
            item.subItems,
            item.slot
        )
    end

    -- Apply character template (talents, skills, perma afflictions, prefab traits)
    NCS.ApplyCharacterTemplate(character, charPrefab)
    
    -- Apply additional traits passed as parameter
    if traits and Neurologics.ApplyTrait then
        for _, traitName in ipairs(traits) do
            Neurologics.ApplyTrait(character, traitName)
            print("[Neurologics/CharacterSpawner] Applied trait (param): " .. traitName)
        end
    end
    
    -- Assign role based on team (for NCS-spawned characters)
    NCS.AssignRoleByTeam(character, team)
    
    -- Attach objectives if provided
    if objectives then
        NCS.AttachObjectives(character, objectives)
    end

    return character
end

NCS.SpawnCharacterWithClient = function(prefabKey, position, team, client, objectives, traits)
    local character = NCS.SpawnCharacter(prefabKey, position, team, objectives, traits)
    if character then
        client.SetClientCharacter(character)
    end
    return character
end

-- Helper: Recursively spawn sub-items (max 3 nested levels)
NCS.SpawnSubItems = function(subItems, parentInventory, depth)
    depth = depth or 1
    if depth > 3 then return end -- Prevent infinite recursion or performance issues

    for _, subItem in ipairs(subItems or {}) do
        local subItemPrefab = ItemPrefab.GetItemPrefab(subItem.id)
        for i = 1, subItem.count do
            Entity.Spawner.AddItemToSpawnQueue(
                subItemPrefab,
                parentInventory,
                subItem.condition,
                subItem.quality,
                function(spawnedSubItem)
                    -- If this sub-item has its own sub-items, spawn them into its OwnInventory (if available)
                    if subItem.subItems then
                        local childInventory = spawnedSubItem.OwnInventory or parentInventory
                        NCS.SpawnSubItems(subItem.subItems, childInventory, depth + 1)
                    end
                end
            )
        end
    end
end

-- Adds an item to the character's inventory (with its sub-items)
NCS.AddItemToCharacter = function(character, id, count, subItems, slot, quality, condition)
    if not character then
        print("[Neurologics/CharacterSpawner] Character not found")
        return
    end

    local itemPrefab = ItemPrefab.GetItemPrefab(id)
    for i = 1, count do
        Entity.Spawner.AddItemToSpawnQueue(
            itemPrefab,
            character.inventory,
            condition,
            quality,
            function(spawnedItem)
                -- Use the spawned item's OwnInventory if it exists; otherwise, fall back to character.inventory.
                local targetInventory = spawnedItem.OwnInventory or character.inventory
                if subItems then
                    NCS.SpawnSubItems(subItems, targetInventory, 1)
                end
            end,
            nil,
            nil,
            slot
        )
    end
end

NCS.RemoveCharacterInventory = function(character)
    for itemCount = 0, character.Inventory.Capacity do
        local item = character.Inventory.GetItemAt(itemCount)
        if item then
            character.Inventory.RemoveItem(item)
        end
    end
end

-- Apply character template properties (talents, skills, afflictions, perma afflictions, traits)
NCS.ApplyCharacterTemplate = function(character, charPrefab)
    if not character then return end
    
    -- Apply talents
    if charPrefab.Talents then
        for _, talentId in ipairs(charPrefab.Talents) do
            character.GiveTalent(Identifier(talentId), true)
            print("[Neurologics/CharacterSpawner] Gave talent: " .. talentId)
        end
    end
    
    -- Apply skills
    if charPrefab.Skills and character.Info then
        for skillName, level in pairs(charPrefab.Skills) do
            character.Info.SetSkillLevel(Identifier(skillName), level, false)
            print("[Neurologics/CharacterSpawner] Set skill " .. skillName .. " to " .. level)
        end
    end
    
    -- Apply one-time afflictions
    if charPrefab.Afflictions then
        for _, afflictionData in ipairs(charPrefab.Afflictions) do
            local afflictionId = afflictionData[1]
            local strength = afflictionData[2] or 100
            
            local afflictionPrefab = AfflictionPrefab.Prefabs[afflictionId]
            if afflictionPrefab then
                character.CharacterHealth.ApplyAffliction(
                    character.AnimController.MainLimb,
                    afflictionPrefab.Instantiate(strength)
                )
                print("[Neurologics/CharacterSpawner] Applied affliction: " .. afflictionId .. " (" .. strength .. ")")
            end
        end
    end
    
    -- Register permanent afflictions
    if charPrefab.PermaAfflictions then
        NCS.RegisterPermaAfflictions(character, charPrefab.PermaAfflictions)
    end
    
    -- Apply traits from prefab
    if charPrefab.Traits and Neurologics.ApplyTrait then
        for _, traitName in ipairs(charPrefab.Traits) do
            Neurologics.ApplyTrait(character, traitName)
            print("[Neurologics/CharacterSpawner] Applied trait: " .. traitName)
        end
    end
end

-- Register a character for permanent affliction tracking
NCS.RegisterPermaAfflictions = function(character, afflictions)
    if not character or not afflictions then return end
    
    NCS.PermaAfflictionCharacters[character] = afflictions
    print("[Neurologics/CharacterSpawner] Registered perma afflictions for " .. character.Name)
end

-- Assign role based on team for NCS-spawned characters
NCS.AssignRoleByTeam = function(character, team)
    if not character or not Game.RoundStarted then return end
    
    -- Check if character already has a role
    local existingRole = Neurologics.RoleManager.GetRole(character)
    if existingRole then return end
    
    -- Assign role based on team
    local role = nil
    if team == CharacterTeamType.Team1 then
        role = Neurologics.RoleManager.Roles["Crew"]
    else
        -- Team2, Team3, or other teams get Antagonist role
        role = Neurologics.RoleManager.Roles["Antagonist"]
    end
    
    if role then
        Neurologics.RoleManager.AssignRole(character, role:new())
        print("[Neurologics/CharacterSpawner] Assigned " .. role.Name .. " role to " .. character.Name)
    end
end

-- Attach objectives to a character
NCS.AttachObjectives = function(character, objectiveNames)
    if not character or not objectiveNames or #objectiveNames == 0 then return end
    
    -- Get or create role for character
    local role = Neurologics.RoleManager.GetRole(character)
    if not role then
        -- Create a basic Crew role if none exists
        role = Neurologics.RoleManager.Roles["Crew"]
        if role then
            Neurologics.RoleManager.AssignRole(character, role:new())
            role = Neurologics.RoleManager.GetRole(character)
        end
    end
    
    if not role then
        print("[Neurologics/CharacterSpawner] Failed to get/create role for objective attachment")
        return
    end
    
    -- Attach each objective
    for _, objName in ipairs(objectiveNames) do
        local objectiveTemplate = Neurologics.RoleManager.FindObjective(objName)
        if objectiveTemplate then
            local objective = objectiveTemplate:new()
            objective:Init(character)
            
            -- Try to find valid target if needed
            local target = nil
            if role.FindValidTarget then
                target = role:FindValidTarget(objective)
            end
            
            if objective:Start(target) then
                role:AssignObjective(objective)
                print("[Neurologics/CharacterSpawner] Attached objective: " .. objName .. " to " .. character.Name)
            else
                print("[Neurologics/CharacterSpawner] Failed to start objective: " .. objName)
            end
        else
            print("[Neurologics/CharacterSpawner] Objective not found: " .. objName)
        end
    end
end

-- Think hook for permanent afflictions (runs 60 times per second)
Hook.Add("think", "NCS.PermaAfflictions", function()
    NCS.PermaAfflictionFrameCounter = NCS.PermaAfflictionFrameCounter + 1
    
    -- Apply afflictions every 10 frames (1/6th of a second at 60fps)
    if NCS.PermaAfflictionFrameCounter >= 10 then
        NCS.PermaAfflictionFrameCounter = 0
        
        for character, afflictions in pairs(NCS.PermaAfflictionCharacters) do
            -- Check if character is still valid and alive
            if character and not character.Removed and not character.IsDead then
                for _, afflictionData in ipairs(afflictions) do
                    local afflictionId = afflictionData[1]
                    local strength = afflictionData[2] or 100
                    
                    local afflictionPrefab = AfflictionPrefab.Prefabs[afflictionId]
                    if afflictionPrefab then
                        character.CharacterHealth.ApplyAffliction(
                            character.AnimController.MainLimb,
                            afflictionPrefab.Instantiate(strength)
                        )
                    end
                end
            else
                -- Clean up dead/removed characters
                NCS.PermaAfflictionCharacters[character] = nil
            end
        end
    end
end)

-- Clean up on character death
Hook.Add("characterDeath", "NCS.Cleanup", function(character)
    if character then
        NCS.PermaAfflictionCharacters[character] = nil
        NCS.SpawnedCharacters[character] = nil
    end
end)

return NCS

