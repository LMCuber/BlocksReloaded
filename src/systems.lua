---@diagnostic disable: need-check-nil
local ecs = require("src.libs.ecs")
local commons = require("src.libs.commons")
local Vec2 = require("src.libs.vec2")
--
local comp = require("src.components")
local animlib = require("src.animation")
local Color = require("src.color")
local fonts = require("src.fonts")
local blocks = require("src.blocks")
local imgui = require("src.libs.imgui")
local config = require("src.config")

local Button = {
    LEFT = 1,
    RIGHT = 2,
    MIDDLE = 3,
    MOUSE_4 = 4,
    MOUSE_5 = 5,
}
ecs.singletons.joystick = require("src.joystick")
local joystick = ecs.singletons.joystick

local function default_key_data()
    -- return all off states
    return {down = false, _was_down = false, clicked = false, released = false}
end

local systems = {
    -- singleton object
    _singletons = {
        fake_scroll = Vec2:new(0, 0),
        scroll = Vec2:new(0, 0),
        mouse = {x = nil, y = nil},
        buttons = {
            [Button.LEFT]    = default_key_data(),
            [Button.RIGHT]   = default_key_data(),
            [Button.MIDDLE]  = default_key_data(),
            [Button.MOUSE_4] = default_key_data(),
            [Button.MOUSE_5] = default_key_data(),
        },
        raw_buttons = {
            [Button.LEFT]    = default_key_data(),
            [Button.RIGHT]   = default_key_data(),
            [Button.MIDDLE]  = default_key_data(),
            [Button.MOUSE_4] = default_key_data(),
            [Button.MOUSE_5] = default_key_data(),
        },
        keys = {},
        late_rects = {},
        dead_zone = {0, 0, love.graphics.getWidth(), love.graphics.getHeight()}
    },

    -- update step systems
    _misc_update = {
        relocate = {},
    },
    singletons = {},
    physics = {},
    editing = {},

    -- draw step systems
    _misc_draw = {
    },
    render = {},
    imgui = {},
    camera = {},
    controllable = {},
    late_rects = {},
}
-- shorthand
local sg = systems._singletons

-- keyboard map
local alphabet = "abcdefghijklmnopqrstuvwxyz"
for i = 1, #alphabet do
    local char = alphabet:sub(i, i)
    sg.keys[char] = default_key_data()
end

-------------------------------------------------

function systems.process_misc_update_systems(chunks)
    for _, system in pairs(systems._misc_update) do
        system.process(chunks)
    end
end

function systems.process_misc_draw_systems(chunks)
    for _, system in pairs(systems._misc_draw) do
        system.process(chunks)
    end
end

-------------------------------------------------
---
function systems.imgui.process(imgui_area)
    sg.dead_zone = imgui_area

    imgui.begin("Settings", commons.unpack(imgui_area))

    imgui.setNextFont(fonts.orbitron)
    imgui.label("FPS: " .. love.timer.getFPS())
    for debug_type, debug_value in pairs(_G.debug_info) do
        imgui.label(debug_type .. ": " .. debug_value)
    end

    imgui.hbar()

    -- create an imgui checkbox per config item
    for name, _ in pairs(config) do
        if not ({vsync = 0})[name] then
            imgui.checkbox(commons.capitalize(name), config, name)
        end
    end

    -- checkboxes that need execution on click
    if imgui.checkbox("VSync", config, "vsync") then
        love.window.setVSync(config.vsync)
    end

    imgui.end_()
end

function systems.render.process(chunks)
    local num_rendered = 0
    local num_updated = 0

    for _, entry in ipairs(ecs.get_components(chunks, comp.Transform, comp.Sprite)) do
        local ent_id, cx, cy, tr, sprite = commons.unpack(entry)

        local has_anim = false
        local img_w, img_h, anim_data, quad

        if sprite.has_anim then
            anim_data = animlib.get(sprite.anim_skin, sprite.anim_mode)
            -- animate the sprite
            sprite.anim = sprite.anim + anim_data.speed * _G.dt
            if sprite.anim > anim_data.frames + 1 then
                sprite.anim = 1
            end
            quad = anim_data.quads[math.floor(sprite.anim)]
            _, _, img_w, img_h = quad:getViewport()
            img_w = img_w * S
            img_h = img_h * S
            has_anim = true
        else
            img_w, img_h = sprite.img:getDimensions()
            -- don't forget to multiply pixel sizes by the scale factor!!
            img_w, img_h = img_w * S, img_h * S
        end

        -- chunk text
        love.graphics.setColor(Color.ORANGE)

        -- rendering location
        local hitbox = ecs.try_component(ent_id, comp.Hitbox)
        if hitbox ~= nil then
            -- important check. we can't rely on race conditions between system updates
            if hitbox.is_dynamic then
                goto continue
            end

            -- center the image to the center of the hitbox
            local draw_x = math.floor(tr.pos.x - (img_w - hitbox.w) / 2)
            local draw_y = math.floor(tr.pos.y - (img_h - hitbox.h) / 2) + (has_anim and anim_data.offset or 0)
            local vp_x = draw_x - sg.scroll.x
            local vp_y = draw_y - sg.scroll.y

            -- check if the image is even on the viewport
            if (vp_x + img_w < 0 or vp_x > WIDTH or vp_y + img_h < 0 or vp_y > HEIGHT) then
                goto norender
            end

            -- render the image
            love.graphics.setColor(1, 1, 1)

            -- animation needs different render parameters
            if has_anim then
                -- render portion of animation given quad offset
                love.graphics.draw(
                    anim_data.sprs,
                    quad,
                    draw_x + (tr.direc == -1 and img_w or 0),
                    draw_y, 0,
                    (tr.direc == -1 and -1 or 1) * S,
                    S
                )
            else
                -- no animation; render simple image
                love.graphics.draw(
                    sprite.img,
                    draw_x + (tr.direc == -1 and img_w or 0),
                    draw_y, 0,
                    (tr.direc == -1 and -1 or 1) * S,
                    S
                )
            end

            if config.hitboxes then
                -- hitbox
                love.graphics.setColor(Color.ORANGE)
                love.graphics.rectangle("line", tr.pos.x, tr.pos.y, hitbox.w, hitbox.h)
                love.graphics.setFont(fonts.orbitron[12])
                love.graphics.print(hitbox.w .. "x" .. hitbox.h, tr.pos.x, tr.pos.y - 20)

                -- image render location rectangle
                love.graphics.setColor(Color.LIME)
                love.graphics.rectangle("line", draw_x, draw_y, img_w, img_h)
                love.graphics.setFont(fonts.orbitron[12])
                love.graphics.print(img_w .. "x" .. img_h, tr.pos.x, tr.pos.y - 40)

                -- chunk
                love.graphics.setFont(fonts.orbitron[12])
                love.graphics.setColor(Color.CYAN)
                love.graphics.print(cx .. ", " .. cy, tr.pos.x, tr.pos.y - 60)

                -- other debug information
                local ctrl = ecs.try_component(ent_id, comp.Controllable)
                if ctrl ~= nil then
                    if ctrl.grounded then
                        love.graphics.setColor(Color.ORANGE)
                        love.graphics.print("grounded", tr.pos.x, tr.pos.y - 80)
                    end
                end
            end
        end

        num_rendered = num_rendered + 1

        ::norender::
        num_updated = num_updated + 1

        ::continue::
    end

    return num_rendered, num_updated
end

function systems.physics.process(chunks, world)
    local debug_rects = {}

    for _, entry in ipairs(ecs.get_components(chunks, comp.Transform, comp.Sprite, comp.Hitbox)) do
        local ent_id, _, _, tr, sprite, hitbox = commons.unpack(entry)

        -- initialize dynamic hitbox
        if hitbox.is_dynamic then
            local anim_data = animlib.get(sprite.anim_skin, sprite.anim_mode)
            local _, _, w, h = anim_data.quads[math.floor(sprite.anim)]:getViewport()
            hitbox.w, hitbox.h = w * S, h * S
            hitbox.is_dynamic = false
        end

        -- --- Y-COLLISION ---
        tr.vel.y = tr.vel.y + tr.gravity * _G.dt
        tr.pos.y = tr.pos.y + tr.vel.y * _G.dt

        -- calculate tile boundaries
        local min_tx = math.floor(tr.pos.x / BS)
        local max_tx = math.floor((tr.pos.x + hitbox.w - 1) / BS)
        local min_ty = math.floor(tr.pos.y / BS)
        local max_ty = math.floor((tr.pos.y + hitbox.h - 1) / BS)

        for ty = min_ty, max_ty do
            for tx = min_tx, max_tx do
                local tile_id = world:abs_pos_to_tile(tx, ty)
                local name = blocks.name[tile_id]

                if name and nbwand(name, BF.WALKABLE) then
                    local bx, by = tx * BS, ty * BS

                    if hitbox:aabb(tr.pos.x, tr.pos.y, blocks.HITBOX, bx, by) then
                        table.insert(sg.late_rects, {bx, by, BS, BS, Color.PURPLE})
                        if tr.vel.y > 0 then
                            tr.pos.y = by - hitbox.h
                        else
                            tr.pos.y = by + BS
                        end
                        tr.vel.y = 0
                    end
                end
            end
        end

        -- --- X-COLLISION ---
        tr.pos.x = tr.pos.x + tr.vel.x * _G.dt

        -- (recalculate tile boundaries)
        min_tx = math.floor(tr.pos.x / BS)
        max_tx = math.floor((tr.pos.x + hitbox.w - 1) / BS)
        min_ty = math.floor(tr.pos.y / BS)
        max_ty = math.floor((tr.pos.y + hitbox.h - 1) / BS)

        for ty = min_ty, max_ty do
            for tx = min_tx, max_tx do
                local tile_id = world:abs_pos_to_tile(tx, ty)
                local name = blocks.name[tile_id]

                if name and nbwand(name, BF.WALKABLE) then
                    local bx, by = tx * BS, ty * BS
                    if hitbox:aabb(tr.pos.x, tr.pos.y, blocks.HITBOX, bx, by) then
                        table.insert(sg.late_rects, {bx, by, BS, BS, Color.PURPLE})
                        if tr.vel.x > 0 then
                            tr.pos.x = bx - hitbox.w
                        else
                            tr.pos.x = bx + BS
                        end
                    end
                end
            end
        end

        ::continue::
    end

    return debug_rects
end

function systems.camera.process(chunks)
    for _, entry in ipairs(ecs.get_components(chunks, comp.CameraAnchor, comp.Transform)) do
        local _, _, _, cam, tr = commons.unpack(entry)

        sg.fake_scroll.x = sg.fake_scroll.x + (tr.pos.x - sg.fake_scroll.x - WIDTH / 2 + 15) * cam.speed
        sg.fake_scroll.y = sg.fake_scroll.y + (tr.pos.y - sg.fake_scroll.y - HEIGHT / 2 + 15) * cam.speed

        sg.scroll.x = math.floor(sg.fake_scroll.x)
        sg.scroll.y = math.floor(sg.fake_scroll.y)
        love.graphics.translate(-sg.scroll.x, -sg.scroll.y)
    end
end

function systems.controllable.process(chunks, world)
    for _, entry in ipairs(ecs.get_components(chunks, comp.Controllable, comp.Sprite, comp.Transform)) do
        local ent_id, _, _, ctrl, sprite, tr = commons.unpack(entry)

        -- flags
        local jump = false

        -- check if entity is grounded, if so, check if there has been a jump input buffer
        local prev_grounded = ctrl.grounded
        ctrl.grounded = false

        local hitbox = ecs.try_component(ent_id, comp.Hitbox)
        if hitbox ~= nil then
            local probe_ty = math.floor((tr.pos.y + hitbox.h + 1) / BS)
            for ptx = math.floor(tr.pos.x / BS), math.floor((tr.pos.x + hitbox.w - 1) / BS) do
                local block_id = world:abs_pos_to_tile(ptx, probe_ty)
                local name  = blocks.name[block_id]
                if name and nbwand(name, BF.WALKABLE) then
                    ctrl.grounded = true
                    -- check if there was a jump buffer
                    if ctrl.jump_buffered ~= nil and love.timer.getTime() - ctrl.jump_buffered <= ctrl.jump_buffer then
                        jump = true
                        ctrl.jump_buffered = nil
                    end
                    break
                end
            end
        end

        -- the entity came off the ground (since it was grounded in the near past but not according to current calculations)
        if prev_grounded and not ctrl.grounded then
            ctrl.coyote_timer = love.timer.getTime()
        end

        -- controlling movement with keyboard
        if sg.keys["a"].down or sg.keys["d"].down or joystick.axis_any("HOR") then
            if ctrl.grounded then
                sprite.anim_mode = "run"
            end
        else
            if ctrl.grounded then
                sprite.anim_mode = "idle"
            end
            tr.vel.x = 0
        end

        if sg.keys["a"].down or joystick.axis_left("HOR") then
            tr.vel.x = -350
            tr.direc = -1
        elseif sg.keys["d"].down or joystick.axis_right("HOR") then
            tr.vel.x = 350
            tr.direc = 1
        end

        -- jumping with keyboard
        if (sg.keys["w"].clicked or joystick.is_clicked("bottom")) then
            if ctrl.grounded or (ctrl.coyote_timer ~= nil and love.timer.getTime() - ctrl.coyote_timer <= ctrl.coyote_time) then
                jump = true
            elseif ctrl.coyote_timer ~= nil and love.timer.getTime() - ctrl.coyote_timer <= ctrl.coyote_time then
                jump = true
                ctrl.coyote_timer = nil
            else
                ctrl.jump_buffered = love.timer.getTime()
            end
        end

        -- cutting jump short
        if (sg.keys["w"].released) then
            if tr.vel.y < 0 then
                tr.vel.y = tr.vel.y * 0.6
            end
        end

        -- resolve the flags
        if jump then
            tr.vel.y = -850
            sprite.anim_mode = "jump"
        end
    end
end

function systems.editing.process(chunks, world)
    local Intent = comp.Intent

    -- controllable + inventory means editing for now
    for _, entry in ipairs(ecs.get_components(chunks, comp.Inventory, comp.Controllable)) do
        local ent_id, _, _, inv, ctrl = commons.unpack(entry)

        -- get the mouse position and current hovering block
        local mx, my = sg.mouse.x, sg.mouse.y
        local cx, cy, rx, ry = world:mouse_to_timbre(mx, my, sg.scroll)
        local current = blocks.name[world:get(cx, cy, rx, ry)]

        -- visual block hover rectanglem
        local rect_x = (cx * CW + rx - 1) * BS  -- bc 1-based indexing
        local rect_y = (cy * CH + ry - 1) * BS
        table.insert(sg.late_rects, {rect_x, rect_y, BS, BS, Color.ORANGE})

        -- check which action is triggered by clicking mouse
        if sg.buttons[Button.LEFT].clicked then
            if current == nil or bwand(current, BF.EMPTY) then
                ctrl.intent = Intent.PLACE
            else
                ctrl.intent = Intent.BREAK
            end
        end

        -- RIGHT MOUSE TESTING
        if sg.buttons[Button.RIGHT].clicked then
            local tr = ecs.try_component(ent_id, comp.Transform)
            -- mouse_(x/y) are the in-game coordinates of the mouse
            local mouse_x = mx + sg.scroll.x
            local mouse_y = my + sg.scroll.y
            local angle = math.atan2(mouse_y - tr.pos.y, mouse_x - tr.pos.x)
            local m = 1000
            local xvel = math.cos(angle) * m
            local yvel = math.sin(angle) * m
            ecs.create_entity(
                cx, cy,
                comp.Transform:new(
                    Vec2:new(tr.pos.x, tr.pos.y),
                    Vec2:new(xvel, yvel),
                    1.2
                ),
                comp.Sprite:from_path("res/images/bullet.png", false),
                comp.Hitbox:new(12, 12)
            )
        end

        if (sg.buttons[Button.LEFT].down) then
            if ctrl.intent == Intent.PLACE then
                if current == nil or bwand(current, BF.EMPTY) then
                    world:place(cx, cy, rx, ry, inv.items[inv.index])
                end
            elseif ctrl.intent == Intent.BREAK then
                world:break_(cx, cy, rx, ry)
            end
        end
    end
end

function systems.singletons.process()
    -- get mouse position
    local _x, _y = love.mouse.getPosition()
    sg.mouse = {x = _x, y = _y}

    -- all deadzone-limited buttons
    if not commons.collidepointmouse(commons.unpack(sg.dead_zone)) then
        for button_id, state in pairs(sg.buttons) do
            local is_down = love.mouse.isDown(button_id)  -- e.g. 1 or 3
            state.clicked = is_down and not state.down
            state._was_down = state.down
            state.down = is_down
        end
    end

    -- all buttons bypassing the dead zone (raw buttons)
    for button_id, state in pairs(sg.raw_buttons) do
        local is_down = love.mouse.isDown(button_id)  -- e.g. 1 or 3
        state.clicked = is_down and not state.down
        state.released = not is_down and state.down
        state._was_down = state.down
        state.down = is_down
    end

    -- all keyboard unput
    for key, state in pairs(sg.keys) do
        local is_down = love.keyboard.isDown(key)
        state.clicked = is_down and not state.down
        state.released = not is_down and state.down
        state._was_down = state.down
        state.down = is_down
    end

    -- joystick BUTTON input
    for btn_id, state in pairs(joystick.buttons) do
        local is_down = joystick.current:isDown(btn_id)
        state.clicked = is_down and not state.down
        state.released = not is_down and state.down
        state._was_down = state.down
        state.down = is_down
    end

    -- joystick AXIS input
    for axis_id, _ in pairs(joystick.axes) do
        joystick.axes[axis_id] = joystick.current:getAxis(axis_id)
    end
end

function systems.late_rects.process()
    -- draw all the late rects to the screen
    if config.hitboxes then
        for _, rect in ipairs(sg.late_rects) do
            love.graphics.setColor(rect[5])
            love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
        end
    end

    -- clear the late rects
    sg.late_rects = {}
end

-- M I S C E L L A N E O U S  S Y S T E M S -------------------------------------------------------

function systems._misc_update.relocate.process(chunks)
    for _, entry in ipairs(ecs.get_components(chunks, comp.Transform)) do
        local ent_id, cx, cy, tr = commons.unpack(entry)

        local perc_x = ((tr.pos.x / BS) - (cx * CW)) / CW
        local perc_y = ((tr.pos.y / BS) - (cy * CH)) / CH

        if perc_x < 0 then
            ecs.relocate_entity(ent_id, cx, cy, cx - 1, cy)
        elseif perc_x >= 1 then
            ecs.relocate_entity(ent_id, cx, cy, cx + 1, cy)
        elseif perc_y < 0 then
            ecs.relocate_entity(ent_id, cx, cy, cx, cy - 1)
        elseif perc_y >= 1 then
            ecs.relocate_entity(ent_id, cx, cy, cx, cy + 1)
        end
    end
end

return systems