-- This script overrides the default job manager in barotrauma.
-- it is responsible for managing who gets what job if several people have picked the same job.
-- it automatically allocates maximum jobs allowed per job depending on player count.
-- it handles job bans from the job ban command.
-- it will be modular in case of future needs.

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
                client.AssignedJob = Neurologics.MidRoundSpawn.GetJobVariant(newJobName)
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

function Neurologics.JobManager.EvaluateJobMaxAmount(playercount)
    local overflow = 3 -- Allow for 3 extra players worth of jobs
    local adjustedPlayerCount = playercount + overflow

    local jobmaxamounts = { -- given max player count is 25.
        ["doctor"] = 3,
        ["guard"] = 3,
        ["warden"] = 1,
        ["staff"] = 2,
        ["janitor"] = 2,
        ["convict"] = 4,
        ["he-chef"] = 2,
        ["cmo"] = 1,
        ["crewmember"] = 2,
        ["scientist"] = 2,
        ["priest"] = 1,
        ["captain"] = 1,
        ["clown"] = 1
    }

    local minamounts = { -- 5 people required to play default gamemode, anyless becomes sandbox mode and no points will be given.
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

    -- Calculate dynamic job amounts based on player count
    local dynamicAmounts = {}
    
    -- If 5 or fewer players, set all jobs to max of 1
    if playercount <= 5 then
        for job, _ in pairs(jobmaxamounts) do
            -- Some jobs already have max of 1 (captain, warden, priest, etc)
            -- but we'll explicitly set everything to 1 for clarity
            dynamicAmounts[job] = 1
        end
        return dynamicAmounts
    end
    
    -- For more than 5 players, calculate dynamic amounts
    for job, maxAmount in pairs(jobmaxamounts) do
        local minAmount = minamounts[job] or 0
        
        -- Calculate scaled amount based on adjusted player count
        local scaledAmount = math.floor((adjustedPlayerCount / 25) * maxAmount)
        
        -- Ensure we don't go below minimum or above maximum
        scaledAmount = math.max(minAmount, scaledAmount)
        scaledAmount = math.min(maxAmount, scaledAmount)
        
        dynamicAmounts[job] = scaledAmount
    end

    -- Ensure critical roles are maintained
    if dynamicAmounts["captain"] < 1 then dynamicAmounts["captain"] = 1 end -- captain/warden/cmo are the heads so they need to be at least 1
    if dynamicAmounts["warden"] < 1 then dynamicAmounts["warden"] = 1 end
    if dynamicAmounts["cmo"] < 1 then dynamicAmounts["cmo"] = 1 end

    return dynamicAmounts

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

    -- Count current job assignments and store assignments by job
    for _, client in pairs(ptable["unassigned"]) do
        local jobName = client.AssignedJob.Prefab.Identifier.ToString():lower()
        jobCounts[jobName] = (jobCounts[jobName] or 0) + 1
        
        if not jobAssignments[jobName] then
            jobAssignments[jobName] = {}
        end
        table.insert(jobAssignments[jobName], client)
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
        if count > maxAllowed then
            -- Number of players that need to be reassigned
            local overflow = count - maxAllowed
            local playersInJob = jobAssignments[jobName]
            
            -- Shuffle players in this job to randomize who gets reassigned
            for i = #playersInJob, 2, -1 do
                local j = math.random(i)
                playersInJob[i], playersInJob[j] = playersInJob[j], playersInJob[i]
            end

            -- Reassign overflow players
            for i = 1, overflow do
                local client = playersInJob[i]
                local availableJobs = getAvailableJobs(client)
                
                if #availableJobs > 0 then
                    -- Pick random available job
                    local newJob = availableJobs[math.random(#availableJobs)]
                    
                    -- Update counts
                    jobCounts[jobName] = jobCounts[jobName] - 1
                    jobCounts[newJob] = (jobCounts[newJob] or 0) + 1
                    
                    -- Assign new job
                    client.AssignedJob = Neurologics.MidRoundSpawn.GetJobVariant(newJob)
                    Neurologics.SendMessage(client, "Due to role limits, you have been reassigned to: " .. newJob)
                    updated = true
                else
                    Neurologics.Log("Warning: Could not find alternative job for " .. client.Name)
                end
            end
        end
    end

    return updated
end

-- Update the AssignJobs hook to include overflow handling
Hook.Patch("Barotrauma.Networking.GameServer", "AssignJobs", function (instance, ptable)
    -- Reload banned jobs data to ensure we have the latest information
    Neurologics.JobManager.ReloadBannedJobs()
    local updated = false
    
    -- Process job bans first
    updated = Neurologics.JobManager.ProcessJobBans(ptable) or updated
    
    -- Then handle overflow
    updated = Neurologics.JobManager.HandleJobOverflow(ptable) or updated
    
    return updated
end, Hook.HookMethodType.After)

