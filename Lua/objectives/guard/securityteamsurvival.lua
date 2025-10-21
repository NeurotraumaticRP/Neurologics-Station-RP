local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "SecurityTeamSurvival"
objective.AmountPoints = 400
objective.EndRoundObjective = true
objective.Job = {"guard", "warden"} -- Available to security personnel

function objective:Start(target)
    self.Text = Neurologics.Language.SecurityTeamSurvival

    return true
end

function objective:IsCompleted()
    for key, value in pairs(Character.CharacterList) do
        if value.HasJob("guard") and not value.IsDead and value.TeamID == CharacterTeamType.Team1 then
            return true
        end
    end

    return false
end

return objective
