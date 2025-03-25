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
        for player in Client.ClientList do
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
        Neurologics.SendMessage(client, "Usage: !triggerevent <event name>")
        return true
    end

    local event = nil
    for _, value in pairs(Neurologics.RoundEvents.EventConfigs.Events) do
        if value.Name == args[1] then
            event = value
        end
    end

    if event == nil then
        Neurologics.SendMessage(client, "Event " .. args[1] .. " doesnt exist.")
        return true
    end

    Neurologics.RoundEvents.TriggerEvent(event.Name)
    Neurologics.SendMessage(client, "Triggered event " .. event.Name)

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

Neurologics.AddCommand({"!SpawnNukie"}, function(client, args)
    -- for debug, spawns "nukie" at the player's location
    if not client.HasPermission(ClientPermissions.ConsoleCommands) then return end

    if #args > 1 then -- if more than 1 arg, send usage
        Neurologics.SendMessage(client, "Usage: !SpawnNukie")
        return true
    end

    local nukie = NCS.SpawnCharacter("Nukie", client.Character.WorldPosition) -- leave other vals nil, prefab already has defaults
    if not nukie then
        Neurologics.SendMessage(client, "Failed to spawn nukie. check logs for details.")
        return true
    end

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

    local jobList = splitJobList(jobsString)

    local validJobs = { "doctor", "guard", "captain", "head doctor", "scientist", "clown", "priest", "warden", "staff", "janitor", "convict", "he-chef" }
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

    local bannedJobs = Neurologics.LoadBannedJobs()
    if not bannedJobs[steamID] then
        bannedJobs[steamID] = {}
    end

    local function isJobBanned(bannedJobsList, job)
        for _, bannedJob in ipairs(bannedJobsList) do
            if bannedJob == job then
                return true
            end
        end
        return false
    end

    local addedJobs = {}
    for _, job in ipairs(jobList) do
        if not isJobBanned(bannedJobs[steamID], job) then
            table.insert(bannedJobs[steamID], job)
            table.insert(addedJobs, job)
        end
    end

    Neurologics.SaveBannedJobs(bannedJobs)

    if #addedJobs > 0 then
        local jobsStr = table.concat(addedJobs, ", ")
        Neurologics.SendMessage(sender, "Successfully banned " .. (targetClient and targetClient.Name or steamID) .. " from the roles: " .. jobsStr)
        Neurologics.RecieveRoleBan(targetClient, table.concat(addedJobs, ","), reason)
        if targetClient then
            Traitormod.SendMessage(targetClient, "You have been banned from playing the roles: " .. jobsStr .. "\nReason: " .. reason)
        end

        local discordWebHook = Neurologics.GetAPIKey("discordWebhook")
        local hookmsg = string.format("``Admin %s`` banned ``User %s`` from the roles: %s.\nReason: %s", sender.Name, (targetClient and targetClient.Name or steamID), jobsStr, reason)
        local function escapeQuotes(str)
            return str:gsub("\"", "\\\"")
        end
        local escapedMessage = escapeQuotes(hookmsg)
        Networking.RequestPostHTTP(discordWebHook, function(result) end, '{"content": "' .. escapedMessage .. '", "username": "ADMIN HELP (CONVICT STATION)"}')
    else
        Traitormod.SendMessage(sender, (targetClient and targetClient.Name or steamID) .. " is already banned from the specified roles: " .. table.concat(jobList, ", "))
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
    local jobList = splitJobList(jobsString)

    local validJobs = { "prisondoctor", "guard", "headguard", "warden", "staff", "janitor", "convict", "he-chef" }
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

    local targetClient, steamID = getTargetClient(sender, targetClientInput)
    if steamID == nil then return true end

    local bannedJobs = json.loadBannedJobs()
    if not bannedJobs[steamID] then
        bannedJobs[steamID] = {}
    end

    local function unbanJob(bannedJobsList, job)
        for index, bannedJob in ipairs(bannedJobsList) do
            if bannedJob == job then
                table.remove(bannedJobsList, index)
                return true
            end
        end
        return false
    end

    local unbannedJobs = {}
    for _, job in ipairs(jobList) do
        if unbanJob(bannedJobs[steamID], job) then
            table.insert(unbannedJobs, job)
        end
    end

    json.saveBannedJobs(bannedJobs)

    if #unbannedJobs > 0 then
        local jobsStr = table.concat(unbannedJobs, ", ")
        Neurologics.SendMessage(sender, "Successfully unbanned " .. (targetClient and targetClient.Name or steamID) .. " from the roles: " .. jobsStr)
        Neurologics.RecieveRoleUnban(targetClient, jobsStr)
        if targetClient then
            Neurologics.SendMessage(targetClient, "You have been unbanned from playing the roles: " .. jobsStr)
        end

        local discordWebHook = Neurologics.GetAPIKey("discordWebhook")
        local hookmsg = string.format("``Admin %s`` unbanned ``User %s`` from the roles: %s", sender.Name, (targetClient and targetClient.Name or steamID), jobsStr)
        local function escapeQuotes(str)
            return str:gsub("\"", "\\\"")
        end
        local escapedMessage = escapeQuotes(hookmsg)
        Networking.RequestPostHTTP(discordWebHook, function(result) end, '{"content": "' .. escapedMessage .. '", "username": "ADMIN HELP (CONVICT STATION)"}')
    else
        Neurologics.SendMessage(sender, (targetClient and targetClient.Name or steamID) .. " is not banned from the specified roles.")
    end

    return true
end)
