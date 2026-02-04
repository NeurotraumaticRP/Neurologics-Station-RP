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


-- Scan for Team2 humans without controlling clients and add them as ghost roles
gr.ScanTeam2Humans = function()
    if not config.Enabled then return end
    if not config.Team2HumansEnabled then return end
    
    for _, character in pairs(Character.CharacterList) do
        -- Check if character is valid, alive, human, and on Team2
        if character and not character.IsDead and not character.Removed 
           and character.IsHuman 
           and character.TeamID == CharacterTeamType.Team2 then
            
            -- Check if already registered as a ghost role
            if not gr.Characters[character] then
                -- Check if any client is controlling this character
                local hasClient = false
                for _, client in pairs(Client.ClientList) do
                    if client.Character == character then
                        hasClient = true
                        break
                    end
                end
                
                -- If no client is controlling, add as ghost role
                if not hasClient then
                    local roleName = character.Name:lower()
                    
                    -- Make sure name is unique
                    local baseName = roleName
                    local counter = 1
                    while gr.Roles[roleName] do
                        roleName = baseName .. "_" .. counter
                        counter = counter + 1
                    end
                    
                    print("[GhostRoles] Adding Team2 human as ghost role: " .. roleName)
                    
                    gr.Roles[roleName] = {
                        Callback = function(client)
                            client.SetClientCharacter(character)
                            Neurologics.SendMessage(client, "You are now controlling " .. character.Name .. "!")
                        end,
                        Taken = false,
                        Character = character,
                        IsTeam2 = true,
                    }
                    gr.Characters[character] = roleName
                end
            end
        end
    end
end

-- Periodic scan for new Team2 humans
local team2ScanTimer = 0

Hook.Add("think", "Neurologics.GhostRoles.Think", function (...)
    if not config.Enabled then return end
    
    -- Periodically scan for Team2 humans
    if Timer.GetTime() >= team2ScanTimer then
        team2ScanTimer = Timer.GetTime() + (config.Team2ScanInterval or 10)
        gr.ScanTeam2Humans()
    end
    
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