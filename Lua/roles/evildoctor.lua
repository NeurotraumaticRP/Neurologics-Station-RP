--[[
    Evil Doctor Role
    
    A specialized traitor role for doctors and medical staff with unique objectives
    focused on poisoning, malpractice, and medical sabotage.
    
    Inherits from Traitor - gets assassination loop and standard traitor mechanics.
    Sub-objectives are configured in RoleConfig.EvilDoctor
]]

local role = Neurologics.RoleManager.Roles.Traitor:new()
role.Name = "EvilDoctor"

function role:Start()
    -- Track as both EvilDoctor and Traitor for stats
    Neurologics.Stats.AddCharacterStat("EvilDoctor", self.Character, 1)
    Neurologics.Stats.AddCharacterStat("Traitor", self.Character, 1)

    -- Use the parent's assassination loop
    self:AssasinationLoop(true)

    -- Get objectives valid for this character
    local availableObjectives = Neurologics.RoleManager.GetObjectivesForCharacter(self.Character, self)
    
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
                    Neurologics.Stats.AddCharacterStat("EvilDoctorSubObjectives", character, 1)
                end

                if objective:Start(character) then
                    self:AssignObjective(objective)
                    assignedNames[value] = true
                    table.insert(toRemove, key)
                end
            end
        end
    end
    
    -- Remove assigned objectives from pool (iterate in reverse to avoid index shifting)
    table.sort(toRemove, function(a, b) return a > b end)
    for _, idx in ipairs(toRemove) do table.remove(pool, idx) end

    -- Randomly assign remaining objectives up to max
    for i = 1, math.random(self.MinSubObjectives, self.MaxSubObjectives), 1 do
        local objective = Neurologics.RoleManager.RandomObjective(pool)
        if objective == nil then break end

        objective = objective:new()

        local character = self.Character

        objective:Init(character)
        local target = self:FindValidTarget(objective)

        objective.OnAwarded = function ()
            Neurologics.Stats.AddCharacterStat("EvilDoctorSubObjectives", character, 1)
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

    -- Greet the traitor (defer if client not linked yet, e.g. NCS spawn)
    local function doGreet()
        local client = Neurologics.FindClientCharacter(self.Character)
        if client then
            local text = self:Greet()
            if text and text ~= "" then
                if Neurologics.SendTraitorMessageBox then Neurologics.SendTraitorMessageBox(client, text) end
                if Neurologics.UpdateVanillaTraitor then Neurologics.UpdateVanillaTraitor(client, true, text) end
            end
            return true
        end
        return false
    end
    if not doGreet() then
        Timer.Wait(function()
            if self.Character and not self.Character.Removed then doGreet() end
        end, 100)
    end
end

-- Override greet for doctor-specific flavor
function role:Greet()
    local primary, secondary = self:ObjectivesToString()
    
    local sb = Neurologics.StringBuilder:new()
    sb("Your oath means nothing. Use your medical access to complete your objectives.\n\n")
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
