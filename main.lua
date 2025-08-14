blocks = require("src.blocks")
world = require("src.world")
player = require("src.player")

player.world = world

local fake_scroll = { x = 0, y = 0 }
local scroll = { x = 0, y = 0 }

-- functions
function apply_scroll()
    fake_scroll.x = fake_scroll.x + (player.x - fake_scroll.x - WIDTH / 2 + 15)
    fake_scroll.y = fake_scroll.y + (player.y - fake_scroll.y - HEIGHT / 2 + 15)
    scroll.x = math.floor(fake_scroll.x)
    scroll.y = math.floor(fake_scroll.y)
end

-- love load
function love.load()
    love.graphics.setBackgroundColor(1, 1, 1, 0)
    player.y = BS * (CH * 2)
end

-- love update
function love.update(dt)
    apply_scroll()
    world:update(dt, scroll)
    player:update(dt, scroll)
end

-- love draw
function love.draw()
    love.graphics.push()

    love.window.setTitle("Blockingdom | " .. love.timer.getFPS() .. " FPS")
    love.graphics.translate(-scroll.x, -scroll.y)

    world:draw(scroll)
    player:draw(scroll)

    -- Player
    love.graphics.pop()

    -- FPS
    -- love.graphics.setColor(1, 1, 1)
    -- love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
end
