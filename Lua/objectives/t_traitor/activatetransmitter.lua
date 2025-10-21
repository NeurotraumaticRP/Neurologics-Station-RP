local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "Activate transmitter"
objective.AmountPoints = 1000
function objective:Start(item)
    self.item = item

    Hook.Add(--[[here will be hook to check if transmitter has been activated, need to make the transmitter first before I can set up the hook]])

    return true
end

function objective:IsCompleted()
    return self.Target.IsDead
end

function objective:TargetPreference(character)
    if character.IsCaptain then
        return false
    end

    return true
end

return false
