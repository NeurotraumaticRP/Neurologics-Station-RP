local extension = {}

extension.Identifier = "weaponnerfs"

extension.Init = function ()
    do -- Ceremonial Sword
        local replacement = [[
        <overwrite>
            <Attack targetimpulse="2" severlimbsprobability="0.55" itemdamage="10" structuredamage="1" structuresoundtype="StructureSlash">
                <Affliction identifier="lacerations" strength="5" />
                <Affliction identifier="bleeding" strength="25" />
                <Affliction identifier="stun" strength="0.01" />
            </Attack>
        </overwrite>
        ]]

        local itemPrefab = ItemPrefab.GetItemPrefab("ceremonialsword")
        local element = itemPrefab.ConfigElement.Element.Element("MeleeWeapon")
        Neurologics.Patching.RemoveAll(element, "Attack")
        Neurologics.Patching.Add(element, replacement)
    end

    do -- Hardened Crowbar
        local replacement = [[
        <overwrite>
            <Attack targetimpulse="13" penetration="0.25">
                <Affliction identifier="blunttrauma" strength="14" />
                <Affliction identifier="radiationsickness" strength="5" />
                <Affliction identifier="stun" strength="0.1" />
            </Attack>
        </overwrite>
        ]]

        local itemPrefab = ItemPrefab.GetItemPrefab("crowbarhardened")
        local element = itemPrefab.ConfigElement.Element.Element("MeleeWeapon")
        Neurologics.Patching.RemoveAll(element, "Attack")
        Neurologics.Patching.Add(element, replacement)
    end

    do -- Truncheon
        local replacement = [[
        <overwrite>
            <Attack structuredamage="2" itemdamage="2" targetimpulse="16">
                <Affliction identifier="blunttrauma" strength="5" />
                <Affliction identifier="stun" strength="1" />
                <StatusEffect type="OnUse" target="UseTarget">
                <Sound file="Content/Items/Weapons/Smack1.ogg" selectionmode="random" range="500" />
                <Sound file="Content/Items/Weapons/Smack2.ogg" range="500" />
                </StatusEffect>
            </Attack>
        </overwrite>
        ]]

        local itemPrefab = ItemPrefab.GetItemPrefab("thgtruncheon")
        local element = itemPrefab.ConfigElement.Element.Element("MeleeWeapon")
        Neurologics.Patching.RemoveAll(element, "Attack")
        Neurologics.Patching.Add(element, replacement)
    end

    do -- Pickaxe
        local replacement = [[
        <overwrite>
            <Fabricate suitablefabricators="fabricator" requiredtime="9999">
                <RequiredSkill identifier="mechanical" level="100" />
                <RequiredItem identifier="plastic" amount="3" />
                <RequiredItem identifier="steel" amount="3" />
            </Fabricate>
        </overwrite>
        ]]

        local itemPrefab = ItemPrefab.GetItemPrefab("pickaxe")
        local element = itemPrefab.ConfigElement.Element.Element("Fabricate")
        Neurologics.Patching.RemoveAll(element, "Fabricate")
        Neurologics.Patching.Add(element, replacement)
    end
end


return extension