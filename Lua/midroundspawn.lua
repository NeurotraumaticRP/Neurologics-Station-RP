-- Originally by MassCraxx, ported to Neurologics.

Neurologics.DisableMidRoundSpawn = false
if not Neurologics.Config then print("[Midroundspawn] Neurologics.Config failed to load") return end
if not Neurologics.Config.MidRoundSpawn then print("[Midroundspawn] MidRoundSpawn is disabled in config") return end

local textPromptUtils = require("textpromptutils")

local checkDelaySeconds = 10
local spawnDelaySeconds = 0
local giveSpectatorsSpawnOption = false   -- if true, spectating players will be given the option to mid-round spawn
local preventMultiCaptain = true          -- if true, will give securityofficer job to players trying to spawn as additional captain

local checkTime = -1
local hasBeenSpawned = {}
local newPlayers = {}

local m = {}

print("[Midroundspawn] loaded")

m.SetSpawnedClient = function (client, character)
    hasBeenSpawned[client.SteamID] = character
end

m.SpawnClientCharacterOnSub = function(submarine, client)
    if not Game.RoundStarted or not client.InGame then return false end 

    local spawned = m.TryCreateClientCharacter(submarine, client)
    hasBeenSpawned[client.SteamID] = spawned
    Neurologics.GiveHungryEuropanToClient(client)

    return spawned
end

m.CrewHasJob = function(job)
    if #Client.ClientList > 1 then
        for key, value in pairs(Client.ClientList) do
            if value.Character and value.Character.HasJob(job) then return true end
        end
    end
    return false
end

-- TryCreateClientCharacter inspied by Oiltanker
m.TryCreateClientCharacter = function(submarine, client)
    local session = Game.GameSession
    local crewManager = session.CrewManager

    -- fix client char info
    if client.CharacterInfo == nil then client.CharacterInfo = CharacterInfo("human", client.Name) end

    -- Gather current job counts
    local jobCounts = {}
    for _, c in pairs(Client.ClientList) do
        if c.CharacterInfo and c.AssignedJob then
            local jobName = c.AssignedJob.Prefab.Identifier.ToString():lower()
            jobCounts[jobName] = (jobCounts[jobName] or 0) + 1
        end
    end

    -- Get job caps for current player count
    local playerCount = #Client.ClientList
    local maxAmounts = Neurologics.JobManager.EvaluateJobMaxAmount(playerCount)

    -- Determine the best job for this client
    local jobPreference = client.JobPreferences[1]
    local assignedJob = nil
    local originalJobName = nil

    if jobPreference then
        originalJobName = jobPreference.Prefab.Identifier.ToString():lower()
        -- Check if job is available (not over cap, not banned)
        local currentCount = jobCounts[originalJobName] or 0
        local maxAllowed = maxAmounts[originalJobName] or 0
        local isBanned = false
        local bannedJobs = Neurologics.JSON.loadBannedJobs()
        if bannedJobs[client.SteamID] then
            for _, bannedJob in ipairs(bannedJobs[client.SteamID]) do
                if originalJobName == bannedJob then
                    isBanned = true
                    break
                end
            end
        end
        if not isBanned and (maxAllowed == -1 or currentCount < maxAllowed) then
            assignedJob = jobPreference
        else
            -- Use JobManager's reassignPlayer to get the next best job
            local nextJobName = Neurologics.JobManager.ReassignPlayer(client, originalJobName, maxAmounts, jobCounts)
            assignedJob = Neurologics.JobManager.GetJobVariant(nextJobName, client)
        end
    else
        -- No options, assign assistant
        assignedJob = Neurologics.JobManager.GetJobVariant("assistant", client)
    end

    client.AssignedJob = assignedJob
    client.CharacterInfo.Job = Job(assignedJob.Prefab, false, 0, assignedJob.Variant)
    crewManager.AddCharacterInfo(client.CharacterInfo)

    local spawnWayPoints = WayPoint.SelectCrewSpawnPoints({client.CharacterInfo}, submarine)
    local randomIndex = Random.Range(1, #spawnWayPoints)
    local waypoint = spawnWayPoints[randomIndex]

    -- find waypoint the hard way
    if waypoint == nil then
        for i,wp in pairs(WayPoint.WayPointList) do
            if
                wp.AssignedJob ~= nil and
                wp.SpawnType == SpawnType.Human and
                wp.Submarine == submarine and
                wp.CurrentHull ~= nil
            then
                if client.CharacterInfo.Job.Prefab == wp.AssignedJob then
                    waypoint = wp
                    break
                end
            end
        end
    end

    -- none found, go random
    if waypoint == nil then 
        Neurologics.Log("WARN: No valid job waypoint found for " .. client.CharacterInfo.Job.Name.Value .. " - using random")
        waypoint = WayPoint.GetRandom(SpawnType.Human, nil, submarine)
    end

    if waypoint == nil then 
        Neurologics.Log("ERROR: Could not spawn player - no valid waypoint found")
        return false 
    end

    Neurologics.Log("Spawning " .. client.Name .. " as " .. client.CharacterInfo.Job.Name.Value)

    Timer.Wait(function () 
        -- spawn character
        local char = Character.Create(client.CharacterInfo, waypoint.WorldPosition, client.CharacterInfo.Name, 0, true, true)
        char.TeamID = submarine.TeamID
        crewManager.AddCharacter(char)

        client.SetClientCharacter(char)

        char.GiveJobItems(false, waypoint)
        char.LoadTalents()

        Hook.Call("Neurologics.midroundspawn", client, char)
    end, spawnDelaySeconds * 1000)

    return true
end

m.ShowSpawnDialog = function(client, force)
    if not force and client.Character and not client.Character.IsDead then
        Neurologics.Log(client.Name .. " was prevented to midroundspawn due to having an alive character.")
        return
    end

    if LuaUserData.IsTargetType(Game.GameSession.GameMode, "Barotrauma.PvPMode") then
        textPromptUtils.Prompt(Neurologics.Language.MidRoundSpawn, {Neurologics.Language.MidRoundSpawnCoalition, Neurologics.Language.MidRoundSpawnSeparatists, Neurologics.Language.MidRoundSpawnWait}, client, function(option, client) 
            if option == 1 or option == 2 then
                if force or not client.Character or client.Character.IsDead then
                    m.SpawnClientCharacterOnSub(Submarine.MainSubs[option], client)
                else
                    Neurologics.Log(client.Name .. " attempted midroundspawn while having alive character.")
                end
            end
        end)
    else
        textPromptUtils.Prompt(Neurologics.Language.MidRoundSpawn, {Neurologics.Language.MidRoundSpawnMission, Neurologics.Language.MidRoundSpawnWait}, client, function(option, client) 
            if option == 1 then
                if force or not client.Character or client.Character.IsDead then
                    m.SpawnClientCharacterOnSub(Submarine.MainSub, client)
                else
                    Neurologics.Log(client.Name .. " attempted midroundspawn while having alive character.")
                end
            end
        end)
    end
end

Hook.Add("roundStart", "Neurologics.MidRoundSpawn.RoundStart", function ()
    if not Neurologics.Config.MidRoundSpawn then return end
    if Neurologics.DisableMidRoundSpawn then return end

    -- Reset tables
    hasBeenSpawned = {}
    newPlayers = {}

    -- Flag all lobby players as spawned
    for key, client in pairs(Client.ClientList) do
        if not client.SpectateOnly then
            hasBeenSpawned[client.SteamID] = true
        else
            Neurologics.Log(client.Name .. " is spectating.")
        end
    end
end)

Hook.Add("roundEnd", "Neurologics.MidRoundSpawn.RoundEnd", function ()
    Neurologics.DisableMidRoundSpawn = false
end)

Hook.Add("client.connected", "Neurologics.MidRoundSpawn.ClientConnected", function (newClient)
    if not Neurologics.Config.MidRoundSpawn then return end
    if Neurologics.DisableMidRoundSpawn then return end

    -- client connects, round has started and client has not been considered for spawning yet
    if not Game.RoundStarted or hasBeenSpawned[newClient.SteamID] then return end

    if newClient.InGame then
        -- if client for some reason is already InGame (lobby skip?) spawn
        m.SpawnClientCharacterOnSub(newClient)
    else
        -- else store for later spawn 
        Neurologics.Log("Adding new player to spawn list: " .. newClient.Name)
        table.insert(newPlayers, newClient)

        -- inform player about his luck
        Game.SendDirectChatMessage("", Neurologics.Language.MidRoundSpawnWelcome, nil, ChatMessageType.Private, newClient)
    end
end)

Hook.Add("think", "Neurologics.MidRoundSpawn.Think", function ()
    --if not Neurologics.Config.MidRoundSpawn then return end -- throwing nil error
    if Neurologics.DisableMidRoundSpawn then return end

    if Game.RoundStarted and checkTime and Timer.GetTime() > checkTime then
        checkTime = Timer.GetTime() + checkDelaySeconds

        -- check all NewPlayers and if not spawned already and inGame spawn
        for i = #newPlayers, 1, -1 do
            local newClient = newPlayers[i]

            -- if client still valid and not spawned yet, no spectator and has an active connection
            if newClient and not hasBeenSpawned[newClient.SteamID] and (giveSpectatorsSpawnOption or not newClient.SpectateOnly) and newClient.Connection and newClient.Connection.Status == 1 then
                -- wait for client to be ingame, then cpasn
                if newClient.InGame then
                    m.ShowSpawnDialog(newClient)
                    table.remove(newPlayers, i)
                end
            else
                if (not giveSpectatorsSpawnOption and newClient.SpectateOnly) then
                    Neurologics.Log("Removing spectator from spawn list: " .. newClient.Name)
                else
                    Neurologics.Log("Removing invalid player from spawn list: " .. newClient.Name)
                end
                table.remove(newPlayers, i)
            end
        end
    end
end)

Neurologics.AddCommand("!midroundspawn", function (client, args)
    if not Neurologics.Config.MidRoundSpawn then return end
    if Neurologics.DisableMidRoundSpawn then return end

    if client.InGame then
        if (not hasBeenSpawned[client.SteamID] or client.HasPermission(ClientPermissions.ConsoleCommands)) and (not client.Character or client.Character.IsDead) then
            m.ShowSpawnDialog(client)
        else
            print("You spawned already.")
        end
    else
        print("You are not in-game.")
    end

    return true
end)

Neurologics.MidRoundSpawn = m

return m