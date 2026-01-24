local eventpath = Neurologics.Path .. "/Lua/config/randomevents"

local function EndsWith(str, suffix)
    return str:sub(-string.len(suffix)) == suffix
end

local function GetFileName(file)
    return file:match("^.+/(.+)$")
end

local function ExecuteProtected(s)
    local result = dofile(s)
    return result
end

local function LoadEventFile(filePath)
    local time = os.clock()
    local ok, result = pcall(ExecuteProtected, filePath)
    local diff = os.clock() - time
    
    local fileName = GetFileName(filePath)
    
    if not ok then
        print(string.format(" - %s ERROR: %s", fileName, tostring(result)))
        return false
    end
    
    -- If event returns false, it's disabled
    if result == false then
        print(string.format(" - %s (Disabled)", fileName))
        return false
    end
    
    -- Valid event loaded
    if result and result.Name then
        table.insert(Neurologics.Config.RandomEventConfig.Events, result)
        print(string.format(" - %s (Took %.5fms)", fileName, diff))
        return true
    else
        print(string.format(" - %s WARNING: No valid event returned", fileName))
        return false
    end
end

local function LoadEventsRecursive(folder)
    local search = File.DirSearch(folder)
    
    -- Load all .lua files
    for i = 1, #search do
        local s = tostring(search[i]):gsub("\\", "/")
        
        if EndsWith(s, ".lua") then
            LoadEventFile(s)
        end
    end
end

print("Loading random events from " .. eventpath)
LoadEventsRecursive(eventpath)

print(string.format("Loaded %d events, now initializing...", #Neurologics.Config.RandomEventConfig.Events))

-- Initialize events that have an Init function
for _, event in pairs(Neurologics.Config.RandomEventConfig.Events) do
    if event.Init then
        print(string.format(" - Initializing event: %s", event.Name))
        event.Init()
        print(string.format(" - %s initialized", event.Name))
    end
end

print("Event initialization complete")

