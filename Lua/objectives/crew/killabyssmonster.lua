local objective = Neurologics.RoleManager.Objectives.KillMonsters:new()

objective.Name = "KillAbyssMonsters"
objective.AmountPoints = 1500
objective.Monster = {
    Identifiers = {"Charybdis", "Endworm", "Latcher"},
    Text = Neurologics.Language.AbyssCreature,
    Amount = 1,
}

return objective
