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
        x = 0,
        y = 0,
        speed = 1000,
        mouse_down,
        block_action = BlockAction.NONE,
    }
    setmetatable(obj, Player)
    return obj
end

function Player:update(dt, scroll)
    self:move(dt)
    self:interact(scroll)
end

function Player:draw(scroll)
    love.graphics.rectangle("fill", self.x, self.y, 30, 30)
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

function Player:move(dt)
    if love.keyboard.isDown("w") then
        self.y = self.y - self.speed * dt
    end
    if love.keyboard.isDown("s") then
        self.y = self.y + self.speed * dt
    end
    if love.keyboard.isDown("a") then
        self.x = self.x - self.speed * dt
    end
    if love.keyboard.isDown("d") then
        self.x = self.x + self.speed * dt
    end
end

player = Player:new()

return player
