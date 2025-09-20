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

--[[ 
Types of item hooks:

OnUse , be aware this is for continuous items, not weapons, like welding tools or books //done//
Always This will wait until ive figured out a way to make this without being terrbile at performance
OnWearing
OnSubmerged
OnSpawn
OnMedical
OnEquipped
OnUnequipped
OnAttack //done//
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

    local prefab = instance.Item.Prefab -- not sure if instance is an item or a component
    if itemScript.item[prefab.Identifier.Value] then
        itemScript.item[prefab.Identifier.Value].OnAttack(instance, character, limb)
    end
end, Hook.HookMethodType.Before)





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

return itemScript



