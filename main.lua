blocks = require("src.blocks")
world = require("src.world")
player = require("src.player")
fonts = require("src.fonts")
systems = require("src.systems")

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

    processed_chunks = world:update(dt, scroll)
    player:update(dt, scroll)

    systems.physics:process(processed_chunks)
end

-- love draw
function love.draw()
    love.graphics.push()

    love.graphics.translate(-scroll.x, -scroll.y)

    -- update the components
    world:draw(scroll)
    player:draw(scroll)

    love.graphics.pop()

    -- FPS
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 136, 40)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setFont(fonts.orbitron[24])
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
end