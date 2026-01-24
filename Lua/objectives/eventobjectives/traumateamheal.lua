local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "TraumaTeamHeal"
objective.AmountPoints = 1000

-- Start the objective
-- target: The character to heal
-- protectedClient: The original membership holder
-- team: All ETC agents on this team
function objective:Start(target, protectedClient, team)
    self.Target = target
    self.ProtectedClient = protectedClient
    self.Team = team or {}

    if self.Target == nil then
        return false
    end

    self.TargetName = Neurologics.GetJobString(self.Target)

    self.Text = string.format("Resuscitate and stabilize %s (Awake, Neurotrauma <30, Heart Damage <30)", self.TargetName)

    return true
end

-- Check if objective is completed
function objective:IsCompleted()
    if self.Target == nil or self.Target.IsDead then
        return false
    end

    -- Must not be unconscious
    if self.Target.IsUnconscious then
        return false
    end

    -- Check neurotrauma
    local neuro = self.Target.CharacterHealth.GetAffliction("neurotrauma", true)
    local neuroStr = neuro and neuro.Strength or 0
    
    if neuroStr >= 30 then
        return false
    end

    -- Check heart damage
    local heart = self.Target.CharacterHealth.GetAffliction("heartdamage", true)
    local heartStr = heart and heart.Strength or 0
    
    if heartStr >= 30 then
        return false
    end

    -- All conditions met
    return true
end

-- Get progress text for UI
function objective:GetProgress()
    if not self.Target or self.Target.IsDead then
        return "Target deceased"
    end

    local neuro = self.Target.CharacterHealth.GetAffliction("neurotrauma", true)
    local neuroStr = neuro and neuro.Strength or 0
    
    local heart = self.Target.CharacterHealth.GetAffliction("heartdamage", true)
    local heartStr = heart and heart.Strength or 0
    
    local status = {}
    
    if self.Target.IsUnconscious then
        table.insert(status, "Unconscious")
    else
        table.insert(status, "Conscious ✓")
    end
    
    if neuroStr < 30 then
        table.insert(status, string.format("Neuro: %.1f ✓", neuroStr))
    else
        table.insert(status, string.format("Neuro: %.1f", neuroStr))
    end
    
    if heartStr < 30 then
        table.insert(status, string.format("Heart: %.1f ✓", heartStr))
    else
        table.insert(status, string.format("Heart: %.1f", heartStr))
    end
    
    return table.concat(status, " | ")
end

return objective