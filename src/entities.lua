Vec2 = require("src.Vec2")

Transform = {}
Transform.__index = Transform
Transform._name = "Transform"

function Transform:new(pos, vel, gravity, sines, rot, rot_vel)
    local obj = setmetatable({}, Transform)

    obj.pos = pos
    obj.vel = vel
    obj.gravity = gravity or 0.001
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
    obj.img = love.graphics.newImage(path)

    return obj

end

entity = {
    Transform = Transform,
    Sprite = Sprite,
}

return entity
