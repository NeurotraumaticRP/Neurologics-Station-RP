-- Define the CharacterSpawner table and character prefab storage
Neurologics = Neurologics or {}
Neurologics.CharacterSpawner = {}
Neurologics.CharacterSpawner.Char = {}

-- Spawns a character from a prefab
Neurologics.CharacterSpawner.SpawnCharacter = function(prefabKey, position, client, team)
    local charPrefab = Neurologics.CharacterSpawner.Char[prefabKey]
    if not charPrefab then
        print("[Neurologics/CharacterSpawner] Character not found")
        return
    end

    local info = CharacterInfo(Identifier("human"))
    if not charPrefab.Prefix then
        return
    end

    if not team then
        team = charPrefab.Team
    end

    info.TeamID = team
    info.Name = charPrefab.Prefix .. " " .. info.Name
    info.Job = Job(JobPrefab.Get(charPrefab.BaseJob), false)

    local character = Character.Create(info, position, info.Name, 0, false, true)

    -- Add each item from the prefab's inventory to the character
    for _, item in pairs(charPrefab.Inventory or {}) do
        Neurologics.CharacterSpawner.AddItemToCharacter(
            character,
            item.id,
            item.count,
            item.subItems
        )
    end

   

    return character
end

-- Helper: Recursively spawn sub-items (max 3 nested levels)
Neurologics.CharacterSpawner.SpawnSubItems = function(subItems, inventory, depth)
    depth = depth or 1
    if depth > 3 then return end

    for _, subItem in ipairs(subItems or {}) do
        local subItemPrefab = ItemPrefab.GetItemPrefab(subItem.id)
        for i = 1, subItem.count do
            Entity.Spawner.AddItemToSpawnQueue(
                subItemPrefab,
                inventory,
                subItem.condition,
                subItem.quality
            )
        end

        -- If there are further nested sub-items, spawn them (increase depth)
        if subItem.subItems then
            Neurologics.CharacterSpawner.SpawnSubItems(subItem.subItems, inventory, depth + 1)
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
            function(item)
                -- After spawning the item, add its sub-items (if any)
                if subItems then
                    Neurologics.CharacterSpawner.SpawnSubItems(subItems, character.inventory, 1)
                end
            end,
            nil,
            nil,
            slot
        )
    end
end

-- Adds a sub-item directly to an inventory (non-recursive)
--[[Neurologics.CharacterSpawner.AddSubItem = function(subItemPrefab, inventory, count, quality, condition)
    for i = 1, count do
        Entity.Spawner.AddItemToSpawnQueue(
            subItemPrefab,
            inventory,
            condition,
            quality
        )
    end
end]]

