# Event Parameter Examples

This file demonstrates how to pass arguments to events using the new system.

## Example Event: TraumaTeam

The `traumateam.lua` event accepts three parameters:
1. `client` - The client to spawn near (optional)
2. `teamSize` - Number of medics (optional, default: 3)
3. `giveWeapons` - Whether to arm them (optional, default: false)

---

## Method 1: Using Neurologics.RunEvent() in Lua

### Basic - No Parameters (uses all defaults)
```lua
Neurologics.RunEvent("TraumaTeam")
-- Spawns 3 unarmed medics at medical bay
```

### With Parameters - Using Table
```lua
-- Spawn 5 armed medics at medical bay
Neurologics.RunEvent("TraumaTeam", {nil, 5, true})

-- Spawn 3 unarmed medics near a specific client
local targetClient = Client.ClientList[1]
Neurologics.RunEvent("TraumaTeam", {targetClient, 3, false})

-- Spawn 10 armed medics near a client
local targetClient = Neurologics.FindClientCharacter(someCharacter)
Neurologics.RunEvent("TraumaTeam", {targetClient, 10, true})
```

### With Condition Checking (3rd parameter)
```lua
-- This would check conditions (but TraumaTeam always returns false)
Neurologics.RunEvent("TraumaTeam", {nil, 5, true}, true)
-- Result: Won't run because conditions return false
```

---

## Method 2: Using !triggerevent Console Command

### Basic - No Parameters
```
!triggerevent TraumaTeam
```
Result: 3 unarmed medics at medical bay

### With Parameters
```
!triggerevent TraumaTeam 5 true
```
Result: 5 armed medics at medical bay (first parameter client is nil)

**Note**: Console commands can't pass client objects directly. For events that need clients, you'll need to modify the event to accept a client name or SteamID instead:

```lua
event.Start = function(clientName, teamSize, giveWeapons)
    local client = nil
    if clientName then
        for c in Client.ClientList do
            if c.Name == clientName then
                client = c
                break
            end
        end
    end
    -- ... rest of code
end
```

Then use:
```
!triggerevent TraumaTeam "PlayerName" 5 true
```

---

## Method 3: Using Old TriggerEvent() (Still Works)

```lua
-- Pass parameters as individual arguments (varargs)
Neurologics.RoundEvents.TriggerEvent("TraumaTeam", someClient, 5, true)
```

---

## Creating Your Own Parameterized Event

Here's a template:

```lua
local event = {}

event.Name = "MyCustomEvent"
event.ChancePerMinute = 0.01

-- Define parameters in the Start function signature
event.Start = function(param1, param2, param3)
    -- Set defaults for optional parameters
    param1 = param1 or "default_value"
    param2 = param2 or 100
    param3 = param3 or false
    
    -- Use the parameters
    print("Received: " .. tostring(param1) .. ", " .. tostring(param2) .. ", " .. tostring(param3))
    
    -- Your event logic here
    
    event.End()
end

event.End = function()
    -- Cleanup
end

return event
```

Call it with:
```lua
-- All parameters
Neurologics.RunEvent("MyCustomEvent", {"custom", 200, true})

-- Some parameters (rest use defaults)
Neurologics.RunEvent("MyCustomEvent", {"custom"})

-- No parameters (all defaults)
Neurologics.RunEvent("MyCustomEvent")
```

---

## Real-World Use Cases

### Use Case 1: Dynamic Event Spawning from Another Event
```lua
-- In some other event or script:
Hook.Add("character.death", "SpawnTraumaTeam", function(character)
    if character.HasJob("captain") then
        -- Captain died! Send a large armed trauma team
        Neurologics.RunEvent("TraumaTeam", {nil, 8, true})
    end
end)
```

### Use Case 2: Command to Spawn Help for Player
```lua
Neurologics.AddCommand("!requestmedics", function(client, args)
    local teamSize = tonumber(args[1]) or 3
    Neurologics.RunEvent("TraumaTeam", {client, teamSize, false})
    Neurologics.SendMessage(client, "Trauma team dispatched to your location!")
    return true
end)
```

### Use Case 3: Timed Event with Custom Parameters
```lua
-- After 10 minutes, spawn armed trauma team
Timer.Wait(function()
    if Game.RoundStarted then
        Neurologics.RunEvent("TraumaTeam", {nil, 5, true})
    end
end, 600000) -- 10 minutes in milliseconds
```

---

## Parameter Type Conversion

When using `!triggerevent`, parameters are automatically converted:
- Numbers: `"123"` → `123`
- Strings: `"text"` → `"text"`
- Booleans: Need to check as strings in your event

For boolean parameters, update your event to handle string input:

```lua
event.Start = function(param1, boolParam)
    -- Convert string to boolean if needed
    if type(boolParam) == "string" then
        boolParam = (boolParam == "true" or boolParam == "1")
    end
    boolParam = boolParam or false
    
    -- Now boolParam is definitely a boolean
end
```

---

## Tips

1. **Always provide defaults** for optional parameters using `param = param or default`
2. **Validate parameters** before using them to prevent errors
3. **Document your parameters** in comments at the top of the event
4. **Use nil** as a placeholder when you want to skip a parameter: `RunEvent("Event", {nil, 5})`
5. **Table unpacking** happens automatically - params table is unpacked into function arguments

