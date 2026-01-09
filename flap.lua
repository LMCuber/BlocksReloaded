local neat = require("src.libs.neat")

local Player = {}
Player.__index = Player
function Player:new()
    return setmetatable({
        x = 80,
        y = 10,
        size = 30,
        yvel = 0
    }, self)
end

function Player:draw()
    love.graphics.setColor(1, 0.9, 0.9)
    love.graphics.rectangle("fill", self.x, self.y, self.size, self.size)
end

function Player:update()
    self.yvel = self.yvel + 0.04
    self.y = self.y + self.yvel
end

---------------------------------------------------------------------

--[[
inputs:
    vertical distance to center of gap
    horizontal distance to the pipe
    (all normalized to [0, 1])
]]

local genome = neat.Genome:new(2, 1)

---------------------------------------------------------------------
love.window.setVSync(1)
_G.WIDTH, _G.HEIGHT = love.graphics.getDimensions()

local pipe = {
    x = -1,
    w = 50,
    h = 240,
    gap = 140
}

local players = {}
for _ = 1, 10 do
    table.insert(players, Player:new())
end

function love.draw()
    love.graphics.clear(0.32, 0.45, 0.6)

    love.graphics.setColor(0.54, 0.78, 0.43)
    love.graphics.rectangle("fill", pipe.x, 0, pipe.w, pipe.h)
    love.graphics.rectangle("fill", pipe.x, pipe.h + pipe.gap, pipe.w, HEIGHT)

    for _, player in ipairs(players) do
        player:draw()
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
end

function love.update(dt)
    pipe.x = pipe.x - 2
    if pipe.x + pipe.w <= 0 then
        pipe.x = WIDTH
        pipe.h = love.math.random(pipe.gap, HEIGHT - pipe.gap)
    end

    for _, player in ipairs(players) do
        player:update()
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        for _, player in ipairs(players) do
            player.yvel = -2
        end
    end
end