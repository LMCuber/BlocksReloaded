local Vec2 = {}
Vec2.__index = Vec2

function Vec2:new(x, y)
    local v = setmetatable({x = x or 0, y = y or 0}, self)
    return v
end

function Vec2:copy()
    return Vec2:new(self.x, self.y)
end

function Vec2:add(other)
    return Vec2:new(self.x + other.x, self.y + other.y)
end

function Vec2:sub(other)
    return Vec2:new(self.x - other.x, self.y - other.y)
end

function Vec2:scale(scalar)
    return Vec2:new(self.x * scalar, self.y * scalar)
end

function Vec2:div(scalar)
    return Vec2:new(self.x / scalar, self.y / scalar)
end

function Vec2:neg()
    return Vec2:new(-self.x, -self.y)
end

function Vec2:tostring()
    return "(" .. self.x .. ", " .. self.y .. ")"
end

-- metamethods (still require explicit arguments)
function Vec2.__add(a, b)
    return Vec2:new(a.x + b.x, a.y + b.y)
end

function Vec2.__sub(a, b)
    return Vec2:new(a.x - b.x, a.y - b.y)
end

function Vec2.__mul(a, b)
    if type(a) == "number" then
        return Vec2:new(b.x * a, b.y * a)
    elseif type(b) == "number" then
        return Vec2:new(a.x * b, a.y * b)
    else
        error("Can only multiply vector by scalar.")
    end
end

function Vec2.__div(a, b)
    if type(b) == "number" then
        return Vec2:new(a.x / b, a.y / b)
    else
        error("Invalid argument types for vector division.")
    end
end

function Vec2.__eq(a, b)
    return a.x == b.x and a.y == b.y
end

function Vec2.__lt(a, b)
    return a.x < b.x and a.y < b.y
end

function Vec2.__le(a, b)
    return a.x <= b.x and a.y <= b.y
end

function Vec2.__unm(a)
    return Vec2:new(-a.x, -a.y)
end

function Vec2.__tostring(v)
    return "(" .. v.x .. ", " .. v.y .. ")"
end

return Vec2
