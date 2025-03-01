dofile(Neurologics.Path .. "/Lua/Neurologicsutil.lua")

Game.OverrideTraitors(true)

if Neurologics.Config.RagdollOnDisconnect ~= nil then
    Game.DisableDisconnectCharacter(not Neurologics.Config.RagdollOnDisconnect)
end

if Neurologics.Config.EnableControlHusk ~= nil then
    Game.EnableControlHusk(Neurologics.Config.EnableControlHusk)
end

math.randomseed(os.time())

Neurologics.Gamemodes = {}

Neurologics.AddGamemode = function(gamemode)
    Neurologics.Gamemodes[gamemode.Name] = gamemode

    if Neurologics.Config.GamemodeConfig[gamemode.Name] ~= nil then
        for key, value in pairs(Neurologics.Config.GamemodeConfig[gamemode.Name]) do
            gamemode[key] = value
        end
    end
end

if not File.Exists(Neurologics.Path .. "/Lua/data.json") then
    File.Write(Neurologics.Path .. "/Lua/data.json", "{}")
end

Neurologics.RoundNumber = 0
Neurologics.RoundTime = 0
Neurologics.LostLivesThisRound = {}
Neurologics.Commands = {}
Neurologics.RespawnedCharacters = {}

local pointsGiveTimer = -1

Neurologics.LoadData()

if Neurologics.Config.RemotePoints then
    for key, value in pairs(Client.ClientList) do
        Neurologics.LoadRemoteData(value)
    end
end

LuaUserData.RegisterType("Barotrauma.GameModePreset")
LuaUserData.RegisterType("Barotrauma.Voting")
Voting = LuaUserData.CreateStatic("Barotrauma.Voting")
Neurologics.PreRoundStart = function (submarineInfo, chooseGamemode)
    Neurologics.SelectedGamemode = nil

    local description = submarineInfo.Description.Value
    local subConfig = Neurologics.ParseSubmarineConfig(description)

    if subConfig.Gamemode and Neurologics.Gamemodes[subConfig.Gamemode] then
        Neurologics.SelectedGamemode = Neurologics.Gamemodes[subConfig.Gamemode]:new()
        for key, value in pairs(subConfig) do
            Neurologics.SelectedGamemode[key] = value
        end
    elseif Game.ServerSettings.GameModeIdentifier == "pvp" then
        Neurologics.SelectedGamemode = Neurologics.Gamemodes.PvP:new()
    elseif Game.ServerSettings.GameModeIdentifier == "multiplayercampaign" then
        Neurologics.SelectedGamemode = Neurologics.Gamemodes.Gamemode:new()
    elseif math.random() <= Game.ServerSettings.TraitorProbability then
        Neurologics.SelectedGamemode = Neurologics.Gamemodes.Secret:new()
    else
        Neurologics.SelectedGamemode = Neurologics.Gamemodes.Gamemode:new()
    end

    if Neurologics.SelectedGamemode.RequiredGamemode then
        Neurologics.OriginalGamemode = Game.ServerSettings.GameModeIdentifier
        Game.NetLobbyScreen.SelectedModeIdentifier = Neurologics.SelectedGamemode.RequiredGamemode
        chooseGamemode.Gamemode = Game.NetLobbyScreen.SelectedMode
    end

    if Neurologics.SelectedGamemode then
        Neurologics.SelectedGamemode:PreStart()
    end
end

Neurologics.RoundStart = function()
    Neurologics.Log("Starting traitor round - Traitor Mod v" .. Neurologics.VERSION)
    pointsGiveTimer = Timer.GetTime() + Neurologics.Config.ExperienceTimer

    Neurologics.CodeWords = Neurologics.SelectCodeWords()

    -- give XP to players based on stored points
    for key, value in pairs(Client.ClientList) do
        if value.Character ~= nil then
            Neurologics.SetData(value, "Name", value.Character.Name)
        end

        if not value.SpectateOnly then
            Neurologics.LoadExperience(value)
        else
            Neurologics.Debug("Skipping load experience for spectator " .. value.Name)
        end

        -- Send Welcome message
        Neurologics.SendWelcome(value)
    end

    if Neurologics.Config.HideCrewList then
        for key, value in pairs(Character.CharacterList) do
            Networking.CreateEntityEvent(value, Character.RemoveFromCrewEventData.__new(value.TeamID, {}))
        end
    end

    if Neurologics.SelectedGamemode == nil then
        Neurologics.Log("No gamemode selected!")
        return
    end

    Neurologics.Log("Starting gamemode " .. Neurologics.SelectedGamemode.Name)

    if Neurologics.SubmarineBuilder then
        Neurologics.SubmarineBuilder.RoundStart()
    end

    if Neurologics.SelectedGamemode then
        Neurologics.SelectedGamemode:Start()
    end
end

Hook.Patch("Barotrauma.Networking.GameServer", "InitiateStartGame", function (instance, ptable)
    local mode = {}
    Neurologics.PreRoundStart(ptable["selectedSub"], mode)
    if mode.Gamemode then
        ptable["selectedMode"] = mode.Gamemode
    end

    if Neurologics.SubmarineBuilder then
        ptable["selectedShuttle"] = Neurologics.SubmarineBuilder.BuildSubmarines()
    end
end)

Hook.Add("roundStart", "Neurologics.RoundStart", function()
    Neurologics.RoundStart()
end)

Hook.Add("missionsEnded", "Neurologics.MissionsEnded", function(missions)
    Neurologics.RoundMissions = missions
    Neurologics.Debug("missionsEnded with " .. #Neurologics.RoundMissions .. " missions.")

    for key, value in pairs(Client.ClientList) do
        -- add weight according to points and config conversion
        Neurologics.AddData(value, "Weight", Neurologics.Config.AmountWeightWithPoints(Neurologics.GetData(value, "Points") or 0))
    end

    Neurologics.Debug("Round " .. Neurologics.RoundNumber .. " ended.")
    Neurologics.RoundNumber = Neurologics.RoundNumber + 1
    Neurologics.Stats.AddStat("Rounds", "Rounds finished", 1)

    Neurologics.PointsToBeGiven = {}
    Neurologics.AbandonedCharacters = {}
    Neurologics.PointItems = {}
    Neurologics.RoundTime = 0
    Neurologics.LostLivesThisRound = {}

    local endMessage = ""
    if Neurologics.SelectedGamemode then
        endMessage = Neurologics.SelectedGamemode:RoundSummary()

        Neurologics.SendMessageEveryone(Neurologics.HighlightClientNames(endMessage, Color.Red))
    end
    Neurologics.LastRoundSummary = endMessage

    if Neurologics.SelectedGamemode then
        Neurologics.SelectedGamemode:End(missions)
    end

    Neurologics.RoleManager.EndRound()
    Neurologics.RoundEvents.EndRound()

    Neurologics.SelectedGamemode = nil

    Neurologics.SaveData()
    Neurologics.Stats.SaveData()

    if Neurologics.Config.RemotePoints then
        for key, value in pairs(Client.ClientList) do
            Neurologics.PublishRemoteData(value)
        end
    end
end)

Hook.Add("roundEnd", "Neurologics.RoundEnd", function()
    if Neurologics.OriginalGamemode then
        Game.NetLobbyScreen.SelectedModeIdentifier = Neurologics.OriginalGamemode
        Neurologics.OriginalGamemode = nil
    end

    Neurologics.RespawnedCharacters = {}

    if Neurologics.SelectedGamemode then
        --return Neurologics.SelectedGamemode:TraitorResults()
        return nil
    end
end)

Hook.Add("characterCreated", "Neurologics.CharacterCreated", function(character)
    -- if character is valid player
    if character == nil or
        character.IsBot == true or
        character.IsHuman == false or
        character.ClientDisconnected == true then
        return
    end

    -- delay handling, otherwise client won't be found
    Timer.Wait(function()
        local client = Neurologics.FindClientCharacter(character)
        
        Neurologics.Stats.AddClientStat("Spawns", client, 1)

        if client ~= nil then
            -- set experience of respawned character to stored value - note initial spawn may not call this hook (on local server)
            Neurologics.LoadExperience(client)
        else
            Neurologics.Error("Loading experience on characterCreated failed! Client was nil after 1sec")
        end
    end, 1000)
end)

local tipDelay = 0

-- register tick
Hook.Add("think", "Neurologics.Think", function()
    if Timer.GetTime() > tipDelay then
        tipDelay = Timer.GetTime() + 500
        Neurologics.SendTip()
    end

    if not Game.RoundStarted or Neurologics.SelectedGamemode == nil then
        return
    end

    Neurologics.RoundTime = Neurologics.RoundTime + 1 / 60

    if Neurologics.SelectedGamemode then
        Neurologics.SelectedGamemode:Think()
    end

    -- every 60s, if a character has 100+ PointsToBeGiven, store added points and send feedback
    if pointsGiveTimer and Timer.GetTime() > pointsGiveTimer then
        for key, value in pairs(Neurologics.PointsToBeGiven) do
            if value > 100 then
                local points = Neurologics.AwardPoints(key, value)
                if Neurologics.GiveExperience(key.Character, Neurologics.Config.AmountExperienceWithPoints(points)) then
                    local text = Neurologics.Language.SkillsIncreased ..
                        "\n" .. string.format(Neurologics.Language.PointsAwarded, math.floor(points))
                    Game.SendDirectChatMessage("", text, nil, Neurologics.Config.ChatMessageType, key)

                    Neurologics.PointsToBeGiven[key] = 0
                end
            end
        end

        -- if configured, give temporary experience to all characters
        if Neurologics.Config.FreeExperience and Neurologics.Config.FreeExperience > 0 then
            for key, value in pairs(Client.ClientList) do
                Neurologics.GiveExperience(value.Character, Neurologics.Config.FreeExperience)
            end
        end

        pointsGiveTimer = Timer.GetTime() + Neurologics.Config.ExperienceTimer
    end
end)

-- when a character gains skill level, add PointsToBeGiven according to config
Neurologics.PointsToBeGiven = {}
Hook.HookMethod("Barotrauma.CharacterInfo", "IncreaseSkillLevel", function(instance, ptable)
    if not ptable or ptable.gainedFromAbility or instance.Character == nil or instance.Character.IsDead then return end

    local client = Neurologics.FindClientCharacter(instance.Character)

    if client == nil then return end

    local points = Neurologics.Config.PointsGainedFromSkill[tostring(ptable.skillIdentifier)]

    if points == nil then return end

    points = points * ptable.increase

    Neurologics.PointsToBeGiven[client] = (Neurologics.PointsToBeGiven[client] or 0) + points
end)

Neurologics.AbandonedCharacters = {}
-- new player connected to the server
Hook.Add("clientConnected", "Neurologics.ClientConnected", function (client)
    if Neurologics.Config.RemotePoints then
        Neurologics.LoadRemoteData(client, function ()
            Neurologics.SendWelcome(client)
        end)
    else
        Neurologics.SendWelcome(client)
    end

    if Neurologics.AbandonedCharacters[client.SteamID] then
        if Neurologics.AbandonedCharacters[client.SteamID].IsDead then
            -- client left while char was alive -> but char is dead
            Neurologics.Debug(string.format("%s connected, but his character died in the meantime...", Neurologics.ClientLogName(client)))
        end

        Neurologics.AbandonedCharacters[client.SteamID] = nil
    end
end)

-- player disconnected from server
Hook.Add("clientDisconnected", "Neurologics.ClientDisconnected", function (client)
    if Neurologics.Config.RemotePoints then
        Neurologics.PublishRemoteData(client)
    end

    -- if character was alive while disconnecting, make sure player looses live if he rejoins the round
    if client.Character and not client.Character.IsDead and client.Character.IsHuman then
        Neurologics.Debug(string.format("%s disconnected with an alive character. Remembering for rejoin...", Neurologics.ClientLogName(client)))
        Neurologics.AbandonedCharacters[client.SteamID] = client.Character
    end
end)

-- Neurologics.Commands hook
Hook.Add("chatMessage", "Neurologics.ChatMessage", function(message, client)
    local split = Neurologics.ParseCommand(message)

    if #split == 0 then return end

    local command = string.lower(table.remove(split, 1))

    if Neurologics.Commands[command] then
        Neurologics.Log(Neurologics.ClientLogName(client) .. " used command: " .. message)
        return Neurologics.Commands[command].Callback(client, split)
    end
end)


LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Item"], "set_InventoryIconColor")

Neurologics.PointItems = {}
Neurologics.SpawnPointItem = function(inventory, amount, text, onSpawn, onUsed)
    text = text or ""

    Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab("logbook"), inventory, nil, nil, function(item)
        Neurologics.PointItems[item] = {}
        Neurologics.PointItems[item].Amount = amount
        Neurologics.PointItems[item].OnUsed = onUsed

        local terminal = item.GetComponentString("Terminal")
        terminal.ShowMessage = text ..
            "\nThis LogBook contains " .. amount .. " points. Type \"claim\" into it to claim the points."
        terminal.SyncHistory()

        item.set_InventoryIconColor(Color(0, 0, 255))
        item.SpriteColor = Color(0, 0, 255, 255)
        item.Scale = 0.5

        local color = item.SerializableProperties[Identifier("SpriteColor")]
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(color, item))

        local scale = item.SerializableProperties[Identifier("Scale")]
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(scale, item))

        local invColor = item.SerializableProperties[Identifier("InventoryIconColor")]
        Networking.CreateEntityEvent(item, Item.ChangePropertyEventData(invColor, item))

        if onSpawn then
            onSpawn(item)
        end
    end)
end

Hook.Patch("Barotrauma.Items.Components.Terminal", "ServerEventRead", function(instance, ptable)
    local msg = ptable["msg"]
    local client = ptable["c"]

    local rewindBit = msg.BitPosition
    local output = msg.ReadString()
    msg.BitPosition = rewindBit -- this is so the game can still read the net message, as you cant read the same bit twice

    local item = instance.Item

    Hook.Call("Neurologics.terminalWrite", item, client, output)
end, Hook.HookMethodType.Before)


Hook.Add("Neurologics.terminalWrite", "Neurologics.PointItem", function (item, client, output)
    if output ~= "claim" then return end

    local data = Neurologics.PointItems[item]

    if data == nil then return end

    Neurologics.AwardPoints(client, data.Amount)
    Neurologics.SendMessage(client, "You have received " .. data.Amount .. " points.", "InfoFrameTabButton.Mission")

    if data.OnUsed then
        data.OnUsed(client)
    end

    local terminal = item.GetComponentString("Terminal")
    terminal.ShowMessage = "Claimed by " .. client.Name
    terminal.SyncHistory()

    Neurologics.PointItems[item] = nil
end)

if Neurologics.Config.OverrideRespawnSubmarine then
    Neurologics.SubmarineBuilder = dofile(Neurologics.Path .. "/Lua/submarinebuilder.lua")
end

Neurologics.StringBuilder = dofile(Neurologics.Path .. "/Lua/stringbuilder.lua")
Neurologics.Voting = dofile(Neurologics.Path .. "/Lua/voting.lua")
Neurologics.RoleManager = dofile(Neurologics.Path .. "/Lua/rolemanager.lua")
Neurologics.Pointshop = dofile(Neurologics.Path .. "/Lua/pointshop.lua")
Neurologics.RoundEvents = dofile(Neurologics.Path .. "/Lua/roundevents.lua")
Neurologics.MidRoundSpawn = dofile(Neurologics.Path .. "/Lua/midroundspawn.lua")
Neurologics.GhostRoles = dofile(Neurologics.Path .. "/Lua/ghostroles.lua")

dofile(Neurologics.Path .. "/Lua/playtime.lua")
dofile(Neurologics.Path .. "/Lua/commands.lua")
dofile(Neurologics.Path .. "/Lua/statistics.lua")
dofile(Neurologics.Path .. "/Lua/respawnshuttle.lua")
dofile(Neurologics.Path .. "/Lua/Neurologicsmisc.lua")

Neurologics.AddGamemode(dofile(Neurologics.Path .. "/Lua/gamemodes/gamemode.lua"))
Neurologics.AddGamemode(dofile(Neurologics.Path .. "/Lua/gamemodes/secret.lua"))
Neurologics.AddGamemode(dofile(Neurologics.Path .. "/Lua/gamemodes/pvp.lua"))
Neurologics.AddGamemode(dofile(Neurologics.Path .. "/Lua/gamemodes/submarineroyale.lua"))
Neurologics.AddGamemode(dofile(Neurologics.Path .. "/Lua/gamemodes/attackdefend.lua"))

Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/objective.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/assassinate.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/kidnap.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/poisoncaptain.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/stealcaptainid.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/survive.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/husk.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/turnhusk.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/destroycaly.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/assassinatedrunk.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/bananaslip.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/suffocatecrew.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/growmudraptors.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/assassinatepressure.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/stealidcard.lua"))

Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/killmonsters.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/killsmallmonsters.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/killlargemonsters.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/killpets.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/killabyssmonster.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/repair.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/finishroundfast.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/securityteamsurvival.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/repairmechanical.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/repairelectrical.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/repairhull.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/healcharacters.lua"))
Neurologics.RoleManager.AddObjective(dofile(Neurologics.Path .. "/Lua/objectives/crew/finishallobjectives.lua"))

Neurologics.RoleManager.AddRole(dofile(Neurologics.Path .. "/Lua/roles/role.lua"))
Neurologics.RoleManager.AddRole(dofile(Neurologics.Path .. "/Lua/roles/antagonist.lua"))
Neurologics.RoleManager.AddRole(dofile(Neurologics.Path .. "/Lua/roles/traitor.lua"))
Neurologics.RoleManager.AddRole(dofile(Neurologics.Path .. "/Lua/roles/cultist.lua"))
Neurologics.RoleManager.AddRole(dofile(Neurologics.Path .. "/Lua/roles/huskservant.lua"))
Neurologics.RoleManager.AddRole(dofile(Neurologics.Path .. "/Lua/roles/crew.lua"))
Neurologics.RoleManager.AddRole(dofile(Neurologics.Path .. "/Lua/roles/clown.lua"))

if Neurologics.Config.Extensions then
    for key, extension in pairs(Neurologics.Config.Extensions) do
        local config = Neurologics.Config.ExtensionConfig[extension.Identifier or ""]
        if config then
            for key, value in pairs(config) do
                extension[key] = value
            end
        end
        if extension.Init then
            extension.Init()
        end
    end
end

-- Round start call for reload during round
if Game.RoundStarted then
    Neurologics.PreRoundStart(Submarine.MainSub.Info, {})
    Neurologics.RoundStart()
end
