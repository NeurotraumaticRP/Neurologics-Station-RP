local role = Neurologics.RoleManager.Roles.Antagonist:new()

role.Name = "HuskServant"
role.IsAntagonist = false

function role:Start()
    local text = self:Greet()
    local client = Neurologics.FindClientCharacter(self.Character)
    if client then
        Neurologics.SendTraitorMessageBox(client, text, "oneofus")
        Neurologics.UpdateVanillaTraitor(client, true, text, "oneofus")
    end
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

    local sb = Neurologics.StringBuilder:new()
    sb(Neurologics.Language.HuskServantYou)

    sb("\n\n")
    sb(Neurologics.Language.HuskCultists, partners)

    if self.TraitorBroadcast then
        sb("\n\n%s", Neurologics.Language.HuskServantTcTip)
    end

    return sb:concat()
end

function role:OtherGreet()
    local sb = Neurologics.StringBuilder:new()
    sb(Neurologics.Language.HuskServantOther, self.Character.Name)
    return sb:concat()
end

return role
