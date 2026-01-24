local category = {}

category.Identifier = "services"
category.Decoration = "security"

category.CanAccess = function(client)
    --if not client.Character then return false end
    return false
end

category.Products = {
    {
        Identifier = "Platinum Europan Trauma Corps Membership",
        Price = 350,
        Limit = 1,
        IsLimitGlobal = false,
        CanBuy = function(client)
            if not client.Character then
                return false, "You must be alive to purchase"
            end
            
            if client.Character.IsDead then
                return false, "You must be alive to purchase"
            end
            
            return true
        end,
        Action = function (client, product, items)
            -- Capture the character at purchase time - membership stays with THIS character
            local character = client.Character
            
            if not character then
                Neurologics.SendMessage(client, "You must have a character to purchase this!")
                return
            end
            
            -- Grant membership to the CHARACTER, not the client
            Neurologics.SetCharacterData(character, "TraumaTeamMember", true)
            Neurologics.SetCharacterData(character, "TraumaTeamUsed", false)
            
            -- Register this character for monitoring
            if not Neurologics.TraumaTeamMembers then
                Neurologics.TraumaTeamMembers = {}
            end
            Neurologics.TraumaTeamMembers[character] = true
            
            Neurologics.SendMessage(client, "You are now a Platinum Member of the Europan Trauma Corps! If you are knocked unconscious for 10+ seconds, an emergency team will be dispatched to rescue you.")
            
        end
    }
}

return category