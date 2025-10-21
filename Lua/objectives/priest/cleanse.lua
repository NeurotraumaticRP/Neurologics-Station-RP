local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "PriestCleanse"
objective.AmountPoints = 1500
objective.Job = {"priest"}
objective.ForceJob = {"priest"} -- ALWAYS give to priests

function objective:Start(target)
    self.Text = "Locate a traitor and cleanse them of their sins."
    return true
end

function objective:IsCompleted()
    for key, value in pairs(Character.CharacterList) do
        if Neurologics.RoleManager.IsAntagonist(value) then
            if HF.HasAffliction(value, "cleansingflame", 10) then
                return true
            end
        end
    end
end

return objective