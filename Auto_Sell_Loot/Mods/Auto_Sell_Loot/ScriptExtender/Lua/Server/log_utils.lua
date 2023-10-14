local logBuffer = "" -- Initialize an empty log buffer
local logBufferMaxSize = 512 -- Maximum buffer size before flushing

function Custom_floor(x)
    return x - x % 1
end

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
    Files.Save(logPath, "")
end