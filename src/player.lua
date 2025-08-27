local Vec2 = require("src.vec2")
local Color = require("src.color")
-- 
local comp = require("src.components")
local anim = require("src.animation")

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
local Direction = {
    LEFT = 0,
    RIGHT = 1,
    NONE = 2,
}

local Player = {}
Player.__index = Player

function Player:new(world)
    local obj = {
        world = world,
        pos = Vec2:new(0, 0),
        vel = Vec2:new(0, 0),
        anim_skin = "samurai",
        anim_mode = "run",
        jump_vel = -650,
        speed = 350,
        jump_buffer = 0.15,
        coyote = 0.1,
        hitbox = comp.Hitbox:new(50, 70),
        mouse_down = false,
        block_action = BlockAction.NONE,
        direc = Direction.NONE,
    }
    obj.jump_capture = nil
    obj.ground_capture = nil

    obj.sprite = comp.Sprite:from_path(string.format("res/images/player_animations/%s/%s.png", obj.anim_skin, obj.anim_mode))

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
    local anim_data = anim.get(self.anim_skin, self.anim_mode)

    self.sprite.anim = self.sprite.anim + anim_data.speed * _G.dt
    if self.sprite.anim > anim_data.frames + 1 then
        self.sprite.anim = 1
    end

    local quad = anim_data.quads[math.floor(self.sprite.anim)]

    local _, _, img_w, img_h = quad:getViewport()
    img_w = img_w * S
    img_h = img_h * S

    local draw_x = math.floor(self.pos.x + self.hitbox.w / 2 - img_w / 2)
    local draw_y = math.floor(self.pos.y + self.hitbox.h / 2 - img_h / 2)

    love.graphics.draw(
        anim_data.sprs,
        quad,
        draw_x + (self.direc == Direction.LEFT and img_w or 0),
        draw_y, 0,
        (self.direc == Direction.LEFT and -1 or 1) * S,
        S
    )

    -- rendering location
    love.graphics.setColor(Color.CYAN)
    love.graphics.rectangle("line", draw_x, draw_y, img_w, img_h)

    -- hitbox location
    love.graphics.setColor(Color.RED)
    love.graphics.rectangle("line", math.floor(self.pos.x), math.floor(self.pos.y), self.hitbox.w, self.hitbox.h)

    love.graphics.setColor(Color.WHITE)
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
    if self.vel.y == 0 and self.jump_capture ~= nil and love.timer.getTime() - self.jump_capture <= self.jump_buffer then
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
    self.direc = Direction.NONE
    if love.keyboard.isDown("a") then
        self.vel.x = -self.speed
        self.direc = Direction.LEFT
    end
    if love.keyboard.isDown("d") then
        self.vel.x = self.speed
        self.direc = Direction.RIGHT
    end
    if self.direc == Direction.NONE then
        self.vel.x = 0
        self.anim_mode = "idle"
    else
        self.anim_mode = "run"
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
