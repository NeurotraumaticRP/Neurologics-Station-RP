local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "Decapitate"
objective.AmountPoints = 1000
objective.Role = {"EvilDoctor"}

function objective:Start(target)
    self.Target = target

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target) .. " " .. self.Target.Name
    self.Text = string.format("surgically decapitate %s", self.TargetName)

    return true
end

function objective:IsCompleted()
    if self.Target == nil then
        return false
    end

    -- Target must be dead AND have sh_amputation > 1 (decapitated)
    if self.Target.IsDead then
        local amputation = HF.HasAffliction(self.Target, "sh_amputation", 1)
        if amputation then
            return true
        end
    end

    return false
end

function objective:IsFailed()
    if self.Target == nil then
        return false
    end

    -- Fail if target is dead but NOT decapitated
    if self.Target.IsDead then
        local amputation = HF.HasAffliction(self.Target, "sh_amputation", 1)
        if not amputation then
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
