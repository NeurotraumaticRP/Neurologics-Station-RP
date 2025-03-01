print("[Neurologics] Test") -- for debug

-- -------------------------------
-- ATTENTION:
-- This file is for character prefabs.
-- If you want to add a new character, you can do so here.
-- Max nested sub-items is 3 for lag prevention, so if it does not spawn, try reducing the amount of sub-items.
-- Make sure all Char names are lowercase, otherwise it will not spawn.
-- -------------------------------
if not Neurologics.CharacterSpawner then
    Neurologics.CharacterSpawner = {}
end

if not Neurologics.CharacterSpawner.Char then
    Neurologics.CharacterSpawner.Char = {}
end

--[[
Any
InvSlotType.Any = 1

Bag
InvSlotType.Bag = 256

Card
InvSlotType.Card = 128

Head
InvSlotType.Head = 8

Headset
InvSlotType.Headset = 64

HealthInterface
InvSlotType.HealthInterface = 512

InnerClothes
InvSlotType.InnerClothes = 16

LeftHand
InvSlotType.LeftHand = 4

None
InvSlotType.None = 0

OuterClothes
InvSlotType.OuterClothes = 32

RightHand
InvSlotType.RightHand = 2

]]

Neurologics.CharacterSpawner.Char["nukie"] = {
    Team    = Neurologics.Config.Teams.Nukies,
    Prefix  = "Nukie",
    BaseJob = "captain", -- this will be changed once we start working with the content package
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
        { id = "crowbar", count = 1 } -- Add crowbar as a normal item
    }
}
