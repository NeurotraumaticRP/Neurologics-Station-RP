----- USER COMMANDS -----
Neurologics.AddCommand("!help", function (client, args)
    Neurologics.SendMessage(client, Neurologics.Language.Help)

    return true
end)

Neurologics.AddCommand("!helpadmin", function (client, args)
    Neurologics.SendMessage(client, Neurologics.Language.HelpAdmin)

    return true
end)

Neurologics.AddCommand("!helptraitor", function (client, args)
    Neurologics.SendMessage(client, Neurologics.Language.HelpTraitor)

    return true
end)

Neurologics.AddCommand("!version", function (client, args)
    Neurologics.SendMessage(client, "Running Evil Factory's Traitor Mod v" .. Neurologics.VERSION)

    return true
end)

Neurologics.AddCommand({"!role", "!traitor"}, function (client, args)
    if client.Character == nil or client.Character.IsDead then
        Neurologics.SendMessage(client, Neurologics.Language.CMDAliveToUse)
        return true
    end

    local role = Neurologics.RoleManager.GetRole(client.Character)
    if role == nil then
        Neurologics.SendMessage(client, Neurologics.Language.CMDNoRole)
    else
        Neurologics.SendMessage(client, role:Greet())
    end

    return true
end)

Neurologics.AddCommand({"!roles", "!traitors"}, function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    local roles = {}

    for character, role in pairs(Neurologics.RoleManager.RoundRoles) do
        if not roles[role.Name] then
            roles[role.Name] = {}
        end

        table.insert(roles[role.Name], character.Name)
    end

    local message = ""

    for roleName, r in pairs(roles) do
        message = message .. roleName .. ": "
        for _, name in pairs(r) do
            message = message .. "\"" .. name .. "\" "
        end
        message = message .. "\n\n"
    end

    if message == "" then message = "None." end

    Neurologics.SendMessage(client, message)

    return true
end)

Neurologics.AddCommand("!traitoralive", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    for _, character in pairs(Neurologics.RoleManager.FindAntagonists()) do
        if not character.IsDead then
            Neurologics.SendMessage(client, Neurologics.Language.TraitorsAlive)
            return true
        end
    end

    Neurologics.SendMessage(client, Neurologics.Language.AllTraitorsDead)
    return true
end)

Neurologics.AddCommand("!toggletraitor", function (client, args)
    local text = Neurologics.Language.CommandNotActive

    if Neurologics.Config.OptionalTraitors then
        local toggle = false
        if #args > 0 then
            toggle = string.lower(args[1]) == "on"
        else
            toggle = Neurologics.GetData(client, "NonTraitor") == true
        end
    
        if toggle then
            text = Neurologics.Language.TraitorOn
        else
            text = Neurologics.Language.TraitorOff
        end
        Neurologics.SetData(client, "NonTraitor", not toggle)
        Neurologics.SaveData() -- move this to player disconnect someday...
        
        Neurologics.Log(Neurologics.ClientLogName(client) .. " can become traitor: " .. tostring(toggle))
    end

    Neurologics.SendMessage(client, text)

    return true
end)

Neurologics.AddCommand({"!point", "!points"}, function (client, args)
    Neurologics.SendMessage(client, Neurologics.GetDataInfo(client, true))

    return true
end)

Neurologics.AddCommand("!info", function (client, args)
    Neurologics.SendWelcome(client)
    
    return true
end)

Neurologics.AddCommand({"!suicide", "!kill", "!death"}, function (client, args)
    if client.Character == nil or client.Character.IsDead then
        Neurologics.SendMessage(client, Neurologics.Language.CMDAlreadyDead)
        return true
    end

    if client.Character.IsHuman then
        local item = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
        if item ~= nil and item.Prefab.Identifier == "handcuffs" then
            Neurologics.SendMessage(client, Neurologics.Language.CMDHandcuffed)
            return true
        end

        if client.Character.IsKnockedDown then
            Neurologics.SendMessage(client, Neurologics.Language.CMDKnockedDown)
            return true
        end
    end

    if Neurologics.GhostRoles.ReturnGhostRole(client.Character) then
        client.SetClientCharacter(nil)
    else
        client.Character.Kill(CauseOfDeathType.Unknown)
    end
    return true
end)

----- ADMIN COMMANDS -----
Neurologics.AddCommand("!alive", function (client, args)
    if not (client.Character == nil or client.Character.IsDead) and not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    if not Game.RoundStarted or Neurologics.SelectedGamemode == nil then
        Neurologics.SendMessage(client, Neurologics.Language.RoundNotStarted)

        return true
    end

    local msg = ""
    for index, value in pairs(Character.CharacterList) do
        if value.IsHuman and not value.IsBot then
            if value.IsDead then
                msg = msg .. value.Name .. " ---- " .. Neurologics.Language.Dead .. "\n"
            else
                msg = msg .. value.Name .. " ++++ " .. Neurologics.Language.Alive .. "\n"
            end
        end
    end

    Neurologics.SendMessage(client, msg)

    return true
end)

Neurologics.AddCommand("!roundinfo", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    if Game.RoundStarted and Neurologics.SelectedGamemode and Neurologics.SelectedGamemode.RoundSummary then
        local summary = Neurologics.SelectedGamemode:RoundSummary()
        Neurologics.SendMessage(client, summary)
    elseif Game.RoundStarted and not Neurologics.SelectedGamemode then
        Neurologics.SendMessage(client, Neurologics.Language.GamemodeNone)
    elseif Neurologics.LastRoundSummary ~= nil then
        Neurologics.SendMessage(client, Neurologics.LastRoundSummary)
    else
        Neurologics.SendMessage(client, Neurologics.Language.RoundNotStarted)
    end

    return true
end)

Neurologics.AddCommand({"!allpoint", "!allpoints"}, function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    local messageToSend = ""

    for index, value in pairs(Client.ClientList) do
        messageToSend = messageToSend .. "\n" .. value.Name .. ": " .. math.floor(Neurologics.GetData(value, "Points") or 0) .. " Points - " .. math.floor(Neurologics.GetData(value, "Weight") or 0) .. " Weight"
    end

    Neurologics.SendMessage(client, messageToSend)

    return true
end)

Neurologics.AddCommand({"!addpoint", "!addpoints"}, function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then
        Neurologics.SendMessage(client, Neurologics.Language.CMDPermisionPoints)
        return
    end
    
    if #args < 2 then
        Neurologics.SendMessage(client, "Incorrect amount of arguments. usage: !addpoint \"Client Name\" 500")

        return true
    end

    local name = table.remove(args, 1)
    local amount = tonumber(table.remove(args, 1))

    if amount == nil or amount ~= amount then
        Neurologics.SendMessage(client, Neurologics.Language.CMDInvalidNumber)
        return true
    end

    if name == "all" then
        for index, value in pairs(Client.ClientList) do
            Neurologics.AddData(value, "Points", amount)
        end

        Neurologics.SendMessage(client, string.format(Neurologics.Language.PointsAwarded, amount), "InfoFrameTabButton.Mission")

        local msg = string.format(Neurologics.Language.CMDAdminAddedPointsEveryone, amount)
        Neurologics.SendMessageEveryone(msg)
        msg = Neurologics.ClientLogName(client) .. ": " .. msg
        Neurologics.Log(msg)

        return true
    end

    local found = Neurologics.FindClient(name)

    if found == nil then
        Neurologics.SendMessage(client, Neurologics.Language.CMDClientNotFound .. name)
        return true
    end

    Neurologics.AddData(found, "Points", amount)

    Neurologics.SendMessage(client, string.format(Neurologics.Language.PointsAwarded, amount), "InfoFrameTabButton.Mission")

    local msg = string.format(Neurologics.Language.CMDAdminAddedPoints, amount, Neurologics.ClientLogName(found))
    Neurologics.SendMessageEveryone(msg)
    msg = Neurologics.ClientLogName(client) .. ": " .. msg
    Neurologics.Log(msg)

    return true
end)

Neurologics.AddCommand({"!addlife", "!addlive", "!addlifes", "!addlives"}, function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    if #args < 1 then
        Neurologics.SendMessage(client, "Incorrect amount of arguments. usage: !addlife \"Client Name\" 1")

        return true
    end

    local name = table.remove(args, 1)

    local amount = 1
    if #args > 0 then
        amount = tonumber(table.remove(args, 1))
    end

    if amount == nil or amount ~= amount then
        Neurologics.SendMessage(client, Neurologics.Language.CMDInvalidNumber)
        return true
    end

    local gainLifeClients = {}
    if string.lower(name) == "all" then
        gainLifeClients = Client.ClientList
    else
        local found = Neurologics.FindClient(name)

        if found == nil then
            Neurologics.SendMessage(client, Neurologics.Language.CMDClientNotFound .. name)
            return true
        end
        table.insert(gainLifeClients, found)
    end

    for lifeClient in gainLifeClients do
        local lifeMsg, lifeIcon = Neurologics.AdjustLives(lifeClient, amount)
        local msg = string.format(Neurologics.Language.CMDAdminAddedLives, amount, Neurologics.ClientLogName(lifeClient))

        if lifeMsg then
            Neurologics.SendMessage(lifeClient, lifeMsg, lifeIcon)
            Neurologics.SendMessageEveryone(msg)
        else
            Game.SendDirectChatMessage("", Neurologics.ClientLogName(lifeClient) .. " already has maximum lives.", nil, Neurologics.Config.Error, client)
        end
    end

    return true
end)

local voidPos = {}

Neurologics.AddCommand("!void", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    local target = Neurologics.FindClient(args[1])

    if not target then
        Neurologics.SendMessage(client, Neurologics.Language.CMDClientNotFound)
        return true
    end

    if target.Character == nil or target.Character.IsDead then
        Neurologics.SendMessage(client, "Client's character is dead or non-existent.")
        return true
    end

    voidPos[target.Character] = target.Character.WorldPosition
    target.Character.TeleportTo(Vector2(0, Level.Loaded.Size.Y + 100000))
    target.Character.GodMode = true

    Neurologics.SendMessage(client, "Sent the character to the void.")

    return true
end)

Neurologics.AddCommand("!unvoid", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    local target = Neurologics.FindClient(args[1])

    if not target then
        Neurologics.SendMessage(client, Neurologics.Language.CMDClientNotFound)
        return true
    end

    if target.Character == nil or target.Character.IsDead then
        Neurologics.SendMessage(client, "Client's character is dead or non-existent.")
        return true
    end

    target.Character.TeleportTo(voidPos[target.Character])
    target.Character.GodMode = false
    voidPos[target.Character] = nil
    
    Neurologics.SendMessage(client, "Remove character from the void.")

    return true
end)

Neurologics.AddCommand("!revive", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    local reviveClient = client

    if #args > 0 then
        -- if client name is given, revive related character
        local name = table.remove(args, 1)
        -- find character by client name
        for key, player in pairs(Client.ClientList) do
            if player.Name == name or player.SteamID == name then
                reviveClient = player
            end
        end
    end

    if reviveClient.Character and reviveClient.Character.IsDead then
        reviveClient.Character.Revive()
        Timer.Wait(function ()
            reviveClient.SetClientCharacter(reviveClient.Character)
        end, 1500)
        local liveMsg, liveIcon = Neurologics.AdjustLives(reviveClient, 1)

        if liveMsg then
            Neurologics.SendMessage(reviveClient, liveMsg, liveIcon)
        end

        Game.SendDirectChatMessage("", "Character of " .. Neurologics.ClientLogName(reviveClient) .. " revived and given back 1 life.", nil, ChatMessageType.Error, client)
        Neurologics.SendMessageEveryone(string.format("Admin revived %s", Neurologics.ClientLogName(reviveClient)))

    elseif reviveClient.Character then
        Game.SendDirectChatMessage("", "Character of " .. Neurologics.ClientLogName(reviveClient) .. " is not dead.", nil, ChatMessageType.Error, client)
    else
        Game.SendDirectChatMessage("", "Character of " .. Neurologics.ClientLogName(reviveClient) .. " not found.", nil, ChatMessageType.Error, client)
    end

    return true
end)

Neurologics.AddCommand("!ongoingevents", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    local text = "On Going Events: "
    for key, value in pairs(Neurologics.RoundEvents.OnGoingEvents) do
        text = text .. "\"" .. value.Name .. "\" "
    end

    Neurologics.SendMessage(client, text)

    return true
end)

Neurologics.AddCommand("!giveghostrole", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    if #args < 2 then
        Neurologics.SendMessage(client, "Usage: !giveghostrole <ghost role name> <character>")
        return true
    end

    local target

    for key, value in pairs(Character.CharacterList) do
        if value.Name == args[2] and not value.IsDead then
            target = value
            break
        end
    end

    if not target then
        Neurologics.SendMessage(client, Neurologics.Language.CMDCharacterNotFound)
        return true
    end

    Neurologics.GhostRoles.Ask(args[1], function (ghostClient)
        Neurologics.LostLivesThisRound[ghostClient.SteamID] = false

        ghostClient.SetClientCharacter(target)
    end, target)

    return true
end)

Neurologics.AddCommand("!roundtime", function (client, args)
    Neurologics.SendMessage(client, string.format(Neurologics.Language.CMDRoundTime, Neurologics.FormatTime(math.ceil(Neurologics.RoundTime))))

    return true
end)

Neurologics.AddCommand("!assignrolecharacter", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if #args < 2 then
        Neurologics.SendMessage(client, "Usage: !assignrole <character> <role>")
        return true
    end

    local target

    for key, value in pairs(Character.CharacterList) do
        if value.Name == args[1] then
            target = value
            break
        end
    end

    if not target then
        Neurologics.SendMessage(client, Neurologics.Language.CMDCharacterNotFound)
        return true
    end

    if target == nil or target.IsDead then
        Neurologics.SendMessage(client, "Client's character is dead or non-existent.")
        return true
    end

    local role = Neurologics.RoleManager.Roles[args[2]]

    if role == nil then
        Neurologics.SendMessage(client, "Couldn't find role to assign.")
        return true
    end

    if Neurologics.RoleManager.GetRole(target) ~= nil then
        Neurologics.RoleManager.RemoveRole(target)
    end
    Neurologics.RoleManager.AssignRole(target, role:new())

    Neurologics.SendMessage(client, "Assigned " .. target.Name .. " the role " .. role.Name .. ".")

    return true
end)

Neurologics.AddCommand("!assignrole", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if #args < 2 then
        Neurologics.SendMessage(client, "Usage: !assignrole <client> <role>")
        return true
    end

    local target = Neurologics.FindClient(args[1])

    if not target then
        Neurologics.SendMessage(client, Neurologics.Language.CMDClientNotFound)
        return true
    end

    if target.Character == nil or target.Character.IsDead then
        Neurologics.SendMessage(client, "Client's character is dead or non-existent.")
        return true
    end

    local role = Neurologics.RoleManager.Roles[args[2]]

    if role == nil then
        Neurologics.SendMessage(client, "Couldn't find role to assign.")
        return true
    end

    local targetCharacter = target.Character

    if Neurologics.RoleManager.GetRole(targetCharacter) ~= nil then
        Neurologics.RoleManager.RemoveRole(targetCharacter)
    end
    Neurologics.RoleManager.AssignRole(targetCharacter, role:new())

    Neurologics.SendMessage(client, "Assigned " .. target.Name .. " the role " .. role.Name .. ".")

    return true
end)

Neurologics.AddCommand("!triggerevent", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    if #args < 1 then
        Neurologics.SendMessage(client, "Usage: !triggerevent <event name> [parameters...]")
        return true
    end

    local eventName = table.remove(args, 1)
    
    local event = nil
    for _, value in pairs(Neurologics.RoundEvents.EventConfigs.Events) do
        if value.Name == eventName then
            event = value
        end
    end

    if event == nil then
        Neurologics.SendMessage(client, "Event " .. eventName .. " doesnt exist.")
        return true
    end

    -- Parse parameters - convert numeric strings to numbers
    local params = {}
    for _, arg in ipairs(args) do
        local num = tonumber(arg)
        if num ~= nil then
            table.insert(params, num)
        else
            table.insert(params, arg)
        end
    end

    -- Trigger event with parameters
    local success, result = Neurologics.RoundEvents.TriggerEvent(event.Name, table.unpack(params))
    
    if success then
        local paramStr = ""
        if #params > 0 then
            paramStr = " with parameters: " .. table.concat(args, ", ")
        end
        Neurologics.SendMessage(client, "Triggered event " .. event.Name .. paramStr)
    else
        local errorMsg = "Failed to trigger event " .. event.Name .. ": " .. tostring(result)
        
        -- Check if event has parameter documentation
        if event.Parameters then
            errorMsg = errorMsg .. "\nUsage: !triggerevent " .. event.Name .. " " .. event.Parameters
        elseif #params > 0 then
            errorMsg = errorMsg .. "\nNote: This event may not accept parameters."
        end
        
        Neurologics.SendMessage(client, errorMsg)
    end

    return true
end)

Neurologics.AddCommand({"!locatesub", "!locatesubmarine"}, function (client, args)
    if client.Character == nil or not client.InGame then
        Neurologics.SendMessage(client, Neurologics.Language.CMDAliveToUse)
        return true
    end

    if client.Character.IsHuman and client.Character.TeamID == CharacterTeamType.Team1 then
        Neurologics.SendMessage(client, Neurologics.Language.CMDOnlyMonsters)
        return true
    end

    local center = client.Character.WorldPosition
    local target = Submarine.MainSub.WorldPosition

    local distance = Vector2.Distance(center, target) * Physics.DisplayToRealWorldRatio

    local diff = center - target

    local angle = math.deg(math.atan2(diff.X, diff.Y)) + 180

    local function degreeToOClock(v)
        local oClock = math.floor(v / 30)
        if oClock == 0 then oClock = 12 end
        return oClock .. " o'clock"
    end

    Game.SendDirectChatMessage("", string.format(Neurologics.Language.CMDLocateSub, math.floor(distance), degreeToOClock(angle)), nil, ChatMessageType.Error, client)

    return true
end)


Neurologics.AddCommand({"!monster", "!m"}, function (client, args)
    if client.Character == nil or client.Character.IsHuman then
        Neurologics.SendMessage(client, Neurologics.Language.CMDOnlyMonsters)
        return true
    end

    if #args < 1 then
        Neurologics.SendMessage(client, "Usage: !monster message")
        return true
    end

    local msg = ""
    for word in args do
        msg = msg .. " " .. word
    end

    for _, targetClient in pairs(Client.ClientList) do
        if (not targetClient.Character or targetClient.Character.IsDead) or not targetClient.Character.IsHuman then
            Game.SendDirectChatMessage("",
                string.format(Neurologics.Language.CMDMonsterBroadcast, client.Character.Name, Neurologics.ClientLogName(client), msg), nil,
                ChatMessageType.Error, targetClient)
        end
    end

    return true
end)

Neurologics.AddCommand("!giveobjective", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if client.Character == nil or client.Character.IsDead then
        Neurologics.SendMessage(client, "You must be alive to use this command.")
        return true
    end
    
    if #args < 1 then
        Neurologics.SendMessage(client, "Usage: !giveobjective <objective_name>")
        return true
    end
    
    local objectiveName = args[1]
    
    -- Find the objective
    local objectiveTemplate = Neurologics.RoleManager.FindObjective(objectiveName)
    
    if not objectiveTemplate then
        Neurologics.SendMessage(client, "Objective '" .. objectiveName .. "' not found.")
        
        -- List available objectives
        local availableObjectives = {}
        for name, _ in pairs(Neurologics.RoleManager.Objectives) do
            table.insert(availableObjectives, name)
        end
        table.sort(availableObjectives)
        
        local objectiveList = table.concat(availableObjectives, ", ")
        Neurologics.SendMessage(client, "Available objectives: " .. objectiveList)
        return true
    end
    
    -- Get or create role for character
    local role = Neurologics.RoleManager.GetRole(client.Character)
    
    if not role then
        -- If character has no role, create a basic crew role
        role = Neurologics.RoleManager.Roles.Crew:new()
        Neurologics.RoleManager.AssignRole(client.Character, role)
        Neurologics.SendMessage(client, "Created basic crew role for you.")
    end
    
    -- Create new instance of objective
    local objective = objectiveTemplate:new()
    objective:Init(client.Character)
    
    -- Try to find a valid target if needed
    local target = nil
    if role.FindValidTarget then
        target = role:FindValidTarget(objective)
    end
    
    -- Start the objective
    local success = objective:Start(target)
    
    if success then
        role:AssignObjective(objective)
        Neurologics.SendMessage(client, "Objective '" .. objectiveName .. "' assigned: " .. objective.Text, "InfoFrameTabButton.Mission")
    else
        Neurologics.SendMessage(client, "Failed to start objective '" .. objectiveName .. "'. It may require specific conditions or a valid target.")
    end
    
    return true
end)

Neurologics.AddCommand("!forceassignroles", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if not Game.RoundStarted then
        Neurologics.SendMessage(client, "Round must be started to assign roles.")
        return true
    end
    
    local assignedCount = 0
    
    -- Assign Crew role to all players without a role
    for key, value in pairs(Client.ClientList) do
        if value.Character ~= nil and value.Character.IsHuman and not value.SpectateOnly and not value.Character.IsDead and value.Character.TeamID == CharacterTeamType.Team1 then
            local role = Neurologics.RoleManager.GetRole(value.Character)
            if role == nil then
                role = Neurologics.RoleManager.Roles["Crew"]
                Neurologics.RoleManager.AssignRole(value.Character, role:new())
                assignedCount = assignedCount + 1
                Neurologics.SendMessage(value, "You have been assigned the Crew role with objectives.", "InfoFrameTabButton.Mission")
            end
        end
    end
    
    if assignedCount > 0 then
        Neurologics.SendMessage(client, "Assigned Crew role to " .. assignedCount .. " player(s).")
    else
        Neurologics.SendMessage(client, "All players already have roles assigned.")
    end
    
    return true
end)

Neurologics.AddCommand("!debugobjectives", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if client.Character == nil then
        Neurologics.SendMessage(client, "You must have a character to use this command.")
        return true
    end
    
    local jobId = client.Character.Info.Job.Prefab.Identifier.Value
    local role = Neurologics.RoleManager.GetRole(client.Character)
    local roleId = role and role.Name or "None"
    
    local message = string.format("Your Job: %s\nYour Role: %s\n\nAvailable Objectives:\n", jobId, roleId)
    
    local availableObjectives = Neurologics.RoleManager.GetObjectivesForCharacter(client.Character, role)
    
    if #availableObjectives == 0 then
        message = message .. "NONE - No objectives match your job/role!\n\nAll Objectives:\n"
        
        -- List all objectives and their requirements
        for name, objective in pairs(Neurologics.RoleManager.Objectives) do
            local jobReq = "None (not auto-assigned)"
            local roleReq = "None (not auto-assigned)"
            
            if objective.Job == true then
                jobReq = "ALL"
            elseif objective.Job then
                if type(objective.Job) == "table" then
                    jobReq = table.concat(objective.Job, ", ")
                else
                    jobReq = objective.Job
                end
            end
            
            if objective.Role == true then
                roleReq = "ALL"
            elseif objective.Role then
                if type(objective.Role) == "table" then
                    roleReq = table.concat(objective.Role, ", ")
                else
                    roleReq = objective.Role
                end
            end
            
            message = message .. string.format("- %s (Job: %s, Role: %s)\n", name, jobReq, roleReq)
        end
    else
        for _, objName in ipairs(availableObjectives) do
            message = message .. "- " .. objName .. "\n"
        end
    end
    
    Neurologics.SendMessage(client, message)
    
    return true
end)

Neurologics.AddCommand("!forceselecttraitors", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if not Game.RoundStarted then
        Neurologics.SendMessage(client, "Round must be started to select traitors.")
        return true
    end
    
    if not Neurologics.SelectedGamemode or Neurologics.SelectedGamemode.Name ~= "Secret" then
        Neurologics.SendMessage(client, "This command only works in Secret gamemode.")
        return true
    end
    
    -- Check if roles have already been assigned
    local hasRoles = false
    for character, role in pairs(Neurologics.RoleManager.RoundRoles) do
        hasRoles = true
        break
    end
    
    if hasRoles then
        Neurologics.SendMessage(client, "Roles have already been assigned this round.")
        return true
    end
    
    -- Trigger the antagonist selection immediately
    Neurologics.SelectedGamemode:SelectAntagonists()
    Neurologics.SendMessage(client, "Traitor selection triggered immediately (bypassing delay).")
    
    return true
end)

Neurologics.AddCommand("!spawntest", function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if client.Character == nil then
        Neurologics.SendMessage(client, "You must have a character to use this command.")
        return true
    end
    
    if #args < 1 then
        Neurologics.SendMessage(client, "Usage: !spawntest <testname>")
        Neurologics.SendMessage(client, "Available tests: superhuman, burnvictim, wounded, crawler, crawlerobjective")
        return true
    end
    
    local testName = args[1]
    local pos = client.Character.WorldPosition
    
    if testName == "superhuman" then
        local char = NCS.SpawnCharacter("superhuman", pos, CharacterTeamType.Team1, nil)
        Neurologics.SendMessage(client, "Spawned superhuman with maxed skills and talents")
        
    elseif testName == "burnvictim" then
        local char = NCS.SpawnCharacter("burnvictim", pos, CharacterTeamType.Team1, nil)
        Neurologics.SendMessage(client, "Spawned burn victim with permanent burn and pain afflictions")
        
    elseif testName == "wounded" then
        local char = NCS.SpawnCharacter("wounded", pos, CharacterTeamType.Team1, nil)
        Neurologics.SendMessage(client, "Spawned wounded survivor with one-time afflictions (bloodloss, gunshot)")
        
    elseif testName == "crawler" then
        local char = NCS.SpawnCharacter("testcrawler", pos, CharacterTeamType.Team2, nil)
        Neurologics.SendMessage(client, "Spawned test crawler (no objectives)")
        
    elseif testName == "crawlerobjective" then
        local char = NCS.SpawnCharacter("testcrawler", pos, CharacterTeamType.Team2, {"KillMonsters"})
        Neurologics.SendMessage(client, "Spawned test crawler with KillMonsters objective")
        
    else
        Neurologics.SendMessage(client, "Unknown test: " .. testName)
        Neurologics.SendMessage(client, "Available tests: superhuman, burnvictim, wounded, crawler, crawlerobjective")
    end
    
    return true
end)

local preventSpam = {}
Neurologics.AddCommand({"!droppoints", "!droppoint", "!dropoint", "!dropoints"}, function (client, args)
    if preventSpam[client] ~= nil and Timer.GetTime() < preventSpam[client] then
        Neurologics.SendMessage(client, "Please wait a bit before using this command again.")
        return true
    end

    if client.Character == nil or client.Character.IsDead or client.Character.Inventory == nil then
        Neurologics.SendMessage(client, Neurologics.Language.CMDAliveToUse)
        return true
    end

    if #args < 1 then
        Neurologics.SendMessage(client, "Usage: !droppoints amount")
        return true
    end

    local amount = tonumber(args[1])

    if amount == nil or amount ~= amount or amount < 100 or amount > 100000 then
        Neurologics.SendMessage(client, "Please specify a valid number between 100 and 100000.")
        return true
    end

    local availablePoints = Neurologics.GetData(client, "Points") or 0

    if amount > availablePoints then
        Neurologics.SendMessage(client, "You don't have enough points to drop.")
        return true
    end

    Neurologics.SpawnPointItem(client.Character.Inventory, tonumber(amount))
    Neurologics.SetData(client, "Points", availablePoints - amount)

    preventSpam[client] = Timer.GetTime() + 5

    return true
end)

Neurologics.AddCommand({"!intercom"}, function (client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    if #args < 1 then
        Neurologics.SendMessage(client, "Incorrect amount of arguments. usage: !announce [msg] - If you need to announce something with more than one word, surround it in quotations.")
        return true
    end

    local text = table.remove(args, 1)

    Neurologics.RoundEvents.SendEventMessage(text, nil, Color.LightGreen)

    return true
end)

Neurologics.AddCommand({"!SpawnAs"}, function(client, args)
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end
    
    if #args < 1 then
        Neurologics.SendMessage(client, "Usage: !SpawnAs <character name>")
        return true
    end

    if client.Character == nil then
        Neurologics.SendMessage(client, "You must have a character to use this command.")
        return true
    end

    local characterName = args[1]
    local currentPos = client.Character.WorldPosition
    
    -- Store current character to remove after spawning new one
    local oldCharacter = client.Character
    
    local newCharacter = NCS.SpawnCharacter(characterName, currentPos, nil, nil)
    if not newCharacter then
        Neurologics.SendMessage(client, "Failed to spawn as " .. characterName .. ". Check logs for details.")
        return true
    end

    -- Set the new character as the client's character
    client.SetClientCharacter(newCharacter)
    
    -- Remove the old character
    if oldCharacter then
        Entity.Spawner.AddEntityToRemoveQueue(oldCharacter)
    end

    Neurologics.SendMessage(client, "Successfully spawned as " .. characterName)
    return true
end)

Neurologics.AddCommand({"!roleban", "!banrole", "!jobban", "!banjob"}, function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    if #args < 3 then
        Neurologics.SendMessage(sender, "Usage: !roleban \"name\" \"job1,job2,job3,jobN\" \"reason for banning\"")
        return true
    end

    local targetClientInput = table.remove(args, 1)
    local jobsString = table.remove(args, 1):lower()
    local reason = table.remove(args, 1)
    if #args > 0 then
        reason = reason .. " " .. table.concat(args, " ")
    end

    local jobList = Neurologics.JobManager.splitJobList(jobsString)

    local validJobs = Neurologics.JobManager.ValidJobs
    local validJobsSet = {}
    for _, job in ipairs(validJobs) do
        validJobsSet[job] = true
    end

    local invalidJobs = {}
    for _, job in ipairs(jobList) do
        if not validJobsSet[job] then
            table.insert(invalidJobs, job)
        end
    end

    if #invalidJobs > 0 then
        Neurologics.SendMessage(sender, "Invalid job/role(s) specified: " .. table.concat(invalidJobs, ", "))
        return true
    end

    local targetClient, steamID = Neurologics.GetTargetClient(sender, targetClientInput)
    if steamID == nil then return true end

    -- Use the JobManager.BanJobs function to ban the player from specified jobs
    local addedJobs = Neurologics.JobManager.BanJobs(steamID, jobList, reason, sender, targetClient)
    
    if #addedJobs == 0 then
        Neurologics.SendMessage(sender, (targetClient and targetClient.Name or steamID) .. " is already banned from the specified roles: " .. table.concat(jobList, ", "))
    end

    return true
end)

Neurologics.AddCommand({"!unroleban", "!unbanrole", "!roleunban", "!jobunban", "!unbanjob"}, function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end

    if #args < 2 then
        Neurologics.SendMessage(sender, "Usage: !unbanrole \"name\" \"job1,job2,job3,jobN\"")
        return true
    end

    local targetClientInput = table.remove(args, 1)
    local jobsString = table.remove(args, 1):lower()
    local jobList = Neurologics.JobManager.splitJobList(jobsString)

    local validJobs = Neurologics.JobManager.ValidJobs
    local validJobsSet = {}
    for _, job in ipairs(validJobs) do
        validJobsSet[job] = true
    end

    local invalidJobs = {}
    for _, job in ipairs(jobList) do
        if not validJobsSet[job] then
            table.insert(invalidJobs, job)
        end
    end

    if #invalidJobs > 0 then
        Neurologics.SendMessage(sender, "Invalid job/role(s) specified: " .. table.concat(invalidJobs, ", "))
        return true
    end

    local targetClient, steamID = Neurologics.GetTargetClient(sender, targetClientInput)
    if steamID == nil then return true end

    -- Use the JobManager.UnbanJobs function to unban the player from specified jobs
    local unbannedJobs = Neurologics.JobManager.UnbanJobs(steamID, jobList, sender, targetClient)
    
    if #unbannedJobs == 0 then
        Neurologics.SendMessage(sender, (targetClient and targetClient.Name or steamID) .. " is not banned from the specified roles.")
    end

    return true
end)

Neurologics.AddCommand({"!forcerolechoice", "!frc"}, function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    if #args < 1 then
        Neurologics.SendMessage(sender, "Usage: !forcerolechoice <on/off>")
        return true
    end

    local toggle = string.lower(args[1])
    
    if toggle == "on" then
        Neurologics.ForceRoleChoice = true
        Neurologics.SendMessage(sender, "Force role choice enabled - job manager bypassed")
        Neurologics.SendMessageEveryone("Job restrictions have been disabled by an admin")
        Neurologics.Log("ForceRoleChoice enabled by " .. Neurologics.ClientLogName(sender))
    elseif toggle == "off" then
        Neurologics.ForceRoleChoice = false
        Neurologics.SendMessage(sender, "Force role choice disabled - job manager active")
        Neurologics.SendMessageEveryone("Job restrictions have been re-enabled")
        Neurologics.Log("ForceRoleChoice disabled by " .. Neurologics.ClientLogName(sender))
    else
        Neurologics.SendMessage(sender, "Usage: !forcerolechoice <on/off>")
        return true
    end

    -- Log the action
    Neurologics.Log(Neurologics.ClientLogName(sender) .. " toggled force role choice: " .. toggle)

    return true
end)

Neurologics.AddCommand("!forcerolechoicestatus", function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    local status = Neurologics.ForceRoleChoice and "ENABLED" or "DISABLED"
    Neurologics.SendMessage(sender, "Force role choice is currently: " .. status)
    
    return true
end)

-- DEBUG COMMAND - REMOVE BEFORE RELEASE
Neurologics.AddCommand("!addjobuser", function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    if #args < 2 then
        Neurologics.SendMessage(sender, "Usage: !addjobuser <job> <amount>")
        return true
    end
    
    local jobName = string.lower(args[1])
    local amount = tonumber(args[2])
    
    if not amount or amount <= 0 then
        Neurologics.SendMessage(sender, "Invalid amount. Must be a positive number.")
        return true
    end
    
    -- Initialize debug job users if not exists
    if not Neurologics.DebugJobUsers then
        Neurologics.DebugJobUsers = {}
    end
    
    -- Add debug users
    for i = 1, amount do
        table.insert(Neurologics.DebugJobUsers, jobName)
    end
    
    Neurologics.SendMessage(sender, "Added " .. amount .. " debug user(s) for job: " .. jobName)
    Neurologics.Log("Debug: Added " .. amount .. " fake users for job " .. jobName)
    
    return true
end)

-- DEBUG COMMAND - REMOVE BEFORE RELEASE
Neurologics.AddCommand("!clearjobusers", function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    Neurologics.DebugJobUsers = {}
    Neurologics.SendMessage(sender, "Cleared all debug job users")
    Neurologics.Log("Debug: Cleared all fake job users")
    
    return true
end)

-- DEBUG COMMAND - REMOVE BEFORE RELEASE
Neurologics.AddCommand("!listjobusers", function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    if not Neurologics.DebugJobUsers or #Neurologics.DebugJobUsers == 0 then
        Neurologics.SendMessage(sender, "No debug job users added")
        return true
    end
    
    local jobCounts = {}
    for _, job in ipairs(Neurologics.DebugJobUsers) do
        jobCounts[job] = (jobCounts[job] or 0) + 1
    end
    
    local message = "Debug job users:\n"
    for job, count in pairs(jobCounts) do
        message = message .. "- " .. job .. ": " .. count .. "\n"
    end
    
    Neurologics.SendMessage(sender, message)
    
    return true
end)

-- DEBUG COMMAND - REMOVE BEFORE RELEASE
Neurologics.AddCommand("!addrealplayer", function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    if #args < 2 then
        Neurologics.SendMessage(sender, "Usage: !addrealplayer <job> <player_name>")
        return true
    end
    
    local jobName = string.lower(args[1])
    local playerName = args[2]
    
    -- Initialize debug real players if not exists
    if not Neurologics.DebugRealPlayers then
        Neurologics.DebugRealPlayers = {}
    end
    
    -- Add debug real player
    table.insert(Neurologics.DebugRealPlayers, {
        job = jobName,
        name = playerName,
        steamID = "debug_real_" .. #Neurologics.DebugRealPlayers + 1
    })
    
    Neurologics.SendMessage(sender, "Added debug real player: " .. playerName .. " for job: " .. jobName)
    Neurologics.Log("Debug: Added fake real player " .. playerName .. " for job " .. jobName)
    
    return true
end)

-- DEBUG COMMAND - REMOVE BEFORE RELEASE
Neurologics.AddCommand("!clearrealplayers", function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    Neurologics.DebugRealPlayers = {}
    Neurologics.SendMessage(sender, "Cleared all debug real players")
    Neurologics.Log("Debug: Cleared all fake real players")
    
    return true
end)

-- DEBUG COMMAND - REMOVE BEFORE RELEASE
Neurologics.AddCommand("!listrealplayers", function (sender, args)
    if not sender.HasPermission(ClientPermissions.Kick) then return end
    
    if not Neurologics.DebugRealPlayers or #Neurologics.DebugRealPlayers == 0 then
        Neurologics.SendMessage(sender, "No debug real players added")
        return true
    end
    
    local jobCounts = {}
    local message = "Debug real players:\n"
    for _, player in ipairs(Neurologics.DebugRealPlayers) do
        message = message .. "- " .. player.name .. " wants " .. player.job .. "\n"
        jobCounts[player.job] = (jobCounts[player.job] or 0) + 1
    end
    
    message = message .. "\nJob counts:\n"
    for job, count in pairs(jobCounts) do
        message = message .. "- " .. job .. ": " .. count .. "\n"
    end
    
    Neurologics.SendMessage(sender, message)
    
    return true
end)


