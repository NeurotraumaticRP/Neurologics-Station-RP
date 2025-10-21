local event = {}
event.Name = "NukieRaid"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 0.1
event.ChancePerMinute = 0.000005
event.OnlyOncePerRound = true
event.Parameters = "[count] - Optional: number of nukies to spawn (default: all dead players)"

event.Start = function(count)
    local deadCharacters = {}
    for _,client in pairs(Client.ClientList) do
        if client.Character == nil or client.Character.IsDead then
            table.insert(deadCharacters, client) -- Add dead characters to the list
        end
    end

    if #deadCharacters == 0 then
        event.End()
        return
    end

    -- Determine how many nukies to spawn
    local nukieCount = count or #deadCharacters
    nukieCount = math.min(nukieCount, #deadCharacters) -- Can't spawn more than available dead players
    nukieCount = math.max(1, nukieCount) -- Spawn at least 1

    -- Spawn the specified number of nukies
    for i = 1, nukieCount do
        local deadCharacter = deadCharacters[i]
        local submarine = Submarine.MainSub
        local subPosition = submarine.WorldPosition
        local angle = math.random() * 2 * math.pi
        local distance = math.random(3000, 4000)
        local offsetX = math.cos(angle) * distance
        local offsetY = math.sin(angle) * distance
        local position = Vector2(subPosition.X + offsetX, subPosition.Y + offsetY)
        NCS.SpawnCharacterWithClient("nukie", position, CharacterTeamType.Team2, deadCharacter)
        Neurologics.SendMessageCharacter(deadCharacter.Character, "You are the Nuclear Operatives, you are not aligned with anyone but yourselves, your only goal is to destroy the nuclear reactor, kill all who stand in your way, good luck.", "CrewWalletIconLarge")
    end

    Neurologics.RoundEvents.SendEventMessage("The Nuclear Operatives have arrived!", "CrewWalletIconLarge")
end

event.End = function()
end

return event