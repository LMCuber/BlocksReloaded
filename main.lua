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
local Color = require("src.color")
local commons = require("src.libs.commons")
local fonts = require("src.fonts")
local palettes = require("src.palettes")
local mmath = require("src.libs.mmath")
local menu = require("src.menu")

---------------------------------------------------------------------

_G.bench = Benchmarker:new(200)
_G.debug_info = {}

---------------------------------------------------------------------

ecs.create_entity(
    0, 0,
    comp.Transform:new(
        Vec2:new(400, 400),
        Vec2:new(0, 0),
        1.2
    ),
    comp.Sprite:from_path("res/images/player_animations/dexter/run.png"),
    comp.Hitbox:new(52, 80),  -- static hitbox
    comp.CameraAnchor:new(0.04),  -- camera follows its position
    comp.Controllable:new(),  -- can move using keyboard,
    comp.Inventory:new({"torch", "supertorch", "anvil"}, {10, 10, 3}, true)  -- inventory to place blocks
)

local processed_chunks = {}
local player_skins = {"dexter", "samurai"}
local current_menu = nil

---------------------------------------------------------------------

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    world:process_keypress(key)
end

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

    palettes:send(shaders.palette, palettes.list[config.cm.palette_index])
end

local model = Model:new({
    obj_path = "res/models/sword.obj",
    ortho_size = 40,
    center = Vec3:new(600, 600),
    angle = Vec3:new(0, 0, 0),
    avel = Vec3:new(0.9, 0.2, 2.3),
    points = Color.NAVY,
})
local imgui_area = {0, 0, 160, HEIGHT}

function love.update(dt)
    _G.debug_info = {}
    _G.dt = dt

    processed_chunks = world:update(dt, systems._singletons.scroll)

    systems.singletons.process(imgui_area)

    -- other systems that don't just take processed_chunks as argument
    if config.cb.physics then
        bench:start("physics", Color.LIGHT_GRAY)
        systems.physics.process(processed_chunks, world)
        bench:finish("physics", false)
    end

    -- update the UI elements
    model:update(dt)
    if current_menu ~= nil then
        local closed = current_menu:update()
        if closed then
            current_menu = nil
        end
    end

    -- update the editing (and get new model potentially)
    local new_menu = systems.editing.process(processed_chunks, world)
    if new_menu ~= nil then
        current_menu = menu.new_menu(new_menu)
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
    world:draw(systems._singletons.scroll)

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

    -- =================================================================
    -- 2D CAMERA ENDS HERE!
    -- =================================================================
    love.graphics.pop()
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
    world:prepare_lighting_shader(systems._singletons.scroll)  -- sends data to shader including: light texture, offsets
    love.graphics.draw(canvas.lighting, 0, 0)

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

    -- =================================================================
    -- 3D MODEL > canvas.deep -> MAIN WINDOW
    -- =================================================================
    love.graphics.setCanvas({canvas.deep, depth = true})
    love.graphics.setShader(shaders.model)
    love.graphics.clear(true, true, true)
    love.graphics.setDepthMode("lequal", true)

    shaders.model:send("uModel", mmath.mat4_transpose(model.model))
    shaders.model:send("uView",  mmath.mat4_transpose(model.view))
    shaders.model:send("uProj",  mmath.mat4_transpose(model.proj))

    love.graphics.draw(model.mesh)

    -- model -> main window
    love.graphics.setShader()
    love.graphics.setDepthMode()
    love.graphics.setCanvas(nil)
    local sx = love.graphics.getWidth() / canvas.deep:getWidth()
    local sy = love.graphics.getHeight() / canvas.deep:getHeight()
    love.graphics.draw(canvas.deep, 0, 0, 0, sx, sy)

    -- =================================================================
    -- UI RENDERING
    -- =================================================================
    love.graphics.setCanvas(nil)
    bench:draw()
    systems.imgui.process(imgui_area)
    systems.inventory_ui.process(processed_chunks)

    -- render the current menu
    if current_menu ~= nil then
        current_menu:draw()
    end

    -- =================================================================
    -- POSTCONDITIONS
    -- =================================================================
    assert(love.graphics.getCanvas() == nil, "the final blit must be onto the global canvas")
end