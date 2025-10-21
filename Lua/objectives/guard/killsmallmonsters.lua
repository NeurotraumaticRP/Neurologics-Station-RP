local objective = Neurologics.RoleManager.Objectives.KillMonsters:new()

objective.Name = "KillSmallMonsters"
objective.AmountPoints = 500
objective.Monster = {
    Identifiers = {"Crawler", "Crawlerhusk", "Husk", "Tigerthresher", "Bonethresher", "Mudraptor", "Mudraptor_unarmored", "Spineling"},
    Text = Neurologics.Language.SmallCreatures,
    Amount = 6,
}
objective.Job = {"guard","warden","captain"}
return objective
