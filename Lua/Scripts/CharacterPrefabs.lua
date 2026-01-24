-- -------------------------------
-- ATTENTION:
-- This file is for character prefabs.
-- If you want to add a new character, you can do so here.
-- Max nested sub-items is 3 for lag prevention, so if it does not spawn, try reducing the amount of sub-items.
-- Make sure all Char names are lowercase, otherwise it will not spawn.
--
-- NEW FEATURES:
-- Name = "Static Name" -- Static character name (overrides Prefix + generated name)
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

NCS.Char["traumateam"] = {
    Team = CharacterTeamType.Team1,
    Prefix = "ETC Agent", -- Europan Trauma Corps
    BaseJob = "medicaldoctor",
    Species = "human",
    Skills = {
        weapons = 100,
        medical = 100,
        mechanical = math.random(1, 50),
        electrical = math.random(1, 50),
        helm = math.random(1, 50)
    },
    Talents = {
        "itbelongsinamuseum", "alienhoarder", "deliverysystem", "genetampering",
        "bigbrain", "genesplicer", "uncoveringtheold", "foreignflora",
        "boldandbrash", "frontlineaid", "labcontacts", "medicalassistance",
        "grantmoney", "bloodybusiness", "artificialintelligence", "fieldresearch",
        "whatastench", "tombraider", "blackmarketgenes", "fontofhealth",
        "downrightarchimedean", "dissertation", "sorceroussnack", "drsubmarine",
        "macrodosing", "vitaminsupplements", "geneharvester", "supersoldiers",
        "madscience", "medicalexpertise", "laresistance", "crewmeninblack",
        "fastlearner", "medicalschooldropout", "plaguedoctor",
        "emergencyresponse", "containmentprotocol", "weneedtocook", "companionplants",
        "battlemedic", "nobodyimportantdies", "geneticgenious", "healthinsurance",
        "labanimal", "nopressure", "reverseengineer", "armoredcore",
        "delayedfuse", "tourofduty", "warstories", "buff",
        "munitionsexpertise", "beatcop", "dontpushit", "manthecannons",
        "powdermonkey", "bythebook", "pacificationkit", "killconfirmed",
        "merfolk", "daringdolphin", "firstaidtraining", "scavenger",
        "wetbehindtheears", "marksman", "policeacademy", "boardingparty",
        "tandemfire", "riotcontrol", "gunlugger", "destroyer",
        "warlord", "easyturtle", "cannoneer", "infantryman",
        "crustyseaman", "inordinateexsanguination", "protectandserve", "physicalconditioning",
        "specops", "slayer", "rescueoperation", "implacable",
        "swole", "operator", "commando", "accuracythroughvolume",
        "stonewall", "rifleman", "bootcamp", "firingsquad",
        "choppyseas", "killquota", "extrapowder", "onthemove"
    },
    Inventory = {
        { id = "idcard", count = 1, slot = InvSlotType.Card },
        { id = "autoinjectorheadset", count = 1, slot = InvSlotType.Headset, subItems = {
            { id = "combatstimulantsyringe", count = 1 }
        }},
        { id = "scp_cbrnhelmet", count = 1, slot = InvSlotType.Head, subItems = {
            { id = "oxygenitetank", count = 1 }
        }},
        { id = "scp_cbrnsuit", count = 1, slot = InvSlotType.InnerClothes },
        { id = "coalitionbodyarmor", count = 1, slot = InvSlotType.Any },
        { id = "pucs", count = 1, slot = InvSlotType.OuterClothes, subItems = {
            { id = "oxygenitetank", count = 1 },
            { id = "combatstimulantsyringe", count = 1 }
        }},
        { id = "scp_m35a2", count = 1, subItems = {
            { id = "scp_556duramag", count = 1 }
        }},
        { id = "scp_556duramag", count = 3 },
        { id = "thglightbodyarmor_belt", count = 1, slot = InvSlotType.Bag, subItems = {
            { id = "combatstimulantsyringe", count = 4 },
            { id = "scp_556duramag", count = 3, }
        }},
        { id = "boardingaxe", count = 1 },
        { id = "medtoolbox", count = 1, subItems = {
            { id = "scp_armykit", count = 2 },
            { id = "scp_surgicalkit", count = 2 },
            { id = "antibloodloss2", count = 8 },
            { id = "antidama1", count = 8 },
            { id = "antibleeding2", count = 8 }
        }},
        { id = "medtoolbox", count = 1, subItems = {
            { id = "antibleeding3", count = 2 },
            { id = "scp_condenseddeusizine", count = 1 },
            { id = "ointment", count = 2 },
            { id = "scp_adrenaline", count = 1 },
            { id = "deusizine", count = 1 },
            { id = "antinarc", count = 4 },
            { id = "scp_condensedstabilozine", count = 1 }
        }},
        { id = "medtoolbox", count = 1, subItems = {
            { id = "rapidrecoveryserum", count = 2 },
            { id = "ringerssolution", count = 4 },
            { id = "tourniquet", count = 4 },
            { id = "autocpr", count = 1, subItems = {
                { id = "fulguriumbatterycell", count = 1 }
            }},
            { id = "bvm", count = 1, subItems = {
                { id = "oxygenitetank", count = 1 }
            }},
            { id = "genestabilizer", count = 2 },
            { id = "liquidoxygenite", count = 4 },
            { id = "mannitol", count = 4 },
            { id = "thiamine", count = 4 }
        }},
        { id = "medtoolbox", count = 1, subItems = {
            { id = "antibiotics", count = 4 },
            { id = "bloodanalyzer", count = 1 },
            { id = "healthscanner", count = 1, subItems = {
                { id = "fulguriumbatterycell", count = 1 }
            }}
        }},
        { id = "surgerytoolbox", count = 1, subItems = {
            { id = "drainage", count = 4 },
            { id = "endovascballoon", count = 4 },
            { id = "needle", count = 4 },
            { id = "medstent", count = 4 }
        }},
        { id = "surgerytoolbox", count = 1, subItems = {
            { id = "advscalpel", count = 1 },
            { id = "advhemostat", count = 1 },
            { id = "advretractors", count = 1 },
            { id = "tweezers", count = 1 },
            { id = "traumashears", count = 1 },
            { id = "surgicaldrill", count = 1 },
            { id = "surgerysaw", count = 1 },
            { id = "suture", count = 32 },
            { id = "osteosynthesisimplants", count = 1 },
            { id = "spinalimplant", count = 1 },
            { id = "multiscalpel", count = 1 }
        }},
        { id = "advancedgenesplicer", count = 1, slot = InvSlotType.HealthInterface, subItems = {
            { id = "geneticmaterialmoloch", count = 1 },
            { id = "geneticmaterialhammerheadmatriarch", count = 1 }
        }}
    }
}

NCS.Char["god"] = {
    Team = CharacterTeamType.Team1,
    BaseJob = "guard",
    Species = "human",
    Name = "God",
    Skills = {
        weapons = 100,
        medical = 100,
        mechanical = 100,
        electrical = 100,
        helm = 100
    },
    Inventory = {
        { id = "idcard", count = 1, slot = InvSlotType.Card },
    }
}




--[[ Examples:

-- Character with static name
NCS.Char["staticname"] = {
    Team = CharacterTeamType.Team1,
    Name = "John Doe",  -- Static name instead of Prefix + generated
    BaseJob = "assistant",
    Species = "human",
    Inventory = {
        { id = "divingsuit", count = 1, slot = InvSlotType.OuterClothes }
    }
}

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
