--[[
    NEUROLOGICS CURRENCY SYSTEM
    ===========================
    Adds a way to withdraw and deposit currency from the bank.
    This currency will be equivalent to the already existing points made by traitor mod.
    you can use this currency to do in game role play by giving money to other players.
]]

--[[Neurologics.Currency = {}

Neurologics.Currency.Denominations = {
    --{"1", 1},
    --{"5", 5},
    --{"10", 10},
    --{"25", 25},
    {"100", 100},
    {"500", 500},
    {"1000", 1000},
    {"2000", 2000},
    {"5000", 5000},
    {"10000", 10000},
}

Neurologics.Currency.Withdraw = function(client, amount)
    amount = math.floor(amount / 100) * 100
    
    if amount <= 0 then
        Neurologics.SendMessage(client, "Amount must be at least 100.", ChatMessageType.Error)
        return
    end
    local data = Neurologics.GetData(client, "points")
    if data < amount then
        Neurologics.SendMessage(client, "You don't have enough currency to withdraw.", ChatMessageType.Error)
        return
    end
    
    local withdrawDenominationList = {} -- table should be structured like this: {denomination, amountOfDenomination}
    for _, denomination in pairs(Neurologics.Currency.Denominations) do
        local amount = math.floor(amount / denomination[2])
        if amount > 0 then
            table.insert(withdrawDenominationList, {denomination[1], amount})
        end
    end
    
    Neurologics.SendMessage(client, "You have withdrawn " .. amount .. " currency.", ChatMessageType.Success)
end]]