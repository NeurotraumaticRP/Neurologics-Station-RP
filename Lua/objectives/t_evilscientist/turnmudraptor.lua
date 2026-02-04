local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "TurnMudraptor"
objective.AmountPoints = 800
objective.Role = {"EvilScientist"} -- Must match role name exactly (case-sensitive)
function objective:Start(target)
    self.Target = target

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target) .. " " .. self.Target.Name

    self.Text = string.format(Neurologics.Language.ObjectiveTurnMudraptor, self.TargetName)

    return true
end

function objective:IsCompleted()
    if self.Target == nil then
        return false
    end

    local aff = self.Target.CharacterHealth.GetAffliction("mudraptorvirus", true)

    if aff ~= nil and aff.Strength > 95 then
        return true
    end

    return false
end

function objective:IsFailed()
    if self.Target == nil then
        return false
    end

    if self.Target.IsDead then
        return true
    end

    return false
end

function objective:TargetPreference(character)
    if character.IsCaptain then
        return false
    end

    return true
end

return objective