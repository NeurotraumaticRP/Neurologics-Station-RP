print("[Neurologicsutil] loaded")
Neurologics.Config = dofile(Neurologics.Path .. "/Lua/config/baseconfig.lua")

if not File.Exists(Neurologics.Path .. "/Lua/config/config.lua") then
    File.Write(Neurologics.Path .. "/Lua/config/config.lua", File.Read(Neurologics.Path .. "/Lua/config/config.lua.example"))
end

-- user config
loadfile(Neurologics.Path .. "/Lua/config/config.lua")(Neurologics.Config)

Neurologics.Patching = loadfile(Neurologics.Path .. "/Lua/xmlpatching.lua")(Neurologics.Path)

Neurologics.Languages = Neurologics.Config.Languages

Neurologics.DefaultLanguage = Neurologics.Languages[1]
Neurologics.Language = Neurologics.DefaultLanguage

for key, value in pairs(Neurologics.Languages) do
    if Neurologics.Config.Language == value.Name then
        Neurologics.Language = value

        for key, value in pairs(Neurologics.DefaultLanguage) do
            if Neurologics.Language[key] == nil then -- in case the language being loaded doesnt have a specific localization for a key, use the default language
                Neurologics.Language[key] = value
            end
        end

        break
    end
end

local json = dofile(Neurologics.Path .. "/Lua/json.lua")

Neurologics.LoadRemoteData = function (client, loaded)
    local data = {
        Account = client.SteamID,
    }

    for key, value in pairs(Neurologics.Config.RemoteServerAuth) do
        data[key] = value
    end

    Networking.HttpPost(Neurologics.Config.RemotePoints, function (res) 
        local success, result = pcall(json.decode, res)
        if not success then
            Neurologics.Log("Failed to retrieve points from server: " .. res)
            return
        end

        if result.Points then
            local originalPoints = Neurologics.GetData(client, "Points") or 0
            Neurologics.Log("Retrieved points from server for " .. client.SteamID .. ": " .. originalPoints .. " -> " .. result.Points)
            Neurologics.SetData(client, "Points", result.Points)
        end

        if loaded then loaded() end
    end, json.encode(data))
end

Neurologics.PublishRemoteData = function (client)
    local data = {
        Account = client.SteamID,
        Points = Neurologics.GetData(client, "Points")
    }

    if data.Points == nil then return end

    Neurologics.Log("Published points from server for " .. client.SteamID .. ": " .. data.Points)

    for key, value in pairs(Neurologics.Config.RemoteServerAuth) do
        data[key] = value
    end

    Networking.HttpPost(Neurologics.Config.RemotePoints, function (res) end, json.encode(data))
end

Neurologics.NewClientData = function (client)
    Neurologics.ClientData[client.SteamID] = {}
    Neurologics.ClientData[client.SteamID]["Points"] = Neurologics.Config.StartPoints
end

Neurologics.LoadData = function ()
    if Neurologics.Config.PermanentPoints then
        Neurologics.ClientData = json.decode(File.Read(Neurologics.Path .. "/Lua/data.json")) or {}
    else
        Neurologics.ClientData = {}
    end
end

Neurologics.SaveData = function ()
    if Neurologics.Config.PermanentPoints then
        File.Write(Neurologics.Path .. "/Lua/data.json", json.encode(Neurologics.ClientData))
    end
end

Neurologics.SetMasterData = function (name, value)
    Neurologics.ClientData[name] = value
end

Neurologics.GetMasterData = function (name)
    return Neurologics.ClientData[name]
end

Neurologics.SetData = function (client, name, amount)
    if Neurologics.ClientData[client.SteamID] == nil then 
        Neurologics.NewClientData(client)
    end

    Neurologics.ClientData[client.SteamID][name] = amount
end

Neurologics.GetData = function (client, name)
    if Neurologics.ClientData[client.SteamID] == nil then 
        Neurologics.NewClientData(client)
    end

    return Neurologics.ClientData[client.SteamID][name]
end

Neurologics.AddData = function(client, name, amount)
    Neurologics.SetData(client, name, math.max((Neurologics.GetData(client, name) or 0) + amount, 0))
end

Neurologics.FindClient = function (name)
    for key, value in pairs(Client.ClientList) do
        if value.Name == name or tostring(value.SteamID) == name then
            return value
        end
    end
end

Neurologics.FindClientCharacter = function (character)
    for key, value in pairs(Client.ClientList) do
        if character == value.Character then return value end
    end

    return nil
end

Neurologics.SendMessageEveryone = function (text, popup)
    if popup then
        Game.SendMessage(text, ChatMessageType.MessageBox)
    else
        Game.SendMessage(text, ChatMessageType.Server)
    end
end

Neurologics.SendMessage = function (client, text, icon)
    if not client or not text or text == "" then
        return
    end
    text = tostring(text)

    if icon then
        Game.SendDirectChatMessage("", text, nil, ChatMessageType.ServerMessageBoxInGame, client, icon)
    else
        Game.SendDirectChatMessage("", text, nil, ChatMessageType.MessageBox, client)
    end

    Game.SendDirectChatMessage("", text, nil, Neurologics.Config.ChatMessageType, client)
end

Neurologics.SendChatMessage = function (client, text, color)
    if not client or not text or text == "" then
        return
    end

    text = tostring(text)

    local chatMessage = ChatMessage.Create("", text, ChatMessageType.Default)
    if color then
        chatMessage.Color = color
    end

    Game.SendDirectChatMessage(chatMessage, client)
end

Neurologics.SendMessageCharacter = function (character, text, icon)
    if character.IsBot then return end
    
    local client = Neurologics.FindClientCharacter(character)

    if client == nil then
        Neurologics.Error("SendMessageCharacter() Client is null, ", character.name, " ", text)
        return
    end

    Neurologics.SendMessage(client, text, icon)
end

Neurologics.MissionIdentifier =  "easterbunny" -- can be any defined Traitor mission id in vanilla xml, mainly used for icon
Neurologics.SendTraitorMessageBox = function (client, text, icon)
    --Game.SendTraitorMessage(client, text, icon or Neurologics.MissionIdentifier, TraitorMessageType.ServerMessageBox);
    Game.SendDirectChatMessage("", text, nil, Neurologics.Config.ChatMessageType, client)
end

-- set character traitor to enable sabotage, set mission objective text then sync with session
Neurologics.UpdateVanillaTraitor = function (client, enabled, objectiveSummary, missionIdentifier)
    if not client or not client.Character then
        Neurologics.Error("UpdateVanillaTraitor failed! Client or Character was null!")
        return
    end

    client.Character.IsTraitor = enabled
    client.Character.TraitorCurrentObjective = objectiveSummary
    --Game.SendTraitorMessage(client, objectiveSummary, missionIdentifier or Neurologics.MissionIdentifier, TraitorMessageType.Objective)
end

-- send feedback to the character for completing a traitor objective and update vanilla traitor state
Neurologics.SendObjectiveCompleted = function(client, objectiveText, points, livesText)
    if livesText then
        livesText = "\n" .. livesText
    else
        livesText = ""
    end

    Neurologics.SendMessage(client, 
    string.format(Neurologics.Language.ObjectiveCompleted, objectiveText) .. " \n\n" .. 
    string.format(Neurologics.Language.PointsAwarded, points) .. livesText
    , "MissionCompletedIcon") --InfoFrameTabButton.Mission

    local role = Neurologics.RoleManager.GetRole(client.Character)

    if role and role.IsAntagonist then
        Neurologics.UpdateVanillaTraitor(client, true, role:Greet())
    end
end

Neurologics.SendObjectiveFailed = function(client, objectiveText)
    if not Neurologics.Language then return end
    
    local failedMsg = Neurologics.Language.ObjectiveFailed and string.format(Neurologics.Language.ObjectiveFailed, objectiveText) or "Objective failed: " .. objectiveText
    
    Neurologics.SendMessage(client, failedMsg, "MissionFailedIcon")

    local role = Neurologics.RoleManager.GetRole(client.Character)

    if role and role.IsAntagonist then
        Neurologics.UpdateVanillaTraitor(client, true, role:Greet())
    end
end

Neurologics.SelectCodeWords = function ()
    local copied = {}
    for key, value in pairs(Neurologics.Config.Codewords) do
        copied[key] = value
    end

    local selected = {}
    for i=1, Neurologics.Config.AmountCodeWords, 1 do
        table.insert(selected, copied[Random.Range(1, #copied + 1)])
    end

    local selected2 = {}
    for i=1, Neurologics.Config.AmountCodeWords, 1 do
        table.insert(selected2, copied[Random.Range(1, #copied + 1)])
    end

    return {selected, selected2}
end

Neurologics.ParseCommand = function (text)
    local result = {}

    if text == nil then return result end

    local spat, epat, buf, quoted = [=[^(["])]=], [=[(["])$]=]
    for str in text:gmatch("%S+") do
        local squoted = str:match(spat)
        local equoted = str:match(epat)
        local escaped = str:match([=[(\*)["]$]=])
        if squoted and not quoted and not equoted then
            buf, quoted = str, squoted
        elseif buf and equoted == quoted and #escaped % 2 == 0 then
            str, buf, quoted = buf .. ' ' .. str, nil, nil
        elseif buf then
            buf = buf .. ' ' .. str
        end
        if not buf then result[#result + 1] = str:gsub(spat,""):gsub(epat,"") end
    end

    return result
end

Neurologics.AddCommand = function (commandName, callback)
    if type(commandName) == "table" then
        for command in commandName do
            Neurologics.AddCommand(command, callback)
        end
    else
        local cmd = {}
    
        Neurologics.Commands[string.lower(commandName)] = cmd
        cmd.Callback = callback;
    end
end

Neurologics.RemoveCommand = function (commandName)
    Neurologics.Commands[commandName] = nil
end

-- type: 6 = Server message, 7 = Console usage, 9 error
Neurologics.Log = function (message)
    Game.Log("[Neurologics] " .. message, 6)
end

Neurologics.Debug = function (message)
    if Neurologics.Config.DebugLogs then
        Game.Log("[Neurologics-Debug] " .. message, 6)
    end
end

Neurologics.Error = function (message, ...)
    Game.Log("[Neurologics-Error] " .. message, 9)
    
    if Neurologics.Config.DebugLogs then
        printerror(string.format(message, ...))
    end
end

Neurologics.AllCrewMissionsCompleted = function (missions)
    if not missions then
        if Game.GameSession == nil or Game.GameSession.Missions == nil then return end
        missions = Game.GameSession.Missions
    end
    for key, value in pairs(missions) do
        if not value.Completed then
            return false
        end
    end
    return true
end

Neurologics.LoadExperience = function (client)
    if client == nil then
        Neurologics.Error("Loading experience failed! Client was nil")
        return
    elseif not client.Character or not client.Character.Info then 
        Neurologics.Error("Loading experience failed! Client.Character or .Info was null! " .. Neurologics.ClientLogName(client))
        return 
    end
    local amount = Neurologics.Config.AmountExperienceWithPoints(Neurologics.GetData(client, "Points") or 0)
    local max = Neurologics.Config.MaxExperienceFromPoints or 2000000000     -- must be int32

    if amount > max then
        amount = max
    end

    Neurologics.Debug("Loading experience from stored points: " .. Neurologics.ClientLogName(client) .. " -> " .. amount)
    client.Character.Info.SetExperience(amount)
end

Neurologics.GiveExperience = function (character, amount, isMissionXP)
    if character == nil or character.Info == nil or character.Info.GiveExperience == nil or character.IsHuman == false or amount == nil or amount == 0 then
        return false
    end
    Neurologics.Debug("Giving experience to character: " .. character.Name .. " -> " .. amount)
    character.Info.GiveExperience(amount, isMissionXP)
    return true
end

Neurologics.AwardPoints = function (client, amount, isMissionXP)
    if not Neurologics.Config.TestMode then
        Neurologics.AddData(client, "Points", amount)
        Neurologics.Stats.AddClientStat("PointsGained", client, amount)
        Neurologics.Log(string.format("Client %s was awarded %d points.", Neurologics.ClientLogName(client), math.floor(amount)))
        if Neurologics.SelectedGamemode and Neurologics.SelectedGamemode.AwardedPoints then
            local oldValue = Neurologics.SelectedGamemode.AwardedPoints[client.SteamID] or 0
            Neurologics.SelectedGamemode.AwardedPoints[client.SteamID] = oldValue + amount
        end
    end
    return amount
end

Neurologics.AdjustLives = function (client, amount)
    if not amount or amount == 0 then
        return
    end

    local oldLives = Neurologics.GetData(client, "Lives") or Neurologics.Config.MaxLives
    local newLives =  oldLives + amount

    if (newLives or 0) > Neurologics.Config.MaxLives then
        -- if gained more lives than maxLives, reset to maxLives
        newLives = Neurologics.Config.MaxLives
    end

    local icon = "InfoFrameTabButton.Mission"
    if newLives == oldLives then
        -- no change in lives, no need for feedback
        return nil, icon
    end

    local amountString = (Neurologics.Language and Neurologics.Language.ALife) or "a life"
    if amount > 1 then 
        amountString = amount .. ((Neurologics.Language and Neurologics.Language.Lives) or " lives")
    end

    local lifeAdjustMessage
    if Neurologics.Language and Neurologics.Language.LivesGained then
        lifeAdjustMessage = string.format(Neurologics.Language.LivesGained, amountString, newLives, Neurologics.Config.MaxLives)
    else
        lifeAdjustMessage = "Gained " .. amountString .. ". Lives: " .. newLives .. "/" .. Neurologics.Config.MaxLives
    end
    
    if amount < 0 then
        icon = "GameModeIcon.pvp"
        local newLivesString = (Neurologics.Language and Neurologics.Language.ALife) or "a life"
        if newLives > 1 then
            newLivesString = newLives .. ((Neurologics.Language and Neurologics.Language.Lives) or " lives")
        end
        if Neurologics.Language and Neurologics.Language.Death then
            lifeAdjustMessage = string.format(Neurologics.Language.Death, newLivesString)
        else
            lifeAdjustMessage = "Lost a life. Lives: " .. newLivesString
        end
    end

    if (newLives or 0) <= 0 then
        -- if no lives left, reduce amount of points, reset to maxLives
        Neurologics.Log("Player ".. client.Name .." lost all lives. Reducing points...")
        if not Neurologics.Config.TestMode then  
            local oldAmount = Neurologics.GetData(client, "Points") or 0
            local newAmount = Neurologics.Config.PointsLostAfterNoLives(oldAmount)
            Neurologics.SetData(client, "Points", newAmount)
            Neurologics.Stats.AddClientStat("PointsLost", client, oldAmount - newAmount)

            Neurologics.LoadExperience(client)
        end
        newLives = Neurologics.Config.MaxLives
        if Neurologics.Language and Neurologics.Language.NoLives then
            lifeAdjustMessage = string.format(Neurologics.Language.NoLives, newLives)
        else
            lifeAdjustMessage = "No lives left! Reset to " .. newLives .. " lives."
        end
    end
    
    Neurologics.Log("Adjusting lives of player " .. Neurologics.ClientLogName(client) .. " by " .. amount .. ". New value: " .. newLives)
    Neurologics.SetData(client, "Lives", newLives)
    return lifeAdjustMessage, icon
end


print("[Neurologicsutil] SendTip function defined")
Neurologics.SendTip = function()
    local tip = Neurologics.Language.Tips[math.random(1, #Neurologics.Language.Tips)]

    for key, client in pairs(Client.ClientList) do
        Neurologics.SendChatMessage(client, Neurologics.Language.TipText .. tip, Color.Orange)
    end
end

Neurologics.GetDataInfo = function(client, showWeights)
    local weightInfo = ""
    if showWeights then
        local maxPoints = 0
        for index, value in pairs(Client.ClientList) do
            if value.Character and not value.Character.IsDead or not Game.RoundStarted then
                maxPoints = maxPoints + (Neurologics.GetData(value, "Weight") or 0)
            end
        end
    
        local percentage = (Neurologics.GetData(client, "Weight") or 0) / maxPoints * 100
    
        if percentage ~= percentage then
            percentage = 100 -- percentage is NaN, set it to 100%
        end

        if Neurologics.Language and Neurologics.Language.TraitorInfo then
            weightInfo = "\n\n" .. string.format(Neurologics.Language.TraitorInfo, math.floor(percentage))
        else
            weightInfo = "\n\nTraitor chance: " .. math.floor(percentage) .. "%"
        end
    end

    local pointsInfo
    if Neurologics.Language and Neurologics.Language.PointsInfo then
        pointsInfo = string.format(Neurologics.Language.PointsInfo, math.floor(Neurologics.GetData(client, "Points") or 0), Neurologics.GetData(client, "Lives") or Neurologics.Config.MaxLives, Neurologics.Config.MaxLives)
    else
        pointsInfo = "Points: " .. math.floor(Neurologics.GetData(client, "Points") or 0) .. " | Lives: " .. (Neurologics.GetData(client, "Lives") or Neurologics.Config.MaxLives) .. "/" .. Neurologics.Config.MaxLives
    end
    
    return pointsInfo .. weightInfo
end

Neurologics.ClientLogName = function(client, name)
    if name == nil then name = client.Name end

    name = string.gsub(name, "%‖", "")

    local log = "‖metadata:" .. client.SteamID .. "‖" .. name .. "‖end‖"
    return log
end

Neurologics.InsertString = function(str1, str2, pos)
    return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

Neurologics.HighlightClientNames = function (text, color)
    for key, value in pairs(Client.ClientList) do
        local name = value.Name

        local i, j = string.find(text, name)

        if i ~= nil then
            text = Neurologics.InsertString(text, string.format("‖color:%s,%s,%s‖", color.R, color.G, color.B), i - 1)
        end

        local i, j = string.find(text, name)

        if i ~= nil then
            text = Neurologics.InsertString(text, "‖end‖", j)
        end
    end

    return text
end

Neurologics.GetJobString = function(character)
    local prefix = "Crew member"
    if character.Info and character.Info.Job then
        prefix = tostring(TextManager.Get("jobname." .. tostring(character.Info.Job.Prefab.Identifier)))
    end
    return prefix
end

-- returns true if character has reached the end of the level
Neurologics.EndReached = function(character, distance)
    if LevelData and LevelData.LevelType and LevelData.LevelType.Outpost then
        return true
    end

    if Level.Loaded.EndOutpost == nil then
        return Submarine.MainSub.AtEndExit
    end

    local characterInsideOutpost = not character.IsDead and character.Submarine == Level.Loaded.EndOutpost
    -- character is inside or docked to outpost 
    return characterInsideOutpost or Vector2.Distance(character.WorldPosition, Level.Loaded.EndPosition) < distance
end

Neurologics.SendWelcome = function(client)
    if Neurologics.Config.SendWelcomeMessage or Neurologics.Config.SendWelcomeMessage == nil then
        Game.SendDirectChatMessage("", "| Traitor Mod v" .. Neurologics.VERSION .. " |\n" .. Neurologics.GetDataInfo(client), nil, ChatMessageType.Server, client)
    end
end

Neurologics.ParseSubmarineConfig = function (description)
    local startIndex, endIndex = string.find(description, "%[Neurologics%]")

    if startIndex == nil then return {} end

    local configString = string.sub(description, endIndex + 1)
    local success, result = pcall(json.decode, configString)

    if not success then return {} end

    return result
end

Neurologics.FormatTime = function(seconds)
    return TimeSpan.FromSeconds(seconds).ToString()
end

Neurologics.GetClientByName = function(sender, targetClientInput)
    for key, value in pairs(Client.ClientList) do
        if value.Name == targetClientInput or tostring(value.SteamID) == targetClientInput then
            return value
        end
    end
end

Neurologics.GetClientByName = function(sender,inputName)
    inputName = inputName:lower()

    -- Find by client name or SteamID
    for i,client in pairs(Client.ClientList) do
        if type(client.Name) == "string" and client.Name:lower():find(inputName, 1, true) then
            return client
        elseif client.SteamID == inputName then
            return client
        end
    end

    -- Find by character name
    for _, client in pairs(Client.ClientList) do
        if client.Character and type(client.Character.Name) == "string" and client.Character.Name:lower():find(inputName, 1, true) then
            return client
        end
    end

    return nil
end


Neurologics.GetTargetClient = function(sender, targetClientInput)
    local targetClient = nil
    local steamID = nil

    if targetClientInput:match("^%d+$") then
        steamID = targetClientInput
    else
        targetClient = Neurologics.GetClientByName(sender, targetClientInput)
        if targetClient == nil then
            Neurologics.SendMessage(sender, "That player does not exist.")
            return nil, nil
        end
        steamID = targetClient.SteamID
    end

    return targetClient, steamID
end

-- Utility functions to load API keys from a JSON file

Neurologics.LoadAPIKeys = function()
    local path = Neurologics.Path .. "/Lua/Json/apikeys.json"
    if not File.Exists(path) then
        File.Write(path, "{}")
    end
    local content = File.Read(path)
    local keys = Neurologics.JSON.decode(content)
    return keys
end


Neurologics.GetAPIKey = function(keyName)
    local keys = Neurologics.LoadAPIKeys()
    return keys[keyName]
end

Neurologics.SplitJobList = function(jobsString)
    local jobList = {}
    for job in string.gmatch(jobsString, '([^,]+)') do
        local trimmedJob = job:match("^%s*(.-)%s*$")
        table.insert(jobList, trimmedJob)
    end
    return jobList
end

Neurologics.Deepcopy = function(orig) -- copies tables and their metatables
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Neurologics.Deepcopy(orig_key)] = Neurologics.Deepcopy(orig_value)
        end
        setmetatable(copy, Neurologics.Deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
