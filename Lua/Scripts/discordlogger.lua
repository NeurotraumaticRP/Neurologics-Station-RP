local json = require("json")
Neurologics.DiscordLogger = {}

-- Load round data from JSON file (stored in ServerInfo directory)
function json.loadRoundData()
    local path = Neurologics.ServerInfoPath .. "/round_data.json"
    
    if not File.Exists(path) then
        File.Write(path, "[]")
        return {}
    end

    local content = File.Read(path)
    local success, result = pcall(json.decode, content)
    if not success or result == nil then
        print("[DiscordLogger] Warning: Failed to parse round_data.json, resetting to empty")
        File.Write(path, "[]")
        return {}
    end
    
    return result
end

-- Save round data to JSON file (stored in ServerInfo directory)
function json.saveRoundData(roundData)
    local path = Neurologics.ServerInfoPath .. "/round_data.json"
    File.Write(path, json.encode(roundData))
end

-- Initialize round data
local roundData = json.loadRoundData()
local maxRounds = 50000

-- Add new round data and manage history
function Neurologics.DiscordLogger.addRoundData(newRound)
    -- Check for duplicate round IDs
    if #roundData > 0 and newRound.roundId == roundData[#roundData].roundId then
        return
    end

    table.insert(roundData, newRound)

    -- Remove oldest round if exceeding max rounds
    if #roundData > maxRounds then
        table.remove(roundData, 1)
    end

    json.saveRoundData(roundData)
end

-- Escape quotes for Discord webhook
local function escapeQuotes(str)
    return str:gsub("\"", "\\\"")
end

-- Format round information
local function formatRoundInfo(round)
    local roundInfo = string.format("**Round ID:** %d\n**Round Time:** %d seconds\n", round.roundId, round.roundTime)
    roundInfo = roundInfo .. "**Clients:**\n"
    
    for _, client in ipairs(round.clients) do
        local traitorInfo = client.isTraitor and "\n> **Traitor:** Yes" or ""
        roundInfo = roundInfo .. string.format("> **Name:** %s\n> **SteamID:** %s\n> **Character:** %s\n> **Job:** %s%s\n\n",
            client.name, client.steamId, client.characterName, client.job, traitorInfo)
    end

    return roundInfo
end

-- Send round information to Discord
function Neurologics.DiscordLogger.sendRoundInfoToDiscord(round)
    local discordWebHook = Neurologics.GetAPIKey("discordRoundLogger")
    if not discordWebHook or discordWebHook == "" then
        return
    end
    
    local roundInfo = formatRoundInfo(round)
    local escapedMessage = escapeQuotes(roundInfo)
    
    local payload = json.encode({ content = escapedMessage, username = "Round Logger" })
    
    Networking.RequestPostHTTP(discordWebHook, function(result)
    end, payload)
end

-- Initialize variables
local currentRoundId = (#roundData > 0) and (roundData[#roundData].roundId + 1) or 1
local roundStartTime = 0
local roundClients = {}

-- Hook for round start
Hook.Add("roundStart", "namelogging", function()
    -- Reset variables
    roundClients = {}
    roundStartTime = os.time()

    for i, client in pairs(Client.ClientList) do
        local clientData = {
            name = client.Name,
            steamId = client.SteamID,
            characterName = client.Character and client.Character.Name or "N/A",
            job = client.Character and client.Character.JobIdentifier.ToString() or "N/A",
            isTraitor = false -- Initialize as false
        }
        table.insert(roundClients, clientData)
    end
end)

-- Hook for round end
Hook.Add("roundEnd", "roundEndLogging", function()

    -- Calculate round time
    local roundTime = os.time() - roundStartTime

    -- Update client list with any new clients or characters who joined mid-game
    for i, client in pairs(Client.ClientList) do
        local found = false
        for _, roundClient in ipairs(roundClients) do
            if roundClient.steamId == client.SteamID then
                found = true
                break
            end
        end

        if not found then
            local clientData = {
                name = client.Name,
                steamId = client.SteamID,
                characterName = client.Character and client.Character.Name or "N/A",
                job = client.Character and client.Character.JobIdentifier.ToString() or "N/A",
                isTraitor = false -- Initialize as false
            }
            table.insert(roundClients, clientData)
        end
    end

    -- Check for traitors
    local traitors = {}
    for i, character in pairs(Character.CharacterList) do
        if character.IsTraitor then
            local traitorName = character.Name
            table.insert(traitors, traitorName)
            for _, client in ipairs(roundClients) do
                if client.characterName == traitorName then
                    client.isTraitor = true
                end
            end
        end
    end

    -- Prepare round data
    local newRound = {
        roundId = currentRoundId,
        roundTime = roundTime,
        clients = roundClients,
        traitors = traitors
    }

    -- Save round data and send to Discord
    Neurologics.DiscordLogger.addRoundData(newRound)
    Neurologics.DiscordLogger.sendRoundInfoToDiscord(newRound)

    -- Increment round ID for next round
    currentRoundId = currentRoundId + 1
end)

if CLIENT then return end

-- Load API configuration from apikeys.json
local api_endpoint = (Neurologics.GetAPIKey("javierbotApi") or "http://165.22.185.236:8080") .. "/update_data"
local api_key = Neurologics.GetAPIKey("javierbotApiKey") or ""
local json = require 'json'

local function sendPlayerCountToAPI()
    -- Skip if API key is not configured
    if not api_key or api_key == "" then return end

    local data = {
        api_key = api_key,
        data_type = "playercount",
        data = {
            player_count = #Client.ClientList,
            max_players = Game.ServerSettings.MaxPlayers,
            server_name = Game.ServerSettings.ServerName,
            map_name = Game.ServerSettings.SelectedSubmarine
        }
    }

    if next(data.data) ~= nil then
        local payload = json.encode(data)
        Networking.RequestPostHTTP(api_endpoint, function(result) end, payload)
    end
end

local Timertick = 0
Hook.Add("Think", "Timer", function()
    Timertick = Timertick + 1
    if Timertick >= 600 then
        sendPlayerCountToAPI()
        Timertick = 0
    end
end)


-- Track who issued the last punishment (for console commands)
Neurologics.DiscordLogger.LastPunisher = nil

-- for bans
Hook.Patch(
    "Barotrauma.Networking.GameServer",
    "BanClient",
    {
        "Barotrauma.Networking.Client",
        "System.String",
        "System.TimeSpan"
    },

    function(instance, ptable)
      local client = ptable["client"]
      local reason = ptable["reason"]
      local duration = ptable["duration"]

      local punisherName = "Console"
      local punisherSteamId = nil
      if Neurologics.DiscordLogger.LastPunisher then
          punisherName = Neurologics.DiscordLogger.LastPunisher.Name or "Console"
          punisherSteamId = Neurologics.DiscordLogger.LastPunisher.SteamID
      end

      local data = {
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "Ban",
            tempban_duration = tostring(duration),
            punished_by = punisherName,
            punisher_steamid = punisherSteamId,
        }
      }
      
      local payload = json.encode(data)
      Networking.RequestPostHTTP(api_endpoint, function(result) end, payload)
      
      Neurologics.DiscordLogger.LastPunisher = nil

    end, Hook.HookMethodType.Before)

function Neurologics.DiscordLogger.RecieveRoleBan(client, jobs, reason, punisher)
    -- Ensure jobs is a table (array) of strings
    local jobsArray = {}
    if type(jobs) == "string" then
        -- If jobs is a single string, split it into an array
        for job in jobs:gmatch("%S+") do
            table.insert(jobsArray, job)
        end
    elseif type(jobs) == "table" then
        -- If jobs is already a table, use it as is
        jobsArray = jobs
    else
        -- If jobs is neither a string nor a table, log an error
        return
    end

    -- Get punisher info
    local punisherName = "Console"
    local punisherSteamId = nil
    if punisher then
        punisherName = punisher.Name or "Console"
        punisherSteamId = punisher.SteamID
    end

    local data = {
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "jobban",
            rolebanned_roles = jobsArray,
            punished_by = punisherName,
            punisher_steamid = punisherSteamId,
        }
    }

    local payload = json.encode(data)
    Networking.RequestPostHTTP(api_endpoint, function(result) end, payload)
end

function Neurologics.DiscordLogger.RecieveWarn(client, reason, punisher)
    -- Get punisher info
    local punisherName = "Console"
    local punisherSteamId = nil
    if punisher then
        punisherName = punisher.Name or "Console"
        punisherSteamId = punisher.SteamID
    end

    local data = {  
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "warn",
            punished_by = punisherName,
            punisher_steamid = punisherSteamId,
        }
    }

    local payload = json.encode(data)
    Networking.RequestPostHTTP(api_endpoint, function(result) end, payload)
end

function Neurologics.DiscordLogger.SteamidToClient(steamid)
    for _, client in pairs(Client.ClientList) do
        if (client.SteamID == steamid) or (client.AccountInfo and client.AccountInfo.AccountId == steamid) then
            return client
        end
    end

    return nil
end

Hook.Patch(
    "Barotrauma.Networking.GameServer",
    "KickClient",
    {
        "Barotrauma.Networking.Client",
        "System.String",
        "System.Boolean"
    },

    function(instance, ptable)
      local client = ptable["client"]
      local reason = ptable["reason"]
      
      -- Try to get the punisher from our tracker, or mark as Console/Unknown
      local punisherName = "Console"
      local punisherSteamId = nil
      if Neurologics.DiscordLogger.LastPunisher then
          punisherName = Neurologics.DiscordLogger.LastPunisher.Name or "Console"
          punisherSteamId = Neurologics.DiscordLogger.LastPunisher.SteamID
      end

      local data = {
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "Kick",
            punished_by = punisherName,
            punisher_steamid = punisherSteamId,
        }
      }
      
      local payload = json.encode(data)
      Networking.RequestPostHTTP(api_endpoint, function(result) end, payload)
      
      -- Clear the tracker after use
      Neurologics.DiscordLogger.LastPunisher = nil

    end, Hook.HookMethodType.Before)

local function checkCommandQueue()
    -- Skip if API key is not configured
    if not api_key or api_key == "" then return end
    
    local baseApi = Neurologics.GetAPIKey("javierbotApi") or "http://165.22.185.236:8080"
    local commandQueueEndpoint = baseApi .. "/commandqueue"
    
    Networking.RequestGetHTTP(commandQueueEndpoint .. "?api_key=" .. api_key, function(result)
        if result and result ~= "" then
            -- Safely decode JSON response
            local success, commands = pcall(json.decode, result)
            if not success or commands == nil then
                return
            end
            
            if type(commands) == "table" and #commands > 0 then
                for _, command in ipairs(commands) do
                    if command.content and not Starts_with_special_char(command.content) then
                        for client in Client.ClientList do
                            if client.Character == nil or client.Character.IsDead then
                                Neurologics.SendChatMessage(client, "(Discord) " .. (command.author or "Unknown") .. ": " .. command.content)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local CommandQueueTick = 0
Hook.Add("Think", "CommandQueueTimer", function()
    CommandQueueTick = CommandQueueTick + 1
    if CommandQueueTick >= 180 then
        checkCommandQueue()
        CommandQueueTick = 0
    end
end)

function Neurologics.DiscordLogger.SendChatToDiscord(sender, message)
    local baseApi = Neurologics.GetAPIKey("javierbotApi") or "http://165.22.185.236:8080"
    local chat_endpoint = baseApi .. "/chat"
    local data = {
        api_key = api_key,
        sender = sender,
        message = message
    }
    
    local payload = json.encode(data)
    Networking.RequestPostHTTP(chat_endpoint, function(result) end, payload)
end

function Starts_with_special_char(str)
    if str:match("^[/:!;><]") then
        return true
    else
        return false
    end
end

Auth_codes = {}
