local commons = {}

function commons.intersect_n(...)
    local tables = {...}
    local counts = {}
    local result = {}
    local n = #tables

    -- Count occurrences
    for _, tbl in ipairs(tables) do
        local seen = {}
        for _, v in ipairs(tbl) do
            -- avoid counting duplicates within the same table
            if not seen[v] then
                counts[v] = (counts[v] or 0) + 1
                seen[v] = true
            end
        end
    end

    -- Keep items present in all tables
    for k, v in pairs(counts) do
        if v == n then
            table.insert(result, k)
        end
    end

    return result
end

function commons.unpack(t, i)
    i = i or 1
    if t[i] == nil then return end
    return t[i], unpack(t, i + 1)
end

function commons.extend(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
end

return commons