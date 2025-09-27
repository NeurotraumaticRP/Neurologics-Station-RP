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
    
    Hook.Patch("Barotrauma.Networking.GameServer", "AssignJobs", function (instance, ptable)
        
        if Neurologics.ForceRoleChoice then
            
            for index, client in pairs(ptable["unassigned"]) do
                if client.PreferredJob then
                    
                    local jobPrefab = JobPrefab.Get(client.PreferredJob)
                    if jobPrefab then

                        local jobVariant = JobVariant.__new(jobPrefab, 0)
                        client.AssignedJob = jobVariant
                        
                        if client.CharacterInfo then
                            client.CharacterInfo.Job = Job(jobPrefab, false, 0, jobVariant)
                        end
                        
                    else
                    end
                end
            end
            
            return true 
        end
        
        

        Neurologics.JobManager.ReloadBannedJobs()
        local updated = false

        updated = Neurologics.JobManager.ProcessJobBans(ptable) or updated

        updated = Neurologics.JobManager.HandleJobOverflow(ptable) or updated
        
        if updated then
        else
        end
        
        return updated
    end, Hook.HookMethodType.After)
    
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
    ["priest"] = { max = 1, min = 0, minPlayers = 5 }, -- Available at 5+ players, max 1
    ["clown"] = { max = 1, min = 0, minPlayers = 5 }, -- Available at 5+ players, max 1
    ["crewmember"] = { max = -1, min = 0 } -- Unlimited
}

function Neurologics.JobManager.EvaluateJobMaxAmount(playercount)
    local maxPercentage = 0.25 -- 25% of player count
    local dynamicAmounts = {}
    
    for job, config in pairs(jobConfig) do
        if job == "crewmember" then
            dynamicAmounts[job] = -1 -- Unlimited
        else
            -- Check if job has a minimum player requirement
            if config.minPlayers and playercount < config.minPlayers then
                dynamicAmounts[job] = 0 -- Not available yet
            else
                -- Calculate percentage-based limit
                local percentageLimit = math.floor(playercount * maxPercentage)
                -- Use the lower of: percentage limit or hard cap
                local finalLimit = math.min(percentageLimit, config.max)
                dynamicAmounts[job] = math.max(config.min, finalLimit)
            end
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
            else
            end
        else
        end
    end

    for job, count in pairs(jobCounts) do
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
        
        if maxAllowed ~= -1 and count > maxAllowed then
            
            local playersInJob = jobAssignments[jobName]

            -- Build a table of eligible players (real players only, not spectators)
            local eligiblePlayers = {}
            for _, client in pairs(playersInJob) do
                if not client.SpectateOnly then
                    table.insert(eligiblePlayers, client)
                else
                end
            end

            -- Randomly select maxAllowed players to KEEP the job
            local keepers = {}
            local overflowers = {}
            local pool = {table.unpack(eligiblePlayers)}
            for i, client in ipairs(pool) do
            end
            for i = 1, math.min(maxAllowed, #pool) do
                local idx = math.random(#pool)
                table.insert(keepers, pool[idx])
                table.remove(pool, idx)
            end
            -- The rest are overflowers
            for _, client in pairs(pool) do
                table.insert(overflowers, client)
            end

            -- Assign the job to keepers
            for _, client in pairs(keepers) do
                client.AssignedJob = Neurologics.JobManager.GetJobVariant(jobName)
                if client.CharacterInfo then
                    local jobPrefab = JobPrefab.Get(jobName)
                    if jobPrefab then
                        client.CharacterInfo.Job = Job(jobPrefab, false, 0, 0)
                    end
                end
            end

            -- Reassign overflowers
            for _, client in pairs(overflowers) do
                local newJob = Neurologics.JobManager.ReassignPlayer(client, jobName, maxAmounts, jobCounts)
                client.AssignedJob = Neurologics.JobManager.GetJobVariant(newJob)
                if client.CharacterInfo then
                    local jobPrefab = JobPrefab.Get(newJob)
                    if jobPrefab then
                        client.CharacterInfo.Job = Job(jobPrefab, false, 0, 0)
                    end
                end
                -- Update jobCounts for the new job
                jobCounts[jobName] = jobCounts[jobName] - 1
                jobCounts[newJob] = (jobCounts[newJob] or 0) + 1
                updated = true
            end
        else
        end
    end

    return updated
end

function Neurologics.JobManager.GetJobVariant(jobId)
    local prefab = JobPrefab.Get(jobId)
    return JobVariant.__new(prefab, 0)
end

Neurologics.MidRoundSpawn = dofile(Neurologics.Path .. "/Lua/midroundspawn.lua") -- we load here to avoid circular dependency and ensure it's loaded after jobmanager
