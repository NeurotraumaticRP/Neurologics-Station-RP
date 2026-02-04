local objective = Neurologics.RoleManager.Objectives.Objective:new()

local geneticMaterials = {
    "geneticmaterialbroodmother",
    "geneticmaterialhammerheadmatriarch",
    "geneticmaterialmoloch",
    "geneticmaterialhammerhead",
    "geneticmaterialcrawler",
    "geneticmaterialhunter",
    "geneticmaterialhusk",
    "geneticmaterialmantis",
    "geneticmaterialmollusc",
    "geneticmaterialmudraptor",
    "geneticmaterialskitter",
    "geneticmaterialspineling",
    "geneticmaterialthalamus",
    "geneticmaterialthresher",
}

objective.Name = "ResearchGeneticMaterials"
objective.AmountPoints = 100
objective.Job = {"scientist"}


Hook.Add("item.created", "Neurologics.ResearchGeneticMaterial", function (item)
    for i = 1, #geneticMaterials do
        if geneticMaterials[i] == item.Prefab.Identifier.Value then
            Neurologics.RoleManager.CallObjectiveFunction("ResearchGeneticMaterial", item)
            break
        end
    end
end)

function objective:Start(target)
    self.AmountPoints = 0

    self.Text = string.format("Research genetic materials. (100 points each, %s total)", self.AmountPoints)

    return true
end

function objective:ResearchGeneticMaterial(item)
    if not self.Character or self.Character.IsDead or self.Character.Removed then
        return
    end
    
    local distance = Vector2.Distance(self.Character.WorldPosition, item.WorldPosition)
    if distance > 150 then
        return
    end
    
    self.AmountPoints = self.AmountPoints + 100 -- 100 points per genetic material
    self.Text = string.format("Research genetic materials. (100 points each, %s total)", self.AmountPoints)
end

function objective:IsCompleted()
    return self.AmountPoints >= 1000
end

return objective