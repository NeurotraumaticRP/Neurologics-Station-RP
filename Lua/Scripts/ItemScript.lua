local itemScript = {}
itemScript.item = {}

-- Metatable: When new entries are added, automatically assign a Prefab if not provided.
setmetatable(itemScript.item, {
    __newindex = function(t, key, value)
        if type(value) == "table" then
            if value.Prefab == nil then
                value.Prefab = ItemPrefab.GetItemPrefab(key)
            end
        end
        rawset(t, key, value)
    end
})

-- Initialize any pre-existing entries in itemScript.item.
local function InitializeItems()
    for key, value in pairs(itemScript.item) do
        if type(value) == "table" and value.Prefab == nil then
            value.Prefab = ItemPrefab.GetItemPrefab(key)
        end
    end
end

-- Call the initializer (for items defined before the metatable was set)
InitializeItems()

-- Helper function to add item scripts with multiple hooks
function itemScript.AddItem(itemIdentifier, hooks)
    if type(hooks) ~= "table" then
        error("itemScript.AddItem: hooks must be a table")
    end
    
    local itemData = {
        Prefab = ItemPrefab.GetItemPrefab(itemIdentifier)
    }
    
    -- Copy all hook functions
    for hookType, hookFunction in pairs(hooks) do
        if type(hookFunction) == "function" then
            itemData[hookType] = hookFunction
        end
    end
    
    itemScript.item[itemIdentifier] = itemData
end

-- Helper function to check if an item has a specific hook
function itemScript.HasHook(itemIdentifier, hookType)
    return itemScript.item[itemIdentifier] and itemScript.item[itemIdentifier][hookType] ~= nil
end

--[[ 
Types of item hooks:

OnUse - For continuous items, not weapons, like welding tools or books
OnAttack - For melee weapons when they attack
OnHit - When a melee weapon hits a target
OnMedical - When medical items are used for treatment
OnEquipped - When item is equipped (not implemented yet)
OnUnequipped - When item is unequipped (not implemented yet)
OnSpawn - When item spawns (not implemented yet)
OnSubmerged - When item gets submerged (not implemented yet)
OnWearing - For wearable items (not implemented yet)
Always - Continuous hook (not implemented yet - performance concerns)

Multiple hooks per item are supported:
itemScript.item["example"] = {
    OnUse = function(item, character, limb) ... end,
    OnAttack = function(item, character, limb) ... end,
    OnHit = function(item, character, ishuman) ... end,
    OnMedical = function(item, usingCharacter, targetCharacter, limb) ... end
}
]]



--------------------------------
--       Base Hooks           --
--------------------------------


Hook.Add("item.use", "itemScript.OnUse", function(item, character, limb) -- OnUse hook
    local prefab = item.Prefab
    if itemScript.item[prefab.Identifier.Value] and itemScript.item[prefab.Identifier.Value].OnUse then
        itemScript.item[prefab.Identifier.Value].OnUse(item, character, limb)
    end
end)



-- Global game timer updated on each Think cycle (~60 times/second)
local gameTime = 0
Hook.Add("Think", "UpdateGameTime", function()
    gameTime = gameTime + (1/60)
end)



-- Global table for tracking last use times (weak-keyed so instances can be garbage-collected)
local lastUseTimes = setmetatable({}, { __mode = "k" })



Hook.Patch("Barotrauma.Items.Components.MeleeWeapon", "Use", function(instance, ptable)
    local now = gameTime
    local lastTime = lastUseTimes[instance] or 0

    if now - lastTime < instance.reload then
        return false  -- Prevents the hook logic from running if it's too soon
    end

    lastUseTimes[instance] = now

    local prefab = instance.Item.Prefab
    if itemScript.item[prefab.Identifier.Value] and itemScript.item[prefab.Identifier.Value].OnAttack then
        local character = ptable["user"] or ptable["character"]
        local limb = ptable["limb"]
        if character and limb then
            itemScript.item[prefab.Identifier.Value].OnAttack(instance, character, limb)
        end
    end
end, Hook.HookMethodType.Before)

Hook.Add("meleeWeapon.handleImpact", "itemScript.OnHit", function(melee, target) -- OnHit hook
    local item = melee.Item
    print(tostring(target.UserData)) -- might be able to check if the userdate is a character depending on what this prints
    local character = target.UserData.character -- this fails if the userdate is not a character
    local prefab = item.Prefab
    local ishuman = nil
    if character == nil then return end
    if character.IsHuman then ishuman = true else ishuman = false end
    if itemScript.item[prefab.Identifier.Value] and itemScript.item[prefab.Identifier.Value].OnHit then
        itemScript.item[prefab.Identifier.Value].OnHit(item, character, ishuman)
    end
end)

Hook.Add("item.applyTreatment", "itemScript.OnMedical", function(item, usingCharacter, targetCharacter, limb) -- OnMedical hook
    local prefab = item.Prefab
    if itemScript.item[prefab.Identifier.Value] and itemScript.item[prefab.Identifier.Value].OnMedical then
        itemScript.item[prefab.Identifier.Value].OnMedical(item, usingCharacter, targetCharacter, limb)
    end
end)


--------------------------------
--       Item Scripts         --
--------------------------------

--[[itemScript.item["wrench"] = {
    OnAttack = function(item, character, limb)
        print("wrench used ATTACK")
    end
}]]

--[[itemScript.item["screwdriver"] = {
    OnUse = function(item, character, limb)
        print("screwdriver used Use")
    end
}]]

-- Example: Item with multiple hooks using the helper function
itemScript.AddItem("priestsyringe", {
    OnHit = function(item, character, ishuman)
        if itemScript.HF.EvaluateSinful(character) then
            HF.SetAffliction(character, "cleansingflame", 10)
        end
        if character.HasJob("priest") and Neurologics.RoleManager.IsAntagonist(character) then
            HF.SetAffliction(character, "cleansingflame", 10)
        end
    end,
    OnMedical = function(item, usingCharacter, targetCharacter, limb)
        if itemScript.HF.EvaluateSinful(targetCharacter) then
            HF.SetAffliction(targetCharacter, "cleansingflame", 10)
        end
        if targetCharacter.HasJob("priest") and Neurologics.RoleManager.IsAntagonist(targetCharacter) then
            HF.SetAffliction(targetCharacter, "cleansingflame", 10)
        end
    end
})

-- Alternative: Direct assignment (still works)
--[[
itemScript.item["priestsyringe"] = {
    OnHit = function(item, character, ishuman)
        print("The blood of christ hit " .. character.Name .. " and ishuman is " .. tostring(ishuman))
        HF.SetAffliction(character, "cleansingflame", 10)
    end,
    OnMedical = function(item, usingCharacter, targetCharacter, limb)
        print("The blood of christ was used on " .. targetCharacter.Name)
        HF.SetAffliction(targetCharacter, "cleansingflame", 10)
    end
}
]]

-- Example: Complex item with multiple hook types
--[[
itemScript.AddItem("magicwand", {
    OnUse = function(item, character, limb)
        print("Magic wand is being used continuously")
    end,
    OnAttack = function(item, character, limb)
        print("Magic wand attacked!")
    end,
    OnHit = function(item, character, ishuman)
        print("Magic wand hit " .. character.Name)
    end,
    OnMedical = function(item, usingCharacter, targetCharacter, limb)
        print("Magic wand used for healing " .. targetCharacter.Name)
    end
})
]]

-- HELPER FUNCTIONS
itemScript.HF = {}
itemScript.HF.EvaluateSinful = function(character) -- 100% chance to light traitors/convicts on fire, 25% chance to light regular players on fire and 0% chance to work on priests
    local chance = 0.0
    if Neurologics.RoleManager.IsAntagonist(character) or character.HasJob("convict") or character.TeamID == CharacterTeamType.Team2 then
        chance = 1.0 -- 100% chance to light traitors/convicts/evil people on fire
    elseif character.HasJob("priest") then -- if a priest is a traitor, it should still be able to be set on fire, otherwise it should be 0%
        chance = 0.0
    else
        chance = 0.25 -- 25% chance to light regular players on fire
    end

    local val = math.random()
    if val <= chance then
        return true
    else
        return false
    end
end


return itemScript



