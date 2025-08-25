Vec2 = require("src.Vec2")

-- C O M P O N E N T S
Transform = {}
Transform.__index = Transform
Transform._name = "Transform"

function Transform:new(pos, vel, gravity, sines, rot, rot_vel)
    local obj = setmetatable({}, Transform)

    obj.pos = pos
    obj.vel = vel
    obj.gravity = gravity or 100
    obj.acc = Vec2:new(0, 0)
    obj.active = true
    obj.sines = Vec2:new(0, 0)
    obj.rot = rot or 0
    obj.rot_vel = rot_vel or 0
    
    obj.def_vel = vel:copy()
    obj.last_tile = nil
    obj.last_blocks_around = nil

    if obj.sines.x ~= 0 or obj.sines.y ~= 0 then
        obj.sine_offsets = Vec2:new(
            math.random() * 2 * math.pi,
            math.random() * 2 * math.pi
        )
    end
    
    return obj
end

Sprite = {}
Sprite.__index = Sprite
Sprite._name = "Sprite"

function Sprite:from_path(path)
    local obj = setmetatable({}, Sprite)

    obj.path = path
    obj.anim_skin, obj.anim_mode = path:match(".*/(.-)/(.-)%.png$")  -- (portal, idle)

    obj.img = love.graphics.newImage(path)
    obj.anim = 1
    return obj

end

Hitbox = {}
Hitbox.__index = Hitbox
Hitbox._name = "Hitbox"

function Hitbox:new(w, h)
    local obj = setmetatable({}, Hitbox)

    obj.w, obj.h = w, h
    
    return obj
end

function Hitbox:late()
    local obj = setmetatable({}, Hitbox)

    obj.late = true

    return obj
end

function Hitbox:aabb(x, y, other, ox, oy)
    return x < ox + other.w and
        x + self.w > ox and
        y < oy + other.h and
        y + self.h > oy
end

function Hitbox:__tostring()
    return string.format("Hitbox(%d, %d)", self.w, self.h)
end

entity = {
    Transform = Transform,
    Sprite = Sprite,
    Hitbox = Hitbox,
}


return entity
