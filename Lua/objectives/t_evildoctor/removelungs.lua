local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "RemoveLungs"
objective.AmountPoints = 1000
objective.Role = {"EvilDoctor"}

function objective:Start(target)
    self.Target = target

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target) .. " " .. self.Target.Name
    self.Text = string.format("Surgically remove %s's lungs and ensure they die.", self.TargetName)

    return true
end

function objective:IsCompleted()
    if self.Target == nil then
        return false
    end

    -- Target must be dead AND have lungremoved > 1
    if self.Target.IsDead then
        local lungRemoved = HF.HasAffliction(self.Target, "lungremoved", 1)
        if lungRemoved then
            return true
        end
    end

    return false
end

function objective:IsFailed()
    if self.Target == nil then
        return false
    end

    -- Fail if target is dead but lungs NOT removed
    if self.Target.IsDead then
        local lungRemoved = HF.HasAffliction(self.Target, "lungremoved", 1)
        if not lungRemoved then
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
