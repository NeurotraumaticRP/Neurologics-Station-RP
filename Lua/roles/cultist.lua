local role = Neurologics.RoleManager.Roles.Antagonist:new()
role.Name = "Cultist"

function role:CultistLoop(first)
    if not Game.RoundStarted then return end
    if self.RoundNumber ~= Neurologics.RoundNumber then return end

    local this = self

    local husk = Neurologics.RoleManager.Objectives.Husk:new()
    husk:Init(self.Character)
    local target = self:FindValidTarget(husk)
    if not self.Character.IsDead and husk:Start(target) then
        self:AssignObjective(husk)

        local client = Neurologics.FindClientCharacter(self.Character)

        husk.OnAwarded = function()
            if client then
                Neurologics.SendMessage(client, Neurologics.Language.CultistNextTarget, "")
                Neurologics.Stats.AddClientStat("TraitorMainObjectives", client, 1)
            end

            local delay = math.random(this.NextObjectiveDelayMin, this.NextObjectiveDelayMax) * 1000
            Timer.Wait(function(...)
                this:CultistLoop()
            end, delay)
        end


        if client and not first then
            Neurologics.SendMessage(client, string.format(Neurologics.Language.HuskNewObjective, target.Name),
                "GameModeIcon.pvp")
            Neurologics.UpdateVanillaTraitor(client, true, self:Greet())
        end
    else
        Timer.Wait(function()
            this:CultistLoop()
        end, 5000)
    end
end

function role:Start()
    Neurologics.Stats.AddCharacterStat("Traitor", self.Character, 1)

    self.Character.AddAbilityFlag(AbilityFlags.IgnoredByEnemyAI) -- husks ignore the cultists

    self:CultistLoop(true)

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
        Neurologics.SendTraitorMessageBox(client, text, "oneofus")
        Neurologics.UpdateVanillaTraitor(client, true, text, "oneofus")
    end
end


function role:End(roundEnd)
    local client = Neurologics.FindClientCharacter(self.Character)
    if not roundEnd and client then
        --Neurologics.SendMessage(client, Neurologics.Language.TraitorDeath, "InfoFrameTabButton.Traitor")
        Neurologics.UpdateVanillaTraitor(client, false)
    end
end

---@return string mainPart, string subPart
function role:ObjectivesToString()
    local primary = Neurologics.StringBuilder:new()
    local secondary = Neurologics.StringBuilder:new()

    for _, objective in pairs(self.Objectives) do
        -- Husk objectives are primary
        local buf = objective.Name == "Husk" and primary or secondary

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
    sb("%s\n\n", Neurologics.Language.CultistYou)
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
    sb(Neurologics.Language.CultistOther, self.Character.Name)
    sb("\n%s\n", Neurologics.Language.MainObjectivesOther)
    sb(primary)
    sb("\n%s\n", Neurologics.Language.SecondaryObjectivesOther)
    sb(secondary)
    return sb:concat()
end

function role:FilterTarget(objective, character)
    if not self.SelectBotsAsTargets and character.IsBot then return false end

    if character.TeamID ~= CharacterTeamType.Team1 and not self.SelectPiratesAsTargets then
        return false
    end

    local aff = character.CharacterHealth.GetAffliction("huskinfection", true)

    if aff ~= nil and aff.Strength > 1 then
        return false
    end

    return Neurologics.RoleManager.Roles.Antagonist.FilterTarget(self, objective, character)
end

Hook.Add("husk.clientControlHusk", "Neurologics.Cultist.HuskControl", function (client, husk)
    local cultist
    for _, character in pairs(Neurologics.RoleManager.FindCharactersByRole("Cultist")) do
        if character.Name == client.Name then
            cultist = Neurologics.RoleManager.GetRole(character)
            break
        end
    end

    if cultist then
        Neurologics.RoleManager.TransferRole(client.Character, cultist)
    else
        Neurologics.RoleManager.AssignRole(client.Character, Neurologics.RoleManager.Roles.HuskServant:new())
    end
end)

return role
