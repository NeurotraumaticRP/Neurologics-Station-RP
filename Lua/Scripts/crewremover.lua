if CLIENT then return end

Hook.Add("roundStart", "HideCrewList", function ()
    if Level.Loaded and Level.Loaded.IsLoadedFriendlyOutpost then
        return
    end
    
    for key, value in pairs(Character.CharacterList) do
        Networking.CreateEntityEvent(value, Character.RemoveFromCrewEventData.__new(value.TeamID, {}))
    end
end)

Hook.Add("character.death", "HideOnDeath", function (character)
    if character ~= nil and character.IsHuman and not character.IsBot then
        Networking.CreateEntityEvent(character, Character.RemoveFromCrewEventData.__new(character.TeamID, {}))
    end
end)

Hook.Add("character.created", "HideOnSpawn", function (character)
    if character ~= nil and character.IsHuman and not character.IsBot then
        Networking.CreateEntityEvent(character, Character.RemoveFromCrewEventData.__new(character.TeamID, {}))
    end
end)


Hook.Add("chatMessage", "crewmenu_chatcommands", function(msg, client)
    if msg == "!alive" then
        if client.Character == nil or client.Character.IsDead == true or client.HasPermission(ClientPermissions.ConsoleCommands) then

            local msg = ""
            for key, value in pairs(Character.CharacterList) do

                if value.IsHuman and not value.IsBot then
                    print(value.IsDead)
                    if value.IsDead then
                        msg = msg .. "[DEAD] " .. value.name .. "\n"
                    else
                        msg = msg .. "[ALIVE] " .. value.name .. "\n"
                    end
                end
            end

            Game.SendDirectChatMessage("", msg, nil, 7, client)
            Game.SendDirectChatMessage("", msg, nil, 1, client)

            return true
        end

    end
end)