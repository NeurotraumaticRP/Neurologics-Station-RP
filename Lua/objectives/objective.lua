local objective = {}

objective.Name = "Objective"
objective.Text = "Complete the objective!"
objective.AmountPoints = 100
objective.EndRoundObjective = false
objective.DontLooseLives = false
objective.Job = nil -- Can be string or table of strings (e.g., "doctor" or {"doctor", "cmo"})
objective.Role = nil -- Can be string or table of strings (e.g., "traitor" or {"traitor", "cultist"})

objective.Awarded = false

function objective:Static() end

function objective:Init(character)
    self.Character = character
end

function objective:Start()
    return true
end

function objective:IsCompleted()
    return true
end

function objective:TargetPreference(character) return true end
function objective:CharacterDeath(character) end
function objective:StopRepairing(item, character) end
function objective:HullRepaired(item, character) end
function objective:CharacterHealed(character, healer, healthChange) end

function objective:IsFailed()
    return false
end

function objective:Award()
    self.Awarded = true

    local client = Neurologics.FindClientCharacter(self.Character)

    if client then 
        local points = Neurologics.AwardPoints(client, self.AmountPoints)
        local lives = Neurologics.AdjustLives(client, self.AmountLives)
        Neurologics.SendObjectiveCompleted(client, self.Text, points, lives)

        if self.DontLooseLives then
            Neurologics.LostLivesThisRound[client.SteamID] = true
        end
    end

    if self.OnAwarded ~= nil then
        self:OnAwarded()
    end
end

function objective:Fail()
    self.Awarded = true
    
    local client = Neurologics.FindClientCharacter(self.Character)

    if client then 
        Neurologics.SendObjectiveFailed(client, self.Text)
    end

    if self.OnAwarded ~= nil then
        self:OnAwarded()
    end
end

function objective:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

return objective