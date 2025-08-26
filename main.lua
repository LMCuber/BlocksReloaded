blocks = require("src.blocks")
world = require("src.world")
Player = require("src.player")
fonts = require("src.fonts")
systems = require("src.systems")
Color = require("src.color")

player = Player:new(world)

local fake_scroll = Vec2:new(0, 0)
local scroll = Vec2:new(0, 0)

debug_rects = {}

-- functions
function apply_scroll()
    local m = 1
    fake_scroll.x = fake_scroll.x + (player.pos.x - fake_scroll.x - WIDTH / 2 + 15) * m
    fake_scroll.y = fake_scroll.y + (player.pos.y - fake_scroll.y - HEIGHT / 2 + 15) * m
    scroll.x = math.floor(fake_scroll.x)
    scroll.y = math.floor(fake_scroll.y)
    scroll.x = fake_scroll.x
    scroll.y = fake_scroll.y
end

-- love callbacks
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    
    world:process_keypress(key)
    player:process_keypress(key)
end

-- love load
function love.load()
    love.graphics.setBackgroundColor(1, 1, 1, 0)
    player.pos.y = BS * (CH * 1)
end

-- love update
function love.update(dt)
    _G.dt = dt
    apply_scroll()

    processed_chunks = world:update(dt, scroll)
    player:update(dt, scroll)

    systems.relocate:process(processed_chunks)
    debug_rects = systems.physics:process(processed_chunks)
end

-- love draw
function love.draw()
    love.graphics.push()

    love.graphics.translate(-scroll.x, -scroll.y)

    -- update the components
    local num_rendered_entities = world:draw(scroll)
    player:draw(scroll)
    
    -- debug hitboxes
    for _, rect in ipairs(debug_rects) do
        love.graphics.setColor(rect[5] or {1, 0, 0})
        love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
    end

    love.graphics.pop()

    -- FPS, debug, etc.
    love.graphics.setColor(Color.ORANGE)
    love.graphics.setFont(fonts.orbitron[24])
    love.graphics.print("FPS: " .. love.timer.getFPS(), 6, 6)
    love.graphics.setFont(fonts.orbitron[18])
    love.graphics.print("ent. " .. num_rendered_entities, 6, 34)
    love.graphics.setColor(1, 1, 1, 1)
end