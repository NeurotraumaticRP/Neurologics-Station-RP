local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "AssassinateCancer"
objective.AmountPoints = 800
objective.Role = {"EvilScientist"}
objective.Job = {"scientist"}
function objective:Start(target)
    self.Target = target

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target)

    self.Poison = "Cancer"

    self.Text = string.format(Neurologics.Language.ObjectiveAssassinateCancer, self.TargetName, self.Target.Name,
        self.Poison)

    return true
end

function objective:IsCompleted()
    if self.Target == nil then
        return
    end

    local aff = self.Target.CharacterHealth.GetAffliction("cancer", true)

    -- If the target has cancer and it's strength is greater than 90, or if the target is dead and the cancer is still present, then the objective is completed
    if (aff ~= nil and aff.Strength > 90) or (self.Target.IsDead and aff ~= nil and aff.Strength >= 1) then
        return true
    end

    return false
end

return objective
