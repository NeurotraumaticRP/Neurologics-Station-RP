local textPromptUtils = require("textpromptutils")

local objective = Neurologics.RoleManager.Objectives.Objective:new()

objective.Name = "Escape"
objective.AmountPoints = 1500
objective.EndRoundObjective = false -- Check continuously during round
objective.Job = {"convict"}

local ESCAPE_DISTANCE = 10000 -- Distance in display units from submarine
local ESCAPE_TIME = 300 -- 5 minutes in seconds
local HALF_POINTS_THRESHOLD = 300 -- 5 minutes

function objective:Start(target)
    self.Text = "Escape the station! Get 10,000 units away from the submarine without handcuffs. Survive 5 minutes to fully escape and become a pirate."
    
    self.EscapeStartTime = nil -- When escape conditions were first met
    self.HasEscaped = false -- Full escape completed (5 mins)
    self.ConditionsMet = false -- Currently meeting escape conditions
    self.BecamePirate = false -- Whether they took the pirate option
    self.OfferedPirateRole = false -- Whether we've offered the pirate role
    
    return true
end

function objective:CheckEscapeConditions()
    if self.Character.IsDead then
        return false
    end
    
    -- Check if handcuffed
    if self.Character.IsHuman then
        local handcuffs = self.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
        if handcuffs ~= nil and handcuffs.Prefab.Identifier == "handcuffs" then
            return false
        end
    end
    
    -- Check distance from submarine
    if Submarine.MainSub then
        local distance = Vector2.Distance(self.Character.WorldPosition, Submarine.MainSub.WorldPosition)
        if distance < ESCAPE_DISTANCE then
            return false
        end
    end
    
    return true
end

function objective:IsCompleted()
    -- Don't complete if already awarded or became pirate
    if self.Awarded or self.BecamePirate then
        return false
    end
    
    local conditionsMet = self:CheckEscapeConditions()
    
    -- Start timer when conditions first met
    if conditionsMet and not self.ConditionsMet then
        self.ConditionsMet = true
        self.EscapeStartTime = Timer.GetTime()
        
        local client = Neurologics.FindClientCharacter(self.Character)
        if client then
            Neurologics.SendMessage(client, "Escape conditions met! Survive for 5 minutes to fully escape.", "CommandInterface")
        end
    end
    
    -- Reset if conditions no longer met
    if not conditionsMet and self.ConditionsMet then
        self.ConditionsMet = false
        self.EscapeStartTime = nil
        
        local client = Neurologics.FindClientCharacter(self.Character)
        if client then
            Neurologics.SendMessage(client, "Escape conditions lost! Get away from the submarine.", "CommandInterface")
        end
    end
    
    -- Check if 5 minutes have passed
    if self.EscapeStartTime ~= nil and self.ConditionsMet then
        local escapeTime = Timer.GetTime() - self.EscapeStartTime
        
        -- Update text with timer
        local remainingTime = math.max(0, ESCAPE_TIME - escapeTime)
        if remainingTime > 0 then
            self.Text = string.format("Escape the station! Remaining time: %d seconds", math.floor(remainingTime))
        else
            self.Text = "Escaped! You can now become a pirate if you wish."
        end
        
        if escapeTime >= ESCAPE_TIME then
            self.HasEscaped = true
            
            -- Show dialogue box once
            if not self.OfferedPirateRole then
                self.OfferedPirateRole = true
                local client = Neurologics.FindClientCharacter(self.Character)
                if client then
                    self:ShowEscapeChoicePrompt(client)
                end
            end
            
            return true
        end
    end
    
    return false
end

function objective:ShowEscapeChoicePrompt(client)
    local message = "You have successfully escaped! What would you like to do?"
    local options = {
        "Return as a Pirate",
        "Continue as Convict",
        "Respawn as Crew Member"
    }
    
    local character = self.Character
    local objectiveRef = self
    
    textPromptUtils.Prompt(message, options, client, function(choice, responseClient)
        if choice == 1 then
            -- Return as pirate
            objectiveRef.BecamePirate = true
            
            local currentPos = character.WorldPosition
            local oldCharacter = character
            responseClient.SetClientCharacter(nil)
            
            Timer.Wait(function()
                local newCharacter = NCS.SpawnCharacterWithClient("nukie", currentPos, CharacterTeamType.Team2, responseClient)
                
                if newCharacter then
                    Neurologics.SendMessage(responseClient, "You have returned as a pirate! You are now hostile to the station crew.", "CrewWalletIconLarge")
                    Neurologics.SendMessageEveryone(responseClient.Name .. " has escaped and returned as a pirate!")
                    
                    if oldCharacter then
                        Entity.Spawner.AddEntityToRemoveQueue(oldCharacter)
                    end
                else
                    Neurologics.SendMessage(responseClient, "Failed to spawn as pirate. Please contact an admin.")
                end
            end, 100)
            
        elseif choice == 2 then
            -- Continue as convict
            Neurologics.SendMessage(responseClient, "You continue your life as a fugitive. Good luck out there!", "CrewWalletIconLarge")
            
        elseif choice == 3 then
            -- Respawn as crew member using midroundspawn
            objectiveRef.BecamePirate = true -- Prevent re-completion
            
            responseClient.SetClientCharacter(nil)
            
            Timer.Wait(function()
                local spawned = Neurologics.MidRoundSpawn.SpawnClientCharacterOnSub(Submarine.MainSub, responseClient)
                
                if spawned then
                    Neurologics.SendMessage(responseClient, "You have been given a new identity and returned to the station as crew.", "CrewWalletIconLarge")
                    Neurologics.SendMessageEveryone(responseClient.Name .. " has joined the crew.")
                    
                    -- Call the midroundspawn hook to assign crew role
                    Hook.Call("Neurologics.midroundspawn", responseClient, spawned)
                    
                    Entity.Spawner.AddEntityToRemoveQueue(character)
                else
                    Neurologics.SendMessage(responseClient, "Failed to respawn as crew. Please contact an admin.")
                end
            end, 100)
        end
    end, "CrewWalletIconLarge", false)
end

function objective:CharacterDeath(character)
    -- If the character who died is us and we started escaping
    if character == self.Character and self.EscapeStartTime ~= nil and not self.HasEscaped and not self.Awarded then
        local escapeTime = Timer.GetTime() - self.EscapeStartTime
        
        -- Award half points if died during escape attempt
        if escapeTime < HALF_POINTS_THRESHOLD then
            self.AmountPoints = math.floor(self.AmountPoints * 0.5)
            self:Award()
            
            local client = Neurologics.FindClientCharacter(self.Character)
            if client then
                Neurologics.SendMessage(client, "You died during your escape attempt. Half points awarded.", "CommandInterface")
            end
        end
    end
end

function objective:Award()
    self.Awarded = true

    local client = Neurologics.FindClientCharacter(self.Character)

    if client then 
        local points = Neurologics.AwardPoints(client, self.AmountPoints)
        local lives = Neurologics.AdjustLives(client, self.AmountLives)
        Neurologics.SendObjectiveCompleted(client, self.Text, points, lives)

        if self.DontLooseLives then
            Neurologics.LostLivesThisRound[client.SteamID] = true
        end
    end

    if self.OnAwarded ~= nil then
        self:OnAwarded()
    end
end

return objective