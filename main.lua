---@diagnostic disable: duplicate-set-field
local Vec2 = require("src.libs.vec2")
local Vec3 = require("src.libs.vec3")
local Benchmarker = require("src.libs.benchmarker")
local ecs = require("src.libs.ecs")
local comp = require("src.components")
local Model = require("src.3d_model")
local shaders = require("src.shaders")
local world = require("src.world")
local systems = require("src.systems")
local config = require("src.config")
local math = require("math")
local Color = require("src.color")
local commons = require("src.libs.commons")
local fonts = require("src.fonts")

---------------------------------------------------------------------

_G.bench = Benchmarker:new(200)
_G.debug_info = {}

---------------------------------------------------------------------

ecs:create_entity(
    0, 0,
    comp.Transform:new(
        Vec2:new(400, 400),
        Vec2:new(0, 0),
        1.2
    ),
    comp.Sprite:from_path("res/images/player_animations/nutcracker/run.png"),
    comp.Hitbox:new(52, 80),  -- static hitbox
    comp.CameraAnchor:new(0.04),  -- camera follows its position
    comp.Controllable:new(),  -- can move using keyboard,
    comp.Inventory:new({"torch", "torch", "supertorch"})  -- inventory to place blocks
)

local processed_chunks = {}

local o = 0.17 * math.pi
local model = Model:new({
    obj_path = "res/models/bcc.obj",
    center = Vec2:new(500, 300),
    size = 140,
    light = {0, -1, 0},
    angle = Vec3:new(o, o, 0),
    avel = Vec3:new(0.0, 0.7, 0),
    points = Color.NAVY,
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
    love.window.setVSync(config.vsync)
end

-------

function love.update(dt)
    _G.debug_info = {}
    _G.dt = dt

    processed_chunks = world:update(dt, systems._singletons.scroll)

    -- singletons first
    systems.singletons.process()

    -- other systems that don't just take processed_chunks as argument
    if config.physics then
        bench:start(Color.LIGHT_GRAY)
        systems.physics.process(processed_chunks, world)
        bench:finish(Color.LIGHT_GRAY, false)
    end

    systems.editing.process(processed_chunks, world)
    systems.controllable.process(processed_chunks, world)
    systems.process_misc_update_systems(processed_chunks)

    -- shaders
    shaders.sky:send("time", love.timer.getTime())
    shaders.default:send("time", love.timer.getTime())
    shaders.default:send("levels", 16);
end

---------------------------------------------------------------------

function love.draw()
    -- DRAW EVERYHING ON AUXILIARY CANVAS
    love.graphics.setCanvas(CANVAS)

    -- reset the shader of the last frame
    love.graphics.setShader()

    -- background
    if config.shaders then
        love.graphics.setShader(shaders.sky)
    end
    love.graphics.setColor({0.14, 0.12, 0.24})
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    love.graphics.setShader()

    -- ENTER: RENDERING WITH CAMERA SCROLL OFFSET
    love.graphics.push()

    systems.camera.process(processed_chunks)
    world:draw(systems._singletons.scroll)

    -- render chunk border rectangles (visual)
    if config.borders then
        for _, chunk_key in ipairs(processed_chunks) do
            love.graphics.setColor(Color.CYAN)
            local cx, cy = commons.unpack(chunk_key)
            local blit_x = cx * CW * BS
            local blit_y = cy * CH * BS
            love.graphics.rectangle("line", blit_x, blit_y, CW * BS, CH * BS)
            love.graphics.setFont(fonts.orbitron[20])
            love.graphics.print(cx .. ", " .. cy, blit_x + CW * BS / 2, blit_y + CH * BS / 2)
        end
    end

    -- a batch of rectangles sent by the systems to render at once
    if config.hitboxes then
        systems.late_rects.process()
    end
    systems.process_misc_draw_systems(processed_chunks)

    -- EXIT: OFFSETTED RENDERING. EVERYHING FROM HERE WILL BE RENDERED ABSOLUTELY
    love.graphics.pop()

    -- BLITTING CANVAS ONTO MAIN WINDOW
    love.graphics.setCanvas()
    -- apply lighting shader beforehand
    love.graphics.setColor(Color.WHITE)
    if config.lighting and world.light_tex then
        world:prepare_lighting_shader(systems._singletons.scroll)  -- sends data to shader including: light texture, offsets
        love.graphics.setShader(shaders.lighting)
    end
    love.graphics.draw(CANVAS, 0, 0)
    love.graphics.setShader()

    -- POST-CANVAS
    bench:draw()
    systems.imgui.process({0, 0, 160, HEIGHT})
    love.graphics.setColor(Color.WHITE)
end