if CLIENT then return end

--[[local api_endpoint = Neurologics.GetAPIKey("apiEndpoint")
local api_key = Neurologics.GetAPIKey("apiKey")
local json = require 'json'

local function sendPlayerCountToAPI()
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
        Networking.RequestPostHTTP(api_endpoint, function(result)
        end, payload)
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



      local data = {
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "Ban",
            tempban_duration = duration,
        }

        }
        local payload = json.encode(data)
        Networking.RequestPostHTTP(api_endpoint, function(result) end, payload)

    end, Hook.HookMethodType.Before)

function Neurologics.RecieveRoleBan(client, jobs, reason)
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

    local data = {
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "jobban",
            rolebanned_roles = jobsArray,  -- Send as an array
        }
    }

    local payload = json.encode(data)
    print("Sending jobban punishment payload: " .. payload)  -- Add this line for debugging
    Networking.RequestPostHTTP(api_endpoint, function(result)
        print("Received response for jobban punishment: " .. tostring(result))
    end, payload)
end

function Neurologics.RecieveWarn(client, reason)
    local data = {
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "warn",
            -- discordid is optional and can be omitted or set to nil
        }
    }

    local payload = json.encode(data)
    print("Sending warn punishment payload: " .. payload)  -- Add this line for debugging
    Networking.RequestPostHTTP(api_endpoint, function(result)
        print("Received response for warn punishment: " .. tostring(result))
    end, payload)
end

function Neurologics.SteamidToClient(steamid)
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



      local data = {
        api_key = api_key,
        data_type = "punishment",
        data = {
            steamid = client.SteamID,
            name = client.Name,
            reason = reason,
            punishment = "Kick",
        }

        }
        local payload = json.encode(data)
        Networking.RequestPostHTTP(api_endpoint, function(result) end, payload)

    end, Hook.HookMethodType.Before)

local function checkCommandQueue()
    local api_endpoint = 'http://165.22.185.236:8080/commandqueue'
    local data = {
        api_key = api_key
    }
    
    Networking.RequestGetHTTP(api_endpoint .. "?api_key=" .. api_key, function(result)
        if result ~= "" then
            local commands = json.decode(result)
            if #commands > 0 then
                for _, command in ipairs(commands) do
                    if not Starts_with_special_char(command.content) then
                        print("Received command from " .. command.author .. ": " .. command.content)
                        for client in Client.ClientList do
                            if client.Character == nil or client.Character.IsDead then
                                Neurologics.SendChatMessage(client, "(Discord) "..command.author .. ": " .. command.content)
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
    if CommandQueueTick >= 180 then  -- Check every 10 seconds (adjust as needed)
        checkCommandQueue()
        CommandQueueTick = 0
    end
end)

Hook.Add("chatMessage", "content filter", function(message, client)
    -- Load words from words.json
    local words = {}
    local content = File.Read(Neurologics.Path .. "/Lua/words.json")
    if content then
        words = json.decode(content)
    end

    -- Check if any word from words.json is in the message
    for _, word in ipairs(words) do
        if string.match(message:lower(), word:lower()) then
            if client.Character then
                client.Character.Kill()
            end
            Neurologics.SendMessage(client, "You have been warned for violating the content filter.")
           return true
        end
    end
end)]]-- disabled for now