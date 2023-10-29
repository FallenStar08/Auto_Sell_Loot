JUNKTABLE = Ext.Require("Server/junk_table.lua")
Ext.Require("Server/IO_utils.lua")
Ext.Require("Server/config_utils.lua")
Ext.Require("Server/log_utils.lua")
Ext.Require("Server/table_utils.lua")

-- -------------------------------------------------------------------------- --
--                                   GLOBALS                                  --
-- -------------------------------------------------------------------------- --

Bags = {

}
PersistentVars = {}
SELL_ADD_BAG_ROOT = "93165800-7962-4dec-96dc-1310129f6620"
GOLD = "1c3c9c74-34a1-4685-989e-410dc080be6f"
SELL_ADD_BAG_ITEM = ""
SQUADIES = {}
SELL_VALUE_COUNTER = 0
FRACTIONAL_PART = 0
SEll_LIST_EDIT_MODE = false
DURGY_ROOT = "DragonBorn_Male_OriginIntro_dca00de8-eb34-49b5-b65f-668cdf75116b"

Messages = {
    message_warning_config_start =
    "You are about to start the configuration of the auto sell mod, do not press escape and READ the option, press yes to start the configuration or no to abort",
    message_bag_sell_mode =
    "Do you want to set the bag to sell mode only? \n if this is enabled the item you drag & drop into the bag won't be added to your sell list.",
    message_user_list_only =
    "Do you want to only use your personal sell list? \n if this is enabled the mod won't use its internal junk list.",
    message_save_specific_list =
    "Do you want to use a save specific sell list for this save? \n if this is enabled your personal list will be tied to this save file. \n WARNING THIS WILL CREATE A NEW EMPTY LIST SPECIFIC TO THIS SAVE FILE! IF THIS IS ALREADY ENABLED CLICK YES",
    message_clear_sell_list =
    "Do you want to clear your personal sell list?"
}

-- -------------------------------------------------------------------------- --
--                                General Stuff                               --
-- -------------------------------------------------------------------------- --

-- Function to retrieve the list of squad members (The ones in the party at least)
function GetSquadies()
    local squadies = {}
    local players = Osi.DB_Players:Get(nil)
    for _, player in pairs(players) do table.insert(squadies, player[1]) end
    return squadies
end

function GetItemName(item)
    return string.sub(item, 1, -38)
end

--for the weird _xxx at the end of some items UUIDs
function RemoveTrailingNumbers(inputString)
    return inputString:gsub("_%d%d%d$", "")
end

--Fuck you whoever made me add this garbage
function StringEmpty(str)
    return not string.match(str, "%S")
end

function AddGoldTo(Character, Amount)
    Osi.TemplateAddTo(GOLD, Character, Amount)
end

function RemoveGoldFrom(Character, Amount)
    Osi.TemplateRemoveFrom(GOLD, Character, Amount)
end

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
            REMOVER_BAG_CONTENT_LIST[itemName] = string.sub(template, -36)
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
    item = string.sub(item, -36)
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
    item = string.sub(item, -36)
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
                BasicPrint("FindBagItemFromTemplate() Selling bag UUID found :" .. SELL_ADD_BAG_ITEM)
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
    if not Config.initDone then return end                                    --Somehow got there before Init (probably new game stuff)
    if Config.GetValue(Config.config_tbl, "MOD_ENABLED") == 0 then return end -- Mod Disabled
    local rootName = GetItemName(root)
    root = string.sub(root, -36)
    if root == GOLD or root == SELL_ADD_BAG_ROOT then return end --Ignore gold & bag
    local itemName = RemoveTrailingNumbers(GetItemName(item)) or "BAD MOD"

    Bags.FindBagItemFromTemplate()
    --Set weights & values of items inside bag to 0 in edit mode
    if SEll_LIST_EDIT_MODE == true then
        if string.sub(inventoryHolder, -36) == SELL_ADD_BAG_ITEM then
            local itemUUID = string.sub(item, -36)
            Ext.Entity.Get(itemUUID):GetComponent("Data").Weight = 0
            Ext.Entity.Get(itemUUID):GetComponent("Value").Value = 0
            Ext.Entity.Get(itemUUID):Replicate("Data")
            Ext.Entity.Get(itemUUID):Replicate("Value")
            --TODO Do something to trigger a refresh of the weight here
            --TODO probably add/remove an item to the bag
            return
        end
        return
    end

    --Draggidy dropped onto the baggy, addy to the sell listy
    if string.sub(inventoryHolder, -36) == SELL_ADD_BAG_ITEM then Bags.AddToSellList(itemName, root) end

    --Specific to BAG SELL MODE ONLY
    if Config.config_tbl["BAG_SELL_MODE_ONLY"] == 1 then
        if string.sub(inventoryHolder, -36) == SELL_ADD_BAG_ITEM then
            local char = Osi.GetOwner(SELL_ADD_BAG_ITEM)
            HandleSelling(char, inventoryHolder, root, item)
            return
        end
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
            "ITEM NAME : " .. translatedName,
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
            local itemUUID = string.sub(item, -36)
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
        if attackerOwner == Osi.GetHostCharacter() and defender == SELL_ADD_BAG_ITEM then
            Osi.OpenMessageBoxYesNo(attackerOwner, Messages.message_warning_config_start)
        end
    end)

Ext.Osiris.RegisterListener("MessageBoxYesNoClosed", 3, "after", function(character, message, result)
    if message == Messages.message_warning_config_start then
        if result == 1 then
            Osi.OpenMessageBoxYesNo(character, Messages.message_bag_sell_mode)
        end
    elseif message == Messages.message_bag_sell_mode then
        if result == 1 then
            Config.SetValue(Config.config_tbl, "BAG_SELL_MODE_ONLY", 1)
        else
            Config.SetValue(Config.config_tbl, "BAG_SELL_MODE_ONLY", 0)
        end
    Config.SaveConfig()
    Osi.OpenMessageBoxYesNo(character, Messages.message_user_list_only)
    elseif message == Messages.message_user_list_only then
        if result == 1 then
            Config.SetValue(Config.config_tbl, "CUSTOM_LISTS_ONLY", 1)
        else
            Config.SetValue(Config.config_tbl, "CUSTOM_LISTS_ONLY", 0)
        end
    Config.SaveConfig()
    Osi.OpenMessageBoxYesNo(character, Messages.message_save_specific_list)
    elseif message == Messages.message_save_specific_list then
        if result == 1 and not PersistentVars.saveIdentifier then
            table.insert(PersistentVars, { saveIdentifier = Ext.Math.Random(0, 999999999) })
            Config.InitDefaultFilterList(Config.GetSellPath(), Config.default_sell)
        elseif result == 0 and PersistentVars.saveIdentifier then
            PersistentVars.saveIdentifier = nil
        end
    Osi.OpenMessageBoxYesNo(character,Messages.message_clear_sell_list)
    elseif message == Messages.message_clear_sell_list then
        if result == 1 then
            Config.InitDefaultFilterList(Config.GetSellPath(), Config.default_sell)
        else
            --do nothing
        end
    end
end)
