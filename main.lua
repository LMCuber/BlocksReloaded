---@diagnostic disable: duplicate-set-field, lowercase-global
local Player = require("src.player")
local Color = require("src.color")
local Vec2 = require("src.libs.vec2")
local Benchmarker = require("src.libs.benchmarker")
local ecs = require("src.libs.ecs")
local comp = require("src.components")
-- 
local world = require("src.world")
local fonts = require("src.fonts")
local systems = require("src.systems")

-- dependency injection
_G.bench = Benchmarker:new(200)
_G.debug_info = {}
local player = Player:new(world)
player.scroll = scroll
player.bench = bench
world.player = player

-- create the player entity
ecs:create_entity(
    "0,0",
    comp.Transform:new(
        Vec2:new(400, 400),
        Vec2:new(0, 0),
        1
    ),
    comp.Sprite:from_path("res/images/player_animations/samurai/idle.png"),
    comp.Hitbox:new(52, 80),
    comp.CameraAnchor:new(0.05),
    comp.Controllable:new()
)

processed_chunks = {}

-- globals
local debug_rects = {}

-- love callbacks
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    world:process_keypress(key)
    player:process_keypress(key)
end

function love.mousepressed(mouse_x, mouse_y, button)
    -- systems:set_mouse(mouse_x, mouse_y, button)
end

function love.mousereleased(mouse_x, mouse_y, button)
    -- systems:unset_mouse(button)
end

-- love load
function love.load()
    love.graphics.setBackgroundColor(1, 1, 1, 0)
    player.pos.y = BS * (CH * 1)
end

-- love update
function love.update(dt)
    _G.debug_info = {}
    _G.dt = dt

    processed_chunks = world:update(dt, systems._singletons.scroll)

    bench:start(Color.CYAN)

    systems:process_misc_systems(processed_chunks)

    bench:finish(Color.CYAN)
end

-- love draw
function love.draw()
    love.graphics.push()

    systems.events:process()
    systems.camera:process(processed_chunks)
    systems.controllable:process(processed_chunks, world)

    world:draw(systems._singletons.scroll)

    -- debug hitboxes
    for _, rect in ipairs(debug_rects) do
        love.graphics.setColor(rect[5] or Color.RED)
        love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
    end

    love.graphics.pop()

    -- FPS, debug, etc.
    bench:draw()

    love.graphics.setColor(Color.ORANGE)
    love.graphics.setFont(fonts.orbitron[24])
    love.graphics.print("FPS: " .. love.timer.getFPS(), 6, 6)

    love.graphics.setFont(fonts.orbitron[18])

    local y = 0
    for debug_type, debug_value in pairs(_G.debug_info) do
        love.graphics.print(debug_type .. ": " .. debug_value, 6, 80 + y * 22)
        y = y + 1
    end

    love.graphics.setColor(1, 1, 1, 1)
end