local re = {}

LuaUserData.RegisterType("Barotrauma.EventManager") -- temporary

re.OnGoingEvents = {}

re.ThisRoundEvents = {}
re.EventConfigs = Neurologics.Config.RandomEventConfig

re.AllowedEvents = {}

re.IsEventActive = function (eventName)
    if re.OnGoingEvents[eventName] then
        return true
    end
    return false
end

re.EventExists = function (eventName)
    local event = nil
    for _, value in pairs(re.EventConfigs.Events) do
        if value.Name == eventName then
            event = value
        end
    end

    return event ~= nil
end

re.TriggerEvent = function (eventName, ...)
    if not Game.RoundStarted then
        Neurologics.Error("Tried to trigger event " .. eventName .. ", but round is not started.")
        return false, "Round not started"
    end

    if re.OnGoingEvents[eventName] then
        Neurologics.Error("Event " .. eventName .. " is already running.")
        return false, "Event already running"
    end

    local event = nil
    for _, value in pairs(re.EventConfigs.Events) do
        if value.Name == eventName then
            event = value
        end
    end

    if event == nil then
        Neurologics.Error("Tried to trigger event " .. eventName .. " but it doesnt exist or is disabled.")
        return false, "Event doesn't exist"
    end

    local originalEnd = event.End
    event.End = function (isRoundEnd)
        re.OnGoingEvents[eventName] = nil
        originalEnd(isRoundEnd)
    end

    Neurologics.Stats.AddStat("EventTriggered", event.Name, 1)

    re.OnGoingEvents[eventName] = event
    
    -- Pass parameters to event.Start
    local params = {...}
    event.Start(table.unpack(params))

    if re.ThisRoundEvents[eventName] == nil then
        re.ThisRoundEvents[eventName] = 0
    end
    re.ThisRoundEvents[eventName] = re.ThisRoundEvents[eventName] + 1

    Neurologics.Log("Event " .. eventName .. " triggered.")
    return true, event
end

re.CheckRandomEvent = function (event)
    if event.MinRoundTime ~= nil and Neurologics.RoundTime / 60 < event.MinRoundTime then
        return
    end

    if event.MaxRoundTime ~= nil and Neurologics.RoundTime / 60 > event.MaxRoundTime then
        return
    end

    local intensity = Game.GameSession.EventManager.CurrentIntensity

    if event.MinIntensity ~= nil and intensity < event.MinIntensity then
        return
    end

    if event.MaxIntensity ~= nil and intensity > event.MaxIntensity then
        return
    end

    -- Check custom conditions if they exist
    if event.Conditions and not event.Conditions() then
        return
    end

    if math.random() > event.ChancePerMinute then
        return
    end

    Neurologics.Log("Selected random event to trigger \"" .. event.Name .. "\" with intensity " .. intensity .. " and round time " .. Neurologics.RoundTime / 60 .. " minutes.")

    re.TriggerEvent(event.Name)
end

re.SendEventMessage = function (text, icon, color)
    for key, value in pairs(Client.ClientList) do
        local messageChat = ChatMessage.Create("", text, ChatMessageType.Default, nil, nil)
        messageChat.Color = Color(200, 30, 241, 255)
        Game.SendDirectChatMessage(messageChat, value)

        local messageBox = ChatMessage.Create("", text, ChatMessageType.ServerMessageBoxInGame, nil, nil)
        messageBox.IconStyle = icon
        if color then messageBox.Color = color end
        Game.SendDirectChatMessage(messageBox, value)
    end 
end

local lastRandomEventCheck = 0
Neurologics.AddThrottledThink("RoundEvents.Think", function()
    if not Game.RoundStarted then return end

    -- Call Think() on ongoing events
    for eventName, event in pairs(re.OnGoingEvents) do
        if event.Think then
            event.Think()
        end
    end

    if Timer.GetTime() > lastRandomEventCheck then
        for _, event in pairs(re.EventConfigs.Events) do
            if re.OnGoingEvents[event.Name] == nil and re.AllowedEvents[event.Name] then
                if not event.OnlyOncePerRound or re.ThisRoundEvents[event.Name] == nil then
                    re.CheckRandomEvent(event)
                end
            end
        end
        lastRandomEventCheck = Timer.GetTime() + 60
    end
end, 0.5)

re.RunEvent = function (eventName, params, checkConditions)
    if not Game.RoundStarted then
        Neurologics.Error("Tried to run event " .. eventName .. ", but round is not started.")
        return false, "Round not started"
    end

    if re.OnGoingEvents[eventName] then
        Neurologics.Error("Event " .. eventName .. " is already running.")
        return false, "Event already running"
    end

    local event = nil
    for _, value in pairs(re.EventConfigs.Events) do
        if value.Name == eventName then
            event = value
        end
    end

    if event == nil then
        Neurologics.Error("Tried to run event " .. eventName .. " but it doesnt exist or is disabled.")
        return false, "Event doesn't exist"
    end

    -- Check conditions if checkConditions is true
    if checkConditions and event.Conditions and not event.Conditions() then
        Neurologics.Error("Event " .. eventName .. " conditions not met.")
        return false, "Conditions not met"
    end

    -- Convert params table to varargs if provided
    if params then
        return re.TriggerEvent(eventName, table.unpack(params))
    else
        return re.TriggerEvent(eventName)
    end
end

re.Initialize = function (allowedEvents)
    re.AllowedEvents = {}

    if allowedEvents == nil then
        for key, value in pairs(re.EventConfigs.Events) do
            re.AllowedEvents[value.Name] = true
        end
    else
        for key, value in pairs(allowedEvents) do
            re.AllowedEvents[value] = true
        end
    end
end

re.EndRound = function ()
    for key, value in pairs(re.OnGoingEvents) do
        value.End(true)
        re.OnGoingEvents[key] = nil
    end

    re.ThisRoundEvents = {}
    re.AllowedEvents = {}
end

-- Expose RunEvent to global Neurologics namespace for easy access
Neurologics.RunEvent = re.RunEvent

return re