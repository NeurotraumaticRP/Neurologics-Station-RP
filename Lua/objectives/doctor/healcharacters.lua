local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "HealCharacters"
objective.AmountPoints = 400
objective.Amount = 500
objective.Job = {"doctor", "cmo"} -- Available to medical staff

function objective:Start(target)
    self.Progress = 0

    self.Text = string.format(Neurologics.Language.ObjectiveHealCharacters, math.floor(self.Progress), self.Amount, self.MinCondition)

    return true
end

function objective:CharacterHealed(character, healer, amount)
    if healer ~= self.Character then return end

    self.Progress = self.Progress + amount
    self.Text = string.format(Neurologics.Language.ObjectiveHealCharacters, math.floor(self.Progress), self.Amount, self.MinCondition)
end

function objective:IsCompleted()
    if self.Progress >= self.Amount then
        return true
    end

    return false
end

return objective
