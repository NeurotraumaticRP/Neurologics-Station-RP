if CLIENT and Game.IsMultiplayer then return end

function Log(msg)
    if msg then
        Game.Log("Dr. Javier's Surgical Bomb // ".. msg, 9)
    end
end

function ParseCommand(text)
    local result = {}

    if text == nil then return result end

    local spat, epat, buf, quoted = [=[^(["])]=], [=[(["])$]=]
    for str in text:gmatch("%S+") do
        local squoted = str:match(spat)
        local equoted = str:match(epat)
        local escaped = str:match([=[(\*)["]$]=])
        if squoted and not quoted and not equoted then
            buf, quoted = str, squoted
        elseif buf and equoted == quoted and #escaped % 2 == 0 then
            str, buf, quoted = buf .. ' ' .. str, nil, nil
        elseif buf then
            buf = buf .. ' ' .. str
        end
        if not buf then result[#result + 1] = str:gsub(spat,""):gsub(epat,"") end
    end

    return result
end

local Commands = {}

function AddCommand(commandName, callback)
    if type(commandName) == "table" then
        for command in commandName do
            AddCommand(command, callback)
        end
    else
        local cmd = {}

        Commands[string.lower(commandName)] = cmd
        cmd.Callback = callback;
    end
end

Hook.Add("chatMessage", "Javier.ChatMessage", function(message, client)
    local split = ParseCommand(message)

    if #split == 0 then return end

    local command = string.lower(table.remove(split, 1))

    if Commands[command] then
        Log(client.Name .. " used command: " .. message)
        return Commands[command].Callback(client, split)
    end
end)

function SendChatMessage(client, text, color, popup, header)
    if not client or not text or text == "" then
        return
    end

    text = tostring(text)

    local chatMessage = ChatMessage.Create(header, text, ChatMessageType.Default)
    if color then
        chatMessage.Color = color
    end

    Game.SendDirectChatMessage(chatMessage, client)
    if popup then
        local chatMessage2 = ChatMessage.Create("", text, ChatMessageType.MessageBox)

        if color then
            chatMessage2.Color = color
        end
        Game.SendDirectChatMessage(chatMessage2, client)
    end
end

function DetonateCharacter(character)
    local JavierUEX = character.CharacterHealth.GetAffliction("internalbomb", true)
    local JavierC4 = character.CharacterHealth.GetAffliction("internalc4", true)
    local JavierDirtyBomb = character.CharacterHealth.GetAffliction("internaldirtybomb", true)
    local JavierIC4 = character.CharacterHealth.GetAffliction("internalincendc4", true)
    local JavierCompoundN = character.CharacterHealth.GetAffliction("internalcompoundn", true)
    local JavierWarhead = character.CharacterHealth.GetAffliction("internalwarhead", true)
    local explosionPrefab = ItemPrefab.GetItemPrefab("wrench")
    local particlePrefab = ItemPrefab.GetItemPrefab("surgeryexplosion")
    local leftArm = AfflictionPrefab.Prefabs["gate_ta_la"].Instantiate(1)
    local rightArm = AfflictionPrefab.Prefabs["gate_ta_ra"].Instantiate(1)
    local head = AfflictionPrefab.Prefabs["gate_ta_h"].Instantiate(1)
    local leftLeg = AfflictionPrefab.Prefabs["gate_ta_ll_2"].Instantiate(1)
    local rightLeg = AfflictionPrefab.Prefabs["gate_ta_rl_2"].Instantiate(1)
    
    if JavierUEX and JavierUEX.Strength > 0 then
       JavierUEX.SetStrength(0)
       explosionPrefab = ItemPrefab.GetItemPrefab("uex")
    elseif JavierC4 and JavierC4.Strength > 0 then
        JavierC4.SetStrength(0)
        explosionPrefab = ItemPrefab.GetItemPrefab("c4block")
    elseif JavierDirtyBomb and JavierDirtyBomb.Strength > 0 then
        JavierDirtyBomb.SetStrength(0)
        explosionPrefab = ItemPrefab.GetItemPrefab("dirtybomb")
    elseif JavierIC4 and JavierIC4.Strength > 0 then
        JavierIC4.SetStrength(0)
        explosionPrefab = ItemPrefab.GetItemPrefab("ic4block")
    elseif JavierCompoundN and JavierCompoundN.Strength > 0 then
        JavierCompoundN.SetStrength(0)
        explosionPrefab = ItemPrefab.GetItemPrefab("compoundn")
    elseif JavierWarhead and JavierWarhead.Strength > 0 then
        JavierWarhead.SetStrength(0)
        explosionPrefab = ItemPrefab.GetItemPrefab("javier_thermonuclearblast")
    end

    if explosionPrefab == ItemPrefab.GetItemPrefab("wrench") then
        return false
    end

    Entity.Spawner.AddItemToSpawnQueue(explosionPrefab, character.WorldPosition, 0, 1, function(item)
        item.Use(0)
        character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, leftArm)
        character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, rightArm)
        character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, leftLeg)
        character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, rightLeg)

        Timer.Wait(function ()
            character.CharacterHealth.ApplyAffliction(character.AnimController.MainLimb, head)
            Entity.Spawner.AddItemToSpawnQueue(particlePrefab, character.Inventory, 0, 0)
            Game.Explode(character.WorldPosition, 1, 50, 0, 0, 0, 0, 0)
            
            -- Fire hook when surgical bomb detonates a character
            Hook.Call("Javier.CharacterDetonated", character)
        end, 200)

        return true
    end)
end

NT.ItemMethods.surgerybomb = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)
    -- don't work if they have a bomb
    if HF.HasAffliction(targetCharacter,"internalbomb",0.1)
       or (HF.HasAffliction(targetCharacter,"internalc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internaldirtybomb",0.1))
       or (HF.HasAffliction(targetCharacter,"internalincendc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internalcompoundn",0.1))
       or (HF.HasAffliction(targetCharacter,"internalwarhead",0.1))
    then return end

    if HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,99)
        and not HF.HasAfflictionLimb(targetCharacter,"internalbomb",limbtype,1)
    then
        HF.AddAfflictionLimb(targetCharacter,"internalbomb",limbtype,100,usingCharacter)
        item.Drop()
        Entity.Spawner.AddItemToRemoveQueue(item)
        Log(usingCharacter.Name.. " has put a bomb inside of ".. targetCharacter.Name)
    end
end

NT.ItemMethods.surgerydirtybomb = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)
    -- don't work if they have a bomb
    if HF.HasAffliction(targetCharacter,"internalbomb",0.1)
       or (HF.HasAffliction(targetCharacter,"internalc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internaldirtybomb",0.1))
       or (HF.HasAffliction(targetCharacter,"internalincendc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internalcompoundn",0.1))
       or (HF.HasAffliction(targetCharacter,"internalwarhead",0.1))
    then return end

    if HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,99)
        and not HF.HasAfflictionLimb(targetCharacter,"internaldirtybomb",limbtype,1)
    then
        HF.AddAfflictionLimb(targetCharacter,"internaldirtybomb",limbtype,100,usingCharacter)
        item.Drop()
        Entity.Spawner.AddItemToRemoveQueue(item)
        Log(usingCharacter.Name.. " has put a bomb inside of ".. targetCharacter.Name)
    end
end

NT.ItemMethods.surgeryC4Block = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)
    -- don't work if they have a bomb
    if HF.HasAffliction(targetCharacter,"internalbomb",0.1)
       or (HF.HasAffliction(targetCharacter,"internalc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internaldirtybomb",0.1))
       or (HF.HasAffliction(targetCharacter,"internalincendc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internalcompoundn",0.1))
       or (HF.HasAffliction(targetCharacter,"internalwarhead",0.1))
    then return end

    if HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,99)
        and not HF.HasAfflictionLimb(targetCharacter,"internalc4",limbtype,1)
    then
        HF.AddAfflictionLimb(targetCharacter,"internalc4",limbtype,100,usingCharacter)
        item.Drop()
        Entity.Spawner.AddItemToRemoveQueue(item)
        Log(usingCharacter.Name.. " has put a bomb inside of ".. targetCharacter.Name)
    end
end

NT.ItemMethods.surgeryIC4Block = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)
    -- don't work if they have a bomb
    if HF.HasAffliction(targetCharacter,"internalbomb",0.1)
       or (HF.HasAffliction(targetCharacter,"internalc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internaldirtybomb",0.1))
       or (HF.HasAffliction(targetCharacter,"internalincendc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internalcompoundn",0.1))
       or (HF.HasAffliction(targetCharacter,"internalwarhead",0.1))
    then return end

    if HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,99)
        and not HF.HasAfflictionLimb(targetCharacter,"internalincendc4",limbtype,1)
    then
        HF.AddAfflictionLimb(targetCharacter,"internalincendc4",limbtype,100,usingCharacter)
        item.Drop()
        Entity.Spawner.AddItemToRemoveQueue(item)
        Log(usingCharacter.Name.. " has put a bomb inside of ".. targetCharacter.Name)
    end
end

NT.ItemMethods.surgerycompoundn = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)
    -- don't work if they have a bomb
    if HF.HasAffliction(targetCharacter,"internalbomb",0.1)
       or (HF.HasAffliction(targetCharacter,"internalc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internaldirtybomb",0.1))
       or (HF.HasAffliction(targetCharacter,"internalincendc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internalcompoundn",0.1))
       or (HF.HasAffliction(targetCharacter,"internalwarhead",0.1))
    then return end

    if HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,99)
        and not HF.HasAfflictionLimb(targetCharacter,"internalcompoundn",limbtype,1)
    then
        HF.AddAfflictionLimb(targetCharacter,"internalcompoundn",limbtype,100,usingCharacter)
        item.Drop()
        Entity.Spawner.AddItemToRemoveQueue(item)
        Log(usingCharacter.Name.. " has put a bomb inside of ".. targetCharacter.Name)
    end
end

NT.ItemMethods.javierwarhead = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)
    -- don't work if they have a bomb
    if HF.HasAffliction(targetCharacter,"internalbomb",0.1)
       or (HF.HasAffliction(targetCharacter,"internalc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internaldirtybomb",0.1))
       or (HF.HasAffliction(targetCharacter,"internalincendc4",0.1))
       or (HF.HasAffliction(targetCharacter,"internalcompoundn",0.1))
       or (HF.HasAffliction(targetCharacter,"internalwarhead",0.1))
    then return end

    if HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,99)
        and not HF.HasAfflictionLimb(targetCharacter,"internalwarhead",limbtype,1)
    then
        HF.AddAfflictionLimb(targetCharacter,"internalwarhead",limbtype,100,usingCharacter)
        item.Drop()
        Entity.Spawner.AddItemToRemoveQueue(item)
        Log(usingCharacter.Name.. " has put a bomb inside of ".. targetCharacter.Name)
    end
end

NT.ItemMethods.Javier_Pliers = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)
    local item = "wrench"
    local affname = "sans"
    -- don't work if stasis
    if(HF.HasAffliction(targetCharacter,"stasis",0.1)) then return end

    if HF.CanPerformSurgeryOn(targetCharacter) and HF.HasAfflictionLimb(targetCharacter,"retractedskin",limbtype,99) then
        if HF.HasAfflictionLimb(targetCharacter,"internalbomb",limbtype,50) then
            item = "surgerybomb"
            affname = "internalbomb"
        elseif HF.HasAfflictionLimb(targetCharacter,"internalc4",limbtype,50) then
            item = "surgeryC4Block"
            affname = "internalc4"
        elseif HF.HasAfflictionLimb(targetCharacter,"internaldirtybomb",limbtype,50) then
            item = "surgerydirtybomb"
            affname = "internaldirtybomb"
        elseif HF.HasAfflictionLimb(targetCharacter,"internalincendc4",limbtype,50) then
            item = "surgeryIC4Block"
            affname = "internalincendc4"
        elseif HF.HasAfflictionLimb(targetCharacter,"internalcompoundn",limbtype,50) then
            item = "surgerycompoundn"
            affname = "internalcompoundn"
        elseif HF.HasAfflictionLimb(targetCharacter,"internalwarhead",limbtype,50) then
            item = "javierwarhead"
            affname = "internalwarhead"
        end

        if item ~= "wrench" then
            HF.SetAfflictionLimb(targetCharacter,affname,limbtype,0,usingCharacter)
            HF.GiveItem(usingCharacter,item)
        end
    end
end

NT.ItemMethods.husk_praziquantel = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = HF.NormalizeLimbType(limb.type)

    if HF.HasAffliction(targetCharacter,"tb_Tuberculosis",10) and not HF.HasAffliction(targetCharacter,"tb_Tuberculosis",175) then
        HF.SetAffliction(targetCharacter,"tb_Tuberculosis",5,usingCharacter)
    end
end

function FindCharacter(name)
    for key, value in pairs(Character.CharacterList) do
        if value.Name == name and value.IsHuman then
            return value
        end
    end
end

AddCommand({"!detonate", "!explode"}, function (client, args)
    local character = nil
    local name = "unknown"

    if client.Character == nil or not client.Character.IsHuman or client.Character.IsDead then
        SendChatMessage(client, "Your character is dead, non-existent, or non-human!", Color.Red, false, "ERROR")
        return true
    elseif client.Character then
        if not client.Character.Inventory.FindItemByIdentifier("internalbombdetonator", true) then
            SendChatMessage(client, "You do not have a surgical detonator.", Color.Red, false, "ERROR")
            return true
        end
    end
    --can't press the detonator if you're asleep
    if client.Character.IsUnconscious
        or client.Character.IsRagdolled
        or HF.HasAffliction(client.Character,"sym_unconsciousness",0.1)
        or HF.HasAffliction(client.Character,"givein",0.1)
        or HF.HasAffliction(client.Character,"anesthesia",15)
        or HF.HasAffliction(client.Character,"paralysis",99)
    then
        SendChatMessage(client, "You're unconscious!", Color.Red, false, "ERROR")
        return true
    end
    --can't press the detonator if you have no arms
    if HF.HasAffliction(client.Character,"tra_amputation",0.1) and HF.HasAffliction(client.Character,"tla_amputation",0.1) then
        SendChatMessage(client, "You don't have any arms!", Color.Red, false, "ERROR")
        return true
    elseif HF.HasAffliction(client.Character,"sra_amputation",0.1) and HF.HasAffliction(client.Character,"sla_amputation",0.1) then
        SendChatMessage(client, "You don't have any arms!", Color.Red, false, "ERROR")
        return true
    elseif HF.HasAffliction(client.Character,"ra_fracture",0.1) and HF.HasAffliction(client.Character,"la_fracture",0.1) then
        SendChatMessage(client, "Your arms are broken!", Color.Red, false, "ERROR")
        return true
    elseif client.Character.LockHands then
        SendChatMessage(client, "You're handcuffed!", Color.Red, false, "ERROR")
        return true
    end

    if #args ~= 1 then
        name = client.Character.Name
        character = client.Character
    else
        name = table.remove(args, 1)
        character = FindCharacter(name)
    end

    if character ~= nil then
        if HF.HasAffliction(character,"internalbomb",0.1) 
            or HF.HasAffliction(character,"internalc4",0.1)
            or HF.HasAffliction(character,"internaldirtybomb",0.1)
            or HF.HasAffliction(character,"internalincendc4",0.1)
            or HF.HasAffliction(character,"internalcompoundn",0.1)
            or HF.HasAffliction(character,"internalwarhead",0.1)
        then
            DetonateCharacter(character)
            SendChatMessage(client, "Successfully detonated the bomb inside of " ..character.Name.. ".", Color.LightSteelBlue, false, "")
            Log(client.Name.." successfully detonated "..character.Name.. ".")
        else
            SendChatMessage(client, character.Name.. " doesn't have a bomb in them.", Color.LightSteelBlue, false, "")
            Log(client.Name.." failed to detonate "..character.Name.. ".")
        end
    else
        SendChatMessage(client, "Could not find character " ..name.. ".", Color.Red, false, "ERROR")
        Log(client.Name.." failed to detonate a non-existent character, "..name.. ".")
    end

    return true
end)

AddCommand({"!test", "!sans"}, function (client, args)
    SendChatMessage(client, "fuck you", Color.AliceBlue, true, "Sans the Skeleton")

    return true
end)

Hook.Add("Javier.DetonateAll", "Javier.DetonateAll", function ()
    for key, value in pairs(Character.CharacterList) do
        if value.IsHuman then
            DetonateCharacter(value)
        end
    end
end)

TB = {}

TB.UpdateCooldown = 0
TB.UpdateInterval = 120
TB.Deltatime = TB.UpdateInterval/60 -- Time in seconds that transpires between updates

if NTC == nil then
    print("Tuberculosis requires neurotrauma to function.")
    return
end

Hook.Add("think", "Tuberculosis.update", function()
    if HF.GameIsPaused() then return end

    TB.UpdateCooldown = TB.UpdateCooldown-1
    if (TB.UpdateCooldown <= 0) then
        TB.UpdateCooldown = TB.UpdateInterval
        TB.Update()
    end
end)

TB.Update = function ()
    for key, human in pairs(Character.CharacterList) do
        if human.IsHuman and not human.IsDead then
            local strength = HF.GetAfflictionStrength(human, "tb_Tuberculosis")
            local lungStrength = HF.GetAfflictionStrength(human, "lungremoved")

            if strength < 20 and strength > 5 then
                NTC.SetSymptomTrue(human,"sym_cough",2)
            elseif strength > 20 and strength < 45 then
                NTC.SetSymptomTrue(human,"sym_cough",2)
                NTC.SetSymptomTrue(human,"dyspnea",2)
            elseif strength > 45 and strength < 75 then
                NTC.SetSymptomTrue(human,"sym_cough",2)
                NTC.SetSymptomTrue(human,"pain_chest",2)
                NTC.SetSymptomTrue(human,"dyspnea",2)
            elseif strength > 75 and strength < 100 then
                NTC.SetSymptomTrue(human,"sym_cough",2)
                NTC.SetSymptomTrue(human,"pain_chest",2)
                NTC.SetSymptomTrue(human,"dyspnea",2)
                NTC.SetSymptomTrue(human,"sym_weakness",2)
                NTC.SetSymptomTrue(human,"fever",2)
            elseif strength > 100 and strength < 185 then
                NTC.SetSymptomFalse(human,"sym_cough",2)
                NTC.SetSymptomTrue(human,"pain_chest",2)
                NTC.SetSymptomTrue(human,"dyspnea",2)
                NTC.SetSymptomTrue(human,"sym_weakness",2)
                NTC.SetSymptomTrue(human,"fever",2)
            elseif strength > 185 then
                NTC.SetSymptomFalse(human,"sym_cough",2)
                NTC.SetSymptomTrue(human,"pain_chest",2)
                NTC.SetSymptomTrue(human,"dyspnea",2)
                NTC.SetSymptomTrue(human,"sym_weakness",2)
                NTC.SetSymptomTrue(human,"fever",2)
            end

            if HF.HasAffliction(human,"artificialbrain") then
                NTC.SetSymptomTrue(human,"sym_unconsciousness")
            end

            if strength > 1 and lungStrength > 1 then
                HF.SetAffliction(human, "tb_Tuberculosis", 0)
            end
        end
    end
end

Hook.Add("character.giveJobItems", "IsleUntoThyself", function(character, waypoint)
    if not character.HasTalents() then
        --character.GiveTalent("he-hungryeuropanBETTER", true)
    end
end)

local experimentalEffects = {
    -- resistances and buffs
    vigor={weight=3,afflictions={{identifier="strengthen",minstrength=200,maxstrength=400,limbspecific=false}}},
    haste={weight=3,afflictions={{identifier="haste",minstrength=200,maxstrength=400,limbspecific=false}}},
    psychosisresistance={weight=2,afflictions={{identifier="psychosisresistance",minstrength=200,maxstrength=400,limbspecific=false}}},
    huskinfectionresistance={weight=2,afflictions={{identifier="huskinfectionresistance",minstrength=200,maxstrength=400,limbspecific=false}}},
    paralysisresistance={weight=2,afflictions={{identifier="paralysisresistance",minstrength=300,maxstrength=600,limbspecific=false}}},
    analgesia={weight=1,afflictions={{identifier="analgesia",minstrength=20,maxstrength=100,limbspecific=false}}},
    anesthesia={weight=0.5,afflictions={{identifier="anesthesia",minstrength=1,maxstrength=100,limbspecific=false}}},
    ointmented={weight=1,afflictions={{identifier="ointmented",minstrength=20,maxstrength=100,limbspecific=true}}},
    combatstimulant={weight=2,afflictions={{identifier="combatstimulant",minstrength=30,maxstrength=100,limbspecific=false}}},
    pressurestabilized={weight=1,afflictions={{identifier="pressurestabilized",minstrength=30,maxstrength=100,limbspecific=false}}},
    -- other positive
    fullheal={weight=5,afflictions={
        {identifier="bleeding",minstrength=-20,maxstrength=-100,limbspecific=true},
        {identifier="burn",minstrength=-20,maxstrength=-100,limbspecific=true},
        {identifier="explosiondamage",minstrength=-20,maxstrength=-100,limbspecific=true},
        {identifier="gunshotwound",minstrength=-20,maxstrength=-100,limbspecific=true},
        {identifier="bitewounds",minstrength=-20,maxstrength=-100,limbspecific=true},
        {identifier="lacerations",minstrength=-20,maxstrength=-100,limbspecific=true},
        {identifier="organdamage",minstrength=-20,maxstrength=-100,limbspecific=false},
        {identifier="cerebralhypoxia",minstrength=-20,maxstrength=-100,limbspecific=false},
        {identifier="bloodloss",minstrength=-20,maxstrength=-100,limbspecific=false},
        {identifier="blunttrauma",minstrength=-20,maxstrength=-100,limbspecific=true},
        {identifier="sepsis",minstrength=-200,maxstrength=-200,limbspecific=false},
    }},
    -- damage
    bleeding=       {weight=1,afflictions={{identifier="bleeding",minstrength=30,maxstrength=80,limbspecific=true}}},
    burn=           {weight=1,afflictions={{identifier="burn",minstrength=5,maxstrength=20,limbspecific=true}}},
    explosiondamage={weight=1,afflictions={{identifier="explosiondamage",minstrength=5,maxstrength=20,limbspecific=true}}},
    gunshotwound=   {weight=1,afflictions={{identifier="gunshotwound",minstrength=5,maxstrength=20,limbspecific=true}}},
    bitewounds=     {weight=1,afflictions={{identifier="bitewounds",minstrength=5,maxstrength=20,limbspecific=true}}},
    lacerations=    {weight=1,afflictions={{identifier="lacerations",minstrength=5,maxstrength=20,limbspecific=true}}},
    organdamage=    {weight=1,afflictions={{identifier="organdamage",minstrength=5,maxstrength=20,limbspecific=false}}},
    blunttrauma=    {weight=1,afflictions={{identifier="blunttrauma",minstrength=5,maxstrength=20,limbspecific=true}}},
    -- other negative
    stun={weight=1,afflictions={{identifier="stun",minstrength=2,maxstrength=15,limbspecific=false}}},
    
}

Timer.Wait(function()

NT.ItemMethods.artificialbrain = function(item, usingCharacter, targetCharacter, limb) 
    local limbtype = limb.type
    if(HF.HasAffliction(targetCharacter,"brainremoved",1) and limbtype == LimbType.Head) then
        HF.SetAffliction(targetCharacter,"cerebralhypoxia",0,usingCharacter)
        HF.SetAffliction(targetCharacter,"brainremoved",0,usingCharacter)
        HF.SetAffliction(targetCharacter,"artificialbrain",100,usingCharacter)
        
        HF.RemoveItem(item)
    end
end

NT.ItemMethods.experimentaltreatment = function(item, usingCharacter, targetCharacter, limb)
    local limbtype = limb.type

    -- endocrine booster
    if HF.Chance(1/25) then
        HF.ApplyEndocrineBoost(targetCharacter)
    end

    local weightsum = 0
    for key,val in pairs(experimentalEffects) do weightsum = weightsum + val.weight end
    
    local triggerNewEffect = true
    while triggerNewEffect do
        triggerNewEffect = HF.Chance(0.5)

        local weightpick = math.random()*weightsum
        local currentweightsum = 0
    
        for key,val in pairs(experimentalEffects) do
            currentweightsum = currentweightsum + val.weight
            if currentweightsum > weightpick then
                -- picked effect: val

                for aff in val.afflictions do
                    if aff.limbspecific then
                        HF.AddAfflictionLimb(targetCharacter,aff.identifier,limbtype,HF.Lerp(aff.minstrength,aff.maxstrength,math.random()),usingCharacter)
                    else
                        HF.AddAffliction(targetCharacter,aff.identifier,HF.Lerp(aff.minstrength,aff.maxstrength,math.random()),usingCharacter)
                    end
                end
    
                break
            end
        end
    end
    
    
    HF.RemoveItem(item)
    HF.GiveItem(targetCharacter,"ntsfx_syringe")
end

end,1)

-- Disable Give In Button
local ignoreKill = false
Hook.Patch("Barotrauma.Character", "ServerEventRead", function()
    ignoreKill = true
 end, Hook.HookMethodType.Before)
 
 Hook.Patch("Barotrauma.Character", "ServerEventRead", function()
    ignoreKill = false
 end, Hook.HookMethodType.After)

 Hook.Patch("Barotrauma.Character", "Kill", function(instance, ptable)
    if ignoreKill then
        ptable.PreventExecution = true
    end
 end, Hook.HookMethodType.Before)