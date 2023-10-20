Config = {}
Config.initDone = false
--Lazy
Config.config_tbl = {MOD_ENABLED = 1}
Config.selllist = {}
Config.keeplist = {}

Config.config_json_file_path = "config.json"
Config.junk_table_json_file_path = "junk_list.json"
Config.keeplist_json_file_path = "keep_list.json"
Config.selllist_json_file_path = "sell_list.json"
Config.logPath = "logs.txt"

FolderName = "Fall_AutoSeller"
MODVERSION=Ext.Mod.GetMod("0662253d-1cbf-479f-80c2-5878c6eb5a80").Info.ModVersion
Config.CurrentVersion = MODVERSION[2].."."..MODVERSION[1]..".".."0".."."..MODVERSION[4]
-- TODO basically log level selector, rename it later
DEBUG_MESSAGES = 3
-- TODO REMINDER use string.format for everything
-- -------------------------------------------------------------------------- --
--                               Default tables                               --
-- -------------------------------------------------------------------------- --

Config.default_config_tbl = {
    VERSION = Config.CurrentVersion,
    SELL_VALUE_PERCENTAGE = 40,
    ENABLE_LOGGING = 0,
    MOD_ENABLED = 1,
    DEBUG_MESSAGES = 3,
    FIX_MODE = 0,
    GIVE_BAG = 1,
    CUSTOM_LISTS_ONLY = 0,
    BAG_SELL_MODE_ONLY = 0,
}

Config.default_junk = {
    JUNKTABLE = JUNKTABLE
}

Config.default_sell = {
    SELLLIST = {}
}

Config.default_keep = {
    KEEPLIST = {}
}
-- -------------------------------------------------------------------------- --
--                             Config IO functions                            --
-- -------------------------------------------------------------------------- --

function Config.SaveConfig(filePath, config)
    local success, error_message = pcall(function()
        BasicPrint("Config.SaveConfig() - Config file saved")
        BasicDebug(config)
        JSON.LuaTableToFile(config, filePath)
    end)

    if not success then BasicWarning("Config.SaveConfig() - " .. error_message) end
end

function Config.LoadConfig(filePath)
    local config = {}

    local success, error_message = pcall(function()
        config = JSON.LuaTableFromFile(filePath) or {}
    end)

    if not success then
        BasicWarning("Config.LoadConfig() - " .. error_message)
        config = {}
    end

    return config
end
---@param config table Configuration table
---@param key string Key we're trying to get the value from
---@return ... The Key value
function Config.GetValue(config, key)
    if config[key] ~= nil then
        return config[key]
    else
        BasicError("GetValue() - The following key was not found : " .. key)
        BasicError(config)
        return nil
    end
end

function Config.SetValue(config, key, value)
    config[key] = value
end

-- TODO Better name, make a separate function to validate the lists
function EnsureAllListsExist()
    BasicPrint("EnsureAllListsExist() - Doing the ensuring")
    local sellExists = Files.Load(Config.selllist_json_file_path)
    local keepExists = Files.Load(Config.keeplist_json_file_path)
    local junkExists = Files.Load(Config.junk_table_json_file_path)

    -- Create selllist if it doesn't exist
    if not sellExists then
        Config.InitDefaultFilterList(Config.selllist_json_file_path, Config.default_sell)
    else
        -- Validate selllist structure
        local selllist = Config.LoadConfig(Config.selllist_json_file_path)
        if not selllist or not selllist.SELLLIST or type(selllist.SELLLIST) ~= "table" or not Table.IsValidSet(selllist.SELLLIST) then
            BasicWarning("EnsureAllListsExist() - Invalid selllist structure detected. Reinitializing...")
            Config.InitDefaultFilterList(Config.selllist_json_file_path, Config.default_sell)
        end
    end

    -- Create keeplist if it doesn't exist
    if not keepExists then
        Config.InitDefaultFilterList(Config.keeplist_json_file_path, Config.default_keep)
    else
        -- Validate keeplist structure
        local keeplist = Config.LoadConfig(Config.keeplist_json_file_path)
        if not keeplist or not keeplist.KEEPLIST or type(keeplist.KEEPLIST) ~= "table" or not Table.IsValidSet(keeplist.KEEPLIST) then
            BasicWarning("EnsureAllListsExist() - Invalid keeplist structure detected. Reinitializing...")
            Config.InitDefaultFilterList(Config.keeplist_json_file_path, Config.default_keep)
        end
    end

    -- Create junklist if it doesn't exist, we don't really care if this table is valid or not it's just something we dump for users to look at
    if not junkExists then
        -- Avoid console spam
        local previousDBGValue = DEBUG_MESSAGES
        DEBUG_MESSAGES = 0
        Config.InitDefaultFilterList(Config.junk_table_json_file_path, Config.default_junk)
        DEBUG_MESSAGES = previousDBGValue
    end
end

function CheckConfigStructure(config)
    local configChanged = false
    local defaultConfig = Config.default_config_tbl
    -- Write the missing keys
    for key, value in pairs(defaultConfig) do
        if config[key] == nil then
            config[key] = value
            BasicWarning("CheckConfigStructure() - Added missing key : " .. key .. " to the configuration file")
            configChanged = true
        end
    end
    -- Check if value type is correct
    for key, value in pairs(defaultConfig) do
        if type(config[key]) ~= type(value) then
            BasicWarning(string.format("CheckConfigStructure() - Config key '%s' has incorrect type. Reverting to default.", key))
            config[key] = value
            configChanged = true
        end
    end
    -- If anything had to change, also update the actual file
    if configChanged then
        BasicPrint("CheckConfigStructure() - Config repaired!")
        Config.SaveConfig(Config.config_json_file_path, config)
    end
    -- Return the potentially repaired table :')
    return config
end

-- Shouldn't be called too often if ever, fine to manually do the things when needed
function Config.UpgradeConfig(config)
    config["VERSION"] = Config.CurrentVersion
    -- For the config version 1 to 2 update
    if Config.CurrentVersion == "2" then
        if config["DEBUG_MESSAGES"] == 0 then
            config["DEBUG_MESSAGES"] = 3
        elseif config["DEBUG_MESSAGES"] == 1 then
            config["DEBUG_MESSAGES"] = 4
        end
    end
    Config.SaveConfig(Config.config_json_file_path, config)
end

-- -------------------------------------------------------------------------- --
--                          Initialization functions                          --
-- -------------------------------------------------------------------------- --

function Config.InitDefaultConfig(filePath, defaultConfig)
    BasicDebug("Config.InitDefaultConfig() - Creating default config file at :" .. filePath)
    Config.SaveConfig(filePath, defaultConfig)
end

function Config.InitDefaultFilterList(filePath, list)
    BasicDebug("Config.InitDefaultFilterList() - Creating default filter list file at :" .. filePath)
    Config.SaveConfig(filePath, list)
end

function Config.LoadUserLists()
    BasicPrint("Config.LoadUserLists() - Loading user filter lists...")
    Config.keeplist = Config.LoadConfig(Config.keeplist_json_file_path)
    -- In theory, this isn't possible since we call EnsureAllListsExist before but you never know...
    if not Config.keeplist then
        BasicError("Config.LoadUserLists() - keeplist wasn't valid, generating a blank one...")
        Config.InitDefaultFilterList(Config.keeplist_json_file_path, Config.default_keep)
    end
    Config.selllist = Config.LoadConfig(Config.selllist_json_file_path)
    if not Config.selllist then
        BasicError("Config.LoadUserLists() - selllist wasn't valid, generating a blank one...")
        Config.InitDefaultFilterList(Config.selllist_json_file_path, Config.default_sell)
    end
    BasicPrint("Config.LoadUserLists() - User lists loaded!")
end

function Config.Init()
    Files.ClearLogFile()
    -- Until we read the user's log level just pretend it's the default one
    DEBUG_MESSAGES = Config.default_config_tbl["DEBUG_MESSAGES"]
    BasicPrint("Config.Init() - Automatic loot seller by FallenStar VERSION : "..Config.CurrentVersion.." starting up... ")
    local loadedConfig = Files.Load(Config.config_json_file_path)
    -- Check if the config file doesn't exist, Initialize it
    if not loadedConfig then Config.InitDefaultConfig(Config.config_json_file_path, Config.default_config_tbl) end
    -- Load its contents
    BasicPrint("Config.Init() - Loading config from Config.json")
    local loaded = Config.LoadConfig(Config.config_json_file_path)
    -- Check the Config Structure and correct it if needed, using default value for missing keys / wrong types
    loaded = CheckConfigStructure(loaded)
    DEBUG_MESSAGES = Config.GetValue(loaded, "DEBUG_MESSAGES")
    -- Exist and are valid and pretty and... Yeah I need to break this up
    EnsureAllListsExist()
    -- Check if version is different, upgrade if it is and redump the junk list because why not
    -- Honestly not sure If dumping the junklist is of any uses other than giving a good template for users
    -- If this can keep some 30 IQ handi from writting strings line by line in the pre formated lists files no harm keeping it...
    if loaded["VERSION"] ~= Config.CurrentVersion then
        BasicWarning("Config.Init() - Detected version mismatch, upgrading file...")
        Config.UpgradeConfig(loaded)
        Config.InitDefaultFilterList(Config.junk_table_json_file_path, Config.default_junk)
        Config.config_tbl = loaded
    else
        BasicPrint("Config.Init() - VERSION check passed")
        Config.config_tbl = loaded
    end
    BasicDebug("Config.Init() - DEBUG MESSAGES ARE ENABLED")
    Config.LoadUserLists()
    Config.initDone = true
end
