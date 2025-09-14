local Player = require("src.player")
local Color = require("src.color")
local Vec2 = require("src.vec2")
local Vec3 = require("src.vec3")
local Model = require("src.3d_model");
-- 
local world = require("src.world")
local fonts = require("src.fonts")
local systems = require("src.systems")
local shader = require("src.shader")

local fake_scroll = Vec2:new(0, 0)
local scroll = Vec2:new(0, 0)

-- dependency injection
local player = Player:new(world)
player.scroll = scroll
world.player = player

-- global objects
local model = Model:new({
        obj_file = "res/models/gun.obj",
        center = Vec2:new(WIDTH / 2, HEIGHT / 2),
        size = 15,
        avel = Vec3:new(3, 2, 2);
    }
)

-- globals
local debug_rects = {}

-- functions
local function apply_scroll(dt)
    local m = 0.1
    fake_scroll.x = fake_scroll.x + (player.pos.x - fake_scroll.x - WIDTH / 2 + 15) * m
    fake_scroll.y = fake_scroll.y + (player.pos.y - fake_scroll.y - HEIGHT / 2 + 15) * m
    scroll.x = math.floor(fake_scroll.x)
    scroll.y = math.floor(fake_scroll.y)
    -- scroll.x = fake_scroll.x
    -- scroll.y = fake_scroll.y
end

-- love callbacks
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    world:process_keypress(key)
    player:process_keypress(key)
end

function love.mousepressed(mouse_x, mouse_y, button)
    player:process_mousepressed(mouse_x, mouse_y, button)
end

function love.mousereleased(mouse_x, mouse_y, button)
    player:process_mousereleased(mouse_x, mouse_y, button)
end

-- love load
function love.load()
    love.graphics.setBackgroundColor(1, 1, 1, 0)
    player.pos.y = BS * (CH * 1)
end

-- love update
function love.update(dt)
    _G.dt = dt
    apply_scroll(dt)

    local processed_chunks = world:update(dt, scroll)
    player:update(dt, scroll)

    model:update()

    systems.relocate:process(processed_chunks)
    debug_rects = systems.physics:process(processed_chunks)
end

-- love draw
function love.draw()
    love.graphics.push()
    love.graphics.translate(-scroll.x, -scroll.y)

    -- update the main components: world and player
    local num_rendered_entities = world:draw(scroll)
    -- player:draw(scroll)

    -- debug hitboxes
    for _, rect in ipairs(debug_rects) do
        love.graphics.setColor(rect[5] or Color.RED)
        love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
    end

    love.graphics.pop()

    -- update misc objects
    model:draw()

    -- FPS, debug, etc.
    love.graphics.setColor(Color.ORANGE)
    love.graphics.setFont(fonts.orbitron[24])
    love.graphics.print("FPS: " .. love.timer.getFPS(), 6, 6)
    love.graphics.setFont(fonts.orbitron[18])
    love.graphics.print("ent. " .. num_rendered_entities, 6, 34)
    love.graphics.setColor(1, 1, 1, 1)
end