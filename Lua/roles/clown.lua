local role = Neurologics.RoleManager.Roles.Antagonist:new()
role.Name = "Clown"

local MAIN_OBJECTIVE = "StealIDCard"

function role:ClownLoop(first)
    if not Game.RoundStarted then return end
    if self.RoundNumber ~= Neurologics.RoundNumber then return end

    local this = self

    local mainObjective = Neurologics.RoleManager.Objectives[MAIN_OBJECTIVE]:new()
    mainObjective:Init(self.Character)
    local target = self:FindValidTarget(mainObjective)
    if not self.Character.IsDead and mainObjective:Start(target) then
        table.insert(self.StolenTargets, target)
        self:AssignObjective(mainObjective)

        local client = Neurologics.FindClientCharacter(self.Character)

        mainObjective.OnAwarded = function()
            if client then
                Neurologics.SendMessage(client, Neurologics.Language.HonkmotherNextTarget, "")
                Neurologics.Stats.AddClientStat("TraitorMainObjectives", client, 1)
            end

            local delay = math.random(this.NextObjectiveDelayMin, this.NextObjectiveDelayMax) * 1000
            Timer.Wait(function(...)
                this:ClownLoop()
            end, delay)
        end


        if client and not first then
            Neurologics.SendMessage(client, string.format(Neurologics.Language.HonkmotherNewObjective, target.Name),
                "GameModeIcon.pvp")
            Neurologics.UpdateVanillaTraitor(client, true, self:Greet())
        end
    else
        Timer.Wait(function()
            this:ClownLoop()
        end, 5000)
    end
end

function role:Start()
    self.StolenTargets = {}

    Neurologics.Stats.AddCharacterStat("Traitor", self.Character, 1)

    for i = 1, 3, 1 do
        self:ClownLoop(true)      
    end

    local pool = {}
    for key, value in pairs(self.SubObjectives) do pool[key] = value end

    local toRemove = {}
    for key, value in pairs(pool) do
        local objective = Neurologics.RoleManager.FindObjective(value)
        if objective ~= nil and objective.AlwaysActive then
            objective = objective:new()

            local character = self.Character

            objective:Init(character)
            objective.OnAwarded = function ()
                Neurologics.Stats.AddCharacterStat("TraitorSubObjectives", character, 1)
            end

            if objective:Start(character) then
                self:AssignObjective(objective)
                table.insert(toRemove, key)
            end
        end
    end
    for key, value in pairs(toRemove) do table.remove(pool, value) end

    for i = 1, math.random(self.MinSubObjectives, self.MaxSubObjectives), 1 do
        local objective = Neurologics.RoleManager.RandomObjective(pool)
        if objective == nil then break end

        objective = objective:new()

        local character = self.Character

        objective:Init(character)
        local target = self:FindValidTarget(objective)

        objective.OnAwarded = function ()
            Neurologics.Stats.AddCharacterStat("TraitorSubObjectives", character, 1)
        end

        if objective:Start(target) then
            self:AssignObjective(objective)
            for key, value in pairs(pool) do
                if value == objective.Name then
                    table.remove(pool, key)
                end
            end
        end
    end

    local text = self:Greet()
    local client = Neurologics.FindClientCharacter(self.Character)
    if client then
        Neurologics.SendTraitorMessageBox(client, text)
        Neurologics.UpdateVanillaTraitor(client, true, text)
    end
end


function role:End(roundEnd)
    local client = Neurologics.FindClientCharacter(self.Character)
    if not roundEnd and client then
        Neurologics.SendMessage(client, Neurologics.Language.TraitorDeath, "InfoFrameTabButton.Traitor")
        Neurologics.UpdateVanillaTraitor(client, false)
    end
end

---@return string mainPart, string subPart
function role:ObjectivesToString()
    local primary = Neurologics.StringBuilder:new()
    local secondary = Neurologics.StringBuilder:new()

    for _, objective in pairs(self.Objectives) do
        -- AssassinateDrunk objectives are primary
        local buf = objective.Name == MAIN_OBJECTIVE and primary or secondary

        if objective:IsCompleted() or objective.Awarded then
            buf:append(" > ", objective.Text, Neurologics.Language.Completed)
        else
            buf:append(" > ", objective.Text, string.format(Neurologics.Language.Points, objective.AmountPoints))
        end
    end
    if #primary == 0 then
        primary(Neurologics.Language.NoObjectivesYet)
    end

    return primary:concat("\n"), secondary:concat("\n")
end

function role:Greet()
    local partners = Neurologics.StringBuilder:new()
    local traitors = Neurologics.RoleManager.FindAntagonists()
    for _, character in pairs(traitors) do
        if character ~= self.Character then
            partners('"%s" ', character.Name)
        end
    end
    partners = partners:concat(" ")
    local primary, secondary = self:ObjectivesToString()

    local sb = Neurologics.StringBuilder:new()
    sb("%s\n\n", Neurologics.Language.HonkMotherYou)
    sb("%s\n", Neurologics.Language.MainObjectivesYou)
    sb(primary)
    sb("\n\n%s\n", Neurologics.Language.SecondaryObjectivesYou)
    sb(secondary)
    sb("\n\n")
    if #traitors < 2 then
        sb(Neurologics.Language.SoloAntagonist)
    else
        sb(Neurologics.Language.Partners, partners)
        sb("\n")
    
        if self.TraitorBroadcast then
            sb(Neurologics.Language.TcTip)
        end
    end
    
    return sb:concat()
end

function role:OtherGreet()
    local sb = Neurologics.StringBuilder:new()
    local primary, secondary = self:ObjectivesToString()
    sb(Neurologics.Language.HonkMotherOther, self.Character.Name)
    sb("\n%s\n", Neurologics.Language.MainObjectivesOther)
    sb(primary)
    sb("\n%s\n", Neurologics.Language.SecondaryObjectivesOther)
    sb(secondary)
    return sb:concat()
end

function role:FilterTarget(objective, character)
    if not self.SelectBotsAsTargets and character.IsBot then return false end

    for key, value in pairs(self.StolenTargets) do
        if value == character then
            return false
        end
    end

    if objective.Name == MAIN_OBJECTIVE and self.SelectUniqueTargets then
        for key, value in pairs(Neurologics.RoleManager.FindCharactersByRole("Clown")) do
            local targetRole = Neurologics.RoleManager.GetRole(value)

            for key, obj in pairs(targetRole.Objectives) do
                if obj.Target == character then
                    return false
                end
            end
        end
    end

    if character.TeamID ~= CharacterTeamType.Team1 and not self.SelectPiratesAsTargets then
        return false
    end

    return Neurologics.RoleManager.Roles.Antagonist.FilterTarget(self, objective, character)
end


return role
