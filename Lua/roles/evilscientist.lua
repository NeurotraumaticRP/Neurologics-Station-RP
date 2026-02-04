--[[
    Evil Scientist Role
    
    A specialized traitor role for scientists with unique objectives
    focused on experimentation and mutation.
    
    Main objective: TurnMudraptor (instead of Assassinate)
    Sub-objectives are configured in RoleConfig.EvilScientist
]]

local role = Neurologics.RoleManager.Roles.Antagonist:new()
role.Name = "EvilScientist"

-- Main objective name for this role
local MAIN_OBJECTIVE = "TurnMudraptor"

-- Main objective loop - assigns TurnMudraptor objectives
function role:EvilScientistLoop(first)
    if not Game.RoundStarted then return end
    if self.RoundNumber ~= Neurologics.RoundNumber then return end

    local this = self

    local objective = Neurologics.RoleManager.Objectives[MAIN_OBJECTIVE]:new()
    objective:Init(self.Character)
    local target = self:FindValidTarget(objective)
    
    if not self.Character.IsDead and target and objective:Start(target) then
        self:AssignObjective(objective)

        local client = Neurologics.FindClientCharacter(self.Character)

        objective.OnAwarded = function()
            if client then
                Neurologics.SendMessage(client, "Excellent! The mutation was a success. Find another subject.", "")
                Neurologics.Stats.AddClientStat("TraitorMainObjectives", client, 1)
            end

            local delay = math.random(this.NextObjectiveDelayMin, this.NextObjectiveDelayMax) * 1000
            Timer.Wait(function(...)
                this:EvilScientistLoop()
            end, delay)
        end

        if client and not first then
            Neurologics.SendMessage(client, string.format("New objective: Infect %s with the mudraptor virus!", target.Name),
                "GameModeIcon.pvp")
            Neurologics.UpdateVanillaTraitor(client, true, self:Greet())
        end
    else
        Timer.Wait(function()
            this:EvilScientistLoop()
        end, 5000)
    end
end

function role:Start()
    -- Track as both EvilScientist and Traitor for stats
    Neurologics.Stats.AddCharacterStat("EvilScientist", self.Character, 1)
    Neurologics.Stats.AddCharacterStat("Traitor", self.Character, 1)

    -- Use the EvilScientist main objective loop (TurnMudraptor)
    self:EvilScientistLoop(true)

    -- Debug: Print SubObjectives
    print("[EvilScientist] Starting for " .. self.Character.Name)
    print("[EvilScientist] SubObjectives: " .. (self.SubObjectives and table.concat(self.SubObjectives, ", ") or "NIL"))

    -- Get objectives valid for this character
    local availableObjectives = Neurologics.RoleManager.GetObjectivesForCharacter(self.Character, self)
    print("[EvilScientist] Available objectives: " .. table.concat(availableObjectives, ", "))
    
    -- Build pool from SubObjectives config, but only include those that match job/role
    local pool = {}
    if self.SubObjectives then
        for key, value in pairs(self.SubObjectives) do
            -- Check if this objective is in the available list
            for _, availableName in ipairs(availableObjectives) do
                if value == availableName then
                    table.insert(pool, value)
                    break
                end
            end
        end
    end
    print("[EvilScientist] Pool after filtering: " .. table.concat(pool, ", "))

    local jobId = self.Character.Info.Job.Prefab.Identifier.Value
    local assignedNames = {}
    
    -- First pass: Assign AlwaysActive and Forced objectives
    print("[EvilScientist] First pass - checking for AlwaysActive/Forced objectives")
    local toRemove = {}
    for key, value in pairs(pool) do
        local objective = Neurologics.RoleManager.FindObjective(value)
        if objective ~= nil then
            local shouldAssign = false
            
            -- Check if AlwaysActive
            if objective.AlwaysActive then
                print("[EvilScientist] " .. value .. " has AlwaysActive=true")
                shouldAssign = true
            end
            
            -- Check if ForceJob matches
            if objective.ForceJob then
                if objective.ForceJob == true then
                    shouldAssign = true
                elseif type(objective.ForceJob) == "string" and objective.ForceJob == jobId then
                    shouldAssign = true
                elseif type(objective.ForceJob) == "table" then
                    for _, forcedJob in ipairs(objective.ForceJob) do
                        if forcedJob == jobId then
                            shouldAssign = true
                            break
                        end
                    end
                end
            end
            
            -- Check if ForceRole matches
            if objective.ForceRole then
                if objective.ForceRole == true then
                    shouldAssign = true
                elseif type(objective.ForceRole) == "string" and objective.ForceRole == self.Name then
                    shouldAssign = true
                elseif type(objective.ForceRole) == "table" then
                    for _, forcedRole in ipairs(objective.ForceRole) do
                        if forcedRole == self.Name then
                            shouldAssign = true
                            break
                        end
                    end
                end
            end
            
            if shouldAssign then
                print("[EvilScientist] Attempting to assign forced/always-active: " .. value)
                objective = objective:new()
                local character = self.Character

                objective:Init(character)
                objective.OnAwarded = function ()
                    Neurologics.Stats.AddCharacterStat("EvilScientistSubObjectives", character, 1)
                end

                if objective:Start(character) then
                    self:AssignObjective(objective)
                    print("[EvilScientist] Successfully assigned: " .. value)
                    assignedNames[value] = true
                    table.insert(toRemove, key)
                else
                    print("[EvilScientist] Start() returned false for: " .. value)
                end
            end
        end
    end
    
    -- Remove assigned objectives from pool (iterate in reverse to avoid index shifting)
    table.sort(toRemove, function(a, b) return a > b end)
    for _, idx in ipairs(toRemove) do table.remove(pool, idx) end

    -- Randomly assign remaining objectives up to max
    local minObj = self.MinSubObjectives or 1
    local maxObj = self.MaxSubObjectives or 2
    print("[EvilScientist] Assigning " .. minObj .. " to " .. maxObj .. " objectives from pool of " .. #pool)
    
    for i = 1, math.random(minObj, maxObj), 1 do
        local objective = Neurologics.RoleManager.RandomObjective(pool)
        if objective == nil then 
            print("[EvilScientist] RandomObjective returned nil, breaking")
            break 
        end

        print("[EvilScientist] Trying to assign: " .. objective.Name)
        objective = objective:new()

        local character = self.Character

        objective:Init(character)
        local target = self:FindValidTarget(objective)

        objective.OnAwarded = function ()
            Neurologics.Stats.AddCharacterStat("EvilScientistSubObjectives", character, 1)
        end

        if objective:Start(target) then
            self:AssignObjective(objective)
            print("[EvilScientist] Assigned objective: " .. objective.Name)
            for key, value in pairs(pool) do
                if value == objective.Name then
                    table.remove(pool, key)
                end
            end
        else
            print("[EvilScientist] objective:Start() returned false for " .. objective.Name)
        end
    end
    
    print("[EvilScientist] Total objectives assigned: " .. #self.Objectives)

    -- Greet the traitor
    local client = Neurologics.FindClientCharacter(self.Character)
    if client then
        if self.TraitorBroadcast then
            Neurologics.UpdateVanillaTraitor(client, true, self:Greet())
        else
            Neurologics.UpdateVanillaTraitor(client, true, Neurologics.Language.TraitorWelcome)
        end
    end
end

-- Format objectives for display
function role:ObjectivesToString()
    local primary = Neurologics.StringBuilder:new()
    local secondary = Neurologics.StringBuilder:new()

    for _, objective in pairs(self.Objectives) do
        -- TurnMudraptor objectives are primary, others are secondary
        local buf = objective.Name == MAIN_OBJECTIVE and primary or secondary

        if objective:IsCompleted() or objective.Awarded then
            buf:append(" > ", objective.Text, Neurologics.Language.Completed)
        else
            buf:append(" > ", objective.Text, string.format(Neurologics.Language.Points, objective.AmountPoints))
        end
    end
    if #primary == 0 then
        primary(Neurologics.Language.NoObjectivesYet)
    end

    return primary:concat("\n"), secondary:concat("\n")
end

-- Override greet for scientist-specific flavor
function role:Greet()
    local primary, secondary = self:ObjectivesToString()
    
    local sb = Neurologics.StringBuilder:new()
    sb("Your experiments have taken a dark turn.\n\n")
    sb("%s\n", Neurologics.Language.MainObjectivesYou)
    sb(primary)
    sb("\n\n%s\n", Neurologics.Language.SecondaryObjectivesYou)
    sb(secondary)
    sb("\n\n")
    
    -- Find fellow antagonists
    local traitors = Neurologics.RoleManager.FindAntagonists()
    if #traitors < 2 then
        sb(Neurologics.Language.SoloAntagonist)
    elseif self.TraitorMethodCommunication == "Names" then
        local partners = Neurologics.StringBuilder:new()
        for _, character in pairs(traitors) do
            if character ~= self.Character then
                partners('"%s" ', character.Name)
            end
        end
        sb(Neurologics.Language.Partners, partners:concat(" "))
        sb("\n")
        if self.TraitorBroadcast then
            sb(Neurologics.Language.TcTip)
        end
    end
    
    return sb:concat()
end

return role
