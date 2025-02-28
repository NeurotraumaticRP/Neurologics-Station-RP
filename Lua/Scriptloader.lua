local scriptpath = Neurologics.Path .. "/Lua/Scripts"
local luapath = Neurologics.Path .. "/Lua"

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
    for i = 1, #search, 1 do
        local s = search[i]:gsub("\\", "/")

        if EndsWith(s, ".lua") then
            local time = os.clock()
            local ok, result = pcall(ExecuteProtected, s, rootFolder)
            local diff = os.clock() - time

            print(string.format(" - %s (Took %.5fms)", GetFileName(s), diff))
            if not ok then
                printerror(result)
            end
        end

    end
end

RunFolder(scriptpath, luapath)