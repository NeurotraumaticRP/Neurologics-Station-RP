local objectivepath = Neurologics.Path .. "/Lua/objectives"

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

local function LoadObjectiveFile(filePath)
    local time = os.clock()
    local ok, result = pcall(ExecuteProtected, filePath)
    local diff = os.clock() - time
    
    local fileName = GetFileName(filePath)
    
    if not ok then
        print(string.format(" - %s ERROR: %s", fileName, tostring(result)))
        return false
    end
    
    -- If objective returns false, it's disabled
    if result == false then
        print(string.format(" - %s (Disabled)", fileName))
        return false
    end
    
    -- Valid objective loaded
    if result and result.Name then
        Neurologics.RoleManager.AddObjective(result)
        print(string.format(" - %s (Took %.5fms)", fileName, diff))
        return true
    else
        print(string.format(" - %s WARNING: No valid objective returned", fileName))
        return false
    end
end

local function LoadObjectivesRecursive(folder)
    local search = File.DirSearch(folder)
    local loadedFiles = {}
    
    -- First, load objective.lua if it exists (base class)
    local basePath = folder .. "/objective.lua"
    if File.Exists(basePath) then
        LoadObjectiveFile(basePath)
        loadedFiles["objective.lua"] = true
    end
    
    -- Then recursively load all other .lua files
    for i = 1, #search do
        local s = tostring(search[i]):gsub("\\", "/")
        
        if EndsWith(s, ".lua") then
            local fileName = GetFileName(s)
            
            -- Skip if this file was already loaded
            if not loadedFiles[fileName] then
                LoadObjectiveFile(s)
            end
        end
    end
end

print("Loading objectives from " .. objectivepath)
LoadObjectivesRecursive(objectivepath)

