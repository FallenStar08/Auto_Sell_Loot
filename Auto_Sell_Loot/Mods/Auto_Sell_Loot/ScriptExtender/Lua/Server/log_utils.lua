
local function custom_floor(x)
    return x - x % 1
end

local function GetTimestamp()
    local time = Ext.Utils.MonotonicTime()
    local milliseconds = time % 1000
    local seconds = custom_floor(time / 1000) % 60
    local minutes = custom_floor((time / 1000) / 60) % 60
    local hours = custom_floor(((time / 1000) / 60) / 60) % 24
    return string.format("[%02d:%02d:%02d.%03d]",
        hours, minutes, seconds, milliseconds)
end

function Files.LogMessage(message)
        local logMessage = GetTimestamp() .. " " .. message
        Files.AppendToLog(logMessage)
end

function Files.AppendToLog(content)
    local logPath = Config.logPath
    local fileContent = Files.Load(logPath) or ""
    Files.Save(logPath, fileContent .. content .. "\n")
end

function Files.ClearLogFile()
    local logPath = Config.logPath
    Files.Save(logPath, "")
end