local Vec3 = {}
Vec3.__index = Vec3

-- Constructor
function Vec3:new(x, y, z)
    local v = setmetatable({x = x or 0, y = y or 0, z = z or 0}, self)
    return v
end

-- Copy
function Vec3:copy()
    return Vec3:new(self.x, self.y, self.z)
end

-- Basic operations
function Vec3:add(other)
    return Vec3:new(self.x + other.x, self.y + other.y, self.z + other.z)
end

function Vec3:sub(other)
    return Vec3:new(self.x - other.x, self.y - other.y, self.z - other.z)
end

function Vec3:scale(scalar)
    return Vec3:new(self.x * scalar, self.y * scalar, self.z * scalar)
end

function Vec3:div(scalar)
    return Vec3:new(self.x / scalar, self.y / scalar, self.z / scalar)
end

function Vec3:neg()
    return Vec3:new(-self.x, -self.y, -self.z)
end

function Vec3:tostring()
    return "(" .. self.x .. ", " .. self.y .. ", " .. self.z .. ")"
end

-- Metamethods
function Vec3.__add(a, b)
    return Vec3:new(a.x + b.x, a.y + b.y, a.z + b.z)
end

function Vec3.__sub(a, b)
    return Vec3:new(a.x - b.x, a.y - b.y, a.z - b.z)
end

function Vec3.__mul(a, b)
    if type(a) == "number" then
        return Vec3:new(b.x * a, b.y * a, b.z * a)
    elseif type(b) == "number" then
        return Vec3:new(a.x * b, a.y * b, a.z * b)
    else
        error("Can only multiply vector by scalar.")
    end
end

function Vec3.__div(a, b)
    if type(b) == "number" then
        return Vec3:new(a.x / b, a.y / b, a.z / b)
    else
        error("Invalid argument types for vector division.")
    end
end

function Vec3.__eq(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end

function Vec3.__lt(a, b)
    return a.x < b.x and a.y < b.y and a.z < b.z
end

function Vec3.__le(a, b)
    return a.x <= b.x and a.y <= b.y and a.z <= b.z
end

function Vec3.__unm(a)
    return Vec3:new(-a.x, -a.y, -a.z)
end

function Vec3.__tostring(v)
    return "Vec3(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")"
end

return Vec3
