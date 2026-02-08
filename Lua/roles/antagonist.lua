local role = Neurologics.RoleManager.Roles.Role:new()

role.Name = "Antagonist"
role.IsAntagonist = true

-- Mudraptor species to affliction mapping for traitor chat eligibility
local mudraptorAfflictions = {
    ["mudraptor"] = "mudraptorgrowth",
    ["mudraptor_hatchling"] = "mudraptorgrowthhatchling",
    ["mudraptor_veteran"] = "mudraptorgrowthveteran"
}

-- Mudraptor broadcast format (different from traitor)
local mudraptorBroadcastFormat = "[Mudraptor %s]: %s"

-- Check if a character is an eligible mudraptor (has the growth affliction > 1)
local function isEligibleMudraptor(character)
    if not character then return false end
    local speciesName = tostring(character.SpeciesName):lower()
    local afflictionId = mudraptorAfflictions[speciesName]
    if afflictionId and HF.HasAffliction(character, afflictionId, 1) then
        return true
    end
    return false
end

-- Check if a character can use traitor chat (either has TraitorBroadcast role or is eligible mudraptor)
local function canUseTraitorChat(character)
    local charRole = Neurologics.RoleManager.GetRole(character)
    if charRole and charRole.TraitorBroadcast then
        return true, charRole
    end
    if isEligibleMudraptor(character) then
        return true, nil
    end
    return false, nil
end

-- Get the appropriate broadcast format based on sender type
local function getBroadcastFormat(character)
    if isEligibleMudraptor(character) then
        return mudraptorBroadcastFormat
    end
    return Neurologics.Language.TraitorBroadcast
end

Neurologics.AddCommand("!tc", function(client, args)
    local feedback = Neurologics.Language.CommandNotActive

    local character = client.Character
    if not character or character.IsDead then
        Game.SendDirectChatMessage("", Neurologics.Language.NoTraitor, nil, Neurologics.Config.ChatMessageType, client)
        return true
    end

    local canUse, clientRole = canUseTraitorChat(character)

    if not canUse then
        feedback = Neurologics.Language.CommandNotActive
    elseif #args > 0 then
        local msg = ""
        for word in args do
            msg = msg .. " " .. word
        end

        -- Get the appropriate format based on sender type
        local broadcastFormat = getBroadcastFormat(character)

        -- Send to all characters who can receive traitor chat
        for roundCharacter, roundRole in pairs(Neurologics.RoleManager.RoundRoles) do
            if roundRole.TraitorBroadcast or isEligibleMudraptor(roundCharacter) then
                local targetClient = Neurologics.FindClientCharacter(roundCharacter)

                if targetClient then
                    Game.SendDirectChatMessage("",
                        string.format(broadcastFormat, Neurologics.ClientLogName(client), msg), nil,
                        ChatMessageType.Error, targetClient)
                end
            end
        end

        -- Also send to eligible mudraptors not in RoundRoles
        for _, checkChar in pairs(Character.CharacterList) do
            if checkChar and not checkChar.IsDead and not checkChar.Removed then
                if isEligibleMudraptor(checkChar) and not Neurologics.RoleManager.RoundRoles[checkChar] then
                    local targetClient = Neurologics.FindClientCharacter(checkChar)
                    if targetClient then
                        Game.SendDirectChatMessage("",
                            string.format(broadcastFormat, Neurologics.ClientLogName(client), msg), nil,
                            ChatMessageType.Error, targetClient)
                    end
                end
            end
        end

        local shouldHide = clientRole and not clientRole.TraitorBroadcastHearable or true
        return shouldHide
    else
        feedback = "Usage: !tc [Message]"
    end

    Game.SendDirectChatMessage("", feedback, nil, Neurologics.Config.ChatMessageType, client)

    return true
end)

Neurologics.AddCommand({"!tannounce", "!ta"}, function(client, args)
    local feedback = Neurologics.Language.CommandNotActive

    local character = client.Character
    if not character or character.IsDead then
        Game.SendDirectChatMessage("", Neurologics.Language.NoTraitor, nil, Neurologics.Config.ChatMessageType, client)
        return true
    end

    local canUse, clientRole = canUseTraitorChat(character)

    if not canUse then
        feedback = Neurologics.Language.CommandNotActive
    elseif #args > 0 then
        local msg = ""
        for word in args do
            msg = msg .. " " .. word
        end

        -- Get the appropriate format based on sender type
        local broadcastFormat = getBroadcastFormat(character)

        -- Send to all characters who can receive traitor chat
        for roundCharacter, roundRole in pairs(Neurologics.RoleManager.RoundRoles) do
            if roundRole.TraitorBroadcast or isEligibleMudraptor(roundCharacter) then
                local targetClient = Neurologics.FindClientCharacter(roundCharacter)

                if targetClient then
                    Game.SendDirectChatMessage("",
                        string.format(broadcastFormat, client.Name, msg), nil,
                        ChatMessageType.ServerMessageBoxInGame, targetClient)
                end
            end
        end

        -- Also send to eligible mudraptors not in RoundRoles
        for _, checkChar in pairs(Character.CharacterList) do
            if checkChar and not checkChar.IsDead and not checkChar.Removed then
                if isEligibleMudraptor(checkChar) and not Neurologics.RoleManager.RoundRoles[checkChar] then
                    local targetClient = Neurologics.FindClientCharacter(checkChar)
                    if targetClient then
                        Game.SendDirectChatMessage("",
                            string.format(broadcastFormat, client.Name, msg), nil,
                            ChatMessageType.ServerMessageBoxInGame, targetClient)
                    end
                end
            end
        end

        local shouldHide = clientRole and not clientRole.TraitorBroadcastHearable or true
        return shouldHide
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

---@return string objectives
function role:ObjectivesToString()
    local objs = Neurologics.StringBuilder:new()

    for _, objective in pairs(self.Objectives) do
        if objective:IsCompleted() then
            objs:append(" > ", objective.Text, Neurologics.Language.Completed)
        else
            objs:append(" > ", objective.Text, string.format(Neurologics.Language.Points, objective.AmountPoints))
        end
    end

    return objs:concat("\n")
end

function role:Greet()
    local objectives = self:ObjectivesToString()

    local sb = Neurologics.StringBuilder:new()
    sb(Neurologics.Language.AntagonistYou)
    sb(objectives)

    return sb:concat()
end

function role:FilterTarget(objective, character)
    local targetRole = Neurologics.RoleManager.GetRole(character)
    if targetRole and targetRole.IsAntagonist then
        return false
    end

    return Neurologics.RoleManager.Roles.Role.FilterTarget(self, objective, character)
end


return role
