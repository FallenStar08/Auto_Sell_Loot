JUNKTABLE = Ext.Require("Server/junk_table.lua")
Ext.Require("Server/_ModInfos.lua")
Ext.Require("Shared/_Globals.lua")
Ext.Require("Shared/_Utils.lua")
Ext.Require("Server/_Config.lua")
-- -------------------------------------------------------------------------- --
--                                   GLOBALS                                  --
-- -------------------------------------------------------------------------- --
Bags = {}
SELL_VALUE_COUNTER = 0
FRACTIONAL_PART = 0
SEll_LIST_EDIT_MODE = false
-- -------------------------------------------------------------------------- --
--                                General Stuff                               --
-- -------------------------------------------------------------------------- --
--This shitty prefix is actually called... "name", yeah.
function GetItemName(item)
    return string.sub(item, 1, -38)
end

--TODO uncringe this debug message
function DeleteItem(Character, Item, Amount)
    Osi.RequestDelete(Item)
    BasicDebug("DeleteItem() - function called on Character : " ..
        Character .. " for : " .. Amount .. "units of item with UUID : " .. Item)
end

--Anti morbing measure, this ain't morbing time
function IsTransmogInvisible(ItemName, Item)
    if ItemName == "LOOT_GEN_Ring_A_Gem_A_Gold" then
        BasicDebug("IsTransmogInvisible() - " .. ItemName .. " UUID : " .. Item)
        BasicDebug("StatString : " .. Ext.Entity.Get(Item).Data.StatsId)
        if Ext.Entity.Get(Item).Data.StatsId == "ARM_Ring_A_Gem_A_Gold" then
            return false
        else
            BasicWarning("IsTransmogInvisible() - Ignoring invisible transmorbed item, this is not a ring!")
            return true
        end
    end
    return false
end

--Resolve our translated string
--TODO replace this cringe shit with Ext.Loca
function ResolveMessagesHandles()
    local Messages = {
        message_warning_config_start = Osi.ResolveTranslatedString("h995d430eg9629g40c8g9470g6f515582195b"),
        message_bag_sell_mode = Osi.ResolveTranslatedString("h70fb978cg63cbg44d2ga45eg89bcacb356c8"),
        message_user_list_only = Osi.ResolveTranslatedString("hfda8e6cag7e53g41e5gb1b5g4892dbc8a8ae"),
        message_save_specific_list = Osi.ResolveTranslatedString("h5172487eg9d0eg4c06g93e3g5badf1e9401c"),
        message_save_specific_list_already_exist = Osi.ResolveTranslatedString("hbc85062bg1b97g4150g9d31gacac9018d58b"),
        message_clear_sell_list = Osi.ResolveTranslatedString("hd5b72a24g4401g4986gae60g9db54155f4ca"),
        message_disable_mod = Osi.ResolveTranslatedString("he488aa70g5d71g4c0egaf5cg68ac3804b28d"),
        message_enable_mod = Osi.ResolveTranslatedString("hc28d17e2g37b5g4978gb1c6g56d048969ab8")
    }
    return Messages
end

--Update bag description with mod infos
function UpdateBagInfoScreenWithConfig()
    local useSaveSpecificSellList = PersistentVars.useSaveSpecificSellList and PersistentVars.useSaveSpecificSellList or
        "not enabled"
    local saveIdentifier = PersistentVars.saveIdentifier and PersistentVars.saveIdentifier or "not enabled"

    local handle = "he671bb1egab4fg4f2bg981egdd0b1e8585af"

    local bagSellModeOnly = tostring(Config.config_tbl.BAG_SELL_MODE_ONLY == 1)
    local userListOnly = tostring(Config.config_tbl.CUSTOM_LISTS_ONLY == 1)

    local content = string.format(
        "Mod settings:\n - Bag Sell Mode Only: %s\n - User List Only: %s\n - Save Specific List: %s\n - Save Identifier: %s",
        bagSellModeOnly,
        userListOnly,
        useSaveSpecificSellList,
        saveIdentifier
    )

    BasicDebug("UpdateBagInfoScreenWithConfig() - content: " .. content, TEXT_COLORS.magenta)
    UpdateTranslatedString(handle, content)
end

-- -------------------------------------------------------------------------- --
--                                Bags function & related Events              --
-- -------------------------------------------------------------------------- --
-- Listener for bag iteration, may just be our generic EntityEvent listener if needed for more later
Ext.Osiris.RegisterListener("EntityEvent", 2, "after", function(guid, id)
    -- -------------------------- Bags.AddContentToList ------------------------- --
    if id == "AS_bagItems_OnItem" then
        local itemName = GetItemName(guid)
        if not StringEmpty(itemName) then
            local template = Osi.GetTemplate(guid)
            REMOVER_BAG_CONTENT_LIST[itemName] = GUID(template)
        end
    elseif id == "AS_bagItems_Done" then
        -- Do this in a function, or don't
        BasicDebug("EVENT - EntityEvent with id : " .. id .. " finished")
        -- Get the removed items
        local removedItems = Table.CompareSets(Config.selllist["SELLLIST"], REMOVER_BAG_CONTENT_LIST)
        -- Because people will obvsiously complain they can't add items to the list by having the bag open
        -- Anticipating next complain being the fact that it doesn't pay them this way
        -- Fuck that, not doing it... yet? :')
        local addedItems = Table.CompareSets(REMOVER_BAG_CONTENT_LIST, Config.selllist["SELLLIST"])
        BasicDebug("EVENT - EntityEvent Removed Items after bag closing :")
        BasicDebug(removedItems)
        BasicDebug("EVENT - EntityEvent Added Items after bag closing :")
        BasicDebug(addedItems)
        -- Disable/Enable them in the current session
        for name, uid in pairs(removedItems) do JUNKTABLESET[name] = nil end
        for name, uid in pairs(addedItems) do JUNKTABLESET[name] = uid end
        -- Save to file
        Config.selllist["SELLLIST"] = REMOVER_BAG_CONTENT_LIST
        JSON.LuaTableToFile(Config.selllist, Config.GetSellPath())
        REMOVER_BAG_CONTENT_LIST = {}
        -- ------------------- Delete temporary items from the bag ------------------ --
        Osi.IterateInventory(SELL_ADD_BAG_ITEM, "AS_bagItems_OnItemDelete", "AS_bagItems_DeleteDone")
    end
    if id == "AS_bagItems_OnItemDelete" then
        -- ------------------- Delete temporary items from the bag ------------------ --
        DeleteItem("", guid, "some")
        --local exactItemAmount, totalAmount = Osi.GetStackAmount(guid)
        --Osi.TemplateRemoveFrom(string.sub(Osi.GetTemplate(guid), -36), SELL_ADD_BAG_ITEM, exactItemAmount)
    end
end)

-- Listen for item uses, in this case the opening of our bag counts as it being used
Ext.Osiris.RegisterListener("UseStarted", 2, "before", function(character, item)
    item = GUID(item)
    if not SELL_ADD_BAG_ITEM then Bags.FindBagItemFromTemplate() end
    if item == SELL_ADD_BAG_ITEM then
        SEll_LIST_EDIT_MODE = true
        BasicDebug(Config.selllist["SELLLIST"])
        Osi.ShowNotification(character, "AUTOSELL - EDIT MODE ON")
        Ext.OnNextTick(function()
            Bags.AddAllListItemToBag(Config.selllist["SELLLIST"], SELL_ADD_BAG_ITEM, character)
        end)
    end
end)

-- Listener for item uses stop, in this case the closing of our bag counts as it not being used anymore
Ext.Osiris.RegisterListener("UseFinished", 3, "after", function(character, item, sucess)
    item = GUID(item)
    if SEll_LIST_EDIT_MODE == true and item == SELL_ADD_BAG_ITEM then
        Osi.ShowNotification(character, "AUTOSELL - EDIT MODE OFF")
        Bags.AddContentToList(SELL_ADD_BAG_ITEM, character)
        SEll_LIST_EDIT_MODE = false
    end
end)

-- Fill an existing bag with items from a list
function Bags.AddAllListItemToBag(list, bagItem, character)
    for name, uid in pairs(list) do
        Osi.TemplateAddTo(uid, bagItem, 1, 0)
        BasicDebug("AddAllListItemToBag() - Added item with name : " ..
            name .. " and uid : " .. uid .. " to bag : " .. bagItem)
    end
end

function Bags.AddContentToList(bagItem, character)
    REMOVER_BAG_CONTENT_LIST = {}
    Osi.IterateInventory(bagItem, "AS_bagItems_OnItem", "AS_bagItems_Done")
end

-- Function to add a bag to a character if it isn't already in their inventory
-- or in another party member's inventory (to avoid duplicate bags)
function Bags.AddBag(bag, character, notification)
    if Config.config_tbl["GIVE_BAG"] >= 1 then
        for _, player in pairs(SQUADIES) do if Osi.TemplateIsInInventory(bag, player) >= 1 then return end end
        BasicDebug("Bags.AddBag() Bag : " .. bag .. " adding to character : " .. character)
        Osi.TemplateAddTo(bag, character, 1, notification)
    else
        BasicDebug("Bags.AddBag() - Bag disabled in config file")
    end
end

function Bags.AddToSellList(item_name, root)
    if Config.config_tbl["BAG_SELL_MODE_ONLY"] == 1 then return end
    if StringEmpty(item_name) then
        BasicDebug("AddToSellList() - BAD ITEM with root : " .. root)
        return
    end
    JUNKTABLESET[item_name] = root
    -- Save the added item to file for next load
    Config.selllist["SELLLIST"][item_name] = root
    JSON.LuaTableToFile(Config.selllist, Config.GetSellPath())
    BasicDebug("AddToSellList() - Added the following item to the sell list item name : " ..
        item_name .. " root : " .. root)
end

function Bags.FindBagItemFromTemplate()
    if SELL_ADD_BAG_ITEM == "" then
        BasicDebug("FindBagItemFromTemplate() - Trying to find BAG UUID...")
        for _, player in pairs(SQUADIES) do
            if Osi.TemplateIsInInventory(SELL_ADD_BAG_ROOT, player) >= 1 then
                SELL_ADD_BAG_ITEM = Osi.GetItemByTemplateInInventory(SELL_ADD_BAG_ROOT, player)
                BasicPrint("FindBagItemFromTemplate() Selling bag UUID found : " .. SELL_ADD_BAG_ITEM)
            end
        end
        return SELL_ADD_BAG_ITEM
    end
end

-- -------------------------------------------------------------------------- --
--                                   Selling                                  --
-- -------------------------------------------------------------------------- --

-- Function to handle the selling logic, accumulating decimal prices until they reach 1
-- Adding gold according to the sell value
-- Removing the "sold" items from the inventory
-- Cache gold value, easy optimization that probably is totally useless
local itemValueCache = {}
function HandleSelling(Owner, Character, Root, Item)
    -- exact is actually exact, total seems to see in the future and combine the next amounts or some shit I don't get it
    -- difference seems to be related to server ticks and when they get the amount
    local exactItemAmount, totalAmount = Osi.GetStackAmount(Item)
    exactItemAmount, totalAmount = exactItemAmount or 1, totalAmount or 1
    -- Check cache itemValue is the value of 1 item, even in a stack
    local itemValue = itemValueCache[Item]
    if not itemValue then
        -- Cache miss, get the value
        itemValue = Osi.ItemGetGoldValue(Item)
        BasicDebug({
            "HandleSelling() - before manipulation",
            "Item Value  : " .. itemValue,
            "exactItemAmount : " .. exactItemAmount,
            "totalAmount : " .. totalAmount })
        itemValue = itemValue / totalAmount
        itemValueCache[Item] = itemValue
    end
    itemValue = itemValue * exactItemAmount
    local sellValue = itemValue * SELL_VALUE_PERCENTAGE / 100
    -- Accumulate the sell values
    SELL_VALUE_COUNTER = SELL_VALUE_COUNTER + sellValue
    if SELL_VALUE_COUNTER >= 1 then
        local goldToAdd = Custom_floor(SELL_VALUE_COUNTER)    --Integer part
        FRACTIONAL_PART = FRACTIONAL_PART + (SELL_VALUE_COUNTER - goldToAdd)
        goldToAdd = goldToAdd + Custom_floor(FRACTIONAL_PART) -- Fractional part
        AddGoldTo(Owner, goldToAdd)
        BasicDebug("HandleSelling() - Adding " .. goldToAdd .. " Gold to Character")
        DeleteItem(Character, Item, exactItemAmount)
        SELL_VALUE_COUNTER = 0
        FRACTIONAL_PART = FRACTIONAL_PART - Custom_floor(FRACTIONAL_PART) -- Keep the remaining fractional part for later
        BasicDebug("HandleSelling() - Leftovers " .. FRACTIONAL_PART .. " Gold kept for later")
    else
        DeleteItem(Character, Item, exactItemAmount)
    end
end

-- -------------------------------------------------------------------------- --
--                            Core Logic Listeners                            --
-- -------------------------------------------------------------------------- --

-- Loading is done Update SQUADIES and create the JUNKTABLESET from the base junk list and our sell & keep list
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level, isEditorMode)
    Messages = ResolveMessagesHandles()
    if level == "SYS_CC_I" then return end
    if not Config.initDone then Config.Init() end
    if Config.GetValue(Config.config_tbl, "MOD_ENABLED") == 1 then
        SQUADIES = GetSquadies()
        -- Add the bag(s) to the host char if none found in party inventory
        Bags.AddBag(SELL_ADD_BAG_ROOT, Osi.GetHostCharacter(), 1)
        SELL_VALUE_PERCENTAGE = Config.GetValue(Config.config_tbl, "SELL_VALUE_PERCENTAGE")
        BasicDebug("SELL_VALUE_PERCENTAGE : " .. SELL_VALUE_PERCENTAGE)
        -- Create a set from JUNKTABLE with items from keeplist removed and those from selllist added
        BasicDebug(Config.keeplist)
        BasicDebug(Config.selllist)
        local keepList = Config.GetValue(Config.keeplist, "KEEPLIST")
        local sellList = Config.GetValue(Config.selllist, "SELLLIST")
        JUNKTABLESET = Table.ProcessTables(JUNKTABLE, keepList, sellList)
        Bags.FindBagItemFromTemplate()
        if Config.config_tbl.ENABLE_LOGGING == 1 then
            Files.FlushLogBuffer()
        end
        UpdateBagInfoScreenWithConfig()
    end
end)

-- Update SQUADIES for when a character joins the party
Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(Character)
    SQUADIES = GetSquadies()
end)

-- Update SQUADIES for when a character leaves the party
Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function(Character)
    SQUADIES = GetSquadies()
end)


-- Includes moving from container to other inventories etc...
Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "before", function(root, item, inventoryHolder, addType)
    if not Config.initDone or Config.GetValue(Config.config_tbl, "MOD_ENABLED") == 0 then
        return -- Ignore if initialization not done or mod is disabled
    end
    local function setZeroWeightAndValue(itemUUID)
        local entity = Ext.Entity.Get(itemUUID)
        if entity then
            local dataComp = entity:GetComponent("Data")
            local valueComp = entity:GetComponent("Value")
            if dataComp and valueComp then
                dataComp.Weight = 0
                valueComp.Value = 0
                entity:Replicate("Data")
                entity:Replicate("Value")
            end
        end
    end

    local rootName = GetItemName(root)
    root = GUID(root)
    inventoryHolder = GUID(inventoryHolder)

    if root == GOLD or root == SELL_ADD_BAG_ROOT then
        return -- Ignore gold & bag
    end

    local itemName = RemoveTrailingNumbers(GetItemName(item)) or "BAD MOD"

    --Sanity check
    Bags.FindBagItemFromTemplate()

    --Set weights & values of items inside bag to 0 in edit mode
    if SEll_LIST_EDIT_MODE == true then
        if inventoryHolder == SELL_ADD_BAG_ITEM then
            setZeroWeightAndValue(GUID(item))
            --TODO Do something to trigger a refresh of the weight here
            --TODO probably add/remove an item to the bag
            return
        end
        return
    end

    --Draggidy dropped onto the baggy, addy to the sell listy
    if inventoryHolder == SELL_ADD_BAG_ITEM then
        Bags.AddToSellList(itemName, root)
    end

    -- Specific to BAG SELL MODE ONLY
    if Config.config_tbl["BAG_SELL_MODE_ONLY"] == 1 and inventoryHolder == SELL_ADD_BAG_ITEM then
        local char = Osi.GetOwner(SELL_ADD_BAG_ITEM)
        HandleSelling(char, inventoryHolder, root, item)
        return
    end

    -- Ignore the event firing for inventories other than the ones of our party
    -- Important for party view (& Multiplayer?), otherwise we would just check against the host character
    if Table.CheckIfValueExists(SQUADIES, inventoryHolder) or inventoryHolder == Osi.GetHostCharacter() then
        --Error check this
        local success, translatedName = pcall(function()
            ---@diagnostic disable-next-line: param-type-mismatch
            return Osi.ResolveTranslatedString(Osi.GetDisplayName(item))
        end)
        if not success then
            translatedName = "NO HANDLE"
        end

        BasicDebug({
            "ITEM NAME : " .. (translatedName or "NO HANDLE"),
            "ROOT : " .. root,
            "ITEM : " .. item,
            "Item prefix : " .. itemName,
            "Root prefix : " .. rootName,
            string.format("['%s'] = '%s',", itemName, root)
        })

        if IsTransmogInvisible(itemName, item) then
            BasicDebug("Ignoring transmorb item")
            return
        end

        if Table.FindKeyInSet(JUNKTABLESET, itemName) then
            local itemUUID = GUID(item)
            if Osi.IsContainer(itemUUID) == 1 then
                Osi.MoveAllItemsTo(itemUUID, inventoryHolder)
            end
            HandleSelling(inventoryHolder, inventoryHolder, root, item)
            return
        else
            -- Ignored item
            return
        end
    end
end)


-- -------------------------------------------------------------------------- --
--                                   Config                                   --
-- -------------------------------------------------------------------------- --
-- Events
-- Osi.MessageBoxChoiceClosed (character, message, resultChoice)	
-- Osi.MessageBoxClosed (character, message)	
-- Osi.MessageBoxYesNoClosed (character, message, result)

-- Functions
-- OpenMessageBox (character, message)	
-- OpenMessageBoxChoice (character, message, choice1, choice2)	
-- OpenMessageBoxYesNo (character, message)


Ext.Osiris.RegisterListener("AttackedBy", 7, "after",
    function(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
        if damageAmount == 0 and GUID(attackerOwner) == Osi.GetHostCharacter() and GUID(defender) == SELL_ADD_BAG_ITEM then
            if Config.config_tbl.MOD_ENABLED == 1 then
                Osi.OpenMessageBoxYesNo(attackerOwner, Messages.message_warning_config_start)
            else
                Osi.OpenMessageBoxYesNo(attackerOwner, Messages.message_enable_mod)
            end
        end
    end)

Ext.Osiris.RegisterListener("MessageBoxYesNoClosed", 3, "after", function(character, message, result)
    local function handleConfig(configMessage, configValue, nextMessage)
        if message == configMessage then
            Config.SetValue(Config.config_tbl, configValue, result)
            Config.SaveConfig()
            Osi.OpenMessageBoxYesNo(character, nextMessage)
        end
    end

    -- Config Start
    if message == Messages.message_warning_config_start then
        if result == 1 then
            Osi.OpenMessageBoxYesNo(character, Messages.message_bag_sell_mode)
        else
            if SELL_ADD_BAG_ITEM then Osi.Pickup(character, SELL_ADD_BAG_ITEM, "", 1) end
        end

        -- Config Sell mode only
    elseif message == Messages.message_bag_sell_mode then
        handleConfig(Messages.message_bag_sell_mode, "BAG_SELL_MODE_ONLY", Messages.message_user_list_only)

        -- Config user list only
    elseif message == Messages.message_user_list_only then
        handleConfig(Messages.message_user_list_only, "CUSTOM_LISTS_ONLY", PersistentVars.useSaveSpecificSellList
            and Messages.message_save_specific_list_already_exist or Messages.message_save_specific_list)

        -- Config save specific list
    elseif message == Messages.message_save_specific_list then
        if result == 1 and not PersistentVars.saveIdentifier then
            local random = Ext.Math.Random(0, 999999999)
            PersistentVars.saveIdentifier = random
            PersistentVars.useSaveSpecificSellList = true
            Config.InitDefaultFilterList(Config.GetSellPath(), Config.default_sell)
            Config.LoadUserLists()
        elseif result == 1 and PersistentVars.saveIdentifier then
            PersistentVars.useSaveSpecificSellList = true
            Config.LoadUserLists()
        end
        Osi.OpenMessageBoxYesNo(character, Messages.message_clear_sell_list)

        -- Config save specific list already exist
    elseif message == Messages.message_save_specific_list_already_exist then
        if result == 1 then
            PersistentVars.useSaveSpecificSellList = false
            Config.LoadUserLists()
        end
        Osi.OpenMessageBoxYesNo(character, Messages.message_clear_sell_list)

        -- Config clear list
    elseif message == Messages.message_clear_sell_list then
        if result == 1 then
            Config.InitDefaultFilterList(Config.GetSellPath(), Config.default_sell)
        end
        Osi.OpenMessageBoxYesNo(character, Messages.message_disable_mod)

        -- Disable mod
    elseif message == Messages.message_disable_mod then
        local choice = result == 1 and 0 or 1
        Config.SetValue(Config.config_tbl, "MOD_ENABLED", choice)
        Config.SaveConfig()
        if SELL_ADD_BAG_ITEM then Osi.Pickup(character, SELL_ADD_BAG_ITEM, "", 1) end

        -- Re-enable mod
    elseif message == Messages.message_enable_mod then
        handleConfig(Messages.message_enable_mod, "MOD_ENABLED", nil)
    end

    UpdateBagInfoScreenWithConfig()
end)


-- -------------------------------------------------------------------------- --
--                                   TESTING                                  --
-- -------------------------------------------------------------------------- --

Ext.Events.ResetCompleted:Subscribe(function()
    Messages = ResolveMessagesHandles()
    if not Config.initDone then Config.Init() end
    if Config.GetValue(Config.config_tbl, "MOD_ENABLED") == 1 then
        SQUADIES = GetSquadies()
        -- Add the bag(s) to the host char if none found in party inventory
        Bags.AddBag(SELL_ADD_BAG_ROOT, Osi.GetHostCharacter(), 1)
        SELL_VALUE_PERCENTAGE = Config.GetValue(Config.config_tbl, "SELL_VALUE_PERCENTAGE")
        BasicDebug("SELL_VALUE_PERCENTAGE : " .. SELL_VALUE_PERCENTAGE)
        -- Create a set from JUNKTABLE with items from keeplist removed and those from selllist added
        BasicDebug(Config.keeplist)
        BasicDebug(Config.selllist)
        local keepList = Config.GetValue(Config.keeplist, "KEEPLIST")
        local sellList = Config.GetValue(Config.selllist, "SELLLIST")
        JUNKTABLESET = Table.ProcessTables(JUNKTABLE, keepList, sellList)
        Bags.FindBagItemFromTemplate()
        if Config.config_tbl.ENABLE_LOGGING == 1 then
            Files.FlushLogBuffer()
        end
        UpdateBagInfoScreenWithConfig()
    end
end)
