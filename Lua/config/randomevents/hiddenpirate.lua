local event = {}

event.Name = "HiddenPirate"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 0.3
event.ChancePerMinute = 0.018
event.OnlyOncePerRound = true

-- Example of Conditions function - only trigger randomly if there are enough crew members and pumps
event.Conditions = function()
    -- Check if there's at least one pump
    local hasPump = false
    for key, value in pairs(Submarine.MainSub.GetItems(true)) do
        if value.Prefab.Identifier == "pump" then
            hasPump = true
            break
        end
    end
    
    if not hasPump then
        return false
    end
    
    -- Check if there are at least 3 crew members alive
    local crewCount = 0
    for client in Client.ClientList do
        if client.Character and not client.Character.IsDead then
            crewCount = crewCount + 1
        end
    end
    
    return crewCount >= 3
end

event.Start = function ()
    local areas = {}
    
    for key, value in pairs(Submarine.MainSub.GetItems(true)) do
        if value.Prefab.Identifier == "pump" then
            table.insert(areas, value)
        end
    end

    if #areas == 0 then return end

    local area = areas[math.random(#areas)]

    local info = CharacterInfo(Identifier("human"))
    info.Name = "Pirate " .. info.Name
    info.Job = Job(JobPrefab.Get("securityofficer"))

    local character = Character.Create(info, area.WorldPosition, info.Name, 0, false, true)

    character.TeamID = CharacterTeamType.Team2
    character.GiveJobItems(nil)

    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("revolver"), character.Inventory, nil, nil, function (item)
        for i = 1, 6, 1 do
            Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("revolverround"), item.OwnInventory)
        end
    end)

    local oldClothes = character.Inventory.GetItemInLimbSlot(InvSlotType.InnerClothes)
    oldClothes.Drop()
    Entity.Spawner.AddEntityToRemoveQueue(oldClothes)

    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("pirateclothes"), character.Inventory, nil, nil, function (item)
        character.Inventory.TryPutItem(item, character.Inventory.FindLimbSlot(InvSlotType.InnerClothes), true, false, character)
    end)

    --local text = "An enemy pirate has been detected near the pumps."
    --Neurologics.RoundEvents.SendEventMessage(text, "GameModeIcon.sandbox")

    event.End()
end


event.End = function ()

end

return event