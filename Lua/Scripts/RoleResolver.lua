--[[
    Role Resolver Pipeline System
    
    A modular system for determining antagonist roles based on multiple conditions.
    Resolvers are evaluated in priority order (highest first).
    
    Two types of resolvers:
    - Batch Resolvers: Can set roles for ALL antagonists at once (e.g., Nukie Round)
    - Individual Resolvers: Evaluate per-character (e.g., job overrides)
    
    Usage:
    -- Add a batch resolver
    Neurologics.RoleResolver.AddBatchResolver({
        name = "MyBatchResolver",
        priority = 100,
        resolve = function(antagonists, baseRole, context)
            -- Return {[character] = "RoleName"} or nil to pass
        end,
    })
    
    -- Add an individual resolver
    Neurologics.RoleResolver.AddIndividualResolver({
        name = "MyResolver",
        priority = 50,
        resolve = function(character, baseRole, context)
            -- Return "RoleName" or nil to pass
        end,
    })
]]

local RoleResolver = {}

-- Resolver storage
RoleResolver.batchResolvers = {}      -- Resolvers that can set ALL antagonist roles
RoleResolver.individualResolvers = {} -- Resolvers that evaluate per-character

-- Round state (set at round start, can be modified by admin)
RoleResolver.roundState = {
    specialRoundType = nil,  -- "Nukie", "AllCultist", etc.
    forcedByAdmin = false,
}

--------------------------------
--    Core Functions          --
--------------------------------

-- Register a batch resolver
-- resolve(antagonists, baseRole, context) -> {[character] = "RoleName"} or nil
function RoleResolver.AddBatchResolver(config)
    if type(config) ~= "table" or not config.name or not config.resolve then
        error("RoleResolver.AddBatchResolver: config must have 'name' and 'resolve' fields")
    end
    
    table.insert(RoleResolver.batchResolvers, {
        name = config.name,
        priority = config.priority or 50,
        enabled = config.enabled ~= false,
        resolve = config.resolve,
    })
    
    -- Sort by priority (highest first)
    table.sort(RoleResolver.batchResolvers, function(a, b) return a.priority > b.priority end)
end

-- Register an individual resolver
-- resolve(character, baseRole, context) -> "RoleName" or nil
function RoleResolver.AddIndividualResolver(config)
    if type(config) ~= "table" or not config.name or not config.resolve then
        error("RoleResolver.AddIndividualResolver: config must have 'name' and 'resolve' fields")
    end
    
    table.insert(RoleResolver.individualResolvers, {
        name = config.name,
        priority = config.priority or 50,
        enabled = config.enabled ~= false,
        resolve = config.resolve,
    })
    
    -- Sort by priority (highest first)
    table.sort(RoleResolver.individualResolvers, function(a, b) return a.priority > b.priority end)
end

-- Enable or disable a resolver by name
function RoleResolver.SetResolverEnabled(name, enabled)
    for _, resolver in ipairs(RoleResolver.batchResolvers) do
        if resolver.name == name then
            resolver.enabled = enabled
            return true
        end
    end
    for _, resolver in ipairs(RoleResolver.individualResolvers) do
        if resolver.name == name then
            resolver.enabled = enabled
            return true
        end
    end
    return false
end

-- Get resolver by name
function RoleResolver.GetResolver(name)
    for _, resolver in ipairs(RoleResolver.batchResolvers) do
        if resolver.name == name then
            return resolver, "batch"
        end
    end
    for _, resolver in ipairs(RoleResolver.individualResolvers) do
        if resolver.name == name then
            return resolver, "individual"
        end
    end
    return nil
end

-- Count table entries (for non-sequential tables)
local function tableCount(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Main resolution function
-- Returns table: {[character] = roleObject}
function RoleResolver.ResolveRoles(antagonists, baseRole)
    local context = {
        baseRole = baseRole,
        roundState = RoleResolver.roundState,
        config = Neurologics.Config.RoleResolverConfig or {},
    }
    
    local results = {}
    local antagonistCount = #antagonists
    
    -- Phase 1: Try batch resolvers
    for _, resolver in ipairs(RoleResolver.batchResolvers) do
        if resolver.enabled then
            local success, batchResult = pcall(resolver.resolve, antagonists, baseRole, context)
            
            if not success then
            elseif batchResult then
                
                -- Batch resolver returned roles for all/some antagonists
                for character, roleName in pairs(batchResult) do
                    local role = Neurologics.RoleManager.Roles[roleName]
                    if role then
                        results[character] = role
                    end
                end
                
                -- If batch resolver handled everyone, we're done
                if tableCount(results) >= antagonistCount then
                    return results
                end
                
                break -- Only use first matching batch resolver
            end
        end
    end
    
    -- Phase 2: Individual resolvers for remaining antagonists
    for _, character in pairs(antagonists) do
        if not results[character] then
            local resolvedByName = nil
            
            for _, resolver in ipairs(RoleResolver.individualResolvers) do
                if resolver.enabled then
                    local success, roleName = pcall(resolver.resolve, character, baseRole, context)
                    
                    if not success then
                    elseif roleName then
                        local role = Neurologics.RoleManager.Roles[roleName]
                        if role then
                            results[character] = role
                            resolvedByName = resolver.name
                            break
                        else
                        end
                    end
                end
            end
            
            -- Fallback to base role if no resolver matched
            if not results[character] then
                results[character] = baseRole
            end
        end
    end
    
    return results
end

--------------------------------
--    Round State Management  --
--------------------------------

-- Admin command to set special round type
function RoleResolver.SetSpecialRound(roundType)
    RoleResolver.roundState.specialRoundType = roundType
    RoleResolver.roundState.forcedByAdmin = roundType ~= nil
end

-- Get current special round type
function RoleResolver.GetSpecialRound()
    return RoleResolver.roundState.specialRoundType
end

-- Called at round start to potentially trigger random special rounds
function RoleResolver.RollSpecialRound()
    -- Don't override admin-forced round
    if RoleResolver.roundState.forcedByAdmin then
        return
    end
    
    local config = Neurologics.Config.RoleResolverConfig or {}
    local specialRounds = config.SpecialRoundChances or {}
    
    for roundType, chance in pairs(specialRounds) do
        if math.random() < chance then
            RoleResolver.roundState.specialRoundType = roundType
            
            -- Send announcement if configured
            local roundConfig = (config.SpecialRounds or {})[roundType]
            if roundConfig and roundConfig.announcement then
                -- Announcement will be sent when antagonists are assigned
            end
            
            return roundType
        end
    end
    
    return nil
end

-- Reset at round end
function RoleResolver.Reset()
    RoleResolver.roundState = {
        specialRoundType = nil,
        forcedByAdmin = false,
    }
end

--------------------------------
--    Built-in Resolvers      --
--------------------------------

-- BATCH RESOLVER: Special Round Types (Priority 100)
-- Handles special rounds like Nukie, AllCultist, etc.
RoleResolver.AddBatchResolver({
    name = "SpecialRoundType",
    priority = 100,
    resolve = function(antagonists, baseRole, context)
        local roundType = context.roundState.specialRoundType
        if not roundType then return nil end
        
        local config = context.config.SpecialRounds or {}
        local roundConfig = config[roundType]
        if not roundConfig then
            return nil
        end
        
        local results = {}
        for _, character in pairs(antagonists) do
            results[character] = roundConfig.role
        end
        
        -- Send announcement if configured
        if roundConfig.announcement then
            Timer.Wait(function()
                Neurologics.SendMessageEveryone(roundConfig.announcement)
            end, 5000)
        end
        
        return results
    end,
})

-- INDIVIDUAL RESOLVER: Username Match (Priority 90)
-- Assigns roles based on player username patterns
RoleResolver.AddIndividualResolver({
    name = "UsernameMatch",
    priority = 90,
    resolve = function(character, baseRole, context)
        local config = context.config.UsernameOverrides or {}
        if not next(config) then return nil end -- Empty config
        
        local client = Neurologics.FindClientCharacter(character)
        if not client then return nil end
        
        local username = client.Name:lower()
        for pattern, roleName in pairs(config) do
            if username:find(pattern:lower()) then
                return roleName
            end
        end
        return nil
    end,
})

-- INDIVIDUAL RESOLVER: Universal Job Override (Priority 60)
-- Jobs like scientist/doctor ALWAYS get their special roles regardless of base role
-- This resolver is only reached if NO batch resolver handled everyone (i.e., not a special round)
RoleResolver.AddIndividualResolver({
    name = "UniversalJobOverride",
    priority = 60,
    resolve = function(character, baseRole, context)
        local universalOverrides = context.config.UniversalJobOverrides or {}
        
        -- Get job identifier
        if not character.Info or not character.Info.Job or not character.Info.Job.Prefab then
            return nil
        end
        local jobId = character.Info.Job.Prefab.Identifier.Value
        
        -- Check universal overrides (scientist -> EvilScientist, doctor -> EvilDoctor)
        local override = universalOverrides[jobId]
        if override then
        end
        return override
    end,
})

-- INDIVIDUAL RESOLVER: Job Override (Priority 50)
-- Assigns specialized roles based on job + base role combination (legacy, for additional overrides)
RoleResolver.AddIndividualResolver({
    name = "JobOverride",
    priority = 50,
    resolve = function(character, baseRole, context)
        local config = context.config.JobOverrides or {}
        local baseRoleOverrides = config[baseRole.Name]
        if not baseRoleOverrides then return nil end
        
        if not character.Info or not character.Info.Job or not character.Info.Job.Prefab then
            return nil
        end
        local jobId = character.Info.Job.Prefab.Identifier.Value
        return baseRoleOverrides[jobId]
    end,
})

-- INDIVIDUAL RESOLVER: Default (Priority 0)
-- Fallback that returns the base role - ensures everyone gets assigned
RoleResolver.AddIndividualResolver({
    name = "Default",
    priority = 0,
    resolve = function(character, baseRole, context)
        return baseRole.Name
    end,
})

return RoleResolver
