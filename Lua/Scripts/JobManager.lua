-- This script overrides the default job manager in barotrauma.
-- it is responsible for managing who gets what job if several people have picked the same job.
-- it automatically allocates maximum jobs allowed per job depending on player count.
-- it handles job bans from the job ban command.
-- it will be modular in case of future needs.
-- in case of specific scenarios regarding the choice of a job, that code will be put in jobmanager.lua for clarity.

Neurologics.JobManager = {}
Neurologics.JobManager.ValidJobs = { "doctor","clown", "guard", "warden", "staff", "janitor", "convict", "he-chef", "cmo","crewmember","scientist","priest","captain" }

-- Load banned jobs at the beginning
local bannedJobs = Neurologics.JSON.loadBannedJobs()

-- Function to handle job banning logic
function Neurologics.JobManager.ProcessJobBans(ptable)
    local validJobs = Neurologics.JobManager.ValidJobs
    local updated = false

    for index, client in pairs(ptable["unassigned"]) do
        local jobName = client.AssignedJob.Prefab.Identifier.ToString()
        local steamID = client.SteamID
        local flag = false

        -- Check if the client is banned from the assigned job
        if bannedJobs[steamID] then
            for _, bannedJob in ipairs(bannedJobs[steamID]) do
                if jobName == bannedJob then
                    flag = true
                    break
                end
            end
        end

        -- If the client is banned from the job, find a substitute role
        if flag then
            local substituteRoles = {}

            -- Create a list of jobs that the client is not banned from
            for _, validJob in ipairs(validJobs) do
                local isBanned = false

                for _, bannedJob in ipairs(bannedJobs[steamID]) do
                    if validJob == bannedJob then
                        isBanned = true
                        break
                    end
                end

                if not isBanned then
                    table.insert(substituteRoles, validJob)
                end
            end

            -- Choose a random job from the substitute roles
            if #substituteRoles > 0 then
                local newJobName = substituteRoles[math.random(1, #substituteRoles)]
                
                client.AssignedJob = Neurologics.JobManager.GetJobVariant(newJobName)
                
                -- Update CharacterInfo.Job to ensure proper spawning with clothes
                if client.CharacterInfo then
                    client.CharacterInfo.Job = Job(JobPrefab.Get(newJobName), 0, 0)
                end
                
                Neurologics.SendMessage(client, "You have been banned from playing the role: " .. jobName .. ", Appeal in discord https://discord.gg/nv8Zz32PxK")
                updated = true
            else
                -- No substitute roles available, log this situation
                Neurologics.Log("Warning: " .. client.Name .. " is banned from all jobs. No substitute role available.")
            end
        end
    end
    
    return updated
end

-- Function to ban a player from specific jobs
function Neurologics.JobManager.BanJobs(steamID, jobList, reason, sender, targetClient)
    if not bannedJobs[steamID] then
        bannedJobs[steamID] = {}
    end

    local function isJobBanned(bannedJobsList, job)
        for _, bannedJob in ipairs(bannedJobsList) do
            if bannedJob == job then
                return true
            end
        end
        return false
    end

    local addedJobs = {}
    for _, job in ipairs(jobList) do
        if not isJobBanned(bannedJobs[steamID], job) then
            table.insert(bannedJobs[steamID], job)
            table.insert(addedJobs, job)
        end
    end

    -- Save the updated banned jobs to file
    Neurologics.JSON.saveBannedJobs(bannedJobs)

    if #addedJobs > 0 and sender then
        local jobsStr = table.concat(addedJobs, ", ")
        if sender then
            Neurologics.SendMessage(sender, "Successfully banned " .. (targetClient and targetClient.Name or steamID) .. " from the roles: " .. jobsStr)
        end
        
        --Neurologics.RecieveRoleBan(targetClient, table.concat(addedJobs, ","), reason) disabled for now
        
        if targetClient then
            Neurologics.SendMessage(targetClient, "You have been banned from playing the roles: " .. jobsStr .. "\nReason: " .. reason)
        end

        -- Send webhook notification if applicable
        local discordWebHook = Neurologics.GetAPIKey("discordWebhook")
        if discordWebHook and sender then
            local hookmsg = string.format("``Admin %s`` banned ``User %s`` from the roles: %s.\nReason: %s", 
                sender.Name, (targetClient and targetClient.Name or steamID), jobsStr, reason)
            local function escapeQuotes(str)
                return str:gsub("\"", "\\\"")
            end
            local escapedMessage = escapeQuotes(hookmsg)
            Networking.RequestPostHTTP(discordWebHook, function(result) end, 
                '{"content": "' .. escapedMessage .. '", "username": "ADMIN HELP (CONVICT STATION)"}')
        end
    end
    
    return addedJobs
end

-- Function to unban a player from specific jobs
function Neurologics.JobManager.UnbanJobs(steamID, jobList, sender, targetClient)
    if not bannedJobs[steamID] then
        bannedJobs[steamID] = {}
    end

    local function unbanJob(bannedJobsList, job)
        for index, bannedJob in ipairs(bannedJobsList) do
            if bannedJob == job then
                table.remove(bannedJobsList, index)
                return true
            end
        end
        return false
    end

    local unbannedJobs = {}
    for _, job in ipairs(jobList) do
        if unbanJob(bannedJobs[steamID], job) then
            table.insert(unbannedJobs, job)
        end
    end

    -- Save the updated banned jobs to file
    Neurologics.JSON.saveBannedJobs(bannedJobs)

    if #unbannedJobs > 0 and sender then
        local jobsStr = table.concat(unbannedJobs, ", ")
        if sender then
            Neurologics.SendMessage(sender, "Successfully unbanned " .. (targetClient and targetClient.Name or steamID) .. " from the roles: " .. jobsStr)
        end
        
        --Neurologics.RecieveRoleUnban(targetClient, jobsStr) disabled for now
        
        if targetClient then
            Neurologics.SendMessage(targetClient, "You have been unbanned from playing the roles: " .. jobsStr)
        end

        -- Send webhook notification if applicable
        local discordWebHook = Neurologics.GetAPIKey("discordWebhook")
        if discordWebHook and sender then
            local hookmsg = string.format("``Admin %s`` unbanned ``User %s`` from the roles: %s", 
                sender.Name, (targetClient and targetClient.Name or steamID), jobsStr)
            local function escapeQuotes(str)
                return str:gsub("\"", "\\\"")
            end
            local escapedMessage = escapeQuotes(hookmsg)
            Networking.RequestPostHTTP(discordWebHook, function(result) end, 
                '{"content": "' .. escapedMessage .. '", "username": "ADMIN HELP (CONVICT STATION)"}')
        end
    end
    
    return unbannedJobs
end

-- Function to reload banned jobs data from file
function Neurologics.JobManager.ReloadBannedJobs()
    bannedJobs = Neurologics.JSON.loadBannedJobs()
    return bannedJobs
end

-- Initialize JobManager hooks and systems
function Neurologics.JobManager.PreStart()
    print("[JobManager] Initializing JobManager hooks...")
    
    -- Update the AssignJobs hook to include overflow handling
    Hook.Patch("Barotrauma.Networking.GameServer", "AssignJobs", function (instance, ptable)
        print("[JobManager] AssignJobs hook called")
        
        -- Check if force role choice is enabled - if so, force preferred jobs
        if Neurologics.ForceRoleChoice then
            print("[JobManager] Force role choice is enabled, forcing preferred jobs")
            
            for index, client in pairs(ptable["unassigned"]) do
                if client.PreferredJob then
                    print("[JobManager] Forcing " .. client.Name .. " to their preferred job: " .. client.PreferredJob.ToString())
                    
                    -- Get the job prefab from the identifier
                    local jobPrefab = JobPrefab.Get(client.PreferredJob)
                    if jobPrefab then
                        -- Create a JobVariant from the prefab
                        local jobVariant = JobVariant.__new(jobPrefab, 0)
                        client.AssignedJob = jobVariant
                        
                        -- Update CharacterInfo.Job to ensure proper spawning with clothes
                        if client.CharacterInfo then
                            client.CharacterInfo.Job = Job(jobPrefab, false, 0, jobVariant)
                        end
                        
                        print("[JobManager] Successfully assigned " .. client.Name .. " to " .. jobPrefab.Identifier.ToString())
                    else
                        print("[JobManager] Warning: Could not find job prefab for " .. client.PreferredJob.ToString())
                    end
                end
            end
            
            return true -- Indicate that we modified job assignments
        end
        
        print("[JobManager] Processing job assignments...")
        
        -- Reload banned jobs data to ensure we have the latest information
        Neurologics.JobManager.ReloadBannedJobs()
        local updated = false
        
        -- Process job bans first
        updated = Neurologics.JobManager.ProcessJobBans(ptable) or updated
        
        -- Then handle overflow
        updated = Neurologics.JobManager.HandleJobOverflow(ptable) or updated
        
        if updated then
            print("[JobManager] Job assignments were modified")
        else
            print("[JobManager] No job assignments were modified")
        end
        
        return updated
    end, Hook.HookMethodType.After)
    
    print("[JobManager] JobManager hooks initialized successfully")
end

function Neurologics.JobManager.splitJobList(jobString)
    local jobs = {}
    -- Split the string by commas and trim whitespace
    for job in jobString:gmatch("([^,]+)") do
        job = job:match("^%s*(.-)%s*$") -- trim whitespace
        -- Check if it's a valid job
        local isValid = false
        for _, validJob in ipairs(Neurologics.JobManager.ValidJobs) do
            if job:lower() == validJob then
                isValid = true
                table.insert(jobs, job:lower())
                break
            end
        end
        if not isValid then
            -- You might want to handle invalid jobs differently
            Neurologics.Log("Warning: Invalid job name ignored: " .. job)
        end
    end
    return jobs
end

local jobConfig = {
    ["captain"] = { max = 1, min = 1 },
    ["cmo"] = { max = 1, min = 1 },
    ["warden"] = { max = 1, min = 1 },
    ["doctor"] = { max = 3, min = 0 },
    ["guard"] = { max = 3, min = 0 },
    ["staff"] = { max = 2, min = 1 },
    ["he-chef"] = { max = 2, min = 1 },
    ["scientist"] = { max = 2, min = 0 },
    ["janitor"] = { max = 2, min = 0 },
    ["convict"] = { max = 4, min = 0 },
    ["priest"] = { max = 1, min = 0 },
    ["clown"] = { max = 1, min = 0 },
    ["crewmember"] = { max = -1, min = 0 } -- Unlimited
}

function Neurologics.JobManager.EvaluateJobMaxAmount(playercount)
    local maxPercentage = 0.25 -- 25% of player count
    local dynamicAmounts = {}
    
    for job, config in pairs(jobConfig) do
        if job == "crewmember" then
            dynamicAmounts[job] = -1 -- Unlimited
        else
            -- Calculate percentage-based limit
            local percentageLimit = math.floor(playercount * maxPercentage)
            -- Use the lower of: percentage limit or hard cap
            local finalLimit = math.min(percentageLimit, config.max)
            dynamicAmounts[job] = math.max(config.min, finalLimit)
        end
    end
    
    return dynamicAmounts
end

-- Smart reassignment using job preferences
function Neurologics.JobManager.ReassignPlayer(client, originalJob, maxAmounts, jobCounts)
    local steamID = client.SteamID
    local preferences = client.JobPreferences or {}
    
    -- Try each preference in order
    for _, preferredJob in ipairs(preferences) do
        local jobName = preferredJob.Prefab.Identifier.ToString():lower()
        
        -- Skip if it's the same job
        if jobName == originalJob then 
            -- Continue to next preference
        else
            -- Check if job is banned
            local isBanned = false
            if bannedJobs[steamID] then
                for _, bannedJob in ipairs(bannedJobs[steamID]) do
                    if jobName == bannedJob then
                        isBanned = true
                        break
                    end
                end
            end
            
            -- If not banned, check if job has space
            if not isBanned then
                local currentCount = jobCounts[jobName] or 0
                local maxAllowed = maxAmounts[jobName] or 0
                
                if maxAllowed == -1 or currentCount < maxAllowed then
                    return jobName -- Found available job
                end
            end
        end
    end
    
    -- If preferences didn't work, try random jobs
    local availableJobs = {}
    for job, count in pairs(jobCounts) do
        -- Skip if it's the same job or banned
        if job ~= originalJob then
            local isBanned = false
            if bannedJobs[steamID] then
                for _, bannedJob in ipairs(bannedJobs[steamID]) do
                    if job == bannedJob then
                        isBanned = true
                        break
                    end
                end
            end
            
            if not isBanned then
                local maxAllowed = maxAmounts[job] or 0
                if maxAllowed == -1 or count < maxAllowed then
                    table.insert(availableJobs, job)
                end
            end
        end
    end
    
    -- If random jobs are available, pick one
    if #availableJobs > 0 then
        local randomJob = availableJobs[math.random(#availableJobs)]
        return randomJob
    end
    
    -- Fallback to crewmember (unlimited)
    return "crewmember"
end

local forcemaxamounts_debug = {
    ["doctor"] = 0,
    ["guard"] = 0,
    ["warden"] = 1,
    ["staff"] = 1,
    ["janitor"] = 0,
    ["convict"] = 0,
    ["he-chef"] = 1,
    ["cmo"] = 1,
    ["crewmember"] = 0,
    ["scientist"] = 0,
    ["priest"] = 0,
    ["captain"] = 1,
    ["clown"] = 0
}
    

-- Function to handle job overflow and reassignment
function Neurologics.JobManager.HandleJobOverflow(ptable)
    local clientList = Client.ClientList
    local playerCount = #clientList
    local maxAmounts = Neurologics.JobManager.EvaluateJobMaxAmount(playerCount)
    local jobCounts = {}
    local jobAssignments = {}
    local updated = false

    -- Count job preferences and store assignments by preferred job
    for _, client in pairs(ptable["unassigned"]) do
        if not client.SpectateOnly then
            local preferredJob = nil
            if client.JobPreferences and #client.JobPreferences > 0 then
                preferredJob = client.JobPreferences[1].Prefab.Identifier.ToString():lower()
            elseif client.AssignedJob then
                preferredJob = client.AssignedJob.Prefab.Identifier.ToString():lower()
            end
            if preferredJob then
                jobCounts[preferredJob] = (jobCounts[preferredJob] or 0) + 1
                if not jobAssignments[preferredJob] then
                    jobAssignments[preferredJob] = {}
                end
                table.insert(jobAssignments[preferredJob], client)
                print("[JobManager] Counted " .. client.Name .. " for preferred job: " .. preferredJob)
            else
                print("[JobManager] No valid job preference for " .. client.Name)
            end
        else
            print("[JobManager] Skipped spectator: " .. client.Name)
        end
    end

    print("[JobManager] Final job counts:")
    for job, count in pairs(jobCounts) do
        print("[JobManager]   " .. job .. ": " .. count)
    end

    -- Function to get available jobs for a client
    local function getAvailableJobs(client)
        local available = {}
        local steamID = client.SteamID
        
        for job, count in pairs(jobCounts) do
            -- Check if job is not at max capacity
            if count < (maxAmounts[job] or 0) then
                -- Check if client is not banned from this job
                local isBanned = false
                if bannedJobs[steamID] then
                    for _, bannedJob in ipairs(bannedJobs[steamID]) do
                        if job == bannedJob then
                            isBanned = true
                            break
                        end
                    end
                end
                
                if not isBanned then
                    table.insert(available, job)
                end
            end
        end
        return available
    end

    -- Handle overflow for each job
    for jobName, count in pairs(jobCounts) do
        local maxAllowed = maxAmounts[jobName] or 0
        print("[JobManager] Checking job: " .. jobName .. " - Count: " .. count .. ", Max Allowed: " .. maxAllowed)
        
        if maxAllowed ~= -1 and count > maxAllowed then
            print("[JobManager] ===== OVERFLOW DETECTED =====")
            print("[JobManager] Job overflow detected for " .. jobName .. ": " .. count .. " players, max allowed: " .. maxAllowed)
            
            local playersInJob = jobAssignments[jobName]
            print("[JobManager] Total players in " .. jobName .. ": " .. #playersInJob)

            -- Build a table of eligible players (real players only, not spectators)
            local eligiblePlayers = {}
            for _, client in pairs(playersInJob) do
                if not client.SpectateOnly then
                    table.insert(eligiblePlayers, client)
                    print("[JobManager] Added eligible player: " .. client.Name .. " for overflow selection")
                else
                    print("[JobManager] Skipped ineligible player: " .. client.Name .. " (spectator)")
                end
            end
            print("[JobManager] Eligible players for overflow: " .. #eligiblePlayers)

            -- Randomly select maxAllowed players to KEEP the job
            local keepers = {}
            local overflowers = {}
            local pool = {table.unpack(eligiblePlayers)}
            print("[JobManager] Pool before selection:")
            for i, client in ipairs(pool) do
                print("[JobManager]   " .. i .. ": " .. client.Name)
            end
            for i = 1, math.min(maxAllowed, #pool) do
                local idx = math.random(#pool)
                print("[JobManager] Randomly chose index " .. idx .. " (" .. pool[idx].Name .. ") to KEEP " .. jobName)
                table.insert(keepers, pool[idx])
                print("[JobManager] Selected " .. pool[idx].Name .. " to KEEP " .. jobName)
                table.remove(pool, idx)
            end
            -- The rest are overflowers
            for _, client in pairs(pool) do
                table.insert(overflowers, client)
                print("[JobManager] Selected " .. client.Name .. " for REASSIGNMENT from " .. jobName)
            end

            -- Assign the job to keepers
            for _, client in pairs(keepers) do
                client.AssignedJob = Neurologics.JobManager.GetJobVariant(jobName)
                if client.CharacterInfo then
                    local jobPrefab = JobPrefab.Get(jobName)
                    if jobPrefab then
                        client.CharacterInfo.Job = Job(jobPrefab, false, 0, 0)
                        print("[JobManager] Assigned " .. client.Name .. " to " .. jobName)
                    end
                end
            end

            -- Reassign overflowers
            for _, client in pairs(overflowers) do
                local newJob = Neurologics.JobManager.ReassignPlayer(client, jobName, maxAmounts, jobCounts)
                print("[JobManager] Reassigned " .. client.Name .. " from " .. jobName .. " to " .. newJob)
                client.AssignedJob = Neurologics.JobManager.GetJobVariant(newJob)
                if client.CharacterInfo then
                    local jobPrefab = JobPrefab.Get(newJob)
                    if jobPrefab then
                        client.CharacterInfo.Job = Job(jobPrefab, false, 0, 0)
                        print("[JobManager] Updated CharacterInfo.Job for " .. client.Name)
                    end
                end
                -- Update jobCounts for the new job
                jobCounts[jobName] = jobCounts[jobName] - 1
                jobCounts[newJob] = (jobCounts[newJob] or 0) + 1
                print("[JobManager] Updated job counts - " .. jobName .. ": " .. jobCounts[jobName] .. ", " .. newJob .. ": " .. jobCounts[newJob])
                updated = true
            end
            print("[JobManager] ===== OVERFLOW RESOLVED for " .. jobName .. " =====")
        else
            print("[JobManager] No overflow for " .. jobName .. " - count: " .. count .. ", max: " .. maxAllowed)
        end
    end

    return updated
end

function Neurologics.JobManager.GetJobVariant(jobId)
    local prefab = JobPrefab.Get(jobId)
    return JobVariant.__new(prefab, 0)
end

Neurologics.MidRoundSpawn = dofile(Neurologics.Path .. "/Lua/midroundspawn.lua") -- we load here to avoid circular dependency and ensure it's loaded after jobmanager
