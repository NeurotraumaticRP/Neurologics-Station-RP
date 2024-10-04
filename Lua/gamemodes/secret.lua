local weightedRandom = dofile(Neurologics.Path .. "/Lua/weightedrandom.lua")
local gm = Neurologics.Gamemodes.Gamemode:new()

gm.Name = "Secret"

function gm:CharacterDeath(character)
    local client = Neurologics.FindClientCharacter(character)

    -- if character is valid player
    if client == nil or
        character == nil or
        character.IsHuman == false or
        character.ClientDisconnected == true or
        character.TeamID == 0 then
        return
    end

    if Neurologics.RoundTime < Neurologics.Config.MinRoundTimeToLooseLives then
        return
    end

    if Neurologics.LostLivesThisRound[client.SteamID] == nil then
        Neurologics.LostLivesThisRound[client.SteamID] = true
    else
        return
    end

    local liveMsg, liveIcon = Neurologics.AdjustLives(client, -1)

    Neurologics.SendMessage(client, liveMsg, liveIcon)
end

function gm:Start()
    local this = self

    if self.EnableRandomEvents then
        Neurologics.RoundEvents.Initialize()
    end

    Hook.Add("characterDeath", "Neurologics.Secret.CharacterDeath", function(character, affliction)
        this:CharacterDeath(character)
    end)

    self:SelectAntagonists()
end

function gm:AssignAntagonists(antagonists)
    local function AssignCrew()
        for key, value in pairs(Client.ClientList) do
            if value.Character ~= nil and value.Character.IsHuman and not value.SpectateOnly and not value.Character.IsDead and value.Character.TeamID == CharacterTeamType.Team1 then
                local role = Neurologics.RoleManager.GetRole(value.Character)
                if role == nil then
                    role = Neurologics.RoleManager.Roles["Crew"]
                    Neurologics.RoleManager.AssignRole(value.Character, role:new())
                end
            end
        end

        Hook.Add("Neurologics.midroundspawn", "Neurologics.Secret.MidRoundSpawn", function (client, character)
            local role = Neurologics.RoleManager.GetRole(character)
            if role == nil then
                role = Neurologics.RoleManager.Roles["Crew"]
                Neurologics.RoleManager.AssignRole(character, role:new())
            end
        end)
    end

    local function Assign(roles)
        for key, role in pairs(roles) do
            if role.Name == "Cultist" then
                self.RoundEndIcon = "oneofus"
                Game.EnableControlHusk(true)
            end
        end

        local newRoles = {}

        for key, value in pairs(antagonists) do
            table.insert(newRoles, roles[key]:new())
        end

        Neurologics.RoleManager.AssignRoles(antagonists, newRoles)

        AssignCrew()
    end

    if self.TraitorTypeSelectionMode == "Random" then
        local role = Neurologics.RoleManager.Roles[weightedRandom.Choose(self.TraitorTypeChance)]

        local roles = {}
        for key, value in pairs(antagonists) do
            table.insert(roles, role)
        end
        Assign(roles)
    else
        local options = {}
        for key, value in pairs(self.TraitorTypeChance) do
            table.insert(options, key)
        end

        local clients = {}

        for key, value in pairs(antagonists) do
            local client = Neurologics.FindClientCharacter(value)
            if client then
                table.insert(clients, client)
            end
        end

        if #clients == 0 then
            Assign({})
            return
        end

        Neurologics.Voting.StartVote(Neurologics.Language.SecretTraitorAssigned, options, 25, function (results, clientVotes)
            local highestVoted = nil
            local highestedVotedRole = nil
            for key, value in pairs(options) do
                if highestVoted == nil or results[key] > highestVoted then
                    highestVoted = results[key]
                    highestedVotedRole = value
                end
            end

            local roles = {}
            for key, value in pairs(clientVotes) do
                local role = ""
                if value == -1 then
                    role = Neurologics.RoleManager.Roles[highestedVotedRole]
                else
                    role = Neurologics.RoleManager.Roles[options[value]]
                end

                table.insert(roles, role)
            end
            Assign(roles)
        end, clients)
    end
end

function gm:SelectAntagonists()
    local this = self
    local thisRoundNumber = Neurologics.RoundNumber

    local delay = math.random(self.TraitorSelectDelayMin, self.TraitorSelectDelayMax)

    Timer.Wait(function()
        if thisRoundNumber ~= Neurologics.RoundNumber or not Game.RoundStarted then return end

        local clientWeight = {}
        local traitorChoices = 0
        local playerInGame = 0
        for key, value in pairs(Client.ClientList) do
            -- valid traitor choices must be ingame, player was spawned before (has a character), is no spectator
            if value.InGame and value.Character and not value.SpectateOnly then
                -- filter by config
                if this.TraitorFilter(value) > 0 and Neurologics.GetData(value, "NonTraitor") ~= true then
                    -- players are alive or if respawning is on and config allows dead traitors (not supported yet)
                    if not value.Character.IsDead and Neurologics.RoleManager.GetRole(value.Character) == nil then
                        clientWeight[value] = (Neurologics.GetData(value, "Weight") or 0) * this.TraitorFilter(value)
                        traitorChoices = traitorChoices + 1
                    end
                end
                playerInGame = playerInGame + 1
            end
        end

        if traitorChoices == 0 then
            this:AssignAntagonists({})
            Neurologics.Log("No players to assign traitors")
            return
        end

        local amountTraitors = this.AmountTraitors(playerInGame)
        if amountTraitors > traitorChoices then
            amountTraitors = traitorChoices
            Neurologics.Log("Not enough valid players to assign all traitors... New amount: " .. tostring(amountTraitors))
        end

        local antagonists = {}

        for i = 1, amountTraitors, 1 do
            local index = weightedRandom.Choose(clientWeight)

            if index ~= nil then
                Neurologics.Log("Chose " ..
                    index.Character.Name .. " as traitor. Weight: " .. math.floor(clientWeight[index] * 100) / 100)

                table.insert(antagonists, index.Character)

                clientWeight[index] = nil

                Neurologics.SetData(index, "Weight", 0)
            end
        end

        self:AssignAntagonists(antagonists)
    end, delay * 1000)
end

function gm:AwardCrew()
    local missionType = {}

    for key, value in pairs(MissionType) do
        missionType[value] = key
    end

    local missionReward = 0
    for _, mission in pairs(Neurologics.RoundMissions) do
        if mission.Completed then
            local type = missionType[mission.Prefab.Type]
            local missionValue = self.MissionPoints.Default

            for key, value in pairs(self.MissionPoints) do
                if key == type then
                    missionValue = value
                end
            end

            missionReward = missionReward + missionValue
        end
    end

    if self.MissionEndAdditionalReward then
        missionReward = missionReward + self.MissionEndAdditionalReward()
    end

    for key, value in pairs(Client.ClientList) do
        if value.Character ~= nil
            and value.Character.IsHuman
            and not value.SpectateOnly
            and not value.Character.IsDead
        then
            local role = Neurologics.RoleManager.GetRole(value.Character)

            local wasAntagonist = false
            if role ~= nil then
                wasAntagonist = role.IsAntagonist
            end

            -- if client was no traitor, and in reach of end position, gain a live
            if not wasAntagonist and Neurologics.EndReached(value.Character, self.DistanceToEndOutpostRequired) then
                local msg = ""

                -- award points for mission completion
                if missionReward > 0 then
                    local points = Neurologics.AwardPoints(value, missionReward
                        , true)
                    msg = msg ..
                        Neurologics.Language.CrewWins ..
                        " " .. string.format(Neurologics.Language.PointsAwarded, points) .. "\n\n"
                end

                local lifeMsg, icon = Neurologics.AdjustLives(value,
                    (self.LivesGainedFromCrewMissionsCompleted or 1))
                if lifeMsg then
                    msg = msg .. lifeMsg .. "\n\n"
                end

                if msg ~= "" then
                    Neurologics.SendMessage(value, msg, icon)
                end
            end
        end
    end
end

function gm:CheckHandcuffedTraitors(character)
    if character.IsDead then return end
    
    local item = character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
    if item ~= nil and item.Prefab.Identifier == "handcuffs" then
        for key, value in pairs(Client.ClientList) do
            local role = Neurologics.RoleManager.GetRole(value.Character)
            if (role == nil or not role.IsAntagonist) and value.Character and not value.Character.IsDead and value.Character.TeamID == CharacterTeamType.Team1 then
                local points = Neurologics.AwardPoints(value, self.PointsGainedFromHandcuffedTraitors)
                local text = string.format(Neurologics.Language.TraitorHandcuffed, character.Name)
                text = text .. "\n\n" .. string.format(Neurologics.Language.PointsAwarded, points)
                Neurologics.SendMessage(value, text, "InfoFrameTabButton.Mission")
            end
        end
    end
end

function gm:TraitorResults()
    local success = false

    local sb = Neurologics.StringBuilder:new()

    local antagonists = {}
    for character, role in pairs(Neurologics.RoleManager.RoundRoles) do
        if role.IsAntagonist then
            table.insert(antagonists, character)
        end

        if role.IsAntagonist then
            sb("%s %s", role.Name, character.Name)
            sb("\n")

            local objectives = 0
            local pointsGained = 0

            for key, value in pairs(role.Objectives) do
                if value:IsCompleted() or value.IsAwarded then
                    objectives = objectives + 1
                    pointsGained = pointsGained + value.AmountPoints
                end
            end

            if objectives > 0 then
                success = true
            end

            sb(Neurologics.Language.SecretSummary, objectives, pointsGained)
        end
    end

    if success then
        Neurologics.Stats.AddStat("Rounds", "Traitor rounds won", 1)
    else
        Neurologics.Stats.AddStat("Rounds", "Crew rounds won", 1)
    end

    -- first arg = mission id, second = message, third = completed, forth = list of characters
    return {TraitorMissionResult(self.RoundEndIcon or Neurologics.MissionIdentifier, sb:concat(), success, antagonists)}
end

function gm:End()
    for key, character in pairs(Neurologics.RoleManager.FindAntagonists()) do
        self:CheckHandcuffedTraitors(character)
    end

    gm:AwardCrew()

    Game.EnableControlHusk(false)

    Hook.Remove("characterDeath", "Neurologics.Secret.CharacterDeath")
    Hook.Remove("Neurologics.midroundspawn", "Neurologics.Secret.MidRoundSpawn")
end

function gm:Think()
    local ended = true
    local anyTraitorMission = false

    for key, value in pairs(Character.CharacterList) do
        if not value.IsDead and value.IsHuman and value.TeamID == CharacterTeamType.Team1 then
            local role = Neurologics.RoleManager.GetRole(value)
            if role == nil or not role.IsAntagonist then
                ended = false
            else
                if role.Objectives then
                    for key, objective in pairs(role.Objectives) do
                        if objective.Name == "Assassinate" or objective.Name == "Husk" then
                            anyTraitorMission = true
                        end
                    end
                end
            end
        end
    end

    if not anyTraitorMission then
        ended = false
    end

    if not self.Ending and Game.RoundStarted and self.EndOnComplete and ended then
        local delay = self.EndGameDelaySeconds or 0

        Neurologics.SendMessageEveryone(Neurologics.Language.TraitorsWin)
        Neurologics.Log("Secret gamemode complete. Ending round in " .. delay)

        Timer.Wait(function ()
            Game.EndGame()
        end, delay * 1000)

        self.Ending = true
    end
end

return gm
