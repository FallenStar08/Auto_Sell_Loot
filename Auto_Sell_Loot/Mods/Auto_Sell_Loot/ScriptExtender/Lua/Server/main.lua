JUNKTABLE = Ext.Require("Server/junk_table.lua")

Ext.Require("Server/_Filters.lua")


Bags = {}
local SELL_VALUE_COUNTER = 0
local FRACTIONAL_PART = 0
local SEll_LIST_EDIT_MODE = false

RegisterModVariable("Fallen_AutoSellerInfos")

-- -------------------------------------------------------------------------- --
--                                General Stuff                               --
-- -------------------------------------------------------------------------- --

--This is what's called "Name" in the item template, idk which way to get it is smarter
--Probably neither
local function GetItemName(item)
    return string.sub(item, 1, -38)
end

local function DeleteItem(Character, Item, Amount)
    Osi.UnloadItem(Item)
end

--TODO FIND SOMEWHERE SAFE TO HIDE ITEMS
--Create pouch
--Move Dummy inventory to pouch
--Zap back pouch inventory to dummy
--Nuke pouch
--Profit
local function MoveItemToHiddeyHole(Character, Item, Amount)
    --for now...
    Osi.UnloadItem(Item)
    --Osi.ToInventory(Item,NAKED_DUMMY_2)
end

-- function Bags.MoveNakedManItemsToBag(bag)
--     Osi.MoveAllItemsTo(NAKED_DUMMY_2, bag)
-- end

-- function BringHideyHoleToMe()
--     local x, y, z = Osi.GetPosition(NAKED_DUMMY_2)
--     Osi.TeleportTo(NAKED_DUMMY_2, Osi.GetHostCharacter())
--     Ext.OnNextTick(function() Osi.SetOnStage(NAKED_DUMMY_2, 1) end)
--     Osi.SetImmortal(NAKED_DUMMY_2, 1)
--     local dummy = Ext.Entity.Get(NAKED_DUMMY_2)
--     dummy.CanEnterChasm.CanEnter = false
--     dummy.CanBeLooted.Flags = 1
--     dummy:Replicate("CanBeLooted")
--     dummy:Replicate("CanEnterChasm")
--     --Ext.OnNextTick(function() Osi.ActivateTrade(Osi.GetHostCharacter(),NAKED_DUMMY_2,1) end)
-- end

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

local function ResolveMessagesHandles()
    local messages = {
        message_warning_config_start = GetTranslatedString("h995d430eg9629g40c8g9470g6f515582195b"),
        message_bag_sell_mode = GetTranslatedString("h70fb978cg63cbg44d2ga45eg89bcacb356c8"),
        message_user_list_only = GetTranslatedString("hfda8e6cag7e53g41e5gb1b5g4892dbc8a8ae"),
        message_save_specific_list = GetTranslatedString("h5172487eg9d0eg4c06g93e3g5badf1e9401c"),
        message_save_specific_list_already_exist = GetTranslatedString("hbc85062bg1b97g4150g9d31gacac9018d58b"),
        message_clear_sell_list = GetTranslatedString("hd5b72a24g4401g4986gae60g9db54155f4ca"),
        message_disable_mod = GetTranslatedString("he488aa70g5d71g4c0egaf5cg68ac3804b28d"),
        message_enable_mod = GetTranslatedString("hc28d17e2g37b5g4978gb1c6g56d048969ab8"),
        message_delete_bag = GetTranslatedString("h4a84239ag4dd0g4311gbd5ege1aac8b9cca2"),
        message_mark_as_ware = GetTranslatedString("hd3cb471fg0b62g429eg97efg9f3a0f99cc7d")
    }
    return messages
end

--Update bag description with mod infos
local function UpdateBagInfoScreenWithConfig()
    local modVars = GetModVariables()
    local useSaveSpecificSellList = modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList and
        modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList or "not enabled"
    local saveIdentifier = modVars.Fallen_AutoSellerInfos.saveIdentifier and
        modVars.Fallen_AutoSellerInfos.saveIdentifier or "not enabled"

    local handle = "he671bb1egab4fg4f2bg981egdd0b1e8585af"

    -- Determine the color of each setting based on its value
    local bagSellModeColor = CONFIG.BAG_SELL_MODE_ONLY == 1 and "green" or "red"
    local userListColor = CONFIG.CUSTOM_LISTS_ONLY == 1 and "green" or "red"
    local markAsWareColor = CONFIG.MARK_AS_WARE == 1 and "green" or "red"
    local useSaveSpecificSellListColor = modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList and "green" or "red"
    local saveIdentifierColor = modVars.Fallen_AutoSellerInfos.saveIdentifier and "green" or "red"
    local modEnabledColor = CONFIG.MOD_ENABLED == 1 and "green" or "red"

    -- Convert RGB colors to hexadecimal
    local greenHex = RgbToHex(0, 255, 0)
    local redHex = RgbToHex(255, 0, 0)
    local orangeHex = RgbToHex(255, 165, 0)

    -- Format the strings with appropriate color tags
    local bagSellModeText = string.format("<font color='%s'>%s</font>",
        bagSellModeColor == "green" and greenHex or redHex, tostring(CONFIG.BAG_SELL_MODE_ONLY == 1))
    local userListText = string.format("<font color='%s'>%s</font>", userListColor == "green" and greenHex or redHex,
        tostring(CONFIG.CUSTOM_LISTS_ONLY == 1))
    local markAsWareText = string.format("<font color='%s'>%s</font>", markAsWareColor == "green" and greenHex or redHex,
        tostring(CONFIG.MARK_AS_WARE == 1))
    local useSaveSpecificSellListText = string.format("<font color='%s'>%s</font>",
        useSaveSpecificSellListColor == "green" and greenHex or orangeHex, useSaveSpecificSellList)
    local saveIdentifierText = string.format("<font color='%s'>%s</font>",
        saveIdentifierColor == "green" and greenHex or orangeHex, saveIdentifier)
    local modEnabledText = string.format("<font color='%s'>%s</font>", modEnabledColor == "green" and greenHex or redHex,
        tostring(CONFIG.MOD_ENABLED == 1))

    local content = string.format(
        "Mod settings:\n - Bag Sell Mode Only: %s\n - User List Only: %s\n - Mark as ware mode: %s\n - Save Specific List: %s\n - Save Identifier: %s \n - Mod Enabled : %s",
        bagSellModeText,
        userListText,
        markAsWareText,
        useSaveSpecificSellListText,
        saveIdentifierText,
        modEnabledText
    )

    BasicDebug("UpdateBagInfoScreenWithConfig() - content: " .. content, TEXT_COLORS.magenta)
    UpdateTranslatedString(handle, content)
end


-- -------------------------------------------------------------------------- --
--                                Bags function & related Events              --
-- -------------------------------------------------------------------------- --


-- Fill an existing bag with items from a list
function Bags.AddAllListItemToBag(list, bagItem, character)
    for name, uid in pairs(list) do
        Osi.TemplateAddTo(uid, bagItem, 1, 0)
        BasicDebug("AddAllListItemToBag() - Added item with name : " ..
            name .. " and uid : " .. uid .. " to bag : " .. bagItem)
    end
end

function Bags.AddContentToList(bagItem, character)
    local REMOVER_BAG_CONTENT_LIST = {}
    local bagInv = DeepIterateInventory(_GE(bagItem))
    for uuid, data in pairs(bagInv) do
        local templateGuid = data.template
        local template = Ext.Template.GetTemplate(uuid) or (templateGuid and Ext.Template.GetTemplate(templateGuid)) or
            "0"
        REMOVER_BAG_CONTENT_LIST[template.Name] = GUID(templateGuid)
        Osi.UnloadItem(uuid)
    end
    local removedItems = Table.CompareSets(SellList["SELLLIST"], REMOVER_BAG_CONTENT_LIST)
    -- Because people will obvsiously complain they can't add items to the list by having the bag open
    -- Anticipating next complain being the fact that it doesn't pay them this way
    -- Fuck that, not doing it... yet? :')
    local addedItems = Table.CompareSets(REMOVER_BAG_CONTENT_LIST, SellList["SELLLIST"])
    BasicDebug("AddContentToList() Removed Items after bag closing :")
    BasicDebug(removedItems)
    BasicDebug("AddContentToList() Added Items after bag closing :")
    BasicDebug(addedItems)
    -- Disable/Enable them in the current session
    for name, uid in pairs(removedItems) do JUNKTABLESET[name] = nil end
    for name, uid in pairs(addedItems) do JUNKTABLESET[name] = uid end
    -- Save to file
    SellList["SELLLIST"] = REMOVER_BAG_CONTENT_LIST
    JSON.LuaTableToFile(SellList, GetSellPath())
end

-- Function to add a bag to a character if it isn't already in their inventory
-- or in another party member's inventory (to avoid duplicate bags)
function Bags.AddBag(bag, character, notification)
    if CONFIG.GIVE_BAG >= 1 then
        for _, player in pairs(SQUADIES) do if Osi.TemplateIsInInventory(bag, player) >= 1 then return end end
        BasicDebug("Bags.AddBag() Bag : " .. bag .. " adding to character : " .. character)
        Osi.TemplateAddTo(bag, character, 1, notification)
    else
        BasicDebug("Bags.AddBag() - Bag disabled in config file")
    end
end

-- Iterate through the inventory of the party members and mark all copies of the item as ware
function Bags.MarkExistingItemsAsWare(root)
    for _, player in pairs(SQUADIES) do
        local squadieInv = DeepIterateInventory(_GE(player))
        for uuid, data in pairs(squadieInv) do
            if data.template == root then
                MarkAsWare(data.entity)
            end
        end
    end
end

function Bags.AddToSellList(item_name, root, item, bagOwner)
    if CONFIG.BAG_SELL_MODE_ONLY == 1 then return end
    if StringEmpty(item_name) then
        BasicDebug("AddToSellList() - BAD ITEM with root : " .. root)
        return
    end
    JUNKTABLESET[item_name] = root
    -- Save the added item to file for next load
    SellList["SELLLIST"][item_name] = root
    JSON.LuaTableToFile(SellList, GetSellPath())
    BasicDebug("AddToSellList() - Added the following item to the sell list item name : " ..
        item_name .. " root : " .. root)
    if CONFIG.MARK_AS_WARE == 1 then
        DelayedCall(500, function()
            Osi.ToInventory(item, bagOwner, 99999999)
            if CONFIG.MARK_AS_WARE==1 then
                Bags.MarkExistingItemsAsWare(root)
            end
        end)
    end
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

-- Listen for item uses, in this case the opening of our bag counts as it being used
Ext.Osiris.RegisterListener("UseStarted", 2, "before", function(character, item)
    item = GUID(item)
    if not SELL_ADD_BAG_ITEM then Bags.FindBagItemFromTemplate() end
    if item == SELL_ADD_BAG_ITEM then
        SEll_LIST_EDIT_MODE = true
        BasicDebug(SellList["SELLLIST"])
        Osi.ShowNotification(character, "AUTOSELL - EDIT MODE ON")
        Ext.OnNextTick(function()
            Bags.AddAllListItemToBag(SellList["SELLLIST"], SELL_ADD_BAG_ITEM, character)
        end)
    end
end)

-- Listener for item uses stop, in this case the closing of our bag counts as it not being used anymore
Ext.Osiris.RegisterListener("UseFinished", 3, "after", function(character, item, sucess)
    if SEll_LIST_EDIT_MODE == true and GUID(item) == SELL_ADD_BAG_ITEM then
        Osi.ShowNotification(character, "AUTOSELL - EDIT MODE OFF")
        Bags.AddContentToList(SELL_ADD_BAG_ITEM, character)
        SEll_LIST_EDIT_MODE = false
    end
end)

-- -------------------------------------------------------------------------- --
--                                   Selling                                  --
-- -------------------------------------------------------------------------- --

-- Function to handle the selling logic, accumulating decimal prices until they reach 1
-- Adding gold according to the sell value
-- Removing the "sold" items from the inventory
-- Cache gold value, easy optimization that probably is totally useless
local itemValueCache = {}
function HandleSelling(Owner, Character, Root, Item)
    -- exact is actually exact, total is stack total, a stack can be different same items...
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
    local sellValue = itemValue * CONFIG.SELL_VALUE_PERCENTAGE / 100
    -- Accumulate the sell values
    SELL_VALUE_COUNTER = SELL_VALUE_COUNTER + sellValue
    if SELL_VALUE_COUNTER >= 1 then
        local goldToAdd = math.floor(SELL_VALUE_COUNTER)    --Integer part
        FRACTIONAL_PART = FRACTIONAL_PART + (SELL_VALUE_COUNTER - goldToAdd)
        goldToAdd = goldToAdd + math.floor(FRACTIONAL_PART) -- Fractional part
        AddGoldTo(Owner, goldToAdd)
        BasicDebug("HandleSelling() - Adding " .. goldToAdd .. " Gold to Character")
        --DeleteItem(Character, Item, exactItemAmount)
        MoveItemToHiddeyHole(Character, Item, exactItemAmount)
        SELL_VALUE_COUNTER = 0
        FRACTIONAL_PART = FRACTIONAL_PART - math.floor(FRACTIONAL_PART) -- Keep the remaining fractional part for later
        BasicDebug("HandleSelling() - Leftovers " .. FRACTIONAL_PART .. " Gold kept for later")
    else
        --DeleteItem(Character, Item, exactItemAmount)
        MoveItemToHiddeyHole(Character, Item, exactItemAmount)
    end
end

-- -------------------------------------------------------------------------- --
--                            Core Logic Listeners                            --
-- -------------------------------------------------------------------------- --


-- Update SQUADIES for when a character joins the party
Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(Character)
    SQUADIES = GetSquadies()
end)

-- Update SQUADIES for when a character leaves the party
Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function(Character)
    SQUADIES = GetSquadies()
end)

local function setZeroWeightAndValue(itemUUID)
    local entity = Ext.Entity.Get(itemUUID)
    if entity then
        local dataComp = entity.Data
        local valueComp = entity.Value
        if dataComp and valueComp then
            dataComp.Weight = 0
            valueComp.Value = 0
            entity:Replicate("Data")
            entity:Replicate("Value")
        end
    end
end

-- Includes moving from container to other inventories etc...
Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "before", function(root, item, inventoryHolder, addType)
    if not CONFIG or CONFIG.MOD_ENABLED == 0 then
        return -- Ignore if initialization not done or mod is disabled
    end

    local rootName = GetItemName(root)
    root = GUID(root)
    inventoryHolder = GUID(inventoryHolder)

    if root == GOLD or root == SELL_ADD_BAG_ROOT then
        return -- Ignore gold & bag
    end

    local itemName = RemoveTrailingNumbers(GetItemName(item)) or "BAD MOD"

    --Sanity check, this is probably terrible performance wise
    Bags.FindBagItemFromTemplate()

    --Set weights & values of items inside bag to 0 in edit mode
    if SEll_LIST_EDIT_MODE == true then
        if inventoryHolder == SELL_ADD_BAG_ITEM then
            setZeroWeightAndValue(GUID(item))
            return
        end
        return
    end

    --Draggidy dropped onto the baggy, addy to the sell listy
    if inventoryHolder == SELL_ADD_BAG_ITEM then
        Bags.AddToSellList(itemName, root, item, Osi.GetOwner(inventoryHolder))
    end

    -- Specific to BAG SELL MODE ONLY
    if CONFIG.BAG_SELL_MODE_ONLY == 1 and inventoryHolder == SELL_ADD_BAG_ITEM then
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
            return Ext.Loca.GetTranslatedString(Osi.GetDisplayName(item))
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
            if Osi.IsContainer(item) == 1 then
                Osi.MoveAllItemsTo(item, inventoryHolder)
            end
            if CONFIG.MARK_AS_WARE == 1 then
                MarkAsWare(item)
                return
            else
                HandleSelling(inventoryHolder, inventoryHolder, root, item)
                return
            end
        else
            -- Ignored item
            return
        end
    end
end)

-- -------------------------------------------------------------------------- --
--                          KEEP LIST FOR OTHER MODS                          --
-- -------------------------------------------------------------------------- --

local function addItemsUsedInModsToKeepListIfLoaded()
    --Siael equip mod uses gold bars
    if Ext.Mod.IsModLoaded("73696165-6c32-4e31-914f-fc839aaef51d") then
        KeepList.KEEPLIST["LOOT_GEN_Metalbar_Gold_A"] = "44f47718-9769-4c0e-af75-7789d2f2913d"
    end
end



-- -------------------------------------------------------------------------- --
--                                   Config                                   --
-- -------------------------------------------------------------------------- --
-- !Events DOESNT WORK ANYMORE
-- Osi.MessageBoxChoiceClosed (character, message, resultChoice)	
-- Osi.MessageBoxClosed (character, message)	
-- Osi.MessageBoxYesNoClosed (character, message, result)

-- !Functions DOESNT WORK ANYMORE
-- OpenMessageBox (character, message)	
-- OpenMessageBoxChoice (character, message, choice1, choice2)	
-- OpenMessageBoxYesNo (character, message)


--New function (P6+)

-- Osi.ReadyCheckSpecific (eventId, translationId, force, initiator, character1, character2, character3)
-- Parameters:
-- eventId string
-- translationId string
-- force integer
-- initiator CHARACTER
-- character1 CHARACTER
-- character2 CHARACTER
-- character3 CHARACTER

--New event (P6+)
-- Osi.ReadyCheckFailed (id)
-- Osi.ReadyCheckPassed (id)


---Guess this is my life now
---@param eventId string
---@param content string
---@param force? number
---@param initiation? GUIDSTRING --Char who initatittititited the box idk fuck this shit garbage ass function fuck
---@param char1? GUIDSTRING
---@param char2? GUIDSTRING
---@param char3? GUIDSTRING
local function FallenMessageBox(eventId, content, initiation, char1, char2, char3, force)
    force = force or 1
    initiation = initiation or Osi.GetHostCharacter()
    char1 = char1 or ""
    char2 = char2 or ""
    char3 = char3 or ""
    _G.INITIATIOR = initiation
    Osi.ReadyCheckSpecific(eventId, content, force, initiation, char1, char2, char3)
end


Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after",
    function(caster, target, spell, spellType, spellElement, storyActionID)
        if GUID(caster) == GUID(Osi.GetHostCharacter()) and GUID(target) == SELL_ADD_BAG_ITEM then
            if CONFIG.MOD_ENABLED == 1 then
                FallenMessageBox("message_warning_config_start", Messages.message_warning_config_start, caster)
                --Osi.OpenMessageBoxYesNo(caster, Messages.message_warning_config_start)
            else
                FallenMessageBox("message_enable_mod", Messages.message_enable_mod, caster)
            end
        end
    end)

Ext.Osiris.RegisterListener("ReadyCheckPassed", 1, "after", function(id)
    if id == "message_warning_config_start" then
        FallenMessageBox("message_bag_sell_mode", Messages.message_bag_sell_mode, INITIATIOR)
    elseif id == "message_enable_mod" then
        CONFIG["MOD_ENABLED"] = 1
    elseif id == "message_bag_sell_mode" then
        CONFIG["BAG_SELL_MODE_ONLY"] = 1
        FallenMessageBox("message_mark_as_ware", Messages.message_mark_as_ware, INITIATIOR)
    elseif id == "message_mark_as_ware" then
        CONFIG["MARK_AS_WARE"] = 1
        FallenMessageBox("message_user_list_only", Messages.message_user_list_only, INITIATIOR)
    elseif id == "message_user_list_only" then
        CONFIG["CUSTOM_LISTS_ONLY"] = 1
        local modVars = GetModVariables()
        if modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList then
            FallenMessageBox("message_save_specific_list_already_exist",
                Messages.message_save_specific_list_already_exist, INITIATIOR)
        else
            FallenMessageBox("message_save_specific_list", Messages.message_save_specific_list, INITIATIOR)
        end
    elseif id == "message_save_specific_list_already_exist" then
        local modVars = GetModVariables()
        modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = false
        LoadUserLists()
        FallenMessageBox("message_clear_sell_list", Messages.message_clear_sell_list, INITIATIOR)
    elseif id == "message_save_specific_list" then
        local modVars = GetModVariables()
        if not modVars.Fallen_AutoSellerInfos.saveIdentifier then
            local random = Ext.Math.Random(0, 999999999)
            modVars.Fallen_AutoSellerInfos.saveIdentifier = random
            modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = true
            InitDefaultFilterList(GetSellPath(), default_sell)
            LoadUserLists()
        elseif modVars.Fallen_AutoSellerInfos.saveIdentifier then
            modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = true
            LoadUserLists()
        end
        FallenMessageBox("message_clear_sell_list", Messages.message_clear_sell_list, INITIATIOR)
    elseif id == "message_clear_sell_list" then
        InitDefaultFilterList(GetSellPath(), default_sell)
        SellList.SELLLIST = {}
        JUNKTABLESET = Table.ProcessTables(JUNKTABLE, KeepList.KEEPLIST, SellList.SELLLIST)
        FallenMessageBox("message_delete_bag",
        Messages.message_delete_bag, INITIATIOR)
    elseif id == "message_delete_bag" then
        Osi.UnloadItem(SELL_ADD_BAG_ITEM)
        CONFIG["MOD_ENABLED"] = 0
        Osi.ToInventory(SELL_ADD_BAG_ITEM,INITIATIOR or Osi.GetHostCharacter())
        INITIATIOR=nil
        --! END 1
    elseif id == "message_disable_mod" then
        CONFIG["MOD_ENABLED"] = 0
        Osi.ToInventory(SELL_ADD_BAG_ITEM,INITIATIOR or Osi.GetHostCharacter())
        INITIATIOR=nil
        --! END 2
    end
    SyncModVariables()
    UpdateBagInfoScreenWithConfig()
end)

Ext.Osiris.RegisterListener("ReadyCheckFailed", 1, "after", function(id)
    if id == "message_warning_config_start" then
        Osi.ToInventory(SELL_ADD_BAG_ITEM,INITIATIOR or Osi.GetHostCharacter())
    elseif id == "message_enable_mod" then
        CONFIG["MOD_ENABLED"] = 1
    elseif id == "message_bag_sell_mode" then
        CONFIG["BAG_SELL_MODE_ONLY"] = 0
        FallenMessageBox("message_mark_as_ware", Messages.message_mark_as_ware, INITIATIOR)
    elseif id == "message_mark_as_ware" then
        CONFIG["MARK_AS_WARE"] = 0
        FallenMessageBox("message_user_list_only", Messages.message_user_list_only, INITIATIOR)
    elseif id == "message_user_list_only" then
        CONFIG["CUSTOM_LISTS_ONLY"] = 0
        local modVars = GetModVariables()
        if modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList then
            FallenMessageBox("message_save_specific_list_already_exist",
                Messages.message_save_specific_list_already_exist, INITIATIOR)
        else
            FallenMessageBox("message_save_specific_list", Messages.message_save_specific_list, INITIATIOR)
        end
    elseif id == "message_save_specific_list_already_exist" then
        FallenMessageBox("message_clear_sell_list", Messages.message_clear_sell_list, INITIATIOR)
    elseif id == "message_save_specific_list" then
        FallenMessageBox("message_clear_sell_list", Messages.message_clear_sell_list, INITIATIOR)
    elseif id == "message_clear_sell_list" then
        InitDefaultFilterList(GetSellPath(), default_sell)
        SellList.SELLLIST = {}
        JUNKTABLESET = Table.ProcessTables(JUNKTABLE, KeepList.KEEPLIST, SellList.SELLLIST)
        FallenMessageBox("message_delete_bag",
                Messages.message_delete_bag, INITIATIOR)
    elseif id == "message_delete_bag" then
        -- Osi.UnloadItem(SELL_ADD_BAG_ITEM)
        -- CONFIG["MOD_ENABLED"] = 0
        -- INITIATIOR=nil
        --! END 1
        FallenMessageBox("message_disable_mod",
        Messages.message_disable_mod, INITIATIOR)
    elseif id == "message_disable_mod" then
        -- CONFIG["MOD_ENABLED"] = 0
        Osi.ToInventory(SELL_ADD_BAG_ITEM,INITIATIOR or Osi.GetHostCharacter())
        INITIATIOR=nil
        --! END 2
    end
    SyncModVariables()
    UpdateBagInfoScreenWithConfig()
    
end)
--! OLD pre P5 when the game was still good
-- Ext.Osiris.RegisterListener("MessageBoxYesNoClosed", 3, "after", function(character, message, result)
--     local function handleConfig(configMessage, configValue, nextMessage)
--         if message == configMessage then
--             CONFIG[configValue] = result
--             --CONFIG:save()
--             if nextMessage then
--                 Osi.OpenMessageBoxYesNo(character, nextMessage)
--             else
--                 if SELL_ADD_BAG_ITEM then Osi.Pickup(character, SELL_ADD_BAG_ITEM, "", 1) end
--             end
--         end
--     end

--     -- Config Start
--     if message == Messages.message_warning_config_start then
--         if result == 1 then
--             Osi.OpenMessageBoxYesNo(character, Messages.message_bag_sell_mode)
--         else
--             if SELL_ADD_BAG_ITEM then Osi.Pickup(character, SELL_ADD_BAG_ITEM, "", 1) end
--         end

--         -- Config Sell mode only
--     elseif message == Messages.message_bag_sell_mode then
--         handleConfig(Messages.message_bag_sell_mode, "BAG_SELL_MODE_ONLY", Messages.message_mark_as_ware)
--     elseif message == Messages.message_mark_as_ware then
--         handleConfig(Messages.message_mark_as_ware, "MARK_AS_WARE", Messages.message_user_list_only)

--         -- Config user list only
--     elseif message == Messages.message_user_list_only then
--         local modVars = GetModVariables()
--         handleConfig(Messages.message_user_list_only, "CUSTOM_LISTS_ONLY",
--             modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList
--             and Messages.message_save_specific_list_already_exist or Messages.message_save_specific_list)

--         -- Config save specific list
--     elseif message == Messages.message_save_specific_list then
--         local modVars = GetModVariables()
--         if result == 1 and not modVars.Fallen_AutoSellerInfos.saveIdentifier then
--             local random = Ext.Math.Random(0, 999999999)
--             modVars.Fallen_AutoSellerInfos.saveIdentifier = random
--             modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = true
--             InitDefaultFilterList(GetSellPath(), default_sell)
--             LoadUserLists()
--         elseif result == 1 and modVars.Fallen_AutoSellerInfos.saveIdentifier then
--             modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = true
--             LoadUserLists()
--         end
--         Osi.OpenMessageBoxYesNo(character, Messages.message_clear_sell_list)

--         -- Config save specific list already exist
--     elseif message == Messages.message_save_specific_list_already_exist then
--         local modVars = GetModVariables()
--         if result == 1 then
--             modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = false
--             LoadUserLists()
--         end
--         Osi.OpenMessageBoxYesNo(character, Messages.message_clear_sell_list)

--         -- Config clear list
--     elseif message == Messages.message_clear_sell_list then
--         if result == 1 then
--             InitDefaultFilterList(GetSellPath(), default_sell)
--             SellList.SELLLIST = {}
--             JUNKTABLESET = Table.ProcessTables(JUNKTABLE, KeepList.KEEPLIST, SellList.SELLLIST)
--         end
--         Osi.OpenMessageBoxYesNo(character, Messages.message_delete_bag)
--         --Delete Bag
--     elseif message == Messages.message_delete_bag then
--         if result == 1 then
--             Osi.UnloadItem(SELL_ADD_BAG_ITEM)
--             local choice = result == 1 and 0 or 1
--             CONFIG["MOD_ENABLED"] = choice
--         else
--             Osi.OpenMessageBoxYesNo(character, Messages.message_disable_mod)
--         end

--         -- Disable mod
--     elseif message == Messages.message_disable_mod then
--         local choice = result == 1 and 0 or 1
--         CONFIG["MOD_ENABLED"] = choice
--         if SELL_ADD_BAG_ITEM then Osi.Pickup(character, SELL_ADD_BAG_ITEM, "", 1) end

--         -- Re-enable mod
--     elseif message == Messages.message_enable_mod then
--         handleConfig(Messages.message_enable_mod, "MOD_ENABLED", nil)
--     end
--     SyncModVariables()
--     UpdateBagInfoScreenWithConfig()
-- end)


-- -------------------------------------------------------------------------- --
--                                   INIT/TESTING                             --
-- -------------------------------------------------------------------------- --
local function start(level, isEditor)
    local modVars = GetModVariables()
    if not modVars.Fallen_AutoSellerInfos then
        modVars.Fallen_AutoSellerInfos = {}; SyncModVariables()
    end
    if level == "SYS_CC_I" then return end
    Messages = ResolveMessagesHandles()
    if not CONFIG then CONFIG = InitConfig() end
    local execTime = MeasureExecutionTime(function()
        InitFilters()
        SQUADIES = GetSquadies()
        -- Create a set from JUNKTABLE with items from keeplist removed and those from selllist added
        BasicDebug(KeepList)
        BasicDebug(SellList)
        addItemsUsedInModsToKeepListIfLoaded()
        JUNKTABLESET = Table.ProcessTables(JUNKTABLE, KeepList.KEEPLIST, SellList.SELLLIST)
    end)

    BasicDebug("Tables loaded and processed, set successfully created in " .. execTime .. " ms!")

    Bags.FindBagItemFromTemplate()
    if not StringEmpty(SELL_ADD_BAG_ITEM) then
        Bags.AddBag(SELL_ADD_BAG_ROOT, Osi.GetHostCharacter(), 1)
    end

    if CONFIG.ENABLE_LOGGING == 1 then
        Files.FlushLogBuffer()
    end
    UpdateBagInfoScreenWithConfig()
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", start)

Ext.Events.ResetCompleted:Subscribe(start)
