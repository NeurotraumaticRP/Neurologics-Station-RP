-- Generic Status Monitor System
-- Allows any event/system to monitor character states and trigger callbacks
-- Supports both client-based and character-based monitoring

local SM = {}

-- Data structure: { monitorID = { config, tracked = {} } }
SM.Monitors = {}
SM.CharacterMonitors = {} -- Character-based monitors (for bots support)
SM.CheckInterval = 1 -- Check once per second
SM.LastCheck = 0
SM.RoundStartNotified = false
SM.RoundNotStartedWarned = false
SM.DebugMode = false -- Toggle verbose logging (use !statusmonitordebug to toggle)

-- Helper function for debug prints (only prints if DebugMode is enabled)
local function debugPrint(msg)
    if SM.DebugMode then
        print(msg)
    end
end

-- Register a status monitor (client-based - original behavior)
-- id: Unique identifier
-- config: {
--   condition = function(client) -> bool,  -- Condition to track
--   threshold = number,                     -- Seconds condition must be true
--   onTrigger = function(client),          -- Called when threshold met
--   onReset = function(client),            -- Optional: called when condition becomes false
--   filter = function(client) -> bool,     -- Optional: pre-filter clients
-- }
SM.RegisterMonitor = function(id, config)
    if not config.condition or not config.threshold or not config.onTrigger then
        print("[ERROR] StatusMonitor: Invalid config for " .. id)
        return false
    end
    
    SM.Monitors[id] = {
        config = config,
        tracked = {} -- { clientID = { startTime, triggered } }
    }
    
    -- Count monitors
    local count = 0
    for _ in pairs(SM.Monitors) do count = count + 1 end
    
    print("[StatusMonitor] Registered monitor '" .. id .. "' with threshold " .. config.threshold .. "s (Total monitors: " .. count .. ")")
    return true
end

-- Register a CHARACTER-based monitor (supports bots and all characters)
-- id: Unique identifier
-- config: {
--   condition = function(character) -> bool,  -- Condition to track
--   threshold = number,                        -- Seconds condition must be true
--   onTrigger = function(character),          -- Called when threshold met
--   onReset = function(character),            -- Optional: called when condition becomes false
--   filter = function(character) -> bool,     -- Optional: pre-filter characters
--   getCharacters = function() -> table,      -- Optional: custom function to get characters to check
-- }
SM.RegisterCharacterMonitor = function(id, config)
    if not config.condition or not config.threshold or not config.onTrigger then
        print("[ERROR] StatusMonitor: Invalid config for character monitor " .. id)
        return false
    end
    
    SM.CharacterMonitors[id] = {
        config = config,
        tracked = {} -- { characterID = { startTime, triggered, character } }
    }
    
    -- Count monitors
    local count = 0
    for _ in pairs(SM.CharacterMonitors) do count = count + 1 end
    
    print("[StatusMonitor] Registered CHARACTER monitor '" .. id .. "' with threshold " .. config.threshold .. "s (Total character monitors: " .. count .. ")")
    return true
end

-- Unregister a character monitor
SM.UnregisterCharacterMonitor = function(id)
    SM.CharacterMonitors[id] = nil
end

-- Unregister a monitor
SM.UnregisterMonitor = function(id)
    SM.Monitors[id] = nil
end

-- Check a single client against a monitor
SM.CheckClient = function(monitorID, monitor, client)
    if not client or not client.Character then
        -- Clear tracking if client/character is gone
        if monitor.tracked[client.SteamID] then
            monitor.tracked[client.SteamID] = nil
        end
        return
    end
    
    local config = monitor.config
    
    debugPrint(string.format("[StatusMonitor] Checking client: %s", client.Name))
    
    -- Apply filter if exists
    if config.filter then
        local filterPassed = config.filter(client)
        debugPrint(string.format("[StatusMonitor '%s'] %s filter result: %s", monitorID, client.Name, tostring(filterPassed)))
        if not filterPassed then
            -- Clear tracking if filter fails
            if monitor.tracked[client.SteamID] then
                debugPrint(string.format("[StatusMonitor '%s'] %s no longer passes filter", monitorID, client.Name))
                if config.onReset then
                    config.onReset(client)
                end
                monitor.tracked[client.SteamID] = nil
            end
            return
        end
    end
    
    -- Check condition
    local success, conditionMet = pcall(config.condition, client)
    if not success then
        print(string.format("[ERROR] StatusMonitor '%s' condition error for %s: %s", monitorID, client.Name, tostring(conditionMet)))
        return
    end
    
    debugPrint(string.format("[StatusMonitor '%s'] %s condition met: %s", monitorID, client.Name, tostring(conditionMet)))
    
    if conditionMet then
        -- Condition is true, start or continue tracking
        if not monitor.tracked[client.SteamID] then
            -- Start tracking
            monitor.tracked[client.SteamID] = {
                startTime = Timer.GetTime(),
                triggered = false,
                client = client
            }
            debugPrint(string.format("[StatusMonitor '%s'] Started tracking %s", monitorID, client.Name))
        else
            -- Continue tracking
            local tracked = monitor.tracked[client.SteamID]
            local duration = Timer.GetTime() - tracked.startTime
            
            -- Debug message showing progress toward threshold
            debugPrint(string.format("[StatusMonitor '%s'] %s tracked for %.1fs / %.1fs", 
                monitorID, client.Name, duration, config.threshold))
            
            -- Check if threshold met
            if not tracked.triggered and duration >= config.threshold then
                print(string.format("[StatusMonitor '%s'] THRESHOLD MET for %s (%.1fs)!!!", 
                    monitorID, client.Name, duration))
                
                -- Trigger callback
                local success, err = pcall(config.onTrigger, client)
                if not success then
                    print(string.format("[ERROR] StatusMonitor '%s' trigger error: %s", monitorID, tostring(err)))
                end
                
                tracked.triggered = true
            end
        end
    else
        -- Condition is false, reset tracking
        if monitor.tracked[client.SteamID] then
            local tracked = monitor.tracked[client.SteamID]
            
            -- Only call onReset if not yet triggered
            if not tracked.triggered and config.onReset then
                local success, err = pcall(config.onReset, client)
                if not success then
                    print(string.format("[ERROR] StatusMonitor '%s' reset error: %s", monitorID, tostring(err)))
                end
            end
            
            monitor.tracked[client.SteamID] = nil
            debugPrint(string.format("[StatusMonitor '%s'] Stopped tracking %s", monitorID, client.Name))
        end
    end
end

-- Check a single CHARACTER against a character monitor
SM.CheckCharacter = function(monitorID, monitor, character)
    if not character or character.IsDead or character.Removed then
        -- Clear tracking if character is gone/dead
        if character and monitor.tracked[character.ID] then
            monitor.tracked[character.ID] = nil
        end
        return
    end
    
    local config = monitor.config
    local charID = character.ID
    
    -- Apply filter if exists
    if config.filter then
        local filterPassed = config.filter(character)
        debugPrint(string.format("[StatusMonitor '%s'] Character %s filter result: %s", monitorID, character.Name, tostring(filterPassed)))
        if not filterPassed then
            -- Clear tracking if filter fails
            if monitor.tracked[charID] then
                debugPrint(string.format("[StatusMonitor '%s'] Character %s no longer passes filter", monitorID, character.Name))
                if config.onReset then
                    config.onReset(character)
                end
                monitor.tracked[charID] = nil
            end
            return
        end
    end
    
    -- Check condition
    local success, conditionMet = pcall(config.condition, character)
    if not success then
        print(string.format("[ERROR] StatusMonitor '%s' condition error for character %s: %s", monitorID, character.Name, tostring(conditionMet)))
        return
    end
    
    debugPrint(string.format("[StatusMonitor '%s'] Character %s condition met: %s", monitorID, character.Name, tostring(conditionMet)))
    
    if conditionMet then
        -- Condition is true, start or continue tracking
        if not monitor.tracked[charID] then
            -- Start tracking
            monitor.tracked[charID] = {
                startTime = Timer.GetTime(),
                triggered = false,
                character = character
            }
            debugPrint(string.format("[StatusMonitor '%s'] Started tracking character %s", monitorID, character.Name))
        else
            -- Continue tracking
            local tracked = monitor.tracked[charID]
            local duration = Timer.GetTime() - tracked.startTime
            
            -- Debug message showing progress toward threshold
            debugPrint(string.format("[StatusMonitor '%s'] Character %s tracked for %.1fs / %.1fs", 
                monitorID, character.Name, duration, config.threshold))
            
            -- Check if threshold met
            if not tracked.triggered and duration >= config.threshold then
                print(string.format("[StatusMonitor '%s'] THRESHOLD MET for character %s (%.1fs)!!!", 
                    monitorID, character.Name, duration))
                
                -- Trigger callback
                local success, err = pcall(config.onTrigger, character)
                if not success then
                    print(string.format("[ERROR] StatusMonitor '%s' trigger error: %s", monitorID, tostring(err)))
                end
                
                tracked.triggered = true
            end
        end
    else
        -- Condition is false, reset tracking
        if monitor.tracked[charID] then
            local tracked = monitor.tracked[charID]
            
            -- Only call onReset if not yet triggered
            if not tracked.triggered and config.onReset then
                local success, err = pcall(config.onReset, character)
                if not success then
                    print(string.format("[ERROR] StatusMonitor '%s' reset error: %s", monitorID, tostring(err)))
                end
            end
            
            monitor.tracked[charID] = nil
            debugPrint(string.format("[StatusMonitor '%s'] Stopped tracking character %s", monitorID, character.Name))
        end
    end
end

-- Think hook to check all monitors
Hook.Add("think", "Neurologics.StatusMonitor", function()
    -- Check 1: Game.RoundStarted
    if not Game.RoundStarted then
        if not SM.RoundNotStartedWarned then
            SM.RoundNotStartedWarned = true
            debugPrint("[StatusMonitor] Waiting for round to start...")
        end
        return
    end
    
    -- One-time notification when round starts
    if not SM.RoundStartNotified then
        SM.RoundStartNotified = true
        SM.RoundNotStartedWarned = false
        local clientCount = 0
        for _ in pairs(SM.Monitors) do clientCount = clientCount + 1 end
        local charCount = 0
        for _ in pairs(SM.CharacterMonitors) do charCount = charCount + 1 end
        debugPrint(string.format("[StatusMonitor] Round started - %d client monitors, %d character monitors active", clientCount, charCount))
    end
    
    local currentTime = Timer.GetTime()
    
    -- Check 2: Interval timing (runs silently ~60 times per second, only executes once per second)
    if currentTime < SM.LastCheck + SM.CheckInterval then
        return
    end
    
    SM.LastCheck = currentTime
    
    -- Check 3: Monitor count
    local clientMonitorCount = 0
    for monitorID, monitor in pairs(SM.Monitors) do
        clientMonitorCount = clientMonitorCount + 1
    end
    
    local charMonitorCount = 0
    for monitorID, monitor in pairs(SM.CharacterMonitors) do
        charMonitorCount = charMonitorCount + 1
    end
    
    if clientMonitorCount == 0 and charMonitorCount == 0 then
        return
    end
    
    -- Check all registered CLIENT monitors
    for monitorID, monitor in pairs(SM.Monitors) do
        local clientCount = 0
        for client in Client.ClientList do
            clientCount = clientCount + 1
        end
        debugPrint(string.format("[StatusMonitor] Checking client monitor '%s' - %d clients online", monitorID, clientCount))
        
        for client in Client.ClientList do
            SM.CheckClient(monitorID, monitor, client)
        end
    end
    
    -- Check all registered CHARACTER monitors
    for monitorID, monitor in pairs(SM.CharacterMonitors) do
        local config = monitor.config
        
        -- Get characters to check
        local characters
        if config.getCharacters then
            -- Use custom function to get characters
            characters = config.getCharacters()
        else
            -- Default: check all human characters
            characters = {}
            for _, character in pairs(Character.CharacterList) do
                if character.IsHuman and not character.IsDead and not character.Removed then
                    table.insert(characters, character)
                end
            end
        end
        
        debugPrint(string.format("[StatusMonitor] Checking character monitor '%s' - %d characters", monitorID, #characters))
        
        for _, character in ipairs(characters) do
            SM.CheckCharacter(monitorID, monitor, character)
        end
    end
end)

-- Clear all monitors tracking data (NOT the monitors themselves!)
SM.Clear = function()
    local clientMonitorCount = 0
    for id, monitor in pairs(SM.Monitors) do
        monitor.tracked = {}
        clientMonitorCount = clientMonitorCount + 1
    end
    
    local charMonitorCount = 0
    for id, monitor in pairs(SM.CharacterMonitors) do
        monitor.tracked = {}
        charMonitorCount = charMonitorCount + 1
    end
    
    SM.RoundStartNotified = false
    SM.RoundNotStartedWarned = false
    print(string.format("[StatusMonitor] Tracking data cleared (%d client monitors, %d character monitors still registered)", clientMonitorCount, charMonitorCount))
end

-- Get tracking info for a client in a specific monitor
SM.GetTracking = function(monitorID, client)
    if not SM.Monitors[monitorID] or not client then return nil end
    return SM.Monitors[monitorID].tracked[client.SteamID]
end

-- Check if client is being tracked
SM.IsTracking = function(monitorID, client)
    return SM.GetTracking(monitorID, client) ~= nil
end

-- Get tracking info for a character in a specific character monitor
SM.GetCharacterTracking = function(monitorID, character)
    if not SM.CharacterMonitors[monitorID] or not character then return nil end
    return SM.CharacterMonitors[monitorID].tracked[character.ID]
end

-- Check if character is being tracked
SM.IsCharacterTracking = function(monitorID, character)
    return SM.GetCharacterTracking(monitorID, character) ~= nil
end

-- Toggle debug mode
SM.SetDebugMode = function(enabled)
    SM.DebugMode = enabled
    print(string.format("[StatusMonitor] Debug mode %s", enabled and "ENABLED" or "DISABLED"))
end

SM.ToggleDebugMode = function()
    SM.SetDebugMode(not SM.DebugMode)
    return SM.DebugMode
end

-- Register cleanup
Neurologics.RegisterCleanup("StatusMonitor", function()
    SM.Clear()
end)

-- Check if StatusMonitor already exists (module reload detection)
if Neurologics.StatusMonitor then
    print("[StatusMonitor] WARNING: Module is being reloaded! Preserving existing monitors...")
    -- Preserve existing monitors if module is being reloaded
    if Neurologics.StatusMonitor.Monitors then
        SM.Monitors = Neurologics.StatusMonitor.Monitors
        local count = 0
        for _ in pairs(SM.Monitors) do count = count + 1 end
        print(string.format("[StatusMonitor] Preserved %d existing client monitors", count))
    end
    if Neurologics.StatusMonitor.CharacterMonitors then
        SM.CharacterMonitors = Neurologics.StatusMonitor.CharacterMonitors
        local count = 0
        for _ in pairs(SM.CharacterMonitors) do count = count + 1 end
        print(string.format("[StatusMonitor] Preserved %d existing character monitors", count))
    end
    -- Preserve debug mode state
    if Neurologics.StatusMonitor.DebugMode ~= nil then
        SM.DebugMode = Neurologics.StatusMonitor.DebugMode
    end
end

Neurologics.StatusMonitor = SM

local clientMonitorCount = 0
for _ in pairs(SM.Monitors) do clientMonitorCount = clientMonitorCount + 1 end
local charMonitorCount = 0
for _ in pairs(SM.CharacterMonitors) do charMonitorCount = charMonitorCount + 1 end
print(string.format("[StatusMonitor] System loaded and initialized (%d client monitors, %d character monitors registered)", clientMonitorCount, charMonitorCount))

return SM

