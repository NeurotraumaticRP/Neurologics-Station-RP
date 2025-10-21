local role = Neurologics.RoleManager.Roles.Antagonist:new()
role.Name = "Traitor"

function role:AssasinationLoop(first)
    if not Game.RoundStarted then return end
    if self.RoundNumber ~= Neurologics.RoundNumber then return end

    local this = self

    local assassinate = Neurologics.RoleManager.Objectives.Assassinate:new()
    assassinate:Init(self.Character)
    local target = self:FindValidTarget(assassinate)
    if not self.Character.IsDead and assassinate:Start(target) then
        self:AssignObjective(assassinate)

        local num = self:CompletedObjectives("Assassinate")
        assassinate.AmountPoints = assassinate.AmountPoints + (num * self.PointsPerAssassination)

        local client = Neurologics.FindClientCharacter(self.Character)

        assassinate.OnAwarded = function()
            if client then
                Neurologics.SendMessage(client, Neurologics.Language.AssassinationNextTarget, "")
                Neurologics.Stats.AddClientStat("TraitorMainObjectives", client, 1)
            end

            local delay = math.random(this.NextObjectiveDelayMin, this.NextObjectiveDelayMax) * 1000
            Timer.Wait(function(...)
                this:AssasinationLoop()
            end, delay)
        end


        if client and not first then
            Neurologics.SendMessage(client, string.format(Neurologics.Language.AssassinationNewObjective, target.Name),
                "GameModeIcon.pvp")
            Neurologics.UpdateVanillaTraitor(client, true, self:Greet())
        end
    else
        Timer.Wait(function()
            this:AssasinationLoop()
        end, 5000)
    end
end

function role:Start()
    Neurologics.Stats.AddCharacterStat("Traitor", self.Character, 1)

    self:AssasinationLoop(true)

    -- Get objectives valid for this traitor character
    local availableObjectives = Neurologics.RoleManager.GetObjectivesForCharacter(self.Character, self)
    
    -- Build pool from SubObjectives config, but only include those that match job/role
    local pool = {}
    for key, value in pairs(self.SubObjectives) do
        -- Check if this objective is in the available list
        for _, availableName in ipairs(availableObjectives) do
            if value == availableName then
                table.insert(pool, value)
                break
            end
        end
    end

    local jobId = self.Character.Info.Job.Prefab.Identifier.Value
    local assignedNames = {}
    
    -- First pass: Assign AlwaysActive and Forced objectives
    local toRemove = {}
    for key, value in pairs(pool) do
        local objective = Neurologics.RoleManager.FindObjective(value)
        if objective ~= nil then
            local shouldAssign = false
            
            -- Check if AlwaysActive
            if objective.AlwaysActive then
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
                objective = objective:new()
                local character = self.Character

                objective:Init(character)
                objective.OnAwarded = function ()
                    Neurologics.Stats.AddCharacterStat("TraitorSubObjectives", character, 1)
                end

                if objective:Start(character) then
                    self:AssignObjective(objective)
                    assignedNames[value] = true
                    table.insert(toRemove, key)
                end
            end
        end
    end
    
    -- Remove assigned objectives from pool
    for key, value in pairs(toRemove) do table.remove(pool, value) end

    for i = 1, math.random(self.MinSubObjectives, self.MaxSubObjectives), 1 do
        local objective = Neurologics.RoleManager.RandomObjective(pool)
        if objective == nil then break end

        objective = objective:new()

        local character = self.Character

        objective:Init(character)
        local target = self:FindValidTarget(objective)

        objective.OnAwarded = function ()
            Neurologics.Stats.AddCharacterStat("TraitorSubObjectives", character, 1)
        end

        if objective:Start(target) then
            self:AssignObjective(objective)
            for key, value in pairs(pool) do
                if value == objective.Name then
                    table.remove(pool, key)
                end
            end
        end
    end

    local text = self:Greet()
    local client = Neurologics.FindClientCharacter(self.Character)
    if client then
        Neurologics.SendTraitorMessageBox(client, text)
        Neurologics.UpdateVanillaTraitor(client, true, text)
    end
end


function role:End(roundEnd)
    local client = Neurologics.FindClientCharacter(self.Character)
    if not roundEnd and client then
        Neurologics.SendMessage(client, Neurologics.Language.TraitorDeath, "InfoFrameTabButton.Traitor")
        Neurologics.UpdateVanillaTraitor(client, false)
    end
end

---@return string mainPart, string subPart
function role:ObjectivesToString()
    local primary = Neurologics.StringBuilder:new()
    local secondary = Neurologics.StringBuilder:new()

    for _, objective in pairs(self.Objectives) do
        -- Assassinate objectives are primary
        local buf = objective.Name == "Assassinate" and primary or secondary

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

function role:Greet()
    local partners = Neurologics.StringBuilder:new()
    local traitors = Neurologics.RoleManager.FindAntagonists()
    for _, character in pairs(traitors) do
        if character ~= self.Character then
            partners('"%s" ', character.Name)
        end
    end
    partners = partners:concat(" ")
    local primary, secondary = self:ObjectivesToString()

    local sb = Neurologics.StringBuilder:new()
    sb("%s\n\n", Neurologics.Language.TraitorYou)
    sb("%s\n", Neurologics.Language.MainObjectivesYou)
    sb(primary)
    sb("\n\n%s\n", Neurologics.Language.SecondaryObjectivesYou)
    sb(secondary)
    sb("\n\n")
    if #traitors < 2 then
        sb(Neurologics.Language.SoloAntagonist)
    elseif self.TraitorMethodCommunication == "Names" then
        sb(Neurologics.Language.Partners, partners)
        sb("\n")

        if self.TraitorBroadcast then
            sb(Neurologics.Language.TcTip)
        end
    elseif self.TraitorMethodCommunication == "Codewords" then
        sb("Use code words the find your partners\n")
        sb("Code Words: ")
        for key, value in pairs(Neurologics.CodeWords[1]) do
            sb("\"%s\" ", value)
        end
        sb("\nCode Responses: ")
        for key, value in pairs(Neurologics.CodeWords[2]) do
            sb("\"%s\" ", value)
        end
    end

    return sb:concat()
end

function role:OtherGreet()
    local sb = Neurologics.StringBuilder:new()
    local primary, secondary = self:ObjectivesToString()
    sb(Neurologics.Language.TraitorOther, self.Character.Name)
    sb("\n%s\n", Neurologics.Language.MainObjectivesOther)
    sb(primary)
    sb("\n%s\n", Neurologics.Language.SecondaryObjectivesOther)
    sb(secondary)
    return sb:concat()
end

function role:FilterTarget(objective, character)
    if not self.SelectBotsAsTargets and character.IsBot then return false end

    if objective.Name == "Assassinate" and self.SelectUniqueTargets then
        for key, value in pairs(Neurologics.RoleManager.FindCharactersByRole("Traitor")) do
            local targetRole = Neurologics.RoleManager.GetRole(value)

            for key, obj in pairs(targetRole.Objectives) do
                if obj.Name == "Assassinate" and obj.Target == character then
                    return false
                end
            end
        end
    end

    if character.TeamID ~= CharacterTeamType.Team1 and not self.SelectPiratesAsTargets then
        return false
    end

    return Neurologics.RoleManager.Roles.Antagonist.FilterTarget(self, objective, character)
end

return role
