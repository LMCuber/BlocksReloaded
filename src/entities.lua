Vec2 = require("src.Vec2")

Transform = {}
Transform.__index = Transform

function Transform:new(pos, vel, gravity, sines, rot, rot_vel)
    self._name = "Transform"

    local self = setmetatable({}, Transform)
    
    self.pos = pos
    self.vel = vel
    self.gravity = gravity or 0.1
    self.acc = Vec2:new(0, 0)
    self.active = true
    self.sines = Vec2:new(0, 0)
    self.rot = rot or 0
    self.rot_vel = rot_vel or 0
    
    self.def_vel = vel:copy()
    self.last_tile = nil
    self.last_blocks_around = nil

    if self.sines.x ~= 0 or self.sines.y ~= 0 then
        self.sine_offsets = Vec2:new(
            math.random() * 2 * math.pi,
            math.random() * 2 * math.pi
        )
    end
    
    return self
end

entity = {
    Transform = Transform,
}

return entity
