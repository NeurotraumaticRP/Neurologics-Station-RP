local event = {}

event.Name = "TraumaTeam"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 1
event.ChancePerMinute = 0  -- Never triggers randomly
event.OnlyOncePerRound = false

-- Active teams data structure
-- { teamID = { character, agents[], objectives[], completionTime, despawnTime } }
event.ActiveTeams = {}
event.NextTeamID = 1

-- Condition is always false so the event will never trigger automatically
event.Conditions = function()
    return false
end

-- Initialize on load
event.Init = function()
    event.ActiveTeams = {}
    event.NextTeamID = 1
    
    -- Initialize the members tracking table if not exists
    if not Neurologics.TraumaTeamMembers then
        Neurologics.TraumaTeamMembers = {}
    end
    
    -- Register kill penalty handler with centralized death system
    Neurologics.RegisterDeathHandler("TraumaTeamKillPenalty", function(character, killer)
        event.CheckKillPenalty(character, killer)
    end)
    
    -- Register CHARACTER-BASED status monitor for unconscious members
    -- This allows tracking both players AND bots
    Neurologics.StatusMonitor.RegisterCharacterMonitor("TraumaTeamMembership", {
        -- Custom function to get only characters with membership
        getCharacters = function()
            local members = {}
            if Neurologics.TraumaTeamMembers then
                for character, _ in pairs(Neurologics.TraumaTeamMembers) do
                    -- Only include valid, alive characters
                    if character and not character.IsDead and not character.Removed then
                        table.insert(members, character)
                    end
                end
            end
            return members
        end,
        
        -- Filter: Only check characters with membership that hasn't been used
        filter = function(character)
            local hasMembership = Neurologics.GetCharacterData(character, "TraumaTeamMember")
            local hasUsed = Neurologics.GetCharacterData(character, "TraumaTeamUsed")
            return hasMembership and not hasUsed
        end,
        
        -- Condition: Character is unconscious (but not dead)
        condition = function(character)
            local isUnconscious = character.IsUnconscious
            local isDead = character.IsDead
            return isUnconscious and not isDead
        end,
        
        -- Threshold: 10 seconds
        threshold = 10,
        
        -- Trigger: Dispatch trauma team for this character
        onTrigger = function(character)
            print(string.format("[TraumaTeam] TRIGGER CALLBACK for character %s", character.Name))
            event.DispatchTeamForCharacter(character)
        end
    })
    
    -- Register cleanup for membership flags
    Neurologics.RegisterCleanup("TraumaTeamMembership", function()
        -- Clear membership data from all tracked characters
        if Neurologics.TraumaTeamMembers then
            for character, _ in pairs(Neurologics.TraumaTeamMembers) do
                if character and not character.Removed then
                    Neurologics.SetCharacterData(character, "TraumaTeamMember", nil)
                    Neurologics.SetCharacterData(character, "TraumaTeamUsed", nil)
                end
            end
        end
        Neurologics.TraumaTeamMembers = {}
    end)
end

-- Dispatch a trauma team for a CHARACTER (new character-based function)
event.DispatchTeamForCharacter = function(character, teamSize)
    
    -- Mark membership as used on the CHARACTER
    Neurologics.SetCharacterData(character, "TraumaTeamUsed", true)
    
    -- Trigger the event with the character as parameter
    local success, result = Neurologics.RunEvent("TraumaTeam", {character, teamSize})
    
    if success then
        
        -- Notify the character's owner if they have one
        Neurologics.SendMessageCharacter(character, "EMERGENCY ALERT: Europan Trauma Corps team has been dispatched to your location!")
        
        -- Notify everyone
        local text = string.format("Emergency alert: ETC team dispatched for %s", character.Name)
        Neurologics.RoundEvents.SendEventMessage(text, "JobIcon.medicaldoctor", Color(100, 200, 255))
    else
    end
end

-- Legacy function for backwards compatibility - converts client to character call
event.DispatchTeam = function(client, teamSize)
    if client and client.Character then
        event.DispatchTeamForCharacter(client.Character, teamSize)
    else
    end
end

-- Parameters:
-- target: The protected character (membership holder) - REQUIRED (can be character or client)
-- teamSize: Number of agents to spawn (optional, default: 2)
event.Start = function(target, teamSize)
    -- Support both character and client as first parameter
    local targetCharacter
    targetCharacter = target
    
    if not targetCharacter then
        Neurologics.Error("TraumaTeam event requires a valid character parameter")
        return
    end
    
    -- Get list of dead players who can become ETC agents
    local deadPlayers = {}
    for _, deadClient in pairs(Client.ClientList) do
        if deadClient.Character == nil or deadClient.Character.IsDead then
            table.insert(deadPlayers, deadClient)
        end
    end
    
    -- Set default team size
    teamSize = teamSize or 2
    
    -- Can't spawn more agents than available dead players
    if #deadPlayers == 0 then
        Neurologics.Error("TraumaTeam: No dead players available to spawn as ETC agents")
        return
    end
    
    -- Limit team size to available dead players
    teamSize = math.min(teamSize, #deadPlayers)
    teamSize = math.max(1, teamSize) -- At least 1
    
    -- Generate unique team ID
    local teamID = event.NextTeamID
    event.NextTeamID = event.NextTeamID + 1
    
    -- Determine spawn position (outside the submarine)
    local spawnPosition = Neurologics.FindRandomSpawnPosition()
    
    -- Fallback to submarine position
    if spawnPosition == nil then
        spawnPosition = Submarine.MainSub.WorldPosition
    end
    
    -- Spawn the ETC agents from dead players
    local agents = {}
    for i = 1, teamSize do
        local deadPlayer = deadPlayers[i]
        if not deadPlayer then
            break
        end
        local character = nil
        if Neurologics == nil then
            character = NCS.SpawnCharacterWithClient("traumateam", spawnPosition, CharacterTeamType.Team1, deadPlayer, nil)
        end
        if character then
            table.insert(agents, character)
            
            -- Tag the character as ETC agent for identification
            Neurologics.SetCharacterData(character, "ETCAgent", true)
            Neurologics.SetCharacterData(character, "ETCTeamID", teamID)
            
            -- Send message to the ETC agent
            Neurologics.SendMessageCharacter(character, 
                string.format("You are an Europan Trauma Corps Agent. Your mission: Resuscitate and stabilize %s. They must be conscious with neurotrauma <30 and heart damage <30.", 
                    targetCharacter.Name), 
                "JobIcon.medicaldoctor")
        end
    end
    
    if #agents == 0 then
        return
    end
    
    -- Try to find the client for the target character (may be nil for bots)
    local targetClient = Neurologics.FindClientCharacter(targetCharacter)
    
    -- Create objectives for each agent
    local objectives = {}
    for _, agent in ipairs(agents) do
        local objective = Neurologics.RoleManager.Objectives.TraumaTeamHeal:new()
        
        -- Pass the target character, optional client, and agents list
        if objective:Start(targetCharacter, targetClient, agents) then
            table.insert(objectives, objective)
            
            -- Assign objective to a temporary role for the agent
            local agentClient = Neurologics.FindClientCharacter(agent)
            if agentClient then
                Neurologics.SetData(agentClient, "ETCObjective", objective)
            end
        end
    end
    
    -- Store team data (now character-based, client is optional)
    event.ActiveTeams[teamID] = {
        character = targetCharacter,  -- The protected character
        client = targetClient,        -- Optional: the client if target is a player
        agents = agents,
        objectives = objectives,
        completionTime = nil,
        despawnTime = nil,
        spawnTime = Timer.GetTime()
    }
    
    -- Send notification
    local text = string.format("Europan Trauma Corps Team #%d of %d agents deployed for %s!", 
        teamID, teamSize, targetCharacter.Name)
    Neurologics.RoundEvents.SendEventMessage(text, "JobIcon.medicaldoctor", Color(100, 200, 255))
    
    local logName = targetClient and Neurologics.ClientLogName(targetClient) or targetCharacter.Name
    Neurologics.Log(string.format("TraumaTeam: Team #%d deployed with %d agents for %s", 
        teamID, #agents, logName))
    
    -- Don't call event.End() - keep event active to run Think() loop
end

-- Think hook to manage active teams
event.Think = function()
    -- If no active teams, end the event
    if next(event.ActiveTeams) == nil then
        event.End()
        return
    end
    
    -- Process all active teams
    for teamID, teamData in pairs(event.ActiveTeams) do
        -- Check if all objectives are completed
        local allCompleted = true
        local anyIncomplete = false
        
        for _, objective in ipairs(teamData.objectives) do
            if objective:IsCompleted() then
                -- Objective complete
            else
                allCompleted = false
                anyIncomplete = true
            end
        end
        
        -- If all objectives complete and no completion time set, record it
        if allCompleted and #teamData.objectives > 0 and not teamData.completionTime then
            teamData.completionTime = Timer.GetTime()
            teamData.despawnTime = teamData.completionTime + 30 -- Despawn after 30 seconds
            
            -- Notify the character (works for both players and bots)
            if teamData.character and not teamData.character.IsDead then
                Neurologics.SendMessageCharacter(teamData.character, "Europan Trauma Corps has successfully completed their mission!")
            end
        end
        
        -- Auto-despawn after timer (DISABLED FOR NOW)
        -- if teamData.despawnTime and Timer.GetTime() >= teamData.despawnTime then
        --     event.DespawnTeam(teamID)
        -- end
        
        -- Clean up if target died or all agents dead
        local allAgentsDead = true
        for _, agent in ipairs(teamData.agents) do
            if agent and not agent.IsDead and not agent.Removed then
                allAgentsDead = false
                break
            end
        end
        
        if allAgentsDead then
            event.ActiveTeams[teamID] = nil
        end
    end
end

-- Despawn a team
event.DespawnTeam = function(teamID)
    local teamData = event.ActiveTeams[teamID]
    if not teamData then return end
    
    -- Remove all agents
    for _, agent in ipairs(teamData.agents) do
        if agent and not agent.IsDead and not agent.Removed then
            Entity.Spawner.AddEntityToRemoveQueue(agent)
        end
    end
    
    -- Clean up team data
    event.ActiveTeams[teamID] = nil
end

-- Find team by agent character
event.FindTeamByAgent = function(agent)
    if not agent then return nil end
    
    local teamID = Neurologics.GetCharacterData(agent, "ETCTeamID")
    if teamID then
        return event.ActiveTeams[teamID]
    end
    
    -- Fallback: search all teams
    for id, teamData in pairs(event.ActiveTeams) do
        for _, teamAgent in ipairs(teamData.agents) do
            if teamAgent.ID == agent.ID then
                return teamData
            end
        end
    end
    
    return nil
end

-- Check if a character death should result in a penalty
event.CheckKillPenalty = function(character, killer)
    if not character or not killer then return end
    
    -- Check if killer is an ETC agent
    local isETCAgent = Neurologics.GetCharacterData(killer, "ETCAgent")
    if not isETCAgent then return end
    
    -- Find the team this agent belongs to
    local teamData = event.FindTeamByAgent(killer)
    if not teamData then
        Neurologics.Debug("Kill by ETC agent but no team found")
        return
    end
    
    local protectedCharacter = teamData.character
    local protectedClient = teamData.client  -- May be nil for bots
    
    Neurologics.Debug(string.format("ETC agent %s killed %s - checking penalty conditions", 
        killer.Name, character.Name))
    
    -- Exception 1: Victim was a traitor - NO PENALTY
    local victimRole = Neurologics.RoleManager.GetRole(character)
    if victimRole and victimRole.Antagonist then
        Neurologics.Debug("No penalty: Victim was a traitor")
        return
    end
    
    -- Exception 2: Victim was not on Team1 - NO PENALTY
    if character.TeamID ~= CharacterTeamType.Team1 then
        Neurologics.Debug("No penalty: Victim was not on Team1")
        return
    end
    
    -- Exception 3: Victim attacked the protected character - NO PENALTY
    if protectedCharacter and Neurologics.PlayerHasAttacked(character, protectedCharacter, 120) then
        Neurologics.Debug("No penalty: Victim attacked protected character within 120s")
        return
    end
    
    -- Exception 4: Victim attacked this ETC agent - NO PENALTY
    if Neurologics.PlayerHasAttacked(character, killer, 120) then
        Neurologics.Debug("No penalty: Victim attacked ETC agent within 120s")
        return
    end
    
    -- No exceptions apply - APPLY PENALTY
    local penaltyAmount = 250
    
    -- Only apply point penalty if there's a client to penalize
    if protectedClient then
        Neurologics.Log(string.format("PENALTY: ETC agent %s killed innocent %s - deducting %d points from %s", 
            killer.Name, character.Name, penaltyAmount, Neurologics.ClientLogName(protectedClient)))
        
        -- Deduct points from the protected client
        Neurologics.AddData(protectedClient, "Points", -penaltyAmount)
        
        -- Notify the protected client
        Neurologics.SendMessage(protectedClient, 
            string.format("PENALTY: Your Trauma Team killed %s! -%d points.", character.Name, penaltyAmount))
        
        -- Notify admins
        for client in Client.ClientList do
            if client.HasPermission(ClientPermissions.ConsoleCommands) then
                Neurologics.SendMessage(client, 
                    string.format("[ETC PENALTY] %s's team killed %s - %d points deducted", 
                        protectedClient.Name, character.Name, penaltyAmount))
            end
        end
    else
        -- Bot case - just log it
        Neurologics.Log(string.format("PENALTY (Bot): ETC agent %s killed innocent %s (protected: %s, no point penalty)", 
            killer.Name, character.Name, protectedCharacter.Name))
        
        -- Notify admins
        for client in Client.ClientList do
            if client.HasPermission(ClientPermissions.ConsoleCommands) then
                Neurologics.SendMessage(client, 
                    string.format("[ETC PENALTY] %s's team killed %s (bot - no points)", 
                        protectedCharacter.Name, character.Name))
            end
        end
    end
end

event.End = function(isRoundEnd)
    if isRoundEnd then
        -- Clean up all teams on round end
        for teamID, _ in pairs(event.ActiveTeams) do
            event.DespawnTeam(teamID)
        end
        event.ActiveTeams = {}
        event.NextTeamID = 1
    end
end

return event
