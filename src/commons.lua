local commons = {}

-- globals (use sparingly, we do not want to pollute the global namespace)
_G.GRAVITY = 2300
_G.WIDTH, _G.HEIGHT = love.graphics.getDimensions()

function commons.key(cx, cy)
    return cx .. "," .. cy
end

function commons.parse_key(key)
    local cx, cy = key:match("(-?%d+),(-?%d+)")
    return tonumber(cx), tonumber(cy)
end

function _G.test(...)
    print(love.math.random(0, 999), ...)
end

function _G.pprint(tbl, indent)
    indent = indent or 0
    local formatting = string.rep("  ", indent)

    if type(tbl) ~= "table" then
        print(formatting .. tostring(tbl))
        return
    end

    print(formatting .. "{")
    for k, v in pairs(tbl) do
        local key = tostring(k)
        if type(v) == "table" then
            io.write(formatting .. "  " .. key .. " = ")
            pprint(v, indent + 1)
        else
            print(formatting .. "  " .. key .. " = " .. tostring(v))
        end
    end
    print(formatting .. "}")
end

-- useful functions
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

function commons.rand_rgb()
    local color = {}
    for _ = 1, 3 do
        table.insert(color, love.math.random())
    end
    return color
end

function commons.unpack(t, i)
    i = i or 1
    if t[i] == nil then return end
    return t[i], unpack(t, i + 1)
end

function commons.extend(t1, t2)
    for _, e2 in ipairs(t2) do
        table.insert(t1, e2)
    end
end

function commons.split(str, sep)
    local result = {}
    local pattern = "([^" .. sep .. "]+)"
    
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end
    
    return result
end

function commons.contains(tbl, element)
    for _, value in ipairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

function commons.remove_by_key(tbl, element)
    for i, v in ipairs(tbl) do
        if v == element then
            table.remove(tbl, i)
            break
        end
    end
end

function commons.startswith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

function commons.map(tbl, func)
    local result = {}
    for i, v in ipairs(tbl) do
        result[i] = func(v)
    end
    return result
end

function commons.sum(tbl)
    local total = 0
    for _, value in ipairs(tbl) do
        total = total + value
    end
    return total
end

return commons