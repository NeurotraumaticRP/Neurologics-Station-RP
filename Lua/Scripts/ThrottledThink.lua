if not Neurologics then error("ThrottledThink requires Neurologics") end

Neurologics.ThrottledThinkCallbacks = Neurologics.ThrottledThinkCallbacks or {}

-- Deterministic offset from name hash: spreads callbacks with same interval across frames
local function nameToOffset(name, interval)
    local hash = 0
    for i = 1, #name do
        hash = hash * 31 + string.byte(name, i)
    end
    return ((math.abs(hash) % 1000) / 1000) * interval
end

Neurologics.AddThrottledThink = function(name, callback, interval)
    if type(name) ~= "string" or type(callback) ~= "function" then
        error("AddThrottledThink: name must be string, callback must be function")
    end
    interval = interval or 1.0
    local offset = nameToOffset(name, interval)
    local now = Timer.GetTime()
    Neurologics.ThrottledThinkCallbacks[name] = {
        callback = callback,
        interval = interval,
        lastRun = now - (interval - offset)
    }
end

Neurologics.RemoveThrottledThink = function(name)
    Neurologics.ThrottledThinkCallbacks[name] = nil
end

Hook.Add("think", "Neurologics.ThrottledThink", function()
    local now = Timer.GetTime()
    for name, data in pairs(Neurologics.ThrottledThinkCallbacks) do
        if data and data.callback and (now - data.lastRun) >= data.interval then
            data.lastRun = now
            data.callback()
        end
    end
end)
