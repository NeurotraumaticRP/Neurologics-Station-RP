local gm = {}

gm.Name = "Gamemode"

function gm:PreStart()
    Neurologics.Pointshop.Initialize(self.PointshopCategories or {})
    
    -- Initialize JobManager hooks and systems
    if Neurologics.JobManager then
        print("[Gamemode] Initializing JobManager...")
        Neurologics.JobManager.PreStart()
    else
        print("[Gamemode] Warning: JobManager not found!")
    end
end

function gm:Start()
    --Neurologics.GiveHungryEuropan()
end

function gm:Think()

end

function gm:End()

end

function gm:TraitorResults()

end

function gm:RoundSummary()
    local sb = Neurologics.StringBuilder:new()

    sb("Gamemode: %s\n", self.Name)

    for character, role in pairs(Neurologics.RoleManager.RoundRoles) do
        local text = role:OtherGreet()
        if text then
            sb("\n%s\n", role:OtherGreet())
        end
    end

    return sb:concat()
end

function gm:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

return gm
