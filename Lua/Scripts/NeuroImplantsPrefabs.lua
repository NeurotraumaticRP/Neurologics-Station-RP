--[[
    NEUROLOGICS IMPLANT PREFAB SYSTEM
    ================================
    
    This system allows for modular implant creation with sensible defaults.
    Most properties are optional and will use defaults if not specified.
    
    IMPLANT TYPES SUPPORTED:
    - Toggle implants (fists, grenade launcher, sword arm)
    - Permanent implants (gun arm - always active)
    - Conditional implants (adrenal spine - auto-activates on health threshold)
    - Affliction-based implants (detects which limb has the affliction)
    
    BASIC USAGE:
    Neurologics.Implants["MyImplant"] = {
        Name = "My Implant",
        ItemIdentifier = "my_implant_item",
        -- Everything else uses defaults
    }
]]

Neurologics.Implants = {}

-- Default values for all implant properties
local DEFAULT_IMPLANT = {
    -- Core Identity
    Name = "Unnamed Implant",
    ItemIdentifier = "",
    Description = "A neural implant.",
    Type = "Internal",
    Category = "Utility",
    
    -- Affliction System
    RequiresAffliction = false,          -- Boolean: does this implant require an affliction to activate?
    AfflictionIdentifier = nil,          -- String: affliction identifier to check for
    AfflictionLimbType = nil,            -- LimbType: which limb to check for affliction (nil = any)
    AfflictionRequired = true,           -- Boolean: must have affliction (true) or must NOT have it (false)
    
    -- Slot Management
    Slots = {},                          -- Table: inventory slots used (empty = no slots)
    MaxInstances = 1,                    -- Number: max items spawned
    RequiresFreeSlots = false,           -- Boolean: must slots be empty?
    Blacklist = {},                      -- Table: item identifiers that block activation
    AutoUnequip = true,                  -- Boolean: auto-unequip conflicting items?
    
    -- Activation Behavior
    ActivationMode = "toggle",           -- String: "toggle", "permanent", "conditional"
    ToggleMode = true,                   -- Boolean: can be toggled on/off
    CanDrop = false,                     -- Boolean: can spawned items be dropped?
    Stackable = false,                   -- Boolean: can multiple be active?
    PersistOnDeath = false,              -- Boolean: stays active after death?
    RequiresConscious = true,            -- Boolean: needs character conscious?
    Cooldown = 0,                        -- Number: cooldown in seconds
    Duration = nil,                      -- Number: how long active (nil = permanent)
    
    -- State Persistence (for remembering ammo, etc.)
    SaveState = false,                   -- Boolean: save state between activations?
    StateProperties = {},                -- Table: which properties to save (e.g., {"ammo", "condition"})
    
    -- Spawning Configuration
    SpawnConfig = {
        SpawnMethod = "inventory",       -- String: "inventory", "hand", "slot", "world", "freeHands"
        PreferredSlots = {},             -- Table: preferred slots in order
        Condition = 100,                 -- Number: item condition (0-100)
        Quality = 1,                     -- Number: item quality
        SpawnCount = nil,                -- Number: items to spawn (nil = auto)
        TargetLimb = nil,                -- LimbType: specific limb for affliction-based implants
    },
    
    -- Conditional Activation (for auto-implants like adrenal spine)
    ConditionalActivation = {
        Enabled = false,                 -- Boolean: use conditional activation?
        CheckFunction = nil,             -- Function: function(client) -> boolean
        CheckInterval = 1,               -- Number: how often to check (seconds)
        AutoDeactivate = false,          -- Boolean: auto-deactivate when condition fails?
    },
    
    -- UI/Visual Properties
    Icon = "implant_icon",
    Color = {100, 100, 100},
    SortOrder = 100,
    Hidden = false,
    
    -- Requirements/Permissions
    Requirements = {
        Jobs = nil,                      -- Table: allowed jobs (nil = all)
        Roles = nil,                     -- Table: allowed roles (nil = all)
        MinHealth = 0,                   -- Number: minimum health required (0 = no minimum)
        MaxHealth = nil,                 -- Number: maximum health (nil = no maximum, use for health-based implants)
        Afflictions = {                  -- Table: required/forbidden afflictions
            Required = {},               -- Must have these afflictions
            Forbidden = {},              -- Cannot have these afflictions
        },
    },
    Cost = 0,                           -- Number: points cost
    UnlockCondition = nil,              -- Function: function(client) -> boolean
    
    -- Hook Functions (all optional)
    CanActivate = nil,                  -- Function: function(client, implant) -> boolean, errorMessage
    OnActivate = nil,                   -- Function: function(client, implant, spawnedItems)
    OnDeactivate = nil,                 -- Function: function(client, implant, reason)
    OnSpawned = nil,                    -- Function: function(client, item, slot)
    OnThink = nil,                      -- Function: function(client, implant) -- Continuous
    OnEquipped = nil,                   -- Function: function(client, item, slot)
    OnUnequipped = nil,                 -- Function: function(client, item, slot)
    OnDamaged = nil,                    -- Function: function(client, damage)
    OnKill = nil,                       -- Function: function(client, victim)
    OnDeath = nil,                      -- Function: function(client)
    OnConditionMet = nil,               -- Function: function(client, implant) -- For conditional implants
    OnConditionLost = nil,              -- Function: function(client, implant) -- For conditional implants
}

-- Helper function to create implant with defaults
function Neurologics.Implants.Create(name, customData)
    local implant = {}
    
    -- Copy all defaults
    for key, value in pairs(DEFAULT_IMPLANT) do
        if type(value) == "table" then
            implant[key] = {}
            for subkey, subvalue in pairs(value) do
                implant[key][subkey] = subvalue
            end
        else
            implant[key] = value
        end
    end
    
    -- Override with custom data
    if customData then
        for key, value in pairs(customData) do
            if type(value) == "table" and type(implant[key]) == "table" then
                -- Merge tables instead of replacing
                for subkey, subvalue in pairs(value) do
                    implant[key][subkey] = subvalue
                end
            else
                implant[key] = value
            end
        end
    end
    
    return implant
end

-- Example implants demonstrating different types:

-- 1. BASIC TOGGLE IMPLANT (Fists)
Neurologics.Implants["Fists"] = Neurologics.Implants.Create("Fists", {
    Name = "Cybernetic Fists",
    ItemIdentifier = "ne_fists",
    Description = "Advanced combat implants that allow devastating melee attacks.",
    Type = "Arms",
    Category = "Combat",
    
    Slots = {InvSlotType.RightHand, InvSlotType.LeftHand},
    MaxInstances = 2,
    RequiresFreeSlots = false,
    Blacklist = {"handcuffs", "armlock1", "armlock2"},
    SpawnConfig = {
        SpawnMethod = "freeHands",  -- Special method for hands
    },
    
    OnActivate = function(client, implant, spawnedItems)
        Neurologics.Log(client.Name .. " activated fists")
    end,
    
    OnDeactivate = function(client, implant, reason)
        Neurologics.Log(client.Name .. " deactivated fists: " .. reason)
    end,
})

-- 2. AFFLICTION-BASED TOGGLE IMPLANT (Grenade Launcher Arm)
--[[Neurologics.Implants["GrenadeLauncherArm"] = Neurologics.Implants.Create("GrenadeLauncherArm", {
    Name = "Grenade Launcher Arm",
    ItemIdentifier = "grenadelauncher",
    Description = "A cybernetic arm equipped with a grenade launcher.",
    Type = "Arms",
    Category = "Combat",
    
    RequiresAffliction = true,
    AfflictionIdentifier = "grenadelauncherarm",
    AfflictionLimbType = LimbType.RightArm, -- Could be LeftArm too
    SpawnConfig = {
        SpawnMethod = "hand",
        TargetLimb = LimbType.RightArm,
    },
    
    SaveState = true,
    StateProperties = {"ammo", "condition"},
    
    OnActivate = function(client, implant, spawnedItems)
        -- Restore ammo from previous activation
        local savedAmmo = Neurologics.GetData(client, "grenadelauncher_ammo") or 0
        if spawnedItems[1] and savedAmmo > 0 then
            -- Restore ammo to the launcher
            spawnedItems[1].SetState("ammo", savedAmmo)
        end
    end,
    
    OnDeactivate = function(client, implant, reason)
        -- Save current ammo
        local launcher = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.RightHand)
        if launcher and launcher.Prefab.Identifier == "grenadelauncher" then
            local currentAmmo = launcher.GetState("ammo") or 0
            Neurologics.SetData(client, "grenadelauncher_ammo", currentAmmo)
        end
    end,
})]]--

-- 3. PERMANENT IMPLANT (Gun Arm)
--[[Neurologics.Implants["GunArm"] = Neurologics.Implants.Create("GunArm", {
    Name = "Cybernetic Gun Arm",
    ItemIdentifier = "gunarm",
    Description = "A permanent cybernetic arm replacement with integrated weaponry.",
    Type = "Arms",
    Category = "Combat",
    
    ActivationMode = "permanent",
    ToggleMode = false,
    PersistOnDeath = true,
    
    RequiresAffliction = true,
    AfflictionIdentifier = "gunarm",
    AfflictionLimbType = nil, -- Any arm
    
    SpawnConfig = {
        SpawnMethod = "afflictionLimb", -- Spawn on the limb with the affliction
    },
    
    OnActivate = function(client, implant, spawnedItems)
        Neurologics.Log(client.Name .. " has activated their permanent gun arm")
    end,
})]]--

-- 4. CONDITIONAL AUTO-IMPLANT (Adrenal Spine)
--[[Neurologics.Implants["AdrenalSpine"] = Neurologics.Implants.Create("AdrenalSpine", {
    Name = "Adrenal Spine Autoinjector",
    ItemIdentifier = "adrenalspine",
    Description = "Automatically injects adrenaline when health falls below 25%.",
    Type = "Spine",
    Category = "Medical",
    
    ActivationMode = "conditional",
    ToggleMode = false,
    PersistOnDeath = false,
    RequiresConscious = true,
    
    ConditionalActivation = {
        Enabled = true,
        CheckFunction = function(client)
            return client.Character.HealthPercentage < 0.25
        end,
        CheckInterval = 0.5, -- Check twice per second
        AutoDeactivate = true,
    },
    
    OnConditionMet = function(client, implant)
        -- Inject adrenaline
        HF.SetAffliction(client.Character, "adrenaline", 10)
        Neurologics.Log(client.Name .. "'s adrenal spine activated!")
    end,
    
    OnConditionLost = function(client, implant)
        Neurologics.Log(client.Name .. "'s adrenal spine deactivated")
    end,
})]]--

-- 5. SWORD ARM (Affliction-based, simple toggle)
--[[Neurologics.Implants["SwordArm"] = Neurologics.Implants.Create("SwordArm", {
    Name = "Mantis Blade",
    ItemIdentifier = "sword",
    Description = "A retractable cybernetic blade that extends from your arm.",
    Type = "Arms",
    Category = "Combat",
    
    RequiresAffliction = true,
    AfflictionIdentifier = "swordarm",
    AfflictionLimbType = nil, -- Any arm
    
    SpawnConfig = {
        SpawnMethod = "hand",
        TargetLimb = nil, -- Will be determined by affliction location
    },
    
    OnActivate = function(client, implant, spawnedItems)
        Neurologics.Log(client.Name .. " extended their mantis blade")
    end,
    
    OnDeactivate = function(client, implant, reason)
        Neurologics.Log(client.Name .. " retracted their mantis blade")
    end,
})]]--