JSON = {}
Files = {}
Messages = {}

PrintTypes = {
    INFO = 1,
    ERROR = 2,
    WARNING = 3,
    DEBUG = 4
}
local printError = Ext.Utils.PrintError
local printWarning = Ext.Utils.PrintWarning
local maxPrefixLength = 25

function ConcatPrefix(prefix, message)
    local paddedPrefix = prefix .. string.rep(" ", maxPrefixLength - #prefix) .. " : "

    if type(message) == "table" then
        local serializedMessage = JSON.Stringify(message)
        return paddedPrefix .. serializedMessage
    else
        return paddedPrefix .. tostring(message)
    end
end

-- Rest of the code remains the same

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

-- -------------------------------------------------------------------------- --
--                             Messages functions                             --
-- -------------------------------------------------------------------------- --

function BasicPrintForced(content)
    print(ConcatOutput(ConcatPrefix("Fallen_AutoSell", content)))
end

function BasicPrint(content, messageType)
    messageType = messageType or "INFO"
    local prefix = "Fallen_AutoSell  [" .. messageType .. "]"
    local formattedMessage = ConcatOutput(ConcatPrefix(prefix, content))

    if Config.config_tbl.ENABLE_LOGGING == 1 then
        Files.LogMessage(formattedMessage)
        if messageType == "ERROR" or messageType == "WARNING" then
            Files.FlushLogBuffer()
        end
    end

    if DEBUG_MESSAGES > 0 and PrintTypes[messageType] and DEBUG_MESSAGES >= PrintTypes[messageType] then
        if messageType == "ERROR" then
            printError(formattedMessage)
        elseif messageType == "WARNING" then
            printWarning(formattedMessage)
        else
            print(formattedMessage)
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
    return FolderName .. "/" .. filePath
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
