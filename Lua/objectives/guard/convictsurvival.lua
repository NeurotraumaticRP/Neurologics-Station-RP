local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "ConvictSurvival"
objective.AmountPoints = 200
objective.EndRoundObjective = true
objective.Job = {"guard"}
objective.ForceJob = {"guard"} -- ALWAYS give to guards

function objective:Start(target)
    self.Text = "200 points per living, non escaped convict that survives the round."
    return true
end

function objective:IsCompleted()
    -- Reset and recalculate points each time this is checked
    self.AmountPoints = 0
    local convictCount = 0
    
    for key, character in pairs(Character.CharacterList) do
        if character.JobIdentifier == "convict" and not character.IsDead and character.TeamID == CharacterTeamType.Team1 then
            -- Check if they have the Escape objective and if it's been completed/escaped
            local hasEscaped = false
            local role = Neurologics.RoleManager.GetRole(character)
            
            if role and role.Objectives then
                for _, obj in pairs(role.Objectives) do
                    if obj.Name == "Escape" and (obj.HasEscaped or obj.BecamePirate) then
                        hasEscaped = true
                        break
                    end
                end
            end
            
            -- Only count if they haven't escaped
            if not hasEscaped then
                self.AmountPoints = self.AmountPoints + 150
                convictCount = convictCount + 1
            end
        end
    end
    
    -- Update the text with current count
    self.Text = string.format("Convict Survival: %d convicts alive and contained (150 points each = %d total)", convictCount, self.AmountPoints)

    if convictCount == 0 then
        return false
    end

    return true
end

return objective

