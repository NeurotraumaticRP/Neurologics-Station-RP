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
-- transferFromCharacter: optional - if provided, transfer this character's inventory instead of prefab inventory
NCS.SpawnCharacter = function(prefabKey, position, team, objectives, traits, transferFromCharacter)
    prefabKey = string.lower(prefabKey)
    local charPrefab = NCS.Char[prefabKey]
    if not charPrefab then
        local keys = {}
        for k in pairs(NCS.Char or {}) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        local err = "Character prefab '" .. prefabKey .. "' not found. Available: " .. table.concat(keys, ", ")
        print("[Neurologics/CharacterSpawner] " .. err)
        return nil, err
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

    -- Apply appearance overrides from prefab (HairIndex, BeardIndex, etc.; nil = keep random)
    if species == "human" and info.Head and charPrefab.Appearance then
        local app = charPrefab.Appearance
        -- Gender/HeadId: find matching HeadPreset and use RecreateHead(HeadInfo)
        if app.Gender ~= nil or app.HeadId ~= nil then
            local headId, gender
            if app.HeadId ~= nil then
                headId = (type(app.HeadId) == "string" and app.HeadId:lower():match("^head") and app.HeadId) or ("head" .. tostring(app.HeadId))
            end
            if app.Gender ~= nil then
                gender = (type(app.Gender) == "string" and app.Gender:lower()) or tostring(app.Gender):lower()
            end
            -- Get current values from TagSet if not specified
            if not headId or not gender then
                for tag in info.Head.Preset.TagSet do
                    local s = tostring(tag):lower()
                    if not headId and s:match("^head%d+") then headId = s end
                    if not gender and (s == "male" or s == "female") then gender = s end
                end
            end
            if headId and gender and info.Prefab and info.Prefab.Heads then
                local matchedPreset = nil
                for hp in info.Prefab.Heads do
                    if hp and hp.TagSet then
                        local hasHead, hasGender = false, false
                        for tag in hp.TagSet do
                            local t = tostring(tag):lower()
                            if t == headId:lower() then hasHead = true end
                            if t == gender then hasGender = true end
                        end
                        if hasHead and hasGender then matchedPreset = hp break end
                    end
                end
                if matchedPreset then
                    local hi = app.HairIndex ~= nil and app.HairIndex or info.Head.HairIndex
                    local bi = app.BeardIndex ~= nil and app.BeardIndex or info.Head.BeardIndex
                    local mi = app.MoustacheIndex ~= nil and app.MoustacheIndex or info.Head.MoustacheIndex
                    local fi = app.FaceAttachmentIndex ~= nil and app.FaceAttachmentIndex or info.Head.FaceAttachmentIndex
                    local headInfo = CharacterInfo.HeadInfo(info, matchedPreset, hi, bi, mi, fi)
                    info.RecreateHead(headInfo)
                end
            end
        else
            if app.HairIndex ~= nil then info.Head.HairIndex = app.HairIndex end
            if app.BeardIndex ~= nil then info.Head.BeardIndex = app.BeardIndex end
            if app.MoustacheIndex ~= nil then info.Head.MoustacheIndex = app.MoustacheIndex end
            if app.FaceAttachmentIndex ~= nil then info.Head.FaceAttachmentIndex = app.FaceAttachmentIndex end
        end
        -- Colors: RGBA as table {r,g,b,a} or {r,g,b} (alpha defaults to 255)
        if app.SkinColor ~= nil then
            info.Head.SkinColor = type(app.SkinColor) == "table" and Color(app.SkinColor[1], app.SkinColor[2], app.SkinColor[3], app.SkinColor[4] or 255) or app.SkinColor
        end
        if app.HairColor ~= nil then
            info.Head.HairColor = type(app.HairColor) == "table" and Color(app.HairColor[1], app.HairColor[2], app.HairColor[3], app.HairColor[4] or 255) or app.HairColor
        end
        if app.FacialHairColor ~= nil then
            info.Head.FacialHairColor = type(app.FacialHairColor) == "table" and Color(app.FacialHairColor[1], app.FacialHairColor[2], app.FacialHairColor[3], app.FacialHairColor[4] or 255) or app.FacialHairColor
        end
    end

    local character = Character.Create(info, position, info.Name, 0, false, true)
    
    -- Track this as an NCS-spawned character
    NCS.SpawnedCharacters[character] = true
    
    -- Remove from crew list (human chars) - send now and deferred (client may be linked after SetClientCharacter)
    if species == "human" then
        Networking.CreateEntityEvent(character, Character.RemoveFromCrewEventData.__new(character.TeamID, {}))
        Timer.Wait(function()
            if character and not character.Removed then
                Networking.CreateEntityEvent(character, Character.RemoveFromCrewEventData.__new(character.TeamID, {}))
            end
        end, 150)
    end
    
    -- Remove the character's inventory
    NCS.RemoveCharacterInventory(character)

    -- Either transfer from source character or add prefab inventory
    if transferFromCharacter and transferFromCharacter.Inventory and not transferFromCharacter.Removed then
        NCS.TransferInventory(transferFromCharacter, character)
    else
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
    end

    -- Apply character template (talents, skills, perma afflictions, prefab traits)
    NCS.ApplyCharacterTemplate(character, charPrefab)
    
    -- Apply additional traits passed as parameter
    if traits and Neurologics.ApplyTrait then
        for _, traitName in ipairs(traits) do
            Neurologics.ApplyTrait(character, traitName)
        end
    end
    
    -- Assign role: use charPrefab.Role if set, otherwise team-based (Team1=Crew, others=Antagonist)
    NCS.AssignRoleForCharacter(character, team, charPrefab)
    
    -- Attach objectives: use param, or prefab's default Objectives
    local objList = objectives or (charPrefab and charPrefab.Objectives)
    if objList then
        NCS.AttachObjectives(character, objList)
    end

    return character
end

NCS.SpawnCharacterWithClient = function(prefabKey, position, team, client, objectives, traits, transferInventory)
    local transferFrom = (transferInventory and client and client.Character and not client.Character.IsDead and not client.Character.Removed) and client.Character or nil
    local character = NCS.SpawnCharacter(prefabKey, position, team, objectives, traits, transferFrom)
    if character then
        client.SetClientCharacter(character)
    end
    return character
end

-- Transfers all items from source character's inventory to target character
NCS.TransferInventory = function(fromCharacter, toCharacter)
    if not fromCharacter or not toCharacter or not fromCharacter.Inventory or not toCharacter.Inventory then return end
    local itemsToTransfer = {}
    for slot = 0, fromCharacter.Inventory.Capacity - 1 do
        local item = fromCharacter.Inventory.GetItemAt(slot)
        if item then
            table.insert(itemsToTransfer, item)
        end
    end
    for _, item in ipairs(itemsToTransfer) do
        if item and not item.Removed then
            fromCharacter.Inventory.RemoveItem(item)
            -- Try each slot until one accepts the item
            for slot = 0, toCharacter.Inventory.Capacity - 1 do
                if toCharacter.Inventory.TryPutItem(item, slot, true, false, toCharacter) then
                    break
                end
            end
        end
    end
end

NCS.GetSpawnPositionOutsideSub = function()
    local waypoints = Submarine.MainSub.GetWaypoints(true)

    if LuaUserData.IsTargetType(Game.GameSession.GameMode, "Barotrauma.PvPMode") then
        waypoints = Submarine.MainSubs[math.random(2)].GetWaypoints(true)
    end

    local spawnPositions = {}

    for key, value in pairs(waypoints) do
        if value.CurrentHull == nil then
            table.insert(spawnPositions, value.WorldPosition)
        end
    end

    local spawnPosition

    if #spawnPositions == 0 then
        spawnPosition = Submarine.MainSub.WorldPosition -- spawn it in the middle of the sub
        Neurologics.Log("Couldnt find any good waypoints, spawning in the middle of the sub.")
    else
        spawnPosition = spawnPositions[math.random(#spawnPositions)]
    end

    return spawnPosition
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
    
    -- Apply individual talents
    if charPrefab.Talents then
        for _, talentId in ipairs(charPrefab.Talents) do
            character.GiveTalent(Identifier(talentId), true)
        end
    end
    
    -- Apply talent trees (unlocks all talents in specified trees)
    if charPrefab.TalentTrees then
        for _, treeName in ipairs(charPrefab.TalentTrees) do
            -- Character name needs to be quoted for the command
            local charName = '"' .. character.Name .. '"'
            local command = "unlocktalents " .. treeName .. " " .. charName
            Game.ExecuteCommand(command)
        end
    end
    
    -- Apply skills
    if charPrefab.Skills and character.Info then
        for skillName, level in pairs(charPrefab.Skills) do
            character.Info.SetSkillLevel(Identifier(skillName), level, false)
        end
    end
    
    -- Apply one-time afflictions (format: {"burn", "bleeding"} or {{"burn", 100}, {"bleeding", 50}})
    if charPrefab.Afflictions then
        for _, afflictionData in ipairs(charPrefab.Afflictions) do
            local afflictionId = type(afflictionData) == "string" and afflictionData or afflictionData[1]
            local strength = type(afflictionData) == "table" and afflictionData[2] or 100
            
            local afflictionPrefab = AfflictionPrefab.Prefabs[afflictionId]
            if afflictionPrefab then
                character.CharacterHealth.ApplyAffliction(
                    character.AnimController.MainLimb,
                    afflictionPrefab.Instantiate(strength)
                )
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
        end
    end
end

-- Register a character for permanent affliction tracking
NCS.RegisterPermaAfflictions = function(character, afflictions)
    if not character or not afflictions then return end
    
    NCS.PermaAfflictionCharacters[character] = afflictions
end

-- Assign role for NCS-spawned characters: use charPrefab.Role if set, otherwise team-based
NCS.AssignRoleForCharacter = function(character, team, charPrefab)
    if not character or not Game.RoundStarted then return end
    
    local existingRole = Neurologics.RoleManager.GetRole(character)
    if existingRole then return end
    
    local role = nil
    if charPrefab and charPrefab.Role and Neurologics.RoleManager.Roles[charPrefab.Role] then
        role = Neurologics.RoleManager.Roles[charPrefab.Role]
    end
    if not role then
        -- Fallback: team-based (default Crew for Team1, Antagonist for others)
        if team == CharacterTeamType.Team1 then
            role = Neurologics.RoleManager.Roles["Crew"]
        else
            role = Neurologics.RoleManager.Roles["Antagonist"]
        end
    end
    
    if role then
        Neurologics.RoleManager.AssignRole(character, role:new())
    end
end

NCS.AssignRoleByTeam = function(character, team)
    NCS.AssignRoleForCharacter(character, team, nil)
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
            else
                print("[Neurologics/CharacterSpawner] Failed to start objective: " .. objName)
            end
        else
            print("[Neurologics/CharacterSpawner] Objective not found: " .. objName)
        end
    end

    -- Send greet to client after objectives are attached. Defer so client is linked first
    -- (for !SpawnAs, SetClientCharacter runs after SpawnCharacter returns)
    local charRef = character
    local roleRef = role
    Timer.Wait(function()
        if not charRef or charRef.Removed then return end
        local client = Neurologics.FindClientCharacter and Neurologics.FindClientCharacter(charRef)
        if not client or not roleRef or not roleRef.Objectives or #roleRef.Objectives == 0 then return end
        local text = roleRef:Greet()
        if text and text ~= "" then
            if roleRef.IsAntagonist then
                if Neurologics.SendTraitorMessageBox then
                    Neurologics.SendTraitorMessageBox(client, text)
                end
                if Neurologics.UpdateVanillaTraitor then
                    Neurologics.UpdateVanillaTraitor(client, true, text)
                end
            else
                Neurologics.SendChatMessage(client, text, Color.Green)
            end
        end
    end, 100)
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

