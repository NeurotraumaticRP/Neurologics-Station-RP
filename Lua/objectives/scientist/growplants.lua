local objective = Neurologics.RoleManager.Objectives.Objective:new()

local plantTypes = {
    "tobaccobud",
    "saltgrenade",
    "saltbulb",
    "saltbulb",
    "raptorbacco",
    "raptorbane",
    "raptorpom",
    "popnut",
    "creepingorange",
    "bubbleberries",
}

objective.Name = "GrowPlants"
objective.AmountPoints = 1500
objective.Times = 15
objective.Job = {"scientist"}

Hook.Add("item.created", "Neurologics.GrowPlant", function (item)
    for i = 1, #plantTypes do
        if plantTypes[i] == item.Prefab.Identifier.Value then
            Neurologics.RoleManager.CallObjectiveFunction("GrowPlant", item)
            break
        end
    end
end)

function objective:Start()
    self.Progress = 0

    self.Text = string.format("Grow (%s/%s) plants of any type.", self.Progress, self.Times)

    return true
end

function objective:GrowPlant(item)
    if not self.Character or self.Character.IsDead or self.Character.Removed then
        return
    end
    
    local distance = Vector2.Distance(self.Character.WorldPosition, item.WorldPosition)
    if distance > 250 then
        return
    end
    
    self.Progress = self.Progress + 1
    self.Text = string.format("Grow (%s/%s) plants of any type.", self.Progress, self.Times)
end

function objective:IsCompleted()
    return self.Progress >= self.Times
end

return objective