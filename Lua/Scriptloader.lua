local scriptpath = Neurologics.Path .. "/Lua/Scripts"
local luapath = Neurologics.Path .. "/Lua"

local loadorder = {
    "CharacterPrefabs", -- should load CharacterPrefabs first then load everything else as normal
    "CharacterSpawner" -- loads right after prefabs
}

local function EndsWith(str, suffix)
    return str:sub(-string.len(suffix)) == suffix
end

local function GetFileName(file)
    return file:match("^.+/(.+)$")
end

local function ExecuteProtected(s, folder)
    loadfile(s)(folder)
end

local function RunFolder(folder, rootFolder, package)
    local search = File.DirSearch(folder)
    local loadedFiles = {}
    
    -- First, load files in the specified order
    for i = 1, #loadorder do
        local fileName = loadorder[i] .. ".lua"
        local fullPath = folder .. "/" .. fileName
        
        if File.Exists(fullPath) then
            local time = os.clock()
            local ok, result = pcall(ExecuteProtected, fullPath, rootFolder)
            local diff = os.clock() - time
            
            print(string.format(" - %s (Took %.5fms)", fileName, diff))
            if not ok then
                print(result)
            end
            
            -- Mark this file as loaded
            loadedFiles[fileName] = true
        else
            print(string.format("Warning: File %s not found in loadorder", fileName))
        end
    end
    
    -- Then load all other .lua files, skipping those already loaded
    for i = 1, #search, 1 do
        local s = tostring(search[i]):gsub("\\", "/")

        if EndsWith(s, ".lua") then
            local fileName = GetFileName(s)
            
            -- Skip if this file was already loaded in loadorder
            if not loadedFiles[fileName] then
                local time = os.clock()
                local ok, result = pcall(ExecuteProtected, s, rootFolder)
                local diff = os.clock() - time

                print(string.format(" - %s (Took %.5fms)", fileName, diff))
                if not ok then
                    print(result)
                end
            end
        end
    end
end

RunFolder(scriptpath, luapath)