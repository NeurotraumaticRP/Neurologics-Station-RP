-- Define the CharacterSpawner table and character prefab storage
Neurologics = Neurologics or {}

if not Neurologics.CharacterSpawner then
    Neurologics.CharacterSpawner = {}
end

if not Neurologics.CharacterSpawner.Char then -- this should fix overwriting the original CharacterSpawner
    Neurologics.CharacterSpawner.Char = {}
end

-- Spawns a character from a prefab
Neurologics.CharacterSpawner.SpawnCharacter = function(prefabKey, position, client, team)
    prefabKey = string.lower(prefabKey)
    local charPrefab = Neurologics.CharacterSpawner.Char[prefabKey]
    if not charPrefab then
        print("[Neurologics/CharacterSpawner] Character not found")
        print("[Neurologics/CharacterSpawner] Prefab key: " .. prefabKey)
        print("[Neurologics/CharacterSpawner] Prefab keys: " .. table.concat(Neurologics.CharacterSpawner.Char, ", "))
        return
    end

    if not charPrefab.Prefix then
        return
    end

    if not team then
        team = charPrefab.Team
    end

    local info = CharacterInfo(Identifier("human"))

    info.TeamID = team
    info.Name = charPrefab.Prefix .. " " .. info.Name
    info.Job = Job(JobPrefab.Get(charPrefab.BaseJob), true)

    local character = Character.Create(info, position, info.Name, 0, false, true)
    -- Remove the character's inventory
    Neurologics.CharacterSpawner.RemoveCharacterInventory(character)

    -- Add each item from the prefab's inventory to the character
    for _, item in pairs(charPrefab.Inventory or {}) do
        Neurologics.CharacterSpawner.AddItemToCharacter(
            character,
            item.id,
            item.count,
            item.subItems,
            item.slot -- this is adding the items to the inventory but not the sub inventory
        )
    end

    return character
end

-- Helper: Recursively spawn sub-items (max 3 nested levels)
Neurologics.CharacterSpawner.SpawnSubItems = function(subItems, parentInventory, depth)
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
                        Neurologics.CharacterSpawner.SpawnSubItems(subItem.subItems, childInventory, depth + 1)
                    end
                end
            )
        end
    end
end

-- Adds an item to the character's inventory (with its sub-items)
Neurologics.CharacterSpawner.AddItemToCharacter = function(character, id, count, subItems, slot, quality, condition)
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
                    Neurologics.CharacterSpawner.SpawnSubItems(subItems, targetInventory, 1)
                end
            end,
            nil,
            nil,
            slot
        )
    end
end

Neurologics.CharacterSpawner.RemoveCharacterInventory = function(character)
    for itemCount = 0, character.Inventory.Capacity do
        local item = character.Inventory.GetItemAt(itemCount)
        if item then
            character.Inventory.RemoveItem(item)
        end
    end
end

return Neurologics.CharacterSpawner

