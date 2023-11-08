JSON = {}
Files = {}
Table = {}
Messages = {}

PrintTypes = {
    INFO = 1,
    ERROR = 2,
    WARNING = 3,
    DEBUG = 4
}

local printError = Ext.Utils.PrintError
local printWarning = Ext.Utils.PrintWarning
-- -------------------------------------------------------------------------- --
--                             Messages functions                             --
-- -------------------------------------------------------------------------- --
function ConcatPrefix(prefix, message)
    local paddedPrefix = prefix .. string.rep(" ", MAX_PREFIX_LENGTH - #prefix) .. " : "

    if type(message) == "table" then
        local serializedMessage = JSON.Stringify(message)
        return paddedPrefix .. serializedMessage
    else
        return paddedPrefix .. tostring(message)
    end
end

--Blatantly stolen from KvCampEvents, mine now
local function ConcatOutput(...)
    local varArgs = { ... }
    local outStr = ""
    local firstDone = false
    for _, v in pairs(varArgs) do
        if not firstDone then
            firstDone = true
            outStr = tostring(v)
        else
            outStr = outStr .. " " .. tostring(v)
        end
    end
    return outStr
end

-- Function to print text with custom colors, message type, custom prefix, rainbowText ,and prefix length
function BasicPrint(content, messageType, textColor, customPrefix, rainbowText, prefixLength)
    prefixLength=prefixLength or 15
    messageType = messageType or "INFO"
    local textColorCode = textColor or TEXT_COLORS.cyan -- Default to cyan
    customPrefix = customPrefix or MOD_NAME

    if Config.config_tbl.LOG_ENABLED == 1 then
        Files.LogMessage(ConcatOutput(ConcatPrefix(customPrefix .. "  [" .. messageType .. "]", content)))
    end

    if DEBUG_MESSAGES <= 0 then
        return
    end

    if PrintTypes[messageType] and DEBUG_MESSAGES >= PrintTypes[messageType] then
        local padding = string.rep(" ", prefixLength - #customPrefix)
        local message = ConcatOutput(ConcatPrefix(customPrefix .. padding .. "  [" .. messageType .. "]", content))
        local coloredMessage = rainbowText and GetRainbowText(message) or string.format("\x1b[%dm%s\x1b[0m", textColorCode, message)
        if messageType == "ERROR" then
            printError(coloredMessage)
        elseif messageType == "WARNING" then
            printWarning(coloredMessage)
        else
            print(coloredMessage)
        end
    end
end

function BasicError(content)
    BasicPrint(content, "ERROR")
end

function BasicWarning(content)
    BasicPrint(content, "WARNING")
end

function BasicDebug(content)
    BasicPrint(content, "DEBUG")
end

function GetRainbowText(text)
    local colors = { "31", "33", "32", "36", "35", "34" } -- Red, Yellow, Green, Cyan, Magenta, Blue
    local coloredText = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        local color = colors[i % #colors + 1]
        coloredText = coloredText .. string.format("\x1b[%sm%s\x1b[0m", color, char)
    end
    return coloredText
end

-- ------------------------------------------------------------------------------------------------------
-- File I/O Stuff credit to the kv camp event author, I basically just made their code/functions worse --
-- ------------------------------------------------------------------------------------------------------

function Files.Save(path, content)
    path = Files.Path(path)
    return Ext.IO.SaveFile(path, content)
end

function Files.Load(path)
    path = Files.Path(path)
    return Ext.IO.LoadFile(path)
end

function Files.Path(filePath)
    return FOLDER_NAME .. "/" .. filePath
end

function JSON.Parse(json_str)
    return Ext.Json.Parse(json_str)
end

function JSON.Stringify(data)
    return Ext.Json.Stringify(data)
end

-- Move content of file to new file
-- Clear content of file
--"Move" is probably not the right term but who cares
function Files.Move(oldPath, newPath)
    local content = Files.Load(oldPath)
    if content then
        Files.Save(newPath, content)
        Files.Save(oldPath, "")
        return true
    else
        BasicError("Files.Move() - Failed to read file from oldPath: '" .. (oldPath or "") .. "'")
        return false
    end
end

function JSON.LuaTableToFile(lua_table, filePath)
    local json_str = JSON.Stringify(lua_table)
    Files.Save(filePath, json_str)
end

function JSON.LuaTableFromFile(filePath)
    local json_str = Files.Load(filePath)
    if json_str and json_str ~= "" then
        return JSON.Parse(json_str)
    else
        BasicError("JSON.LuaTableFromFile() - Failed to parse JSON from filePath: '" .. (filePath or "") .. "'")
    end
end

-- -------------------------------------------------------------------------- --
--                                    LOGS                                    --
-- -------------------------------------------------------------------------- --

local logBuffer = ""         -- Initialize an empty log buffer
local logBufferMaxSize = 512 -- Maximum buffer size before flushing
local function GetTimestamp()
    local time = Ext.Utils.MonotonicTime()
    local milliseconds = time % 1000
    local seconds = Custom_floor(time / 1000) % 60
    local minutes = Custom_floor((time / 1000) / 60) % 60
    local hours = Custom_floor(((time / 1000) / 60) / 60) % 24
    return string.format("[%02d:%02d:%02d.%03d]",
        hours, minutes, seconds, milliseconds)
end

function Files.LogMessage(message)
    local logMessage = GetTimestamp() .. " " .. message
    logBuffer = logBuffer .. logMessage .. "\n"

    -- Check if the buffer size exceeds the maximum, then flush it
    if #logBuffer >= logBufferMaxSize then
        Files.FlushLogBuffer()
    end
end

function Files.FlushLogBuffer()
    if logBuffer ~= "" then
        local logPath = Config.logPath
        local fileContent = Files.Load(logPath) or ""
        Files.Save(logPath, fileContent .. logBuffer)
        logBuffer = "" -- Clear the buffer
    end
end

function Files.ClearLogFile()
    local logPath = Config.logPath
    if Files.Load(logPath) then
        Files.Save(logPath, "")
    end
end

-- -------------------------------------------------------------------------- --
--                             List & Table stuff                             --
-- -------------------------------------------------------------------------- --

-- Function to check if a value exists in a table, maybe only use sets? Will change later
function Table.CheckIfValueExists(tbl, value)
    for i, v in ipairs(tbl) do if v == value then return true end end
    return false
end

function Table.CompareSets(set1, set2)
    local result = {}

    for name, uid in pairs(set1) do
        if not set2[name] then
            result[name] = uid
        end
    end

    if next(result) == nil then
        return {}
    else
        return result
    end
end

function Table.IsValidSet(set)
    local isValid = true
    if not set then
        isValid = false
    else
        for k, v in pairs(set) do
            if type(k) ~= "string" or type(v) ~= "string" then
                BasicWarning("IsValidSet() - Set isn't valid : ")
                BasicWarning(set)
                isValid = false
                break
            end
        end
    end
    return isValid
end

function Table.ProcessTables(baseTable, keeplistTable, selllistTable)
    -- User Lists only, clear baseTable
    if Config.config_tbl["CUSTOM_LISTS_ONLY"] >= 1 then baseTable = {} end

    --Merge sell entries to the base list
    for name, uid in pairs(selllistTable) do baseTable[name] = uid end
    --Merge keep entries to the base list
    for name, uid in pairs(keeplistTable) do baseTable[name] = nil end
    BasicDebug("ProcessTables() - Tables processed and set successfully created")
    return baseTable
end

function Table.FindKeyInSet(set, key)
    return set[key] ~= nil
end

-- -------------------------------------------------------------------------- --
--                                    Math                                    --
-- -------------------------------------------------------------------------- --

function Custom_floor(x)
    return x - x % 1
end

-- -------------------------------------------------------------------------- --
--                                    Misc                                    --
-- -------------------------------------------------------------------------- --

function DelayedCall(ms, func)
    local Time = 0
    local handler
    handler = Ext.Events.Tick:Subscribe(function(e)
        Time = Time + e.Time.DeltaTime * 1000 -- Convert seconds to milliseconds

        if (Time >= ms) then
            func()
            Ext.Events.Tick:Unsubscribe(handler)
        end
    end)
end

function IsTransformed(character)
    local entity = Ext.Entity.Get(character)
    local transfoUUID = ""
    local charUUID = ""
    local rootTemplateType = entity.GameObjectVisual.RootTemplateType or 1
    if entity and entity.GameObjectVisual then
        transfoUUID = entity.GameObjectVisual.RootTemplateId
    end
    if entity and entity.Uuid then
        charUUID = entity.Uuid.EntityUuid
    end
    if transfoUUID == charUUID or rootTemplateType == 1 then
        BasicDebug("IsTransformed() False - ")
        BasicDebug({ transfoUUID = transfoUUID, charUUID = charUUID })
        return false, charUUID
    else
        BasicDebug("IsTransformed() True - ")
        BasicDebug({ transfoUUID = transfoUUID, charUUID = charUUID })
        return true, transfoUUID
    end
end

--Call on a temporary character to delete it
function DestroyChar(character)
    Osi.PROC_RemoveAllPolymorphs(character)
    Osi.PROC_RemoveAllDialogEntriesForSpeaker(character)
    Osi.SetImmortal(character, 0)
    Osi.Die(character, 2, "NULL_00000000-0000-0000-0000-000000000000", 0, 0)
    BasicDebug("DestroyChar() - character : " .. character .. " Destroyed, rip :(")
    DelayedCall(250, function()
        Osi.SetOnStage(character, 0)
        Osi.RequestDeleteTemporary(character)
    end)
end

function GetSquadies()
    local squadies = {}
    local players = Osi.DB_Players:Get(nil)
    for _, player in pairs(players) do
        local pattern = "%f[%A]dummy%f[%A]"
        if not string.find(player[1]:lower(), pattern) then
            table.insert(squadies, player[1])
        else
            BasicDebug("Ignoring dummy")
        end
    end
    SQUADIES = squadies
    return squadies
end

function GetSummonies()
    local summonies = {}
    local summons = Osi.DB_PlayerSummons:Get(nil)
    for _, summon in pairs(summons) do
        if #summon[1] > 36 then
            table.insert(summonies, summon[1])
        end
    end
    SUMMONIES = summonies
    return summonies
end

function GetTranslatedName(UUID)
    local success, translatedName = pcall(function()
        return Osi.ResolveTranslatedString(Osi.GetDisplayName(UUID))
    end)

    if success then
        return translatedName
    else
        BasicDebug("Error in GetTranslatedName: " .. translatedName)
        return "No name"
    end
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
