if not Neurologics.CharacterSpawner.Char then
    Neurologics.CharacterSpawner.Char = {}
end

Neurologics.CharacterSpawner.Char["nukie"] = {
    Team = Neurologics.Config.Teams.Nukies,
    Prefix = "Nukie",
    BaseJob = "warden",
    Inventory = {
        { id = "shotgun", count = 1, subItems = { { id = "shotgunshell", count = 6 } } },
        { id = "smg", count = 1, subItems = { { id = "smgmagazinedepletedfuel", count = 1 } } },
        { id = "plasmacutter", count = 1, subItems = { { id = "oxygenitetank", count = 1 } } },
        { id = "underwaterscooter", count = 1, subItems = { { id = "batterycell", count = 1 } } },
        { id = "shotgunshell", count = 12 },
        { id = "toolbelt", count = 1, subItems = {
                { id = "antibleeding1", count = 6 },
                { id = "antibloodloss2", count = 4 },
                { id = "fuelrod", count = 1 },
                { id = "smgmagazine", count = 2 },
                { id = "combatstimulantsyringe", count = 1 },
                { id = "tourniquet", count = 1 },
        }},
        { id = "handheldsonar", count = 1, subItems = { { id = "batterycell", count = 1 } } },
        { id = "pirateclothes", count = 1 },
        { id = "scp_renegadedivingsuit", count = 1, subItems = { { id = "oxygenitetank", count = 1 } } },
        { id = "crowbar", count = 1 } -- Add crowbar as a normal item
    }
}
