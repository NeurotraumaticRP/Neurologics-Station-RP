local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "Survive"
objective.Text = Neurologics.Language.ObjectiveSurvive
objective.EndRoundObjective = true
objective.AlwaysActive = true
objective.AmountPoints = 500
objective.AmountLives = 1
objective.Role = true -- Available to all roles


function objective:Start()
    return true
end

function objective:IsCompleted()
    local role = Neurologics.RoleManager.GetRole(self.Character)

    if role == nil then return false end

    local anyObjective = false
    for key, value in pairs(role.Objectives) do
        if value.Awarded then anyObjective = true end
    end

    return anyObjective and not self.Character.IsDead
end

return objective