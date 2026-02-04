--[[
    Mudraptor Servant Role
    
    Assigned to players who are turned into mudraptors by the Evil Scientist.
    They get an objective to help the scientist survive the round.
]]

local role = Neurologics.RoleManager.Roles.Antagonist:new()

role.Name = "MudraptorServant"
role.IsAntagonist = false

function role:Start()
    -- Assign the help scientist objective
    local helpObjective = Neurologics.RoleManager.Objectives.HelpScientist:new()
    helpObjective:Init(self.Character)
    
    -- Find the evil scientist who turned us
    local scientists = Neurologics.RoleManager.FindCharactersByRole("EvilScientist")
    if #scientists > 0 then
        if helpObjective:Start(scientists[1]) then
            self:AssignObjective(helpObjective)
        end
    end
    
    -- Greet the new mudraptor
    local text = self:Greet()
    local client = Neurologics.FindClientCharacter(self.Character)
    if client then
        Neurologics.SendTraitorMessageBox(client, text, "")
        Neurologics.UpdateVanillaTraitor(client, true, text, "")
    end
end

function role:Greet()
    local sb = Neurologics.StringBuilder:new()
    sb("You have been transformed into a mudraptor!\n\n")
    sb("Your primal instincts tell you to protect the one who gave you this gift.\n\n")
    
    -- Find the evil scientist(s)
    local scientists = Neurologics.RoleManager.FindCharactersByRole("EvilScientist")
    if #scientists > 0 then
        local names = {}
        for _, scientist in pairs(scientists) do
            table.insert(names, '"' .. scientist.Name .. '"')
        end
        sb("Protect: %s\n\n", table.concat(names, ", "))
    end
    
    -- Show objectives
    local objectives = self:ObjectivesToString()
    if objectives and objectives ~= "" then
        sb("Objectives:\n%s\n\n", objectives)
    end
    
    if self.TraitorBroadcast then
        sb(Neurologics.Language.TcTip)
    end
    
    return sb:concat()
end

function role:ObjectivesToString()
    local sb = Neurologics.StringBuilder:new()
    
    for _, objective in pairs(self.Objectives) do
        if objective:IsCompleted() or objective.Awarded then
            sb(" > %s %s", objective.Text, Neurologics.Language.Completed)
        else
            sb(" > %s %s", objective.Text, string.format(Neurologics.Language.Points, objective.AmountPoints))
        end
    end
    
    return sb:concat("\n")
end

function role:OtherGreet()
    local sb = Neurologics.StringBuilder:new()
    sb("%s has been transformed into a mudraptor and will serve you!", self.Character.Name)
    return sb:concat()
end

return role
