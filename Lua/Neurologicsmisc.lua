local timer = Timer.GetTime()

local huskBeacons = {}

Neurologics.AddHuskBeacon = function (item, time)
    huskBeacons[item] = time
end

-- Main death handler hook - calls processor defined in Neurologicsutil.lua
Hook.Add("character.death", "Neurologics.DeathHandler", function(character)
    Neurologics.ProcessDeathHandlers(character)
end)


local peopleInOutpost = 0
local ghostRoleNumber = 1
Hook.Add("think", "Neurologics.MiscThink", function ()
    if timer > Timer.GetTime() then return end
    if not Game.RoundStarted then return end

    for item, _ in pairs(huskBeacons) do
        local interface = item.GetComponentString("CustomInterface")
        if interface.customInterfaceElementList[1].State then
            huskBeacons[item] = huskBeacons[item] - 5
        end

        if huskBeacons[item] <= 0 then
            for i = 1, 4, 1 do
                Entity.Spawner.AddCharacterToSpawnQueue("husk", item.WorldPosition)
            end

            Entity.Spawner.AddEntityToRemoveQueue(item)
            huskBeacons[item] = nil
        end
    end

    timer = Timer.GetTime() + 5
    if not Neurologics.Config then print("[Neurologicsmisc] Neurologics.Config failed to load") return end
    
    if Neurologics.Config.GhostRoleConfig.Enabled then
        for key, character in pairs(Character.CharacterList) do
            local client = Neurologics.FindClientCharacter(character)
            if not Neurologics.GhostRoles.IsGhostRole(character) and not client then
                if Neurologics.Config.GhostRoleConfig.MiscGhostRoles[character.SpeciesName.Value] then
                    Neurologics.GhostRoles.Ask(character.Name .. " " .. ghostRoleNumber, function (client)
                        client.SetClientCharacter(character)
                    end, character)
                    ghostRoleNumber = ghostRoleNumber + 1
                end
            end
        end
    end

    if not Neurologics.RoundEvents.EventExists("OutpostPirateAttack") then return end
    if Neurologics.RoundEvents.IsEventActive("OutpostPirateAttack") then return end
    if Neurologics.SelectedGamemode == nil or Neurologics.SelectedGamemode.Name ~= "Secret" then return end

    local targets = {}
    local outpost = Vector2(10000, 10000)
    if Level.Loaded.EndOutpost then 
        outpost = Level.Loaded.EndOutpost.WorldPosition
    end

    for key, character in pairs(Character.CharacterList) do
        if character.IsRemotePlayer and character.IsHuman and not character.IsDead and Vector2.Distance(character.WorldPosition, outpost) < 5000 then
            table.insert(targets, character)
        end
    end

    if #targets > 0 then
        peopleInOutpost = peopleInOutpost + 1
    end

    if peopleInOutpost > 30 then
        Neurologics.RoundEvents.TriggerEvent("OutpostPirateAttack")
    end
end)

Hook.Add("roundEnd", "Neurologics.MiscEnd", function ()
    peopleInOutpost = 0
    ghostRoleNumber = 1
    huskBeacons = {}
end)

if Neurologics.Config.DeathLogBook then
    local messages = {}

    Hook.Add("roundEnd", "Neurologics.DeathLogBook", function ()
        messages = {}
    end)

    Hook.Add("character.death", "Neurologics.DeathLogBook", function (character)
        if messages[character] == nil then return end

        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("logbook"), character.Inventory, nil, nil, function(item)
            local terminal = item.GetComponentString("Terminal")

            local text = ""
            for key, value in pairs(messages[character]) do
                text = text .. value .. "\n"
            end

            terminal.TextColor = Color.MidnightBlue
            terminal.ShowMessage = text
            terminal.SyncHistory()
        end)
    end)

    Neurologics.AddCommand("!write", function (client, args)
        if client.Character == nil or client.Character.IsDead or client.Character.SpeechImpediment > 0 or not client.Character.IsHuman then
            Neurologics.SendChatMessage(client, "You are unable to write to your death logbook.", Color.Red)
            return true
        end

        if messages[client.Character] == nil then
            messages[client.Character] = {}
        end

        if #messages[client.Character] > 255 then return end

        local message = table.concat(args, " ")
        table.insert(messages[client.Character], message)

        Neurologics.SendChatMessage(client, "Wrote \"" .. message .. "\" to the death logbook.", Color.Green)

        return true
    end)
end