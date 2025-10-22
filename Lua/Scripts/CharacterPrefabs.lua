print("[Neurologics] Test") -- for debug

-- -------------------------------
-- ATTENTION:
-- This file is for character prefabs.
-- If you want to add a new character, you can do so here.
-- Max nested sub-items is 3 for lag prevention, so if it does not spawn, try reducing the amount of sub-items.
-- Make sure all Char names are lowercase, otherwise it will not spawn.
--
-- NEW FEATURES:
-- Species = "human" (default) or "crawler", "mudraptor", etc.
-- Talents = {"talentid1", "talentid2"} -- List of talent identifiers
-- Skills = {weapons = 50, medical = 75} -- Skill name and level
-- Afflictions = {{"burn", 100}, {"bleeding", 50}} -- Applied once on spawn (strength defaults to 100)
-- PermaAfflictions = {{"burn", 100}, {"bleeding", 50}} -- Applied continuously every 1/6 second (strength defaults to 100)
-- -------------------------------
if not NCS then
    NCS = {}
end

if not NCS.Char then
    NCS.Char = {}
end

NCS.Char["nukie"] = {
    Team    = Neurologics.Config.Teams.Nukies,
    Prefix  = "Nuclear Operative",
    BaseJob = "guard",
    Inventory = {
        {
            id = "shotgun",
            count = 1,
            subItems = {
                { id = "shotgunshell", count = 6 }
            }
        },
        {
            id = "smg",
            count = 1,
            subItems = {
                { id = "smgmagazinedepletedfuel", count = 1 }
            }
        },
        {
            id = "plasmacutter",
            count = 1,
            subItems = {
                { id = "oxygenitetank", count = 1 }
            }
        },
        {
            id = "underwaterscooter",
            count = 1,
            subItems = {
                { id = "batterycell", count = 1 }
            }
        },
        { id = "shotgunshell", count = 12 },
        {
            id = "toolbelt",
            count = 1,
            subItems = {
                { id = "antibleeding1", count = 6 },
                { id = "antibloodloss2", count = 4 },
                { id = "fuelrod", count = 1 },
                { id = "smgmagazine", count = 2 },
                { id = "combatstimulantsyringe", count = 1 },
                { id = "tourniquet", count = 1 },
            },
            slot = InvSlotType.Bag
        },
        {
            id = "handheldsonar",
            count = 1,
            subItems = {
                { id = "batterycell", count = 1 }
            }
        },
        { id = "pirateclothes", count = 1, slot = InvSlotType.InnerClothes },
        { id = "crowbar", count = 1 }, -- Add crowbar as a normal item
        { id = "scp_renegadedivingsuit", count = 1, subItems = {
             { id = "oxygenitetank", count = 1 } 
            } 
        },
        { id = "idcard", count = 1, slot = InvSlotType.Card },
    }
}

NCS.Char["infiltrator"] = {
    Team = CharacterTeamType.Team1,
    Prefix = "Agent",
    BaseJob = "guard",
    Species = "human",
    Inventory = {
        { id = "idcard", count = 1, slot = InvSlotType.Card },
        { id = "autoinjectorheadset", count = 1, subItems = { { id = "combatstimulantsyringe", count = 1 } }, slot = InvSlotType.Headset },
        { id = "scp_yuihelmet", count = 1, slot = InvSlotType.Head },
        { id = "scp_specopsuniform", count = 1, subItems = { { id = "scp_surgicalkit", count = 1 }, { id = "scp_armykit", count = 1 }, { id = "antibloodloss2", count = 1 }, { id = "combatstimulantsyringe", count = 1 } }, slot = InvSlotType.InnerClothes },
        { id = "scp_yuirig", count = 1, slot = InvSlotType.OuterClothes },
        { id = "scp_assaultpack", count = 1, subItems = { { id = "scp_ak74dumag", count = 1 }, { id = "scp_45mag", count = 1 }, { id = "tourniquet", count = 1 } }, slot = InvSlotType.Bag },
        { id = "scp_sr3", count = 1, subItems = { { id = "scp_ak74dumag", count = 1 } } },
        { id = "scp_ak74dumag", count = 1, subItems = { { id = "scp_545x39duprojectile", count = 1 } } },
        { id = "boardingaxe", count = 1 },
        { id = "scp_m1911", count = 1, subItems = { { id = "scp_45mag", count = 1 } } },
        { id = "scp_45mag", count = 1, subItems = { { id = "scp_45projectile", count = 1 } } },
        { id = "frogslongdivingknife", count = 1 }
    }
}


--[[ Examples:

-- Super human with maxed skills and talents
NCS.Char["superhuman"] = {
    Team = CharacterTeamType.Team1,
    Prefix = "Super",
    BaseJob = "securityofficer",
    Species = "human",
    Talents = {
        "commando",
        "firemanscarry",
        "physicalconditioning"
    },
    Skills = {
        weapons = 100,
        medical = 100,
        mechanical = 100,
        electrical = 100,
        helm = 100
    },
    Inventory = {
        { id = "divingsuit", count = 1, slot = InvSlotType.OuterClothes },
        { id = "divingmask", count = 1, slot = InvSlotType.Head }
    }
}

-- Burn victim with permanent afflictions
NCS.Char["burnvictim"] = {
    Team = CharacterTeamType.Team1,
    Prefix = "Burned",
    BaseJob = "assistant",
    Species = "human",
    PermaAfflictions = {
        {"burn", 50},  -- Permanent 50% burns
        {"pain", 25}   -- Permanent 25% pain
    },
    Inventory = {
        { id = "divingsuit", count = 1, slot = InvSlotType.OuterClothes }
    }
}

-- Monster crawler with objectives (will work with NCS spawn)
NCS.Char["testcrawler"] = {
    Team = CharacterTeamType.Team2,
    Prefix = "Test",
    BaseJob = "assistant",
    Species = "crawler",
    Inventory = {} -- Crawlers don't need items
    -- Objectives can be attached via: NCS.SpawnCharacter("testcrawler", pos, team, {"KillMonsters"})
}

-- Wounded survivor with one-time afflictions (not permanent)
NCS.Char["wounded"] = {
    Team = CharacterTeamType.Team1,
    Prefix = "Wounded",
    BaseJob = "assistant",
    Species = "human",
    Afflictions = {
        {"bloodloss", 60},  -- One-time bloodloss
        {"gunshotwound", 30} -- One-time gunshot wound
    },
    Inventory = {
        { id = "divingsuit", count = 1, slot = InvSlotType.OuterClothes },
        { id = "healthscanner", count = 1 }
    }
}]]
