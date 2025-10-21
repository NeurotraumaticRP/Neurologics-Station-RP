local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "FinishRoundFast"
objective.AmountPoints = 450
objective.EndRoundObjective = true
objective.Job = {"traitor","clown"}
function objective:Start(target)
    self.Text = Neurologics.Language.ObjectiveFinishRoundFast

    return true
end

function objective:IsCompleted()
    if Neurologics.RoundTime < 60 * 20 then
        return false
    end

    if Neurologics.EndReached(self.Character, 5000) then
        return true
    end

    return false
end

return objective
