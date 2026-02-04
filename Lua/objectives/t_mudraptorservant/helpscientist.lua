--[[
    Help Scientist Objective
    
    Objective for Mudraptor Servants - completes when the Evil Scientist
    who turned them survives the round.
]]

local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "HelpScientist"
objective.AmountPoints = 1000
objective.AlwaysActive = true
objective.Role = {"MudraptorServant"}

function objective:Start(scientist)
    self.Scientist = scientist
    
    if self.Scientist == nil then
        self.Text = "Help the Evil Scientist survive the round"
        return true
    end
    
    self.Text = string.format("Help %s survive the round", self.Scientist.Name)
    
    return true
end

function objective:IsCompleted()
    -- This objective completes at round end if the scientist is alive
    -- Check is done via the roundEnd hook below
    return self.Completed == true
end

function objective:IsFailed()
    -- Fails if the scientist dies
    if self.Scientist and self.Scientist.IsDead then
        return true
    end
    
    return false
end

-- Check at round end if scientist survived
Hook.Add("roundEnd", "MudraptorServant.HelpScientist.RoundEnd", function()
    -- Find all mudraptor servants and check their objectives
    for character, role in pairs(Neurologics.RoleManager.RoundRoles) do
        if role.Name == "MudraptorServant" then
            for _, obj in pairs(role.Objectives) do
                if obj.Name == "HelpScientist" then
                    -- If scientist is alive, mark as completed
                    if obj.Scientist and not obj.Scientist.IsDead then
                        obj.Completed = true
                    end
                end
            end
        end
    end
end)

return objective
