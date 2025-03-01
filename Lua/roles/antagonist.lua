local role = Neurologics.RoleManager.Roles.Role:new()

role.Name = "Antagonist"
role.IsAntagonist = true

Neurologics.AddCommand("!tc", function(client, args)
    local feedback = Neurologics.Language.CommandNotActive

    local clientRole = Neurologics.RoleManager.GetRole(client.Character)

    if clientRole == nil or client.Character.IsDead then
        feedback = Neurologics.Language.NoTraitor
    elseif not clientRole.TraitorBroadcast then
        feedback = Neurologics.Language.CommandNotActive
    elseif #args > 0 then
        local msg = ""
        for word in args do
            msg = msg .. " " .. word
        end

        for character, role in pairs(Neurologics.RoleManager.RoundRoles) do
            if role.TraitorBroadcast then
                local targetClient = Neurologics.FindClientCharacter(character)

                if targetClient then
                    Game.SendDirectChatMessage("",
                        string.format(Neurologics.Language.TraitorBroadcast, Neurologics.ClientLogName(client), msg), nil,
                        ChatMessageType.Error, targetClient)
                end
            end
        end

        return not clientRole.TraitorBroadcastHearable
    else
        feedback = "Usage: !tc [Message]"
    end

    Game.SendDirectChatMessage("", feedback, nil, Neurologics.Config.ChatMessageType, client)

    return true
end)

Neurologics.AddCommand({"!tannounce", "!ta"}, function(client, args)
    local feedback = Neurologics.Language.CommandNotActive

    local clientRole = Neurologics.RoleManager.GetRole(client.Character)

    if clientRole == nil or client.Character.IsDead then
        feedback = Neurologics.Language.NoTraitor
    elseif not clientRole.TraitorBroadcast then
        feedback = Neurologics.Language.CommandNotActive
    elseif #args > 0 then
        local msg = ""
        for word in args do
            msg = msg .. " " .. word
        end

        for character, role in pairs(Neurologics.RoleManager.RoundRoles) do
            if role.TraitorBroadcast then
                local targetClient = Neurologics.FindClientCharacter(character)

                if targetClient then
                    Game.SendDirectChatMessage("",
                        string.format(Neurologics.Language.TraitorBroadcast, client.Name, msg), nil,
                        ChatMessageType.ServerMessageBoxInGame, targetClient)
                end
            end
        end

        return not clientRole.TraitorBroadcastHearable
    else
        feedback = "Usage: !tannounce [Message]"
    end

    Game.SendDirectChatMessage("", feedback, nil, Neurologics.Config.ChatMessageType, client)

    return true
end)

Neurologics.AddCommand("!tdm", function(client, args)
    local feedback = ""

    local clientRole = Neurologics.RoleManager.GetRole(client.Character)

    if clientRole == nil or client.Character.IsDead then
        feedback = Neurologics.Language.NoTraitor
    elseif not clientRole.TraitorDm then
        feedback = Neurologics.Language.CommandNotActive
    else
        if #args > 1 then
            local found = Neurologics.FindClient(table.remove(args, 1))
            local msg = ""
            for word in args do
                msg = msg .. " " .. word
            end
            if found then
                Neurologics.SendMessage(found, Neurologics.Language.TraitorDirectMessage .. msg)
                feedback = string.format("[To %s]: %s", Neurologics.ClientLogName(found), msg)
                return true
            else
                feedback = "Name not found."
            end
        else
            feedback = "Usage: !tdm [Name] [Message]"
        end
    end

    Game.SendDirectChatMessage("", feedback, nil, Neurologics.Config.ChatMessageType, client)
    return true
end)

function role:FilterTarget(objective, character)
    local targetRole = Neurologics.RoleManager.GetRole(character)
    if targetRole and targetRole.IsAntagonist then
        return false
    end

    return Neurologics.RoleManager.Roles.Role.FilterTarget(self, objective, character)
end


return role
