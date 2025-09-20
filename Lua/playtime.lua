Hook.Add("think", "Neurologics.Playtime.think", function()
    for index, client in pairs(Client.ClientList) do
        Neurologics.AddData(client, "Playtime", 1/60) -- throwing nil error
    end
end)

Neurologics.AddCommand({"!playtime", "!pt"}, function (client, args)
    Neurologics.SendChatMessage(
        client,
        string.format(Neurologics.Language.CMDPlaytime, Neurologics.FormatTime(math.ceil(Neurologics.GetData(client, "Playtime") or 0))),
        Color.Green
    )
    return true
end)