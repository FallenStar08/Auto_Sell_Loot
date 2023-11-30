SellList = {}
KeepList = {}

_G.default_sell = {
    SELLLIST = {}
}

_G.default_keep = {
    KEEPLIST = {}
}


function GetSellPath()
    BasicDebug("GetSellPath()")
    local sellPath=Paths.selllist_json_file_path
    if PersistentVars.useSaveSpecificSellList == true then
        --Save specific list
        sellPath = "sell_list_id_"..PersistentVars.saveIdentifier..".json"
    end
    BasicDebug(string.format("GetSellPath() - Sell path : %s",sellPath))
    return sellPath
end

---Ensure all of our lists exist and create them if not, also validate their structure.
local function ensureAllListsExist()
    BasicPrint("EnsureAllListsExist() - Doing the ensuring")
    local sellExists,keepExists,junkExists = false,false,false
    local sellPath,keepPath,junkPath=GetSellPath(),Paths.keeplist_json_file_path,Paths.junk_table_json_file_path
    sellExists = Files.Load(sellPath)
    keepExists = Files.Load(keepPath)
    junkExists = Files.Load(junkPath)
    -- Create selllist if it doesn't exist
    if not sellExists then
        InitDefaultFilterList(sellPath, default_sell)
    else
        -- Validate selllist structure
        local selllist = JSON.LuaTableFromFile(sellPath)
        if not selllist or not selllist.SELLLIST or type(selllist.SELLLIST) ~= "table" or not Table.IsValidSet(selllist.SELLLIST) then
            BasicWarning("EnsureAllListsExist() - Invalid selllist structure detected. Reinitializing...")
            InitDefaultFilterList(sellPath, default_sell)
        end
    end

    -- Create keeplist if it doesn't exist
    if not keepExists then
        InitDefaultFilterList(keepPath, default_keep)
    else
        -- Validate keeplist structure
        local keeplist = JSON.LuaTableFromFile(keepPath)
        if not keeplist or not keeplist.KEEPLIST or type(keeplist.KEEPLIST) ~= "table" or not Table.IsValidSet(keeplist.KEEPLIST) then
            BasicWarning("EnsureAllListsExist() - Invalid keeplist structure detected. Reinitializing...")
            InitDefaultFilterList(keepPath, default_keep)
        end
    end

    -- Create junklist if it doesn't exist, we don't really care if this table is valid or not it's just something we dump for users to look at
    if not junkExists then
        -- Avoid console spam
        local previousDBGValue = DEBUG_MESSAGES
        DEBUG_MESSAGES = 0
        InitDefaultFilterList(junkPath, JUNKTABLE)
        DEBUG_MESSAGES = previousDBGValue
    end
end







---Initialize a filter list and save it
---@param filePath string path to the list
---@param table table the list to initialize
function InitDefaultFilterList(filePath, table)
    BasicDebug("InitDefaultFilterList() - Creating default filter list file at :" .. filePath)
    JSON.LuaTableToFile(table, filePath)
end

function LoadUserLists()
    local sellPath,keepPath=GetSellPath(),Paths.keeplist_json_file_path
    BasicPrint("LoadUserLists() - Loading user filter lists...")
    KeepList = JSON.LuaTableFromFile(keepPath)
    -- In theory, this isn't possible since we call EnsureAllListsExist before but you never know...
    if not KeepList then
        BasicError("LoadUserLists() - keeplist wasn't valid, generating a blank one...")
        InitDefaultFilterList(Paths.keeplist_json_file_path,default_keep)
    end
    SellList = JSON.LuaTableFromFile(sellPath)
    if not SellList then
        BasicError("LoadUserLists() - selllist wasn't valid, generating a blank one...")
        InitDefaultFilterList(Paths.selllist_json_file_path, default_sell)
    end
    BasicPrint("LoadUserLists() - User lists loaded!")
end

function InitFilters()
    ensureAllListsExist()
    LoadUserLists()
end

