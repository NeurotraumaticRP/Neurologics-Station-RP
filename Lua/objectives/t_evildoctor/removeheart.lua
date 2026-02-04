local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "RemoveHeart"
objective.AmountPoints = 1000
objective.Role = {"EvilDoctor"}

function objective:Start(target)
    self.Target = target

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target) .. " " .. self.Target.Name
    self.Text = string.format("Surgically remove %s's heart and ensure they die.", self.TargetName)

    return true
end

function objective:IsCompleted()
    if self.Target == nil then
        return false
    end

    -- Target must be dead AND have heartremoved > 1
    if self.Target.IsDead then
        local heartRemoved = HF.HasAffliction(self.Target, "heartremoved", 1)
        if heartRemoved then
            return true
        end
    end

    return false
end

function objective:IsFailed()
    if self.Target == nil then
        return false
    end

    -- Fail if target is dead but heart NOT removed
    if self.Target.IsDead then
        local heartRemoved = HF.HasAffliction(self.Target, "heartremoved", 1)
        if not heartRemoved then
            return true
        end
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
