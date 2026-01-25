--[[
    NEUROLOGICS IMPLANT SYSTEM
    ==========================
    
    Modular, prefab-based neural implant system.
    Supports toggle, permanent, and conditional implants.
    Extensible design allows easy addition of new features.
    
    ARCHITECTURE:
    - State Management: Tracks active implants per client
    - Helper Functions: Reusable utility functions
    - Affliction System: Detects implants via afflictions
    - Spawn Handlers: Extensible spawn method system
    - Validators: Check if implant can activate
    - Activators: Handle implant activation/deactivation
    - Hook System: Call prefab-defined hooks
    - Conditional System: Auto-activate based on conditions
]]

print("[NeuroImplants] Initializing implant system...")

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

-- Track active implants per client: { [clientSteamID] = { [implantName] = { active = bool, items = {}, lastActivation = time, ... } } }
local ActiveImplants = {}

-- Track conditional implant states: { [clientSteamID] = { [implantName] = { conditionMet = bool, lastCheck = time } } }
local ConditionalStates = {}

-- Track cooldowns: { [clientSteamID] = { [implantName] = lastActivationTime } }
local Cooldowns = {}

-- Initialize client data
local function InitializeClient(client)
    local steamID = client.SteamID
    if not ActiveImplants[steamID] then
        ActiveImplants[steamID] = {}
    end
    if not ConditionalStates[steamID] then
        ConditionalStates[steamID] = {}
    end
    if not Cooldowns[steamID] then
        Cooldowns[steamID] = {}
    end
end

-- Clean up client data on disconnect
Hook.Add("client.disconnected", "NeuroImplants.Cleanup", function(client)
    local steamID = client.SteamID
    ActiveImplants[steamID] = nil
    ConditionalStates[steamID] = nil
    Cooldowns[steamID] = nil
end)

-- ============================================================================
-- HELPER FUNCTIONS LIBRARY (Easy to extend)
-- ============================================================================

local Helpers = {}

-- Get free hand slots (empty hands only)
Helpers.GetFreeHands = function(character)
    local rightitem = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    local freeHands = {}
    if rightitem == nil then
        table.insert(freeHands, InvSlotType.RightHand)
    end
    if leftitem == nil then
        table.insert(freeHands, InvSlotType.LeftHand)
    end
    
    return freeHands
end

-- Check if item is in blacklist
Helpers.IsBlacklisted = function(item, blacklist)
    if not item or not blacklist then return false end
    
    for _, blacklistedItem in ipairs(blacklist) do
        if item.Prefab.Identifier.Value == blacklistedItem then
            return true
        end
    end
    return false
end

-- Unequip items from specified slots (respects blacklist)
Helpers.UnequipFromSlots = function(character, slots, blacklist)
    for _, slot in ipairs(slots) do
        local item = character.Inventory.GetItemInLimbSlot(slot)
        if item and not Helpers.IsBlacklisted(item, blacklist) then
            character.Unequip(item)
        end
    end
end

-- Get all items matching an identifier in character's inventory
Helpers.GetItemsByIdentifier = function(character, identifier)
    local items = {}
    for item in character.Inventory.AllItems do
        if item.Prefab.Identifier.Value == identifier then
            table.insert(items, item)
        end
    end
    return items
end

-- Check if character has room in inventory
Helpers.HasInventorySpace = function(character)
    return character.Inventory.CanBePut(ItemPrefab.GetItemPrefab("wrench")) -- Test with any item
end

-- ============================================================================
-- STATE PERSISTENCE SYSTEM
-- ============================================================================

local StatePersistence = {}

-- Save item state for an implant
StatePersistence.SaveItemState = function(client, implantName, items)
    local implant = Neurologics.Implants[implantName]
    if not implant or not implant.SaveState then return end
    
    local steamID = client.SteamID
    local stateKey = "implant_" .. implantName .. "_state"
    
    -- Collect state from all items
    local savedState = {}
    for i, item in ipairs(items) do
        if item and not item.Removed then
            local itemState = {}
            
            -- Save condition
            itemState.condition = item.Condition
            itemState.maxCondition = item.MaxCondition
            
            -- Save custom properties if specified
            if implant.StateProperties then
                for _, propName in ipairs(implant.StateProperties) do
                    -- Try to get property value (implementation depends on Barotrauma API)
                    -- This is a placeholder - adapt based on actual item API
                    if propName == "ammo" then
                        -- Example: Save ammo from container
                        for component in item.Components do
                            if tostring(component) == "Barotrauma.Items.Components.ItemContainer" then
                                local container = component
                                itemState.ammo = container.Inventory.AllItems.Count
                                break
                            end
                        end
                    end
                end
            end
            
            savedState[i] = itemState
        end
    end
    
    -- Store in Neurologics data system
    Neurologics.SetData(client, stateKey, savedState)
    Neurologics.Log("[NeuroImplants] Saved state for " .. implantName)
end

-- Load item state for an implant
StatePersistence.LoadItemState = function(client, implantName, items)
    local implant = Neurologics.Implants[implantName]
    if not implant or not implant.SaveState then return end
    
    local steamID = client.SteamID
    local stateKey = "implant_" .. implantName .. "_state"
    
    local savedState = Neurologics.GetData(client, stateKey)
    if not savedState then return end
    
    -- Restore state to items
    for i, item in ipairs(items) do
        if item and savedState[i] then
            local itemState = savedState[i]
            
            -- Restore condition
            if itemState.condition then
                item.Condition = itemState.condition
            end
            
            -- Restore custom properties
            if implant.StateProperties and itemState.ammo then
                -- Example: Restore ammo
                -- This would need proper implementation based on item type
                Neurologics.Log("[NeuroImplants] Restored ammo: " .. itemState.ammo)
            end
        end
    end
    
    Neurologics.Log("[NeuroImplants] Loaded state for " .. implantName)
end

-- Clear saved state for an implant
StatePersistence.ClearState = function(client, implantName)
    local stateKey = "implant_" .. implantName .. "_state"
    Neurologics.SetData(client, stateKey, nil)
end

-- ============================================================================
-- AFFLICTION DETECTION SYSTEM
-- ============================================================================

local AfflictionSystem = {}

-- Get all limbs with a specific affliction
AfflictionSystem.GetLimbsWithAffliction = function(character, afflictionIdentifier)
    local limbs = {}
    
    for limb in character.AnimController.Limbs do
        local affliction = limb.character.CharacterHealth.GetAffliction(afflictionIdentifier, limb)
        if affliction and affliction.Strength > 0 then
            table.insert(limbs, limb)
        end
    end
    
    return limbs
end

-- Check if character has affliction on any limb
AfflictionSystem.HasAffliction = function(character, afflictionIdentifier)
    local limbs = AfflictionSystem.GetLimbsWithAffliction(character, afflictionIdentifier)
    return #limbs > 0, limbs
end

-- Get the appropriate slot for a limb type
AfflictionSystem.GetSlotForLimbType = function(limbType)
    if limbType == LimbType.RightArm or limbType == LimbType.RightHand then
        return InvSlotType.RightHand
    elseif limbType == LimbType.LeftArm or limbType == LimbType.LeftHand then
        return InvSlotType.LeftHand
    end
    return nil
end

-- ============================================================================
-- SPAWN METHOD HANDLERS (Easy to add new methods)
-- ============================================================================

local SpawnHandlers = {}

-- Spawn in character's inventory
SpawnHandlers.inventory = function(client, implant, onSpawned)
    local prefab = ItemPrefab.GetItemPrefab(implant.ItemIdentifier)
    Entity.Spawner.AddItemToSpawnQueue(prefab, client.Character.Inventory, nil, implant.SpawnConfig.Condition, onSpawned)
end

-- Spawn in specific hand
SpawnHandlers.hand = function(client, implant, onSpawned)
    local prefab = ItemPrefab.GetItemPrefab(implant.ItemIdentifier)
    local targetSlot = implant.SpawnConfig.TargetLimb and AfflictionSystem.GetSlotForLimbType(implant.SpawnConfig.TargetLimb) or InvSlotType.RightHand
    
    -- Use inventory spawn, items will go to hand slots
    Entity.Spawner.AddItemToSpawnQueue(prefab, client.Character.Inventory, nil, implant.SpawnConfig.Condition, onSpawned)
end

-- Spawn in all free hands
SpawnHandlers.freeHands = function(client, implant, onSpawned)
    local freeHands = Helpers.GetFreeHands(client.Character)
    local prefab = ItemPrefab.GetItemPrefab(implant.ItemIdentifier)
    
    for i, handSlot in ipairs(freeHands) do
        Entity.Spawner.AddItemToSpawnQueue(prefab, client.Character.Inventory, nil, implant.SpawnConfig.Condition, function(item)
            if onSpawned then onSpawned(item) end
        end)
    end
end

-- Spawn on limb with affliction
SpawnHandlers.afflictionLimb = function(client, implant, onSpawned)
    if not implant.RequiresAffliction or not implant.AfflictionIdentifier then
        Neurologics.Log("[NeuroImplants] ERROR: afflictionLimb spawn method requires affliction settings")
        return
    end
    
    local hasAffliction, limbs = AfflictionSystem.HasAffliction(client.Character, implant.AfflictionIdentifier)
    if hasAffliction and #limbs > 0 then
        local targetLimb = limbs[1] -- Use first limb with affliction
        local slot = AfflictionSystem.GetSlotForLimbType(targetLimb.type)
        
        local prefab = ItemPrefab.GetItemPrefab(implant.ItemIdentifier)
        Entity.Spawner.AddItemToSpawnQueue(prefab, client.Character.Inventory, nil, implant.SpawnConfig.Condition, onSpawned)
    end
end

-- Spawn in world at character position
SpawnHandlers.world = function(client, implant, onSpawned)
    local prefab = ItemPrefab.GetItemPrefab(implant.ItemIdentifier)
    local position = client.Character.WorldPosition
    
    if client.Character.Submarine then
        Entity.Spawner.AddItemToSpawnQueue(prefab, position - client.Character.Submarine.Position, client.Character.Submarine, implant.SpawnConfig.Condition, onSpawned)
    else
        Entity.Spawner.AddItemToSpawnQueue(prefab, position, nil, implant.SpawnConfig.Condition, onSpawned)
    end
end

-- ============================================================================
-- VALIDATION SYSTEM
-- ============================================================================

local Validators = {}

-- Check if character is in valid state
Validators.CheckCharacterState = function(client, implant)
    if client.Character.IsDead and not implant.PersistOnDeath then
        return false, "Character is dead"
    end
    if client.Character.IsUnconscious and implant.RequiresConscious then
        return false, "Character is unconscious"
    end
    return true
end

-- Check affliction requirements
Validators.CheckAffliction = function(client, implant)
    if not implant.RequiresAffliction then
        return true
    end
    
    local hasAffliction, limbs = AfflictionSystem.HasAffliction(client.Character, implant.AfflictionIdentifier)
    
    if implant.AfflictionRequired and not hasAffliction then
        return false, "Missing required affliction: " .. implant.AfflictionIdentifier
    elseif not implant.AfflictionRequired and hasAffliction then
        return false, "Has forbidden affliction: " .. implant.AfflictionIdentifier
    end
    
    return true
end

-- Check cooldown
Validators.CheckCooldown = function(client, implant, implantName)
    if implant.Cooldown <= 0 then
        return true
    end
    
    local steamID = client.SteamID
    local lastActivation = Cooldowns[steamID][implantName] or 0
    local currentTime = os.time()
    
    if currentTime - lastActivation < implant.Cooldown then
        local remaining = implant.Cooldown - (currentTime - lastActivation)
        return false, string.format("Cooldown remaining: %.1fs", remaining)
    end
    
    return true
end

-- Check slots and blacklist
Validators.CheckSlots = function(client, implant)
    if #implant.Slots == 0 then
        return true
    end
    
    local allFree = true
    local hasBlacklisted = false
    
    for _, slot in ipairs(implant.Slots) do
        local item = client.Character.Inventory.GetItemInLimbSlot(slot)
        if item then
            allFree = false
            if Helpers.IsBlacklisted(item, implant.Blacklist) then
                hasBlacklisted = true
            end
        end
    end
    
    if implant.RequiresFreeSlots and not allFree then
        return false, "Required slots are not free"
    end
    
    if hasBlacklisted and not implant.AutoUnequip then
        return false, "Blacklisted item in slot"
    end
    
    return true
end

-- Check requirements
Validators.CheckRequirements = function(client, implant)
    local reqs = implant.Requirements
    
    -- Check jobs
    if reqs.Jobs then
        local hasJob = false
        for _, job in ipairs(reqs.Jobs) do
            if client.Character.HasJob(job) then
                hasJob = true
                break
            end
        end
        if not hasJob then
            return false, "Job requirement not met"
        end
    end
    
    -- Check health (only if restrictions are set)
    local healthPercentage = client.Character.HealthPercentage * 100
    if reqs.MinHealth and reqs.MinHealth > 0 and healthPercentage < reqs.MinHealth then
        return false, "Health too low"
    end
    if reqs.MaxHealth and healthPercentage > reqs.MaxHealth then
        return false, "Health too high"
    end
    
    return true
end

-- Master validation function
Validators.CanActivate = function(client, implant, implantName)
    local checks = {
        Validators.CheckCharacterState,
        Validators.CheckAffliction,
        Validators.CheckCooldown,
        Validators.CheckSlots,
        Validators.CheckRequirements
    }
    
    for _, check in ipairs(checks) do
        local success, error = check(client, implant, implantName)
        if not success then
            return false, error
        end
    end
    
    -- Call custom CanActivate hook if present
    if implant.CanActivate then
        return implant.CanActivate(client, implant)
    end
    
    return true
end

-- ============================================================================
-- ACTIVATION SYSTEM
-- ============================================================================

local Activator = {}

-- Check if implant is currently active
Activator.IsActive = function(client, implantName)
    local steamID = client.SteamID
    return ActiveImplants[steamID] and ActiveImplants[steamID][implantName] and ActiveImplants[steamID][implantName].active
end

-- Activate an implant
Activator.Activate = function(client, implantName)
    local implant = Neurologics.Implants[implantName]
    if not implant then
        Neurologics.Log("[NeuroImplants] ERROR: Unknown implant: " .. implantName)
        return false
    end
    
    InitializeClient(client)
    local steamID = client.SteamID
    
    -- Validate activation
    local canActivate, error = Validators.CanActivate(client, implant, implantName)
    if not canActivate then
        Neurologics.Log("[NeuroImplants] Cannot activate " .. implantName .. ": " .. (error or "Unknown reason"))
        return false
    end
    
    -- Auto-unequip if needed
    if implant.AutoUnequip and #implant.Slots > 0 then
        Helpers.UnequipFromSlots(client.Character, implant.Slots, implant.Blacklist)
    end
    
    -- Prepare state tracking
    local state = {
        active = true,
        items = {},
        activationTime = os.time()
    }
    
    -- Spawn items
    local spawnCount = implant.SpawnConfig.SpawnCount or implant.MaxInstances
    local itemsSpawned = 0
    
    local onSpawned = function(item)
        table.insert(state.items, item)
        itemsSpawned = itemsSpawned + 1
        
        -- Call OnSpawned hook
        if implant.OnSpawned then
            implant.OnSpawned(client, item, nil)
        end
        
        -- When all items spawned, call OnActivate and load state
        if itemsSpawned >= spawnCount or (implant.SpawnConfig.SpawnMethod == "freeHands" and itemsSpawned > 0) then
            -- Automatically load state if persistence is enabled
            if implant.SaveState then
                StatePersistence.LoadItemState(client, implantName, state.items)
            end
            
            -- Call OnActivate hook
            if implant.OnActivate then
                implant.OnActivate(client, implant, state.items)
            end
        end
    end
    
    -- Use appropriate spawn handler
    local spawnMethod = implant.SpawnConfig.SpawnMethod or "inventory"
    local spawnHandler = SpawnHandlers[spawnMethod]
    
    if spawnHandler then
        spawnHandler(client, implant, onSpawned)
    else
        Neurologics.Log("[NeuroImplants] ERROR: Unknown spawn method: " .. spawnMethod)
        return false
    end
    
    -- Save state
    ActiveImplants[steamID][implantName] = state
    Cooldowns[steamID][implantName] = os.time()
    
    Neurologics.Log("[NeuroImplants] Activated " .. implantName .. " for " .. client.Name)
    return true
end

-- Deactivate an implant
Activator.Deactivate = function(client, implantName, reason)
    local implant = Neurologics.Implants[implantName]
    if not implant then return false end
    
    local steamID = client.SteamID
    if not ActiveImplants[steamID] or not ActiveImplants[steamID][implantName] then
        return false
    end
    
    local state = ActiveImplants[steamID][implantName]
    
    -- Automatically save state before removing items if persistence is enabled
    if implant.SaveState then
        StatePersistence.SaveItemState(client, implantName, state.items)
    end
    
    -- Call OnDeactivate hook (before removing items so they can still be accessed)
    if implant.OnDeactivate then
        implant.OnDeactivate(client, implant, reason or "manual")
    end
    
    -- Remove spawned items
    for _, item in ipairs(state.items) do
        if item and not item.Removed then
            Entity.Spawner.AddEntityToRemoveQueue(item)
        end
    end
    
    -- Also remove any items by identifier still in inventory (in case they were picked up)
    local remainingItems = Helpers.GetItemsByIdentifier(client.Character, implant.ItemIdentifier)
    for _, item in ipairs(remainingItems) do
        Entity.Spawner.AddEntityToRemoveQueue(item)
    end
    
    -- Clear state
    ActiveImplants[steamID][implantName] = nil
    
    Neurologics.Log("[NeuroImplants] Deactivated " .. implantName .. " for " .. client.Name .. " (" .. (reason or "manual") .. ")")
    return true
end

-- Toggle an implant
Activator.Toggle = function(client, implantName)
    if Activator.IsActive(client, implantName) then
        return Activator.Deactivate(client, implantName, "toggle")
    else
        return Activator.Activate(client, implantName)
    end
end

-- ============================================================================
-- CONFLICT RESOLUTION SYSTEM
-- ============================================================================

-- Define which implants conflict with each other (same body parts)
local ConflictGroups = {
    RightArm = {},  -- Will be populated dynamically
    LeftArm = {},
    BothArms = {},
    RightLeg = {},
    LeftLeg = {},
    BothLegs = {},
    Head = {},
    Torso = {},
    Spine = {},
}

-- Build conflict groups from implant definitions
local function BuildConflictGroups()
    for implantName, implant in pairs(Neurologics.Implants) do
        -- Skip non-table entries (like the Create function)
        if type(implant) == "table" then
            -- Check which slots this implant uses
            if implant.Slots then
                for _, slot in ipairs(implant.Slots) do
                    if slot == InvSlotType.RightHand then
                        table.insert(ConflictGroups.RightArm, implantName)
                    elseif slot == InvSlotType.LeftHand then
                        table.insert(ConflictGroups.LeftArm, implantName)
                    end
                end
            end
            
            -- Check based on Type field
            if implant.Type == "Arms" then
                table.insert(ConflictGroups.BothArms, implantName)
            elseif implant.Type == "Legs" then
                table.insert(ConflictGroups.BothLegs, implantName)
            elseif implant.Type == "Spine" then
                table.insert(ConflictGroups.Spine, implantName)
            end
        end
    end
end

-- Check if two implants conflict
local function ImplantsConflict(implantName1, implantName2)
    if implantName1 == implantName2 then return true end
    
    for groupName, group in pairs(ConflictGroups) do
        local has1 = false
        local has2 = false
        
        for _, name in ipairs(group) do
            if name == implantName1 then has1 = true end
            if name == implantName2 then has2 = true end
        end
        
        if has1 and has2 then return true end
    end
    
    return false
end

-- Deactivate conflicting implants before activating new one
local function DeactivateConflicting(client, implantName)
    local steamID = client.SteamID
    if not ActiveImplants[steamID] then return {} end  -- Return empty table instead of nil
    
    local deactivated = {}
    
    for activeImplantName, state in pairs(ActiveImplants[steamID]) do
        if state.active and ImplantsConflict(implantName, activeImplantName) then
            Activator.Deactivate(client, activeImplantName, "conflict with " .. implantName)
            table.insert(deactivated, activeImplantName)
        end
    end
    
    return deactivated
end

-- ============================================================================
-- NETWORK EVENT HANDLER
-- ============================================================================

--[[
    CLIENT -> SERVER MESSAGE FORMAT:
    - implantName (String): The name of the implant to activate/toggle
    - action (String, optional): "activate", "deactivate", "toggle" (default: "toggle")
    - customData (String, optional): JSON-encoded custom data for the activation
    
    EXAMPLE CLIENT CODE:
    
    local message = Networking.Start("ImplantNetworkEvent")
    message.WriteString("GrenadeLauncherArm")  -- implant name
    message.WriteString("toggle")              -- action (optional)
    message.WriteString("{}")                  -- custom data (optional, JSON)
    Networking.Send(message)
]]

--[[Networking.Receive("ImplantNetworkEvent", function(message, client)
    if not client or not client.Character then return end
    
    -- Read implant name from message
    local implantName = message.ReadString()
    if not implantName then implantName = "Fists" end
    
    -- Read optional action (default to "toggle")
    local action = "toggle"
    if message.LengthBytes > message.BytePosition then
        action = message.ReadString() or "toggle"
    end
    
    -- Read optional custom data (for future extensibility)
    local customData = nil
    if message.LengthBytes > message.BytePosition then
        local customDataStr = message.ReadString()
        if customDataStr and customDataStr ~= "" then
            -- TODO: Parse JSON if needed
            customData = customDataStr
        end
    end
    
    -- Validate implant exists
    local implant = Neurologics.Implants[implantName]
    if not implant then
        Neurologics.Log("[NeuroImplants] Client requested unknown implant: " .. implantName)
        return
    end
    
    -- Check for conflicts and deactivate conflicting implants
    local deactivated = DeactivateConflicting(client, implantName)
    if #deactivated > 0 then
        Neurologics.Log("[NeuroImplants] Deactivated conflicting implants: " .. table.concat(deactivated, ", "))
    end
    
    -- Handle based on action and activation mode
    if action == "toggle" then
        if implant.ActivationMode == "toggle" or implant.ToggleMode then
            Activator.Toggle(client, implantName)
        elseif implant.ActivationMode == "permanent" then
            if not Activator.IsActive(client, implantName) then
                Activator.Activate(client, implantName)
            end
        end
    elseif action == "activate" then
        Activator.Activate(client, implantName)
    elseif action == "deactivate" then
        Activator.Deactivate(client, implantName, "manual")
    end
end)]]--

-- Initialize conflict groups on load
BuildConflictGroups()

-- ============================================================================
-- CONDITIONAL IMPLANT SYSTEM
-- ============================================================================

-- Think hook for conditional implants
Hook.Add("Think", "NeuroImplants.ConditionalCheck", function()
    for steamID, clientImplants in pairs(ConditionalStates) do
        local client = nil
        
        -- Find client by SteamID
        for key, c in pairs(Client.ClientList) do
            if c.SteamID == steamID then
                client = c
                break
            end
        end
        
        -- Only process if client exists and has a character
        if client and client.Character then
            -- Check each conditional implant
            for implantName, condState in pairs(clientImplants) do
                local implant = Neurologics.Implants[implantName]
                
                -- Only process if implant is valid and has conditional activation enabled
                if implant and implant.ConditionalActivation and implant.ConditionalActivation.Enabled then
                    local currentTime = os.clock()
                    local timeSinceLastCheck = currentTime - (condState.lastCheck or 0)
                    
                    -- Check at specified interval
                    if timeSinceLastCheck >= implant.ConditionalActivation.CheckInterval then
                        condState.lastCheck = currentTime
                        
                        -- Evaluate condition
                        local conditionMet = false
                        if implant.ConditionalActivation.CheckFunction then
                            conditionMet = implant.ConditionalActivation.CheckFunction(client)
                        end
                        
                        local wasConditionMet = condState.conditionMet or false
                        condState.conditionMet = conditionMet
                        
                        -- Handle condition changes
                        if conditionMet and not wasConditionMet then
                            -- Condition just became true
                            if implant.OnConditionMet then
                                implant.OnConditionMet(client, implant)
                            end
                        elseif not conditionMet and wasConditionMet then
                            -- Condition just became false
                            if implant.OnConditionLost then
                                implant.OnConditionLost(client, implant)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Initialize conditional implants for clients
Hook.Add("client.connected", "NeuroImplants.InitConditional", function(client)
    InitializeClient(client)
    local steamID = client.SteamID
    
    -- Initialize all conditional implants
    for implantName, implant in pairs(Neurologics.Implants) do
        -- Skip non-table entries (like the Create function)
        if type(implant) == "table" and implant.ConditionalActivation and implant.ConditionalActivation.Enabled then
            ConditionalStates[steamID][implantName] = {
                conditionMet = false,
                lastCheck = 0
            }
        end
    end
end)

-- ============================================================================
-- DROP PREVENTION SYSTEM
-- ============================================================================

Hook.Add("item.drop", "NeuroImplants.PreventDrop", function(item, character)
    if not item or not item.Prefab then return false end
    
    -- Check all implants to see if this item should be prevented from dropping
    for implantName, implant in pairs(Neurologics.Implants) do
        -- Skip non-table entries (like the Create function)
        if type(implant) == "table" and implant.ItemIdentifier == item.Prefab.Identifier.Value and not implant.CanDrop then
            return true -- Prevent drop
        end
    end
    
    return false -- Allow drop
end)

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

print("[NeuroImplants] System initialized successfully!")
