-- Prevents players from giving in when downed
local ignoreKill = false
Hook.Patch("Barotrauma.Character", "ServerEventRead", function()
    ignoreKill = true
end, Hook.HookMethodType.Before)

Hook.Patch("Barotrauma.Character", "ServerEventRead", function()
    ignoreKill = false
end, Hook.HookMethodType.After)

Hook.Patch("Barotrauma.Character", "Kill", function(character, ptable)
    if ignoreKill then
        ptable.PreventExecution = true

        local client = HF.CharacterToClient(character)
        if client then
            HF.SetAffliction(character, "coma", 100)
            client.SetClientCharacter(nil)
            local chatmessage = ChatMessage.Create("", "You have left your body. You will not be able to return to your body. Your chat messages will only be visible to other dead players.", ChatMessageType.Dead)
            Game.SendDirectChatMessage(chatmessage, client)
        end
    end
end, Hook.HookMethodType.Before)

-- Stops players from stasis bagging other players, to apply a stasis bag on someone, they must be unconscious
Hook.Add("inventoryPutItem", "Stasisbagpatcher", function(inventory, item, character, index, removeItemBool)
    if not inventory or not item or not character or not index then return false end
    if tostring(inventory.Owner) == "Human" and item.Prefab.Identifier.Value == "stasisbag" and index == 4 then
        local target = inventory.Owner
        if character == target then return false end
        if target.IsDead then return false end
        if HF.HasAffliction(target, "sym_unconsciousness", 0.1) or HF.HasAffliction(target, "anesthesia", 0.1) or HF.HasAffliction(target, "coma", 0.1) then
            return false
        end
        return true
    end
end)

Hook.Add("roundstart", "HungryEuropan", function()
    Neurologics.GiveHungryEuropan()
end)

Hook.Patch("Barotrauma.Items.Components.Terminal", "ServerEventRead", function(instance, ptable) -- Captain PA system
    local msg = ptable["msg"]
    local client = ptable["c"]
    if client == nil or msg == nil then
        return nil
    end
    
    local rewindBit = msg.BitPosition
    local text = msg.ReadString()
    msg.BitPosition = rewindBit

    local item = instance.Item
    local terminal = item.GetComponentString("Terminal")

    if item.HasTag("captainpa") then
        local id = client.Character.Inventory.GetItemInLimbSlot(InvSlotType.Card)
        
        -- Check if player has captain ID
        if id and id.HasTag("cpt") then
            local paText = "Captains PA: << " .. text .. " >>"
            Neurologics.RoundEvents.SendEventMessage(paText, nil, Color.Aqua)
            return nil
        end
        
        -- No captain ID - show error message in terminal
        if terminal then
            terminal.messageHistory.Clear()
            terminal.SyncHistory()
            terminal.ShowMessage = ">> You are not a captain! You cannot use the captain's PA."
            terminal.SyncHistory()
        end
    end

    return nil
end, Hook.HookMethodType.Before)

