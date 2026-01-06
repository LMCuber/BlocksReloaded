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

---------------------------------------------------------------------

_G.bench = Benchmarker:new(200)
_G.debug_info = {}

---------------------------------------------------------------------

ecs:create_entity(
    "0,0",
    comp.Transform:new(
        Vec2:new(400, 400),
        Vec2:new(0, 0),
        1
    ),
    comp.Sprite:from_path("res/images/player_animations/samurai/idle.png"),
    comp.Hitbox:new(52, 80),
    comp.CameraAnchor:new(0.05),  -- camera follows its position
    comp.Controllable:new()       -- can move using keyboard
)

processed_chunks = {}

-- globals
local debug_rects = {}

---------------------------------------------------------------------

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    world:process_keypress(key)
end

function love.load()
    love.graphics.setBackgroundColor(1, 1, 1, 0)
end

function love.update(dt)
    _G.debug_info = {}
    _G.dt = dt

    processed_chunks = world:update(dt, systems._singletons.scroll)

    bench:start(Color.CYAN)

    systems:process_misc_systems(processed_chunks)

    bench:finish(Color.CYAN)
end

---------------------------------------------------------------------

local function show_debug_info()
    local y = 0
    for debug_type, debug_value in pairs(_G.debug_info) do
        love.graphics.print(debug_type .. ": " .. debug_value, 6, 80 + y * 22)
        y = y + 1
    end
end

function love.draw()
    -- from now on, all rendered entities are rendered with camera scroll
    love.graphics.push()

    -- process all singleton entities (must be updated before the rest of the systems)
    systems.singletons:process()
    systems.camera:process(processed_chunks)

    -- render world AFTER camera
    world:draw(systems._singletons.scroll)

    -- controllable system (accessing world block data)
    systems.controllable:process(processed_chunks, world)

    -- debugging rects
    systems.late_rects:process()

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

    show_debug_info()

    love.graphics.setColor(1, 1, 1, 1)
end