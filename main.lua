---@diagnostic disable: duplicate-set-field, lowercase-global
local Color = require("src.color")
local Vec2 = require("src.libs.vec2")
local Benchmarker = require("src.libs.benchmarker")
local ecs = require("src.libs.ecs")
local comp = require("src.components")
local Model = require("src.3d_model")
local neat = require("src.libs.neat")
local imgui = require("src.libs.imgui")
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
    comp.CameraAnchor:new(0.04),  -- camera follows its position
    comp.Controllable:new(),      -- can move using keyboard,
    comp.Inventory:new({"supertorch", "torch", "supertorch"})         -- inventory to place blocks
)

local processed_chunks = {}
local debug_rects = {}


-- -- mandatory arguments
-- obj.obj_path = kwargs.obj_path
-- obj.center = kwargs.center
-- obj.size = kwargs.size
local model = Model:new({
    obj_path = "res/models/bracelet.obj",
    center = Vec2:new(200, 200),
    size = 24,
    light = {0, -1, 0}
})

---------------------------------------------------------------------

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    world.process_keypress(key)
end

function love.load()
    local icon = love.image.newImageData("res/images/visuals/windows_icon.png")
    love.window.setIcon(icon)
    love.graphics.setBackgroundColor(1, 1, 1, 0)
end

-------

function love.update(dt)
    _G.debug_info = {}
    _G.dt = dt

    processed_chunks = world:update(dt, systems._singletons.scroll)

    bench:start(Color.CYAN)

    -- singletons first
    systems.singletons.process()

    -- other systems that don't just take (processed_chunks)
    systems.physics.process(processed_chunks, world)
    systems.editing.process(processed_chunks, world)
    systems.process_misc_update_systems(processed_chunks)

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
    love.graphics.setColor({0.14, 0.12, 0.24})
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

    -- from now on, all rendered entities are rendered with camera scroll
    love.graphics.push()

    systems.controllable.process(processed_chunks, world)
    systems.camera.process(processed_chunks)

    -- render world AFTER camera at least
    world:draw(systems._singletons.scroll)

    -- debugging rects
    systems.late_rects.process()

    -- debug hitboxes
    for _, rect in ipairs(debug_rects) do
        love.graphics.setColor(rect[5] or Color.RED)
        love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
    end

    love.graphics.pop()

    -- FPS, debug, etc.
    bench:draw()

    -- imgui
    imgui.begin("Settings", 10, 150, 140, 140)

    local _ = imgui.checkbox("Hitboxes")
    local _ = imgui.checkbox("Borders")

    imgui.end_()

    love.graphics.setColor(Color.ORANGE)
    love.graphics.setFont(fonts.orbitron[24])
    love.graphics.print("FPS: " .. love.timer.getFPS(), 6, 6)

    love.graphics.setFont(fonts.orbitron[18])

    show_debug_info()

    love.graphics.setColor(1, 1, 1, 1)
end