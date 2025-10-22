local objective = Neurologics.RoleManager.Objectives.KillMonsters:new()

objective.Name = "KillAbyssMonsters"
objective.AmountPoints = 3000
objective.Monster = {
    Identifiers = {"Charybdis", "Endworm", "Latcher"},
    Text = Neurologics.Language.AbyssCreature,
    Amount = 1,
}
objective.Job = {"warden","captain"}
return objective
