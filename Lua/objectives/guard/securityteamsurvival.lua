local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "SecurityTeamSurvival"
objective.AmountPoints = 250
objective.EndRoundObjective = true
objective.Job = {"warden"}
objective.ForceJob = {"warden"} -- ALWAYS give to wardens

function objective:Start(target)
    self.Text = "250 points per living security guard that survives the round."
    -- Don't set to 0 here, keep the default from the class definition
    return true
end

function objective:IsCompleted()
    -- Reset and recalculate points each time this is checked
    self.AmountPoints = 0
    local guardCount = 0
    
    for key, value in pairs(Character.CharacterList) do
        if value.JobIdentifier == "guard" and not value.IsDead and value.TeamID == CharacterTeamType.Team1 then
            self.AmountPoints = self.AmountPoints + 250
            guardCount = guardCount + 1
        end
    end
    
    -- Update the text with current count
    self.Text = string.format("Security Team Survival: %d guards alive (250 points each = %d total)", guardCount, self.AmountPoints)

    if guardCount == 0 then
        return false
    end

    return true
end

return objective
