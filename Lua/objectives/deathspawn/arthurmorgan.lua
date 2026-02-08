local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "Duel"
objective.AmountPoints = 5000
objective.Role = nil

local DUEL_RANGE = 700
local activeDuelObjectives = {}

local function CharacterHasRangedWeapon(character)
    if not character or not character.Inventory then return false end
    local function checkItem(item)
        if not item then return false end
        local rw = item.GetComponentString("RangedWeapon")
        if rw then return true end
        if item.OwnInventory then
            for subItem in item.OwnInventory.AllItems do
                if checkItem(subItem) then return true end
            end
        end
        return false
    end
    for item in character.Inventory.AllItems do
        if checkItem(item) then return true end
    end
    return false
end

local function GetValidDuelTargets(character)
    local targets = {}
    for other in Character.CharacterList do
        -- Exclude self (must not duel yourself); target must have ranged weapon (range only matters when they go down)
        if other and other ~= character and other.IsHuman and not other.IsDead and not other.Removed then
            table.insert(targets, other)
        end
    end
    return targets
end

Hook.Add("think", "ArthurMorganDuel.TrackGun", function()
    for obj, _ in pairs(activeDuelObjectives) do
        if obj.Target and not obj.Target.IsDead then
            local isConscious = not obj.Target.IsUnconscious
            if isConscious then
                if CharacterHasRangedWeapon(obj.Target) then
                    obj.TargetHadGunWhenConscious = true
                end
                obj.TargetWasConsciousLastFrame = true
            else
                -- Transition to unconscious: if they never had a gun, duel is permanently invalid
                if obj.TargetWasConsciousLastFrame and not obj.TargetHadGunWhenConscious then
                    obj.TargetWentUnconsciousWithoutGun = true
                end
                obj.TargetWasConsciousLastFrame = false
            end
        end
    end
end)

Hook.Add("roundEnd", "ArthurMorganDuel.Cleanup", function()
    activeDuelObjectives = {}
end)

function objective:Start(target)
    -- Find our own target: must have ranged weapon (range only matters when they go unconscious/die)
    local targets = GetValidDuelTargets(self.Character)
    if #targets == 0 then return false end

    self.Target = targets[math.random(1, #targets)]
    self.TargetHadGunWhenConscious = false
    self.TargetWasConsciousLastFrame = true
    self.TargetWentUnconsciousWithoutGun = false
    activeDuelObjectives[self] = true

    self.TargetName = Neurologics.GetJobString(self.Target) .. " " .. self.Target.Name
    self.Text = string.format(Neurologics.Language.ObjectiveDuel, self.TargetName)

    return true
end

function objective:IsCompleted()
    if not self.Target or not self.Character then return false end
    if self.Character.IsDead then return false end

    if self.Target.IsDead and self.TargetHadGunWhenConscious and not self.TargetWentUnconsciousWithoutGun then
        local dist = Vector2.Distance(self.Character.WorldPosition, self.Target.WorldPosition)
        if dist <= DUEL_RANGE then
            activeDuelObjectives[self] = nil
            return true
        end
    end

    return false
end

function objective:IsFailed()
    if not self.Target then return false end
    if self.Character and self.Character.IsDead then return true end

    -- Target went unconscious without ever having a gun (invalid duel, even if they get one later)
    --[[if self.TargetWentUnconsciousWithoutGun then
        activeDuelObjectives[self] = nil
        return true
    end]]

    -- Target died/went unconscious but did NOT have gun when conscious
    if self.Target.IsDead and not self.TargetHadGunWhenConscious then
        activeDuelObjectives[self] = nil
        return true
    end

    if self.Target.IsDead and not (Vector2.distance(self.Character.WorldPosition, self.Target.WorldPosition) <= DUEL_RANGE) then
        activeDuelObjectives[self] = nil
        return true
    end

    return false
end

return objective
