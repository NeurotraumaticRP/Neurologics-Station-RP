local category = {}

category.Identifier = "maintenance"
category.CanAccess = function(client)
    if not client.Character then return false end
    return client.Character and not client.Character.IsDead and client.Character.HasJob("crewmember") or client.Character.HasJob("staff")
end

category.Products = {
    {
        Price = 90,
        Limit = 1,
        Items = {"screwdriver"}
    },

    {
        Price = 90,
        Limit = 1,
        Items = {"wrench"}
    },

    {
        Price = 160,
        Limit = 4,
        Items = {"weldingtool", "weldingfueltank"}
    },

    {
        Price = 250,
        Limit = 2,
        Items = {"handheldstatusmonitor"}
    },

    {
        Price = 190,
        Limit = 4,
        Items = {"fixfoamgrenade", "fixfoamgrenade"}
    },

    {
        Price = 140,
        Limit = 4,
        Items = {"repairpack", "repairpack", "repairpack", "repairpack"}
    },

    {
        Identifier = "fuelrodlowquality",
        Price = 260,
        Limit = 10,

        Items = {{Identifier = "fuelrod", Condition = 9}},
    },
}

return category