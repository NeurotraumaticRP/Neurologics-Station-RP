local category = {}

category.Identifier = "scientist"

local randomItems = {}
for prefab in ItemPrefab.Prefabs do
    if prefab.CanBeSold or prefab.CanBeBought then
        table.insert(randomItems, prefab)
    end
end

category.CanAccess = function(client)
    return client.Character and not client.Character.IsDead and client.Character.HasJob("scientist")
end

category.Products = {

    {
        Price = 350,
        Limit = 1,
        IsLimitGlobal = false,
        Items = {"genesplicer"}
    },
    {
        Price = 750,
        Limit = 1,
        IsLimitGlobal = false,
        Items = {"advancedgenesplicer"}
    },
    {
        Identifier = "geneticmaterials",
        Price = 100,
        Limit = 3,
        IsLimitGlobal = false,
        Items = {"geneticmaterial_unresearched", "geneticmaterial_unresearched", "geneticmaterial_unresearched"},
    },
    {
        Identifier = "stabilozine",
        Price = 100,
        Limit = 3,
        IsLimitGlobal = false,
        Items = {"stabilozine", "stabilozine", "stabilozine", "stabilozine", "stabilozine"},
    },
    {
        Price = 200,
        Limit = 5,
        IsLimitGlobal = false,
        Items = {"athleticsbooster"},
    },
    {
        Price = 200,
        Limit = 5,
        IsLimitGlobal = false,
        Items = {"healthbooster"},
    },
    {
        Price = 200,
        Limit = 5,
        IsLimitGlobal = false,
        Items = {"intelligencebooster"},
    },
    {
        Price = 200,
        Limit = 5,
        IsLimitGlobal = false,
        Items = {"strengthbooster"},
    },
    {
        Price = 500,
        Limit = 5,
        IsLimitGlobal = false,
        Items = {"endocrinebooster"},
    },
    {
        Price = 1000,
        Limit = 1,
        IsLimitGlobal = false,
        Items = {"alienrestorationrifle", "alienpowercell", "alienpowercell"},
    }
}

return category