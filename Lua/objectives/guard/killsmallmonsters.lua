local objective = Neurologics.RoleManager.Objectives.KillMonsters:new()

objective.Name = "KillSmallMonsters"
objective.AmountPoints = 500
objective.Monster = {
    Identifiers = {"Crawler", "Crawlerhusk", "Husk", "Tigerthresher", "Bonethresher", "Mudraptor", "Mudraptor_unarmored", "Spineling"},
    Text = Neurologics.Language.SmallCreatures,
    Amount = math.random(1, 5),
}

function objective:Start(target)
    self.AmountPoints = self.Monster.Amount * 500
    self.Text = string.format(Neurologics.Language.ObjectiveKillMonsters, self.Progress, self.Monster.Amount, self.Monster.Text)
    return true
end

objective.Job = {"guard","warden","captain"}
return objective
