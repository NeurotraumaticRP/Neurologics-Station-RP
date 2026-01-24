# Trauma Team System - Implementation Complete

## Overview

A comprehensive Trauma Team system has been implemented that integrates pointshop purchases, unconsciousness monitoring, automatic team dispatch, complex healing objectives, attack tracking, and kill penalties.

---

## System Components

### 1. Attack Tracking System
**File:** `Lua/Scripts/attacktracker.lua`

Tracks all direct weapon/melee attacks between characters.

**Features:**
- Tracks attacker → victim with timestamps
- Filters environmental damage (only weapon/melee)
- Auto-cleanup of old records (>5 minutes)
- Memory cleared on round end

**Global Functions:**
```lua
Neurologics.PlayerHasAttacked(attacker, victim, sinceTimeSeconds)
-- Returns true if attacker attacked victim within time frame
-- If sinceTimeSeconds is nil, checks all time
```

**Example Usage:**
```lua
-- Check if character attacked another in last 2 minutes
if Neurologics.PlayerHasAttacked(char1, char2, 120) then
    print("Attack detected within last 120 seconds!")
end
```

---

### 2. Pointshop Membership
**File:** `Lua/config/pointshop/services.lua`

**Item:** "Platinum Europan Trauma Corps Membership"
- **Cost:** 350 points
- **Limit:** 1 per player per round
- **One-time use:** After rescue, cannot be used again that round

**Purchase Requirements:**
- Player must be alive
- Player must be conscious
- Player cannot be a traitor

**What It Does:**
- Sets membership flag on client
- Activates unconsciousness monitoring
- Enables automatic ETC dispatch

---

### 3. Status Monitor System (Generic)
**File:** `Lua/Scripts/statusmonitor.lua`

**Purpose:** Generic system for monitoring character states over time.

**Features:**
- Any event can register custom monitors
- Tracks conditions with time thresholds
- Triggers callbacks when conditions met
- Optional filters and reset handlers

**Used by Trauma Team:**
- Monitors unconsciousness for members
- 10 second threshold before dispatch
- Filter checks membership and usage status
- Debug messages every 5s showing progress
- Debug message when threshold met

**Global Functions:**
```lua
Neurologics.StatusMonitor.RegisterMonitor(id, config)
-- config: { filter, condition, threshold, onTrigger, onReset }

Neurologics.StatusMonitor.UnregisterMonitor(id)
Neurologics.StatusMonitor.IsTracking(monitorID, client)
```

---

### 4. Trauma Team Event
**File:** `Lua/config/randomevents/traumateam.lua`

**Parameters:**
- `client` (required): Protected membership holder
- `teamSize` (optional): Number of agents (default: 2)

**Spawning:**
- Spawns ETC agents from **dead players** (ghost role system)
- Uses NCS "traumateam" prefab via SpawnCharacterWithClient
- Assigns unique team ID
- Tags agents for identification
- Creates heal objectives for each agent
- Sends mission briefing to each agent

**State Tracking:**
- Tracks all active teams
- Monitors objective completion
- Auto-despawns 30s after completion
- Cleans up when all agents dead

**Think Loop:**
- Checks objective completion
- Handles auto-despawn timing
- Cleans up dead teams

---

### 5. Trauma Team Heal Objective
**File:** `Lua/objectives/eventobjectives/traumateamheal.lua`

**Completion Requirements (ALL must be true):**
1. Target is conscious (not unconscious)
2. Target neurotrauma < 30
3. Target heart damage < 30
4. Target not dead

**Progress Tracking:**
Displays real-time status of all conditions.

---

### 6. Kill Penalty System
**Integrated into:** `Lua/config/randomevents/traumateam.lua`
**Uses:** Centralized death handler system in `Lua/Neurologicsmisc.lua`

**Penalty:** 250 points deducted from protected client

**Implementation:**
- Event registers callback with `Neurologics.RegisterDeathHandler()`
- Uses centralized death system (reusable by any event)
- `CheckKillPenalty()` method processes ETC-specific logic
- Clean separation: system infrastructure vs. event logic

**Exceptions (NO PENALTY):**
1. Victim was a traitor
2. Victim was not Team1
3. Victim attacked protected client (within 120s)
4. Victim attacked ETC agent (within 120s)

**Notifications:**
- Client receives penalty notice
- Admins notified of penalty application
- Logged for review

---

### 7. Centralized Death Handler System
**Files:** `Lua/Neurologicsutil.lua` (functions) + `Lua/Neurologicsmisc.lua` (hook)

**Purpose:** Provides a single `character.death` hook that any event/system can use without creating hook conflicts.

**Architecture:** Functions defined early in Neurologicsutil.lua so events can register during Init(). Hook registered later in Neurologicsmisc.lua when Hook API is available.

**Global Functions:**
```lua
-- Register a callback for character deaths
Neurologics.RegisterDeathHandler(id, callback)
-- callback: function(character, killer)

-- Unregister a callback
Neurologics.UnregisterDeathHandler(id)
```

**How Events Use It:**
```lua
event.Init = function()
    Neurologics.RegisterDeathHandler("MyEventName", function(character, killer)
        -- Handle death logic here
    end)
end
```

**Benefits:**
- Single hook instead of multiple conflicting hooks
- Centralized error handling
- Automatic cleanup on round end
- Easy to add/remove handlers
- Reusable by any event or system

---

### 8. Centralized Cleanup System
**File:** `Lua/Neurologicsutil.lua`

**Purpose:** Provides a generic cleanup system that any module can register with.

**Global Functions:**
```lua
-- Register a cleanup callback for round end
Neurologics.RegisterCleanup(id, callback)
-- callback: function() - called on round end

-- Unregister a cleanup callback
Neurologics.UnregisterCleanup(id)

-- Execute all registered cleanups (called by Neurologics.lua)
Neurologics.ExecuteCleanup()
```

**How Modules Use It:**
```lua
-- In your module/system file
Neurologics.RegisterCleanup("MySystem", function()
    -- Cleanup your data here
    MySystem.Clear()
end)
```

**Registered Cleanups:**
- `AttackTracker` - Clears attack tracking data
- `TraumaTeamMonitor` - Clears tracking and membership flags
- `DeathHandler` - Clears registered callbacks (in Neurologicsmisc.lua)

**Benefits:**
- No module-specific code in main file
- Automatic error handling with pcall
- Easy to add new modules
- Clean separation of concerns
- Single line in Neurologics.lua: `Neurologics.ExecuteCleanup()`

---

## File Changes Summary

### New Files Created:
1. `Lua/Scripts/attacktracker.lua` - Attack tracking system (reusable for any event)
2. `Lua/Scripts/statusmonitor.lua` - Generic status monitoring system (reusable for any event)

### Modified Files:
1. `Lua/config/pointshop/services.lua` - Membership product
2. `Lua/config/randomevents/traumateam.lua` - Complete event with kill penalty logic
3. `Lua/objectives/eventobjectives/traumateamheal.lua` - Heal objective
4. `Lua/Neurologics.lua` - Calls ExecuteCleanup() (one line!)
5. `Lua/config/baseconfig.lua` - Added services category
6. `Lua/roundevents.lua` - Added Think() support for events
7. `Lua/Neurologicsmisc.lua` - Added centralized death handler system
8. `Lua/Neurologicsutil.lua` - Added centralized cleanup system
9. `Lua/Scripts/attacktracker.lua` - Registers cleanup callback
10. `Lua/Scripts/statusmonitor.lua` - Generic status monitoring system

### Design Philosophy:
✅ **Global Reusable Systems**
- `AttackTracker` - Any event can track attacks
- `DeathHandler` - Any event can register death callbacks
- `StatusMonitor` - Any event can monitor character states over time
- `CleanupSystem` - Any module can register cleanup
- Placed in appropriate utility files

✅ **Event-Specific Logic**
- Kill penalty logic in the event itself
- Uses global systems via helper functions
- Keeps related code together

✅ **Clean Architecture**
- Single hook per event type (no hook conflicts)
- Helper functions for accessing hook data
- No single-purpose script files
- Events/modules register callbacks, don't create hooks
- Main file (Neurologics.lua) stays clean and generic

✅ **Scalability**
- Add new modules without touching main file
- Register callbacks from any file
- Centralized error handling
- Easy debugging and maintenance

---

## Usage Examples

### For Players

**Purchase Membership:**
1. Open pointshop (!pointshop)
2. Navigate to "services" category
3. Buy "Platinum Europan Trauma Corps Membership" (350 pts)
4. If knocked unconscious for 10+ seconds → ETC team dispatched!

### For Admins/Developers

**Manual Dispatch:**
```lua
-- Dispatch team for specific client
local client = Client.ClientList[1]
Neurologics.RunEvent("TraumaTeam", {client, 3})  -- 3 agents

-- Dispatch larger team
Neurologics.RunEvent("TraumaTeam", {client, 5})  -- 5 agents
```

**Console Command:**
```
!triggerevent TraumaTeam
```

**Check Attack History:**
```lua
if Neurologics.PlayerHasAttacked(killer, victim, 60) then
    -- Killer attacked victim in last 60 seconds
end
```

### For Other Events Using the System

**Register Death Handler:**
```lua
-- In your event's Init() function
event.Init = function()
    Neurologics.RegisterDeathHandler("MyEventName", function(character, killer)
        -- Your death handling logic
        if killer and character.TeamID == CharacterTeamType.Team1 then
            print("Crew member killed!")
        end
    end)
end
```

**Track Attacks in Your Event:**
```lua
-- Check if someone was attacked recently
if Neurologics.PlayerHasAttacked(attacker, victim, 30) then
    -- Attacker hit victim in last 30 seconds
    applyPenalty()
end
```

**Example: Bounty System Event**
```lua
event.Init = function()
    Neurologics.RegisterDeathHandler("BountySystem", function(character, killer)
        if killer and event.HasBounty(character) then
            event.AwardBounty(killer, character)
        end
    end)
    
    -- Also register cleanup
    Neurologics.RegisterCleanup("BountySystem", function()
        event.ActiveBounties = {}
    end)
end
```

**Creating a New System with Cleanup:**
```lua
-- In your new system file
local MySystem = {}
MySystem.Data = {}

MySystem.Clear = function()
    MySystem.Data = {}
    print("MySystem cleared!")
end

-- Register cleanup automatically
Neurologics.RegisterCleanup("MySystem", function()
    MySystem.Clear()
end)

return MySystem
```

### Using Status Monitor in Other Events

**Example: Low Health Alert System**
```lua
event.Init = function()
    Neurologics.StatusMonitor.RegisterMonitor("LowHealthAlert", {
        -- Only check alive crew members
        filter = function(client)
            return client.Character 
                and not client.Character.IsDead
                and client.Character.TeamID == CharacterTeamType.Team1
        end,
        
        -- Condition: Health below 20%
        condition = function(client)
            if not client.Character then return false end
            local vitality = client.Character.Vitality
            local maxVitality = client.Character.MaxVitality
            return (vitality / maxVitality) < 0.20
        end,
        
        -- Threshold: 30 seconds of low health
        threshold = 30,
        
        -- Trigger: Send alert to medical
        onTrigger = function(client)
            -- Notify medical staff
            for c in Client.ClientList do
                if c.Character and c.Character.HasJob("medicaldoctor") then
                    Neurologics.SendMessage(c, string.format(
                        "MEDICAL ALERT: %s is critically injured!", client.Name))
                end
            end
        end,
        
        -- Optional: Called when health recovers
        onReset = function(client)
            Neurologics.Debug(client.Name .. " health recovered")
        end
    })
end
```

**Example: Radiation Exposure Tracker**
```lua
event.Init = function()
    Neurologics.StatusMonitor.RegisterMonitor("RadiationExposure", {
        condition = function(client)
            if not client.Character then return false end
            local rad = client.Character.CharacterHealth.GetAffliction("radiationsickness", true)
            return rad and rad.Strength > 50
        end,
        
        threshold = 60, -- 1 minute
        
        onTrigger = function(client)
            -- Award achievement or trigger event
            Neurologics.SendMessage(client, "You have severe radiation poisoning!")
            Neurologics.AddData(client, "Points", -100) -- Penalty
        end
    })
end
```

**Example: AFK Detection**
```lua
-- Track last position to detect AFK players
local lastPositions = {}

event.Init = function()
    Neurologics.StatusMonitor.RegisterMonitor("AFKDetection", {
        condition = function(client)
            if not client.Character then return false end
            
            local currentPos = client.Character.WorldPosition
            local lastPos = lastPositions[client.SteamID]
            
            if not lastPos then
                lastPositions[client.SteamID] = currentPos
                return false
            end
            
            -- Check if player hasn't moved
            local distance = Vector2.Distance(currentPos, lastPos)
            local isAFK = distance < 50 -- Less than 50 units movement
            
            if not isAFK then
                lastPositions[client.SteamID] = currentPos
            end
            
            return isAFK
        end,
        
        threshold = 300, -- 5 minutes
        
        onTrigger = function(client)
            -- Kick or warn AFK player
            Neurologics.SendMessage(client, "You have been AFK for 5 minutes!")
        end
    })
end
```

**Example: Oxygen Deprivation Alarm**
```lua
event.Init = function()
    Neurologics.StatusMonitor.RegisterMonitor("OxygenAlarm", {
        condition = function(client)
            if not client.Character then return false end
            local oxygen = client.Character.CharacterHealth.GetAffliction("oxygenlow", true)
            return oxygen and oxygen.Strength > 30
        end,
        
        threshold = 15, -- 15 seconds
        
        onTrigger = function(client)
            -- Trigger oxygen emergency event
            event.SpawnOxygenTank(client.Character.WorldPosition)
        end
    })
end
```

---

## Testing Checklist

- [ ] Purchase membership while alive and conscious
- [ ] Verify purchase blocked for traitors
- [ ] Get knocked unconscious for 10+ seconds
- [ ] Check debug logs show tracking progress (every 5s)
- [ ] Verify dead players are available for spawning
- [ ] ETC team spawns from dead players (ghost role)
- [ ] Team spawns outside submarine
- [ ] ETC agents receive mission briefing
- [ ] Team has correct objective assigned
- [ ] Heal target to meet all conditions
- [ ] Team despawns 30s after completion
- [ ] Kill innocent as ETC → penalty applied
- [ ] Kill traitor as ETC → no penalty
- [ ] Kill attacker as ETC → no penalty
- [ ] Round end → all data cleared
- [ ] Can't use membership twice in same round
- [ ] No team spawns if no dead players available

---

## System Flow Diagram

```
Player Purchases Membership (350 pts)
    ↓
Monitor detects unconscious (10s)
    ↓
Trauma Team Event triggered
    ↓
2 ETC Agents spawn with objective
    ↓
Agents heal target (conscious, neuro<30, heart<30)
    ↓
Objective complete → 30s timer starts
    ↓
Team despawns automatically
    ↓
Round ends → all data cleared
```

---

## Performance & Memory

**Memory Safety:**
- Attack records auto-cleanup after 5 minutes
- All tracking cleared on round end
- Event cleanup removes despawned agents
- No persistent cross-round storage

**Performance:**
- Think hooks run efficiently
- Monitoring checks only 1/second
- Attack tracking uses character IDs (not objects)
- Minimal overhead when no active teams

---

## Future Enhancements (Optional)

1. **Tiered Memberships:** Bronze (1 agent), Silver (2 agents), Platinum (3 agents)
2. **Partial Refund:** Return points if team fails
3. **Priority System:** VIP members get faster response
4. **Performance Bonuses:** Extra points if team completes quickly
5. **Team Customization:** Choose agent loadouts
6. **Statistics Tracking:** How many rescues, success rate, etc.

---

## Support & Troubleshooting

**Common Issues:**

1. **Team not spawning:**
   - Check round has started
   - Verify membership was purchased
   - Check client is actually unconscious (not force ragdolled)
   - Check 10 second threshold

2. **Penalty applied unfairly:**
   - Check attack tracker: `Neurologics.PlayerHasAttacked(victim, target)`
   - Verify 120 second window
   - Check victim's team and traitor status

3. **Memory issues:**
   - Verify round-end cleanup is running
   - Check attack tracker cleanup (runs every minute)
   - Monitor active teams count

**Debug Commands:**
```lua
-- Check if someone has membership
print(Neurologics.GetData(client, "TraumaTeamMember"))

-- Check if membership used
print(Neurologics.GetData(client, "TraumaTeamUsed"))

-- List active teams
for id, team in pairs(Neurologics.RoundEvents.EventConfigs.Events) do
    if team.Name == "TraumaTeam" then
        for teamID, data in pairs(team.ActiveTeams) do
            print("Team " .. teamID .. " active")
        end
    end
end
```

---

## Implementation Complete! ✓

All features have been implemented according to specifications:
- ✅ One-time use per round
- ✅ No cooldown (single use design)
- ✅ Multiple simultaneous teams
- ✅ Complete round-end cleanup
- ✅ Direct attack tracking only
- ✅ 30s auto-despawn after completion
- ✅ Complex healing requirements
- ✅ Kill penalty with exceptions

The system is ready for testing and deployment!

