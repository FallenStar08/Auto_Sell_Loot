-- -------------------------------------------------------------------------- --
--                             List & Table stuff                             --
-- -------------------------------------------------------------------------- --
Table = {}

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
