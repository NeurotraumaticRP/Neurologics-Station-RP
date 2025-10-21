local objective = Neurologics.RoleManager.Objectives.KillMonsters:new()

objective.Name = "KillLargeMonsters"
objective.AmountPoints = 650
objective.Monster = {
    Identifiers = {"Moloch", "Molochblack", "Hammerhead", "Hammerheadgold", "Hammerheadmatriarch", "Spineling_giant", "Mudraptor_veteran", "Crawlerbroodmother", "Watcher", "Fractalguardian"},
    Text = Neurologics.Language.LargeCreatures,
    Amount = 3,
}
objective.Job = {"warden","captain"}
return objective
