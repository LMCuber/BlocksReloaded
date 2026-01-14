local Vec2 = require("src.libs.vec2")

local comp = {}

-------------------------------------------------

comp.Inventory = {}
comp.Inventory.__index = comp.Inventory
comp.Inventory._name = "Inventory"

function comp.Inventory:new(items)
    return setmetatable({
        items = items,
        index = 1
    }, self)
end

-------------------------------------------------

comp.Intent = {
    NONE  = 0,
    PLACE = 1,
    BREAK = 2,
}

comp.Controllable = {}
comp.Controllable.__index = comp.Controllable
comp.Controllable._name = "Controllable"

function comp.Controllable:new()
    return setmetatable({
        mouse_held = false,
        intent = comp.Intent.NONE,
    }, self)
end

-------------------------------------------------

comp.CameraAnchor = {}
comp.CameraAnchor.__index = comp.CameraAnchor
comp.CameraAnchor._name = "CameraAnchor"

function comp.CameraAnchor:new(speed)
    return setmetatable({
        speed = speed
    }, self)
end

-------------------------------------------------

comp.Transform = {}
comp.Transform.__index = comp.Transform
comp.Transform._name = "Transform"

function comp.Transform:new(pos, vel, gravity, sines, rot, rot_vel)
    local obj = setmetatable({}, self)

    obj.pos = pos
    obj.vel = vel
    obj.direc = 1
    obj.gravity = (gravity or 1) * _G.GRAVITY
    obj.acc = Vec2:new(0, 0)
    obj.active = true
    obj.sines = sines or Vec2:new(0, 0)
    obj.rot = rot or 0
    obj.rot_vel = rot_vel or 0

    obj.def_vel = vel:copy()
    obj.last_tile = nil
    obj.last_blocks_around = nil

    if obj.sines.x ~= 0 or obj.sines.y ~= 0 then
        obj.sine_offsets = Vec2:new(
            love.math.random() * 2 * math.pi,
            love.math.random() * 2 * math.pi
        )
    end

    return obj
end

-------------------------------------------------

comp.Sprite = {}
comp.Sprite.__index = comp.Sprite
comp.Sprite._name = "Sprite"

function comp.Sprite:from_path(path)
    local obj = setmetatable({}, self)

    obj.path = path
    obj.anim_skin, obj.anim_mode = path:match(".*/(.-)/(.-)%.png$")
    obj.img = love.graphics.newImage(path)
    obj.anim = 1

    return obj
end

-------------------------------------------------

comp.Hitbox = {}
comp.Hitbox.__index = comp.Hitbox
comp.Hitbox._name = "Hitbox"

function comp.Hitbox:new(w, h)
    return setmetatable({
        w = w,
        h = h,
        is_dynamic = false
    }, self)
end

function comp.Hitbox:dynamic()
    return setmetatable({
        is_dynamic = true
    }, self)
end

function comp.Hitbox:aabb(x, y, other, ox, oy)
    return x < ox + other.w and
           x + self.w > ox and
           y < oy + other.h and
           y + self.h > oy
end

function comp.Hitbox:__tostring()
    return string.format("Hitbox(%d, %d)", self.w, self.h)
end

-------------------------------------------------

return comp
