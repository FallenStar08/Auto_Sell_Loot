local MaxLogFileSize = 1024 * 1024 -- 1MB, adjust as needed
local MessagesSinceLastSizeCheck = 25 -- Always check the first insertion
local SizeCheckInterval = 25 -- Check the log file size every x insertions
local averageLineLength = 100 -- Assuming an average line length, kind of arbitrary

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
    if (Config.config_tbl["ENABLE_LOGGING"] or 0) == 1 then
        local logMessage = GetTimestamp() .. " " .. message
        Files.AppendToLog(logMessage)
        MessagesSinceLastSizeCheck = MessagesSinceLastSizeCheck + 1
        if MessagesSinceLastSizeCheck >= SizeCheckInterval then
            Files.CheckLogFileSize()
            MessagesSinceLastSizeCheck = 0
        end
    end
end

function Files.AppendToLog(content)
    local logPath = Config.logPath
    local fileContent = Files.Load(logPath) or ""
    Files.Save(logPath, fileContent .. content .. "\n")
end

function Files.CheckLogFileSize()
    local logPath = Config.logPath
    local fileSize = Files.GetFileSizeEstimate(logPath)
    if fileSize > MaxLogFileSize then
        if Files.ArchiveAndClearLog(logPath) then
            BasicPrint("CheckLogFileSize() - Log file reached maximum allowed size, archiving")
        else 
            BasicWarning("CheckLogFileSize() - Couldn't archive log file, turning LOGGING OFF until reload")
            Config.SetValue(Config.config_tbl,"ENABLE_LOGGING",0)
        end
    end
end

function Files.ArchiveAndClearLog(logPath)
    --Fuck this shit, hope for the best, not a big deal
    local archiveFileName = "archive_log_" .. Ext.Utils.Random(0,99999999) .. ".txt"
    if Files.Move(logPath, archiveFileName) then
        return true
    else
        return false
    end
end

function Files.GetFileSizeEstimate(filePath)
    local fileContent = Files.Load(filePath)
    if fileContent then
        local lineCount = select(2, fileContent:gsub('\n', '\n'))
        return lineCount * averageLineLength
    else
        return 0
    end
end
