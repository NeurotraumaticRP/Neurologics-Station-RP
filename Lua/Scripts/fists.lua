-- serverside script for fists, controls the activation and deactivation of fists after recieving the network event

local blacklist = {
    "handcuffs",
    "armlock1", -- broken left arm
    "armlock2", -- broken right arm
}


local function CheckFists(client) -- checks if the client is capable of using fists, returns true if they are
    local rightitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    -- Check if at least one hand is free (empty)
    local rightFree = rightitem == nil
    local leftFree = leftitem == nil
    
    return rightFree or leftFree -- Allow fists if at least one hand is free
end

local function CheckBlacklist(client) -- checks if the client has non-blacklisted items in hands, returns true if they do
    local rightitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    -- Return true if either hand has a non-blacklisted item
    if rightitem ~= nil and not blacklist[rightitem.Prefab.Identifier] then
        return true
    end
    if leftitem ~= nil and not blacklist[leftitem.Prefab.Identifier] then
        return true
    end
    return false
end

local function GetFreeHands(client) -- returns table with free hand slots (empty hands only)
    local rightitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    local freeHands = {}
    if rightitem == nil then
        table.insert(freeHands, InvSlotType.RightHand)
    end
    if leftitem == nil then
        table.insert(freeHands, InvSlotType.LeftHand)
    end
    
    return freeHands
end

local function UnequipItems(client) -- unequips non-blacklisted items from the hands
    local rightitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    local unequipright = false
    local unequipleft = false
    
    -- Check if right hand item is not blacklisted
    if rightitem ~= nil then
        local isBlacklisted = false
        for _, blacklistedItem in ipairs(blacklist) do
            if rightitem.Prefab.Identifier == blacklistedItem then
                isBlacklisted = true
                break
            end
        end
        if not isBlacklisted then
            unequipright = true
        end
    end
    
    -- Check if left hand item is not blacklisted
    if leftitem ~= nil then
        local isBlacklisted = false
        for _, blacklistedItem in ipairs(blacklist) do
            if leftitem.Prefab.Identifier == blacklistedItem then
                isBlacklisted = true
                break
            end
        end
        if not isBlacklisted then
            unequipleft = true
        end
    end
    
    -- Unequip non-blacklisted items
    if unequipright then
        client.Character.Unequip(rightitem)
    end
    if unequipleft then
        client.Character.Unequip(leftitem)
    end
end

local function ActivateFists(client) -- activates fists for the client's free hands
    local freeHands = GetFreeHands(client)
    local fists = ItemPrefab.GetItemPrefab("ne_fists")
    
    -- Spawn fists for each free hand
    for _, handSlot in ipairs(freeHands) do
        Entity.Spawner.AddItemToSpawnQueue(fists, client.Character.Inventory, nil, nil)
    end
end

local function CheckActiveFists(client) -- checks if the client has active fists, returns true if they do
    local rightitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    -- Check if either hand has active fists
    return (rightitem ~= nil and rightitem.Prefab.Identifier == "ne_fists") or 
           (leftitem ~= nil and leftitem.Prefab.Identifier == "ne_fists")
end

local function DeactivateFists(client) -- deactivates fists for the client
    local rightitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    local deactivated = false
    
    -- Remove fists from right hand if present
    if rightitem ~= nil and rightitem.Prefab.Identifier == "ne_fists" then
        Entity.Spawner.AddEntityToRemoveQueue(rightitem)
        deactivated = true
    end
    
    -- Remove fists from left hand if present
    if leftitem ~= nil and leftitem.Prefab.Identifier == "ne_fists" then
        Entity.Spawner.AddEntityToRemoveQueue(leftitem)
        deactivated = true
    end
    
    return deactivated
end

Networking.Receive("attemptActivateFists", function(message, client)
    print("attemptActivateFists") -- receives the network event from the client, message is not used
    
    -- If fists are already active, allow deactivation
    if CheckActiveFists(client) then
        DeactivateFists(client)
        print("deactivated fists")
        return
    end
    
    -- Check for blacklisted items but allow partial activation if at least one hand is free
    local rightitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    local leftitem = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.LeftHand)
    
    local rightHasBlacklisted = false
    local leftHasBlacklisted = false
    
    if rightitem ~= nil then
        for _, blacklistedItem in ipairs(blacklist) do
            if rightitem.Prefab.Identifier == blacklistedItem then
                rightHasBlacklisted = true
                print("Right hand has blacklisted item: " .. blacklistedItem)
                break
            end
        end
    end
    
    if leftitem ~= nil then
        for _, blacklistedItem in ipairs(blacklist) do
            if leftitem.Prefab.Identifier == blacklistedItem then
                leftHasBlacklisted = true
                print("Left hand has blacklisted item: " .. blacklistedItem)
                break
            end
        end
    end
    
    -- Only prevent activation if BOTH hands have blacklisted items
    if rightHasBlacklisted and leftHasBlacklisted then
        print("Cannot activate fists - both hands have blacklisted items")
        return
    end
    
    -- Try to unequip non-blacklisted items first
    UnequipItems(client)
    
    -- Check if we can activate fists after unequipping
    if CheckFists(client) then
        ActivateFists(client)
        print("activated fists")
    else
        print("failed to activate fists - no free hands available after unequipping items")
    end
end)

-- account for stealing fists from people and dead people fists

-- stop users from dropping fists
Hook.Add("item.drop", "fists.drop", function(item, character)
    if item and item.Prefab and item.Prefab.Identifier == "ne_fists" then
        return true -- don't let users drop fists
    end
    return false
end)