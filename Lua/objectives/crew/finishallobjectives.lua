local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "FinishAllObjectives"
objective.Text = Neurologics.Language.ObjectiveFinishAllObjectives
objective.EndRoundObjective = false
objective.AmountPoints = 0
objective.AmountLives = 1
objective.Job = true -- All jobs
objective.Role = true -- All roles
function objective:Start()
    return true
end

function objective:IsCompleted()
    local role = Neurologics.RoleManager.GetRole(self.Character)

    if role == nil then return false end

    local objectivesAwarded = 0
    local objectivesMax = 0
    for key, value in pairs(role.Objectives) do
        if value.Awarded then objectivesAwarded = objectivesAwarded + 1 end

        objectivesMax = objectivesMax + 1
    end

    return objectivesAwarded >= objectivesMax - 1
end

return objective