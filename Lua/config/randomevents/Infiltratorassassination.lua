--[[
    InfiltratorAssassination
    Spawns 3 infiltrators at random positions on the submarine.
    The infiltrators are aligned with the seperatists and their only goal is to kill their target and spare those who are not their target.


local event = {}
event.Name = "InfiltratorAssassination"
event.MinRoundTime = 5
event.MinIntensity = 0
event.MaxIntensity = 0.1
event.ChancePerMinute = 0.000005
event.OnlyOncePerRound = true
event.Parameters = "[count] - Optional: number of infiltrators to spawn (default: 3)"

local infiltratorCount = 3

event.Start = function(count)
    local deadClients = {}
    for _,client in pairs(Client.ClientList) do
        if client.Character == nil or client.Character.IsDead then
            table.insert(deadClients, client) -- Add dead characters to the list
        end
    end

    if #deadClients == 0 then
        event.End()
        return
    end

    -- Spawn the specified number of infiltrators
    for i = 1, infiltratorCount do
        local deadClient = deadClients[i]
        local position = Neurologics.FindRandomSpawnPosition()
        NCS.SpawnCharacterWithClient("infiltrator", position, CharacterTeamType.Team2, deadClient, nil)
        Neurologics.SendMessageCharacter(deadClient.Character, "You are "..deadClient.Character.Name.." and you are an assassin. you and your team are aligned with the seperatists, kill your target and spare those who are not your target.", "CrewWalletIconLarge")
    end

end

event.End = function()
end

return event]]