local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "CrewSurvival"
objective.AmountPoints = 100
objective.EndRoundObjective = true
objective.Job = {"captain"}
objective.ForceJob = {"captain"} -- ALWAYS give to captains

function objective:Start(target)
    self.Text = "100 points per living crew member that survives the round."
    return true
end

function objective:IsCompleted()
    -- Reset and recalculate points each time this is checked
    self.AmountPoints = 0
    local crewCount = 0
    
    for key, character in pairs(Character.CharacterList) do
        -- Count all human crew on Team1 that are alive
        if character.IsHuman and not character.IsDead and character.TeamID == CharacterTeamType.Team1 then
            -- Exclude the captain themselves from the count (they're the one getting the objective)
            if character ~= self.Character then
                self.AmountPoints = self.AmountPoints + 100
                crewCount = crewCount + 1
            end
        end
    end
    
    -- Update the text with current count
    self.Text = string.format("Crew Survival: %d crew members alive (100 points each = %d total)", crewCount, self.AmountPoints)

    if crewCount == 0 then
        return false
    end

    return true
end

return objective

