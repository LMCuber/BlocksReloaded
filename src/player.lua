Vec2 = require("src.Vec2")

-- constants
BlockAction = {
    PLACE = 0,
    BREAK = 1,
    NONE = 2,
}

-- events
function love.mousepressed(mouse_x, mouse_y, button)
    if button == 1 then
        player.mouse_down = true
        player.block_action = BlockAction.BREAK
    end
end

function love.mousereleased(mouse_x, mouse_y, button)
    if button == 1 then
        player.mouse_down = false
    end
end

-- player class
local Player = {}
Player.__index = Player

function Player:new(world)
    local obj = {
        world = world,
        pos = Vec2:new(0, 0),
        vel = Vec2:new(0, 0),
        hitbox = Hitbox:new(BS, BS),
        jump_vel = -600,
        speed = 350,
        coyote = 0.15,
        mouse_down,
        block_action = BlockAction.NONE,
    }
    obj.jump_capture = nil
    obj.ground_capture = nil

    setmetatable(obj, Player)
    return obj
end

function Player:process_keypress(key)
    if key == "w" then
        -- check if grounded
        if self.vel.y == 0 then
            self.vel.y = self.jump_vel

        -- check if coyote timer is small enough
        elseif love.timer.getTime() - self.ground_capture <= self.coyote then
            self.vel.y = self.jump_vel

        else
            -- save jump capture (buffer)
            self.jump_capture = love.timer.getTime()
        end
    end
end

function Player:update(dt, scroll)
    self:move(dt, scroll)
    self:interact(scroll)
end

function Player:draw(scroll)
    love.graphics.rectangle("fill", self.pos.x, self.pos.y, BS, BS)
end

function Player:interact(scroll)
    if self.mouse_down then
        if self.block_action == BlockAction.BREAK then
            local mx, my = love.mouse.getPosition()
        local key, block_x, block_y = self.world:mouse_to_block(mx, my, scroll)
            self.world:break_(key, block_x, block_y)
        end
    end
end

function Player:move(dt, scroll)
    -- process jump capture
    if self.vel.y == 0 and self.jump_capture ~= nil and love.timer.getTime() - self.jump_capture <= self.coyote then
        self.vel.y = self.jump_vel
        self.jump_capture = nil
    end

    -- Y-COLLISION
    self.vel.y = self.vel.y + _G.GRAVITY * dt
    self.pos.y = self.pos.y + self.vel.y * dt

    for _, block_pos in ipairs(self.world:get_blocks_around_pos(
        self.pos.x + self.hitbox.w / 2,
        self.pos.y + self.hitbox.h / 2
    )) do
        local block_hitbox = comp.Hitbox:new(BS, BS)

        if self.hitbox:aabb(self.pos.x, self.pos.y, block_hitbox, block_pos.x, block_pos.y) then
            if self.vel.y > 0 then
                self.pos.y = block_pos.y - self.hitbox.h
            else
                self.pos.y = block_pos.y + BS
            end
            self.vel.y = 0
            self.ground_capture = love.timer.getTime()
        end
    end

    -- X-COLLISION
    local moved = false
    if love.keyboard.isDown("a") then
        self.vel.x = -self.speed
        moved = true
    end
    if love.keyboard.isDown("d") then
        self.vel.x = self.speed
        moved = true
    end
    if not moved then
        self.vel.x = 0
    end
    self.pos.x = self.pos.x + self.vel.x * dt

    for _, block_pos in ipairs(self.world:get_blocks_around_pos(
        self.pos.x + self.hitbox.w / 2,
        self.pos.y + self.hitbox.h / 2
    )) do
        local block_hitbox = comp.Hitbox:new(BS, BS)

        if self.hitbox:aabb(self.pos.x, self.pos.y, block_hitbox, block_pos.x, block_pos.y) then
            if self.vel.x > 0 then
                self.pos.x = block_pos.x - self.hitbox.w
            else
                self.pos.x = block_pos.x + BS
            end
            self.vel.x = 0
        end
    end

    -- print(self.pos.x - scroll.x)
    
end

return Player
