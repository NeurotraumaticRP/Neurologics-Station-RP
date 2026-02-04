local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "SurgicalBombAssassination"
objective.AmountPoints = 1000
objective.Role = {"EvilDoctor"}

-- Track detonated characters via hook
local detonatedCharacters = {}

Hook.Add("Javier.CharacterDetonated", "SurgicalBombAssassination.Track", function(character)
    if character then
        detonatedCharacters[character] = true
    end
end)

-- Clear tracking on round end
Hook.Add("roundEnd", "SurgicalBombAssassination.Reset", function()
    detonatedCharacters = {}
end)

function objective:Start(target)
    self.Target = target

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target) .. " " .. self.Target.Name
    self.Text = string.format("Kill %s with a surgical bomb", self.TargetName)

    return true
end

function objective:IsCompleted()
    if self.Target == nil then
        return false
    end

    -- Target was detonated by surgical bomb
    if detonatedCharacters[self.Target] then
        return true
    end

    return false
end

function objective:IsFailed()
    if self.Target == nil then
        return false
    end

    -- Fail if target is dead but was NOT detonated by surgical bomb
    if self.Target.IsDead and not detonatedCharacters[self.Target] then
        return true
    end

    return false
end

function objective:TargetPreference(character)
    -- Prefer non-captain targets
    if character.IsCaptain then
        return false
    end

    return true
end

return objective
