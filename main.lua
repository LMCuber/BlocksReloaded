---@diagnostic disable: duplicate-set-field
local color = require("src.color")
local Vec2 = require("src.libs.vec2")
local Vec3 = require("src.libs.vec3")
local Benchmarker = require("src.libs.benchmarker")
local ecs = require("src.libs.ecs")
local comp = require("src.components")
local Model = require("src.3d_model")
local shaders = require("src.shaders")
local world = require("src.world")
local fonts = require("src.fonts")
local systems = require("src.systems")
local config = require("src.config")
local joystick = require("src.joystick")
local math = require("math")

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
    comp.Sprite:from_path("res/images/player_animations/samurai/run.png"),
    comp.Hitbox:new(52, 80),  -- static hitbox
    comp.CameraAnchor:new(0.04),  -- camera follows its position
    comp.Controllable:new(),  -- can move using keyboard,
    comp.Inventory:new({"torch", "torch", "supertorch"})  -- inventory to place blocks
)

local processed_chunks = {}
local debug_rects = {}

local o = 0.17 * math.pi
local model = Model:new({
    obj_path = "res/models/bcc.obj",
    center = Vec2:new(500, 300),
    size = 140,
    light = {0, -1, 0},
    angle = Vec3:new(o, o, 0),
    avel = Vec3:new(0.0, 0.7, 0),
    points = color.NAVY,
})

---------------------------------------------------------------------

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    world:process_keypress(key)
end

function love.load()
    _G.CANVAS = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    local icon = love.image.newImageData("res/images/visuals/windows_icon.png")
    love.window.setIcon(icon)
    love.graphics.setBackgroundColor(1, 1, 1, 0)
end

-------

function love.update(dt)
    _G.debug_info = {}
    _G.dt = dt

    processed_chunks = world:update(dt, systems._singletons.scroll)

    bench:start(color.PURPLE)
    -- model:update()
    bench:finish(color.PURPLE)

    bench:start(color.CYAN)

    -- singletons first
    systems.singletons.process()

    -- other systems that don't just take (processed_chunks)
    systems.physics.process(processed_chunks, world)
    systems.editing.process(processed_chunks, world)
    systems.controllable.process(processed_chunks, world)
    systems.process_misc_update_systems(processed_chunks)

    bench:finish(color.CYAN)

    -- shaders
    -- shaders.default:send("lightDir", {0, 1, 0})
    shaders.sky:send("time", love.timer.getTime())
    shaders.default:send("time", love.timer.getTime())
    -- shaders.default:send("intensity", 1)
    -- shaders.default:send("pixelSize", (math.sin(love.timer.getTime() * 4) + 1) * 0.5 * 16)
    -- shaders.default:send("offset", 2)
    -- shaders.default:send("threshold", 0.4)
    -- shaders.default:send("time", love.timer.getTime());
    -- shaders.default:send("resolution", {love.graphics.getWidth(), love.graphics.getHeight()});
    -- shaders.default:send("k", 0.05);
    shaders.default:send("levels", 16);
end

---------------------------------------------------------------------

function love.draw()
    love.graphics.setCanvas(CANVAS)

    -- reset the shader of the last frame
    love.graphics.setShader()

    -- background
    if config.shaders then
        love.graphics.setShader(shaders.sky)
    end
    love.graphics.setColor({0.14, 0.12, 0.24})
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

    -- reset shader after sky
    love.graphics.setShader()

    -- model
    -- model:draw()

    -- from now on, all rendered entities are rendered with camera scroll
    love.graphics.push()

    systems.camera.process(processed_chunks)

    world:draw(systems._singletons.scroll)

    systems.late_rects.process()
    systems.process_misc_draw_systems(processed_chunks)

    -- debug hitboxes
    for _, rect in ipairs(debug_rects) do
        love.graphics.setColor(rect[5] or color.RED)
        love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
    end

    love.graphics.pop()

    -- POST-CANVAS
    love.graphics.setColor(color.WHITE)
    love.graphics.setCanvas()
    love.graphics.draw(CANVAS, 0, 0)
    love.graphics.setShader()

    -- post-shader text
    bench:draw()
    systems.imgui.process({0, 0, 160, 250})
    love.graphics.setColor(color.WHITE)
end