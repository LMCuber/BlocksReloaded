local commons = {}

-- globals (use sparingly, we do not want to pollute the global namespace)
_G.GRAVITY = 2600
_G.WIDTH, _G.HEIGHT = love.graphics.getDimensions()

function _G.test(...)
    print(love.math.random(0, 999), ...)
end

function _G.iprint(tbl)
    for _, elem in ipairs(tbl) do
        print(elem)
    end
end

-- LLM code
function _G.pprint(value, indent, visited)
    indent = indent or 0
    visited = visited or {}

    local spacing = string.rep("  ", indent)

    if type(value) ~= "table" then
        print(spacing .. tostring(value))
        return
    end

    if visited[value] then
        print(spacing .. "<circular reference>")
        return
    end

    visited[value] = true
    print(spacing .. "{")

    for k, v in pairs(value) do
        local key
        if type(k) == "string" then
            key = string.format("%q", k)
        else
            key = tostring(k)
        end

        io.write(spacing .. "  [" .. key .. "] = ")

        if type(v) == "table" then
            pprint(v, indent + 1, visited)
        else
            print(tostring(v))
        end
    end

    print(spacing .. "}")
end

function _G.bar()
    print("--------------------------------------------------------------------------------------")
end

-- useful functions
function commons.key(cx, cy)
    return cx .. "," .. cy
end

function commons.parse_key(key)
    local cx, cy = key:match("(-?%d+),(-?%d+)")
    return tonumber(cx), tonumber(cy)
end

function commons.round_to(x, step)
    return math.floor(x / step + 0.5) * step
end

function commons.cartesian(a, b)
    local result = {}
    for i = 1, #a do
        for j = 1, #b do
            table.insert(result, {a[i], b[j]})
        end
    end
    return result
end

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

function commons.filter(tbl, predicate)
    local result = {}
    for i, v in ipairs(tbl) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
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

function commons.length(v)
    local sum = 0
    for i = 1, #v do
        sum = sum + v[i] * v[i]
    end
    return math.sqrt(sum)
end

-- LLM
function commons.collidepointmouse(rx, ry, rw, rh)
    local px, py = love.mouse.getPosition()
    return px >= rx and
           px <= rx + rw and
           py >= ry and
           py <= ry + rh
end

return commons