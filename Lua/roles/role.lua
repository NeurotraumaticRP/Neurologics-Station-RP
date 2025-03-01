local role = {}

role.Name = "Role"
role.IsAntagonist = false

function role:Init(character)
    self.Character = character
    self.Objectives = {}
    self.RoundNumber = Neurologics.RoundNumber
end

function role:Transfer(character)
    self.Character = character

    for key, value in pairs(self.Objectives) do
        value.Character = character
    end
end

function role:Start()

end

function role:End(roundEnd)

end

function role:NewMember(character)

end

function role:Greet()
   return ""
end

function role:OtherGreet()
    return ""
end

function role:AssignObjective(objective)
    table.insert(self.Objectives, objective)
end

function role:CompletedObjectives(name)
    local num = 0
    for key, value in pairs(self.Objectives) do
        if value.Name == name then
            num = num + 1
        end
    end
    return num
end

function role:FindValidTarget(objective)
    local targets = {}
    local debug = ""
    for key, value in pairs(Character.CharacterList) do
        if self:FilterTarget(objective, value) and objective:TargetPreference(value) and Vector2.Distance(value.WorldPosition, self.Character.WorldPosition) < 8000 then
            table.insert(targets, value)
            debug = debug .. " | " .. value.Name .. " (" .. tostring(value.Info.Job.Prefab.Identifier) .. value.TeamID .. ")"
        end
    end

    if #targets == 0 then -- if theres no targets, lets ignore preference
        for key, value in pairs(Character.CharacterList) do
            if self:FilterTarget(objective, value) then
                table.insert(targets, value)
                debug = debug .. " | " .. value.Name .. " (" .. tostring(value.Info.Job.Prefab.Identifier) .. value.TeamID .. ")"
            end
        end
    end

    Neurologics.Debug("Selecting new random target out of " .. #targets .. " possible candidates" .. debug)
    if #targets > 0 then
        local chosenTarget = targets[math.random(1, #targets)]
        return chosenTarget
    end

    return nil
end

function role:FilterTarget(objective, character)
    if character == botGod then return false end
    if not character.IsHuman or character.IsDead then return false end
    if objective.RoleFilter ~= nil and not objective.RoleFilter[character.Info.Job.Prefab.Identifier.Value] then
        return false
    end

    if Neurologics.RoleManager.IsSameRole(self, character) then return false end

    return true
end

function role:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

return role
