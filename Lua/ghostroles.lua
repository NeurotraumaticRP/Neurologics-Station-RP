local gr = {}

local config = Neurologics.Config.GhostRoleConfig

local ghostRolesAnnounceTimer = 0

gr.Roles = {}
gr.Characters = {}

gr.Ask = function (name, callback, character)
    if not config.Enabled then return false end

    name = string.lower(name)
    gr.Roles[name] = {Callback = callback, Taken = false, Character = character}

    local text = Neurologics.Language.GhostRoleAvailable

    text = string.format(text, name, name)

    for key, client in pairs(Client.ClientList) do
        if client.Character == nil or client.Character.IsDead then
            local chatMessage = ChatMessage.Create("Ghost Roles", text, ChatMessageType.Default, nil, nil)
            chatMessage.Color = Color(255, 100, 10, 255)
            Game.SendDirectChatMessage(chatMessage, client)
        end
    end

    if character then
        gr.Characters[character] = name
    end

    ghostRolesAnnounceTimer = Timer.GetTime() + 80
end

gr.IsGhostRole = function (character)
    if character == nil then return false end

    if gr.Characters[character] and gr.Roles[gr.Characters[character]] then
        return true
    end

    return false
end

gr.ReturnGhostRole = function (character)
    if character == nil then return false end

    if gr.Characters[character] and gr.Roles[gr.Characters[character]] then
        gr.Roles[gr.Characters[character]].Taken = false

        return true
    end

    return false
end

Neurologics.AddCommand({"!ghostrole", "!ghostroles"}, function(client, args)
    if not config.Enabled then
        Neurologics.SendMessage(client, Neurologics.Language.GhostRolesDisabled)
        return true
    end

    if client.Character ~= nil and not client.Character.IsDead then
        Neurologics.SendMessage(client, Neurologics.Language.GhostRolesSpectator)
        return true
    end

    if not client.InGame then
        Neurologics.SendMessage(client, Neurologics.Language.GhostRolesInGame)
        return true
    end

    local name = table.concat(args, " ")
    name = string.lower(name)

    if gr.Roles[name] == nil then
        local roles = ""
        for key, value in pairs(gr.Roles) do
            if value.Character and value.Character.IsDead then
                roles = roles .. key .. Neurologics.Language.GhostRolesDead .. "\n"
            elseif value.Taken then
                roles = roles .. key .. Neurologics.Language.GhostRolesTaken .. "\n"
            else
                roles = roles .. key .. "\n"
            end
        end

        if roles == "" then roles = "None" end

        Neurologics.SendMessage(client, Neurologics.Language.GhostRolesNotFound .. roles)
        return true
    end

    if gr.Roles[name].Taken then
        Neurologics.SendMessage(client, Neurologics.Language.GhostRolesTook)
        return true
    end

    if gr.Roles[name].Character and gr.Roles[name].Character.IsDead then
        Neurologics.SendMessage(client, Neurologics.Language.GhostRolesAlreadyDead)
        return true
    end

    Neurologics.Log(Neurologics.ClientLogName(client) .. " took the ghost role of " .. name .. ".")

    Neurologics.MidRoundSpawn.SetSpawnedClient(client, true)
    gr.Roles[name].Callback(client)
    gr.Roles[name].Taken = true

    return true
end)


Hook.Add("think", "Neurologics.GhostRoles.Think", function (...)
    if not config.Enabled then return end
    if Timer.GetTime() < ghostRolesAnnounceTimer then return end
    ghostRolesAnnounceTimer = Timer.GetTime() + 200

    local roles = ""
    for key, value in pairs(gr.Roles) do
        if not value.Taken and (not value.Character or not value.Character.IsDead) then
            roles = roles .. "\"‖color:gui.orange‖" .. key .. "\"‖color:end‖ "
        end
    end

    if roles == "" then return end

    for key, client in pairs(Client.ClientList) do
        if client.Character == nil or client.Character.IsDead then
            local chatMessage = ChatMessage.Create("Ghost Roles", string.format(Neurologics.Language.GhostRolesReminder, roles), ChatMessageType.Default, nil, nil)
            chatMessage.Color = Color(255, 100, 10, 255)
            Game.SendDirectChatMessage(chatMessage, client)
        end
    end
end)

Hook.Add("roundEnd", "Neurologics.GhostRoles.RoundEnd", function ()
    gr.Roles = {}
    gr.Characters = {}
end)

return gr