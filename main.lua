---@diagnostic disable: duplicate-set-field
local Vec2 = require("src.libs.vec2")
local Benchmarker = require("src.libs.benchmarker")
local engine = require("src.libs.engine")
local comp = require("src.components")
local shaders = require("src.shaders")
local world = require("src.world")
local systems = require("src.systems")
local config = require("src.config")
local Color = require("src.color")
local commons = require("src.libs.commons")
local fonts = require("src.fonts")
local palettes = require("src.palettes")
local menu = require("src.menu")

---------------------------------------------------------------------

_G.bench = Benchmarker:new(200)
_G.debug_info = {}
local sg = systems._singletons
local state = engine.state

---------------------------------------------------------------------

engine.ecs.create_entity(
    0, 0,
    comp.Transform:new(
        Vec2:new(400, 400),
        Vec2:new(0, 0),
        1.2
    ),
    comp.Sprite:from_path("res/images/player_animations/dexter/run.png"),
    comp.Hitbox:new(52, 80),  -- static hitbox
    comp.CameraAnchor:new(0.1),  -- camera follows its position
    comp.Controllable:new(),  -- can move using keyboard,
    comp.Inventory:new({"torch", "supertorch", "anvil"}, {10, 10, 3}, true)  -- inventory to place blocks
)

local processed_chunks = {}
local current_menu = nil

---------------------------------------------------------------------

function love.load()
    local deep_scale = 1
    _G.canvas = {
        main = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight()),  -- penultimate canvas before blitting onto main window
        deep = love.graphics.newCanvas(love.graphics.getWidth() / deep_scale, love.graphics.getHeight() / deep_scale),  -- canvas to be used with a depth field,
        lighting = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight()),  -- when this canvas gets blitted onto next canvas, indermediately: lighting happens
    }
    canvas.deep:setFilter("nearest")

    local icon = love.image.newImageData("res/images/visuals/windows_icon.png")
    love.window.setIcon(icon)
    love.window.setVSync(config.cb.vsync)

    -- love.profiler = require("src.libs.profile")
    -- love.profiler.start()

    palettes:send(shaders.palette, palettes.list[config.cm.palette_index])
end

local imgui_area = {0, 0, 160, HEIGHT}
love.frame = 0

function love.update(dt)
    -- frame updates
    _G.debug_info = {}
    _G.dt = dt

    -- profiling
    -- love.frame = love.frame + 1
    -- if love.frame % 100 == 0 or true then
    --     love.report = love.profiler.report(20)
    --     love.profiler.reset()
    -- end

    engine.preupdate()

    processed_chunks = world:update(dt, sg.scroll)

    systems.singletons.process(imgui_area)

    -- other systems that don't just take processed_chunks as argument
    if config.cb.physics then
        bench:start("physics", Color.LIGHT_GRAY)
        systems.physics.process(processed_chunks, world)
        bench:finish("physics", false)
    end

    -- update the UI elements
    if state.get(menu.state) ~= menu.state.NONE then
        menu.current:update(dt, sg)
    end

    -- update the editing system
    if state.get(menu.state) == menu.state.NONE then
        systems.editing.process(processed_chunks, world)
    end

    -- misc system updates
    systems.controllable.process(processed_chunks, world)
    systems.process_misc_update_systems(processed_chunks)
end

---------------------------------------------------------------------

function love.draw()
    -- =================================================================
    -- SETUP
    -- =================================================================
    love.graphics.setCanvas(canvas.lighting)
    love.graphics.setShader(nil)
    love.graphics.setColor({0.14, 0.12, 0.24})
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

    -- =================================================================
    -- 2D CAMERA STARTED!
    -- =================================================================
    love.graphics.push()

    systems.camera.process(processed_chunks)
    world:draw(sg.scroll)

    -- render chunk border rectangles (visual)
    if config.cb.borders then
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

    systems.late_rects.process()

    love.graphics.pop()
    -- =================================================================
    -- 2D CAMERA ENDED!
    -- =================================================================
    systems.process_misc_draw_systems(processed_chunks)

    -- =================================================================
    -- LIGHTMAP RENDERING -> canvas.main
    -- =================================================================
    love.graphics.setCanvas(canvas.main)
    local shader
    if config.cb.chiaroscuro then
        shader = config.cb.lighting and shaders.lighting or nil
    else
        shader = config.cb.palette and shaders.palette or nil
    end
    love.graphics.setShader(shader)
    world:prepare_lighting_shader(sg.scroll)  -- sends data to shader including: light texture, offsets
    love.graphics.draw(canvas.lighting, 0, 0)
    love.graphics.setCanvas(nil)
    love.graphics.setShader(nil)

    -- =================================================================
    -- canvas.main RENDERING -> MAIN WINDOW
    -- =================================================================
    love.graphics.setCanvas(nil)
    if config.cb.chiaroscuro then
        shader = config.cb.palette and shaders.palette or nil
    else
        shader = config.cb.lighting and shaders.lighting or nil
    end
    love.graphics.setShader(shader)
    bench:start("palette", Color.PINK)
    love.graphics.draw(canvas.main, 0, 0)
    bench:finish("palette")
    love.graphics.setShader(nil)

    -- =================================================================
    -- 3D MODEL > canvas.deep -> MAIN WINDOW
    -- =================================================================
    -- render the current menu
    if state.get(menu.state) ~= menu.state.NONE then
        menu.current:draw()
        if menu.current.draw_model ~= nil then
            menu.current:draw_model()
        end
    end
    love.graphics.setCanvas(nil)

    -- =================================================================
    -- UI RENDERING
    -- =================================================================
    love.graphics.setCanvas(nil)
    bench:draw()
    systems.imgui.process(imgui_area)
    systems.inventory_ui.process(processed_chunks)

    if sg.keys["escape"].clicked and not sg.keys["escape"].consumed then
        love.event.quit()
    end

    -- =================================================================
    -- POSTCONDITIONS
    -- =================================================================
    assert(love.graphics.getCanvas() == nil, "the final blit must be onto the global canvas")
end