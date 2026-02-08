local role = Neurologics.RoleManager.Roles.Role:new()
role.Name = "Crew"
role.Antagonist = false

function role:Start()
    -- Get objectives valid for this character based on job/role
    local availableObjectives = Neurologics.RoleManager.GetObjectivesForCharacter(self.Character, self)

    if not availableObjectives or #availableObjectives == 0 then
        return
    end
    

    local jobId = self.Character.Info.Job.Prefab.Identifier.Value
    local assignedCount = 0
    local assignedNames = {}
    
    -- STEP 1: Assign all FORCED objectives first
    for _, objName in ipairs(availableObjectives) do
        local objectiveTemplate = Neurologics.RoleManager.FindObjective(objName)
        
        if objectiveTemplate and (objectiveTemplate.ForceJob or objectiveTemplate.ForceRole) then
            local shouldForce = false
            
            -- Check if ForceJob matches
            if objectiveTemplate.ForceJob then
                if objectiveTemplate.ForceJob == true then
                    shouldForce = true
                elseif type(objectiveTemplate.ForceJob) == "string" and objectiveTemplate.ForceJob == jobId then
                    shouldForce = true
                elseif type(objectiveTemplate.ForceJob) == "table" then
                    for _, forcedJob in ipairs(objectiveTemplate.ForceJob) do
                        if forcedJob == jobId then
                            shouldForce = true
                            break
                        end
                    end
                end
            end
            
            -- Check if ForceRole matches
            if objectiveTemplate.ForceRole and self.Name then
                if objectiveTemplate.ForceRole == true then
                    shouldForce = true
                elseif type(objectiveTemplate.ForceRole) == "string" and objectiveTemplate.ForceRole == self.Name then
                    shouldForce = true
                elseif type(objectiveTemplate.ForceRole) == "table" then
                    for _, forcedRole in ipairs(objectiveTemplate.ForceRole) do
                        if forcedRole == self.Name then
                            shouldForce = true
                            break
                        end
                    end
                end
            end
            
            if shouldForce then
                local objective = objectiveTemplate:new()
                objective:Init(self.Character)
                local target = self:FindValidTarget(objective)
                
                if objective:Start(target) then
                    self:AssignObjective(objective)
                    assignedCount = assignedCount + 1
                    assignedNames[objName] = true
                end
            end
        end
    end

    -- STEP 2: Build pool of remaining (non-forced, non-assigned) objectives
    local pool = {}
    for _, objName in ipairs(availableObjectives) do
        if not assignedNames[objName] then
            table.insert(pool, objName)
        end
    end
    
    -- STEP 3: Randomly assign up to 3 total objectives (including forced ones)
    local maxObjectives = 3
    while assignedCount < maxObjectives and #pool > 0 do
        local objective = Neurologics.RoleManager.RandomObjective(pool)
        if objective == nil then break end

        objective = objective:new()

        local character = self.Character
        objective:Init(character)
        local target = self:FindValidTarget(objective)

        if objective:Start(target) then
            self:AssignObjective(objective)
            assignedCount = assignedCount + 1
            for key, value in pairs(pool) do
                if value == objective.Name then
                    table.remove(pool, key)
                    break
                end
            end
        else
            -- Remove failed objective from pool to avoid retry
            for key, value in pairs(pool) do
                if value == objective.Name then
                    table.remove(pool, key)
                    break
                end
            end
        end
    end

    local finishObjectives = Neurologics.RoleManager.FindObjective("FinishAllObjectives"):new()
    finishObjectives:Init(self.Character)
    self:AssignObjective(finishObjectives)


    local text = self:Greet()
    local client = Neurologics.FindClientCharacter(self.Character)
    if client then
        Neurologics.SendChatMessage(client, text, Color.Green)
    end
end


function role:End(roundEnd)

end

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
    sb(Neurologics.Language.CrewMember)
    sb(objectives)

    return sb:concat()
end

function role:OtherGreet()
    return nil -- No other greet.
end


return role
