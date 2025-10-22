local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "PoisonCaptain"
objective.RoleFilter = { ["captain"] = true }
objective.AmountPoints = 1600
objective.Role = {"traitor","clown"}
objective.Job = {"doctor"}
function objective:Start(target)
    self.Target = target

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target)

    self.Poison = "Sufforin"

    self.Text = string.format(Neurologics.Language.ObjectivePoisonCaptain, self.TargetName,
        self.Poison)

    return true
end

function objective:IsCompleted()
    if self.Target == nil then
        return
    end

    local aff = self.Target.CharacterHealth.GetAffliction("sufforinpoisoning", true)

    if aff ~= nil and aff.Strength > 10 then
        return true
    end

    return false
end

return objective
