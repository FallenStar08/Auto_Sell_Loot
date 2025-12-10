JUNKTABLE = Ext.Require("Server/junk_table.lua")
Ext.Require("Server/_Filters.lua")

Bags = {}
local SELL_VALUE_COUNTER = 0
local FRACTIONAL_PART = 0
local SEll_LIST_EDIT_MODE = false

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
local function deleteItem(item)
    Osi.RequestDelete(item)
end

--Anti morbing measure, this ain't morbing time
local function IsTransmogInvisible(itemName, item)
    if itemName == "LOOT_GEN_Ring_A_Gem_A_Gold" then
        local statsId = Ext.Entity.Get(item).Data.StatsId
        return statsId ~= "ARM_Ring_A_Gem_A_Gold"
    end
    return false
end

--Update bag description with mod infos
local function UpdateBagInfoScreenWithConfig()
    local modVars = GetModVariables()
    local useSaveSpecificSellList = modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList and
        modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList or "not enabled"
    local saveIdentifier = modVars.Fallen_AutoSellerInfos.saveIdentifier and
        modVars.Fallen_AutoSellerInfos.saveIdentifier or "not enabled"

    local handle = "he671bb1egab4fg4f2bg981egdd0b1e8585af"

    local MCMSettings = GetMCMTable()

    -- Determine the color of each setting based on its value
    local bagSellModeColor = MCMSettings["BAG_SELL_MODE_ONLY"] == true and "green" or
        "red"
    local userListColor = MCMSettings["CUSTOM_LISTS_ONLY"] == true and "green" or "red"
    local markAsWareColor = MCMSettings["MARK_AS_WARE"] == true and "green" or "red"
    local useSaveSpecificSellListColor = modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList and "green" or "red"
    local saveIdentifierColor = modVars.Fallen_AutoSellerInfos.saveIdentifier and "green" or "red"
    local modEnabledColor = MCMSettings["MOD_ENABLED"] == true and "green" or "red"

    -- Convert RGB colors to hexadecimal
    local greenHex = RgbToHex(0, 255, 0)
    local redHex = RgbToHex(255, 0, 0)
    local orangeHex = RgbToHex(255, 165, 0)

    -- Format the strings with appropriate color tags
    local bagSellModeText = string.format("<font color='%s'>%s</font>",
        bagSellModeColor == "green" and greenHex or redHex,
        tostring(MCMSettings["BAG_SELL_MODE_ONLY"] == true))
    local userListText = string.format("<font color='%s'>%s</font>", userListColor == "green" and greenHex or redHex,
        tostring(MCMSettings["CUSTOM_LISTS_ONLY"] == true))
    local markAsWareText = string.format("<font color='%s'>%s</font>", markAsWareColor == "green" and greenHex or redHex,
        tostring(MCMSettings["MARK_AS_WARE"] == true))
    local useSaveSpecificSellListText = string.format("<font color='%s'>%s</font>",
        useSaveSpecificSellListColor == "green" and greenHex or orangeHex, useSaveSpecificSellList)
    local saveIdentifierText = string.format("<font color='%s'>%s</font>",
        saveIdentifierColor == "green" and greenHex or orangeHex, saveIdentifier)
    local modEnabledText = string.format("<font color='%s'>%s</font>", modEnabledColor == "green" and greenHex or redHex,
        tostring(MCMSettings["MOD_ENABLED"] == true))

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
    local removedItems = {}
    local bagInv = DeepIterateInventory(_GE(bagItem))
    if bagInv and next(bagInv) then
        for uuid, data in pairs(bagInv) do
            local templateGuid = data.template
            local template = Ext.Template.GetTemplate(uuid) or (templateGuid and Ext.Template.GetTemplate(templateGuid)) or
                "0"
            REMOVER_BAG_CONTENT_LIST[template.Name] = GUID(templateGuid)
            deleteItem(uuid)
        end
        Osi.CharacterRemoveTaggedItems(character, FALLEN_TAGS["FALLEN_MARK_FOR_DELETION"], 10000000)
    end
    if next(REMOVER_BAG_CONTENT_LIST) then
        removedItems = Table.CompareSets(SellList["SELLLIST"], REMOVER_BAG_CONTENT_LIST)
    end
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
    for _, player in pairs(SQUADIES) do
        local count = Osi.TemplateIsInInventory(bag, player)
        if count and count >= 1 then
            return
        end
    end
    BasicPrint(string.format("Bags.AddBag() Adding bag : %s to character : %s", bag, character))
    Osi.TemplateAddTo(bag, character, 1, notification)
end

-- Iterate through the inventory of the party members and mark all copies of the item as ware
function Bags.MarkExistingItemsAsWare(root)
    for _, player in pairs(SQUADIES) do
        local squadieInv = DeepIterateInventory(_GE(player))
        if not squadieInv then return end
        for uuid, data in pairs(squadieInv) do
            if data.template == root then
                MarkAsWare(data.entity)
            end
        end
    end
end

function Bags.AddToSellList(item_name, root, item, bagOwner)
    if GetMCM("BAG_SELL_MODE_ONLY") == true then return end
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
    if GetMCM("MARK_AS_WARE") == true then
        DelayedCall(500, function()
            Osi.ToInventory(item, bagOwner, 99999999)
            Bags.MarkExistingItemsAsWare(root)
        end)
    end
end

function Bags.FindBagItemFromTemplate()
    if SELL_ADD_BAG_ITEM == "" then
        BasicDebug("FindBagItemFromTemplate() - Trying to find BAG UUID...")
        for _, player in pairs(SQUADIES) do
            local count = Osi.TemplateIsInInventory(SELL_ADD_BAG_ROOT, player)
            if count and count >= 1 then
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
    local sellValue = itemValue * GetMCM("SELL_VALUE_PERCENTAGE") / 100
    -- Accumulate the sell values
    SELL_VALUE_COUNTER = SELL_VALUE_COUNTER + sellValue
    if SELL_VALUE_COUNTER >= 1 then
        local goldToAdd = math.floor(SELL_VALUE_COUNTER)    --Integer part
        FRACTIONAL_PART = FRACTIONAL_PART + (SELL_VALUE_COUNTER - goldToAdd)
        goldToAdd = goldToAdd + math.floor(FRACTIONAL_PART) -- Fractional part
        AddGoldTo(Owner, goldToAdd)
        BasicDebug("HandleSelling() - Adding " .. goldToAdd .. " Gold to Character")
        --DeleteItem(Character, Item, exactItemAmount)
        deleteItem(Item)
        SELL_VALUE_COUNTER = 0
        FRACTIONAL_PART = FRACTIONAL_PART - math.floor(FRACTIONAL_PART) -- Keep the remaining fractional part for later
        BasicDebug("HandleSelling() - Leftovers " .. FRACTIONAL_PART .. " Gold kept for later")
    else
        --DeleteItem(Character, Item, exactItemAmount)
        deleteItem(Item)
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
    if GetMCM("MOD_ENABLED") == false or not MOD_READY then
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
    if GetMCM("BAG_SELL_MODE_ONLY") == true and inventoryHolder == SELL_ADD_BAG_ITEM then
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

        if JUNKTABLESET[itemName] then
            if Osi.IsContainer(item) == 1 then
                Osi.MoveAllItemsTo(item, inventoryHolder)
            end
            if GetMCM("MARK_AS_WARE") == true then
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
--                                   INIT/TESTING                             --
-- -------------------------------------------------------------------------- --
local function start(level, isEditor)
    --Net.Send("FALLEN_AUTO_LOOT_SELLER", "start()")

    local modVars = GetModVariables()
    if not modVars.Fallen_AutoSellerInfos then
        modVars.Fallen_AutoSellerInfos = {}; SyncModVariables()
    end
    if level == "SYS_CC_I" then return end
    MOD_READY = true
    --if not CONFIG then CONFIG = InitConfig() end
    local execTime = MeasureExecutionTime(function()
        InitFilters()
        SQUADIES = GetSquadies()
        -- Create a set from JUNKTABLE with items from keeplist removed and those from selllist added
        BasicDebug(KeepList)
        BasicDebug(SellList)
        addItemsUsedInModsToKeepListIfLoaded()
        JUNKTABLESET = ProcessTables(JUNKTABLE, KeepList.KEEPLIST, SellList.SELLLIST)
    end)

    BasicDebug("Tables loaded and processed, set successfully created in " .. execTime .. " ms!")
    --TODO This is terrible, rewrite all of this
    Bags.FindBagItemFromTemplate()
    if StringEmpty(SELL_ADD_BAG_ITEM) then
        Bags.AddBag(SELL_ADD_BAG_ROOT, Osi.GetHostCharacter(), 1)
    end
    DelayedCall(333, function()
        Bags.FindBagItemFromTemplate()
    end)

    UpdateBagInfoScreenWithConfig()
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", start)

Ext.Events.ResetCompleted:Subscribe(start)

-- -------------------------------------------------------------------------- --
--                                     MCM                                    --
-- -------------------------------------------------------------------------- --

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(data)
    if not data or data.modUUID ~= MOD_INFO.MOD_UUID or not data.settingId then
        return
    end

    if data.settingId == "SAVE_SPECIFIC_LIST" then
        local modVars = GetModVariables()
        if data.value == true and not modVars.Fallen_AutoSellerInfos.saveIdentifier then
            local random = GenerateUUID()
            modVars.Fallen_AutoSellerInfos.saveIdentifier = random
            modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = true
            InitDefaultFilterList(GetSellPath(), default_sell)
            LoadUserLists()
        elseif data.value == true and modVars.Fallen_AutoSellerInfos.saveIdentifier then
            modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = true
            LoadUserLists()
        elseif data.value == false then
            modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList = false
            LoadUserLists()
        end
    end

    UpdateBagInfoScreenWithConfig()
    SyncModVariables()
end)

--Set the checkbox state for save specific list
Net.ListenFor("Fallen_AutoSell_Checkmark", function()
    local modVars = GetModVariables()
    if modVars.Fallen_AutoSellerInfos.useSaveSpecificSellList == true then
        SetMCM("SAVE_SPECIFIC_LIST", true)
        DFprint("Set checkbox to checked")
    else
        SetMCM("SAVE_SPECIFIC_LIST", false)
        DFprint("Set checkbox to unchecked")
    end
end)

Net.ListenFor("Fallen_Autosell_Button_ClearList", function()
    InitDefaultFilterList(GetSellPath(), default_sell)
    SellList.SELLLIST = {}
    JUNKTABLESET = ProcessTables(JUNKTABLE, KeepList.KEEPLIST, SellList.SELLLIST)
end)
