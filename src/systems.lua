---@diagnostic disable: need-check-nil
local ecs = require("src.libs.ecs")
local commons = require("src.libs.commons")
local Vec2 = require("src.libs.vec2")
--
local comp = require("src.components")
local anim = require("src.animation")
local Color = require("src.color")
local fonts = require("src.fonts")
local blocks = require("src.blocks")

local Button = {
    LEFT = 1,
    RIGHT = 2,
    MIDDLE = 3,
    MOUSE_4 = 4,
    MOUSE_5 = 5,
}

local function default_key_data()
    -- turn all buttons off at start of game (nothing is pressed yet)
    return {down = false, was_down = false, clicked = false}
end

local systems = {
    _misc_update = {
        relocate = {},
    },

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
        keys = {},
        late_rects = {},
    },
    singletons = {},
    render = {},
    camera = {},
    controllable = {},
    editing = {},
    late_rects = {},
    physics = {},
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

function systems.process_misc_render_systems(chunks)
    for _, system in pairs(systems._misc_render) do
        system.process(chunks)
    end
end

-------------------------------------------------

function systems.render.process(chunks)
    local num_rendered = 0

    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform, comp.Sprite)) do
        local ent_id, chunk, tr, sprite = commons.unpack(entry)

        local anim_data = anim.get(sprite.anim_skin, sprite.anim_mode)

        sprite.anim = sprite.anim + anim_data.speed * _G.dt
        if sprite.anim > anim_data.frames + 1 then
            sprite.anim = 1
        end
        local quad = anim_data.quads[math.floor(sprite.anim)]
        local _, _, img_w, img_h = quad:getViewport()
        img_w = img_w * S
        img_h = img_h * S

        -- DEBUGGING
        -- chunk text
        love.graphics.setColor(Color.ORANGE)

        -- rendering location
        local hitbox = ecs:try_component(ent_id, comp.Hitbox)
        if hitbox == nil then
            love.graphics.draw(anim_data.sprs, quad, tr.pos.x, tr.pos.y, 0, S, S)
        else
            -- important check. we can't rely on race conditions between system updates
            if hitbox.is_dynamic then
                goto continue
            end

            local draw_x = math.floor(tr.pos.x - (img_w - hitbox.w) / 2)
            local draw_y = math.floor(tr.pos.y - (img_h - hitbox.h) / 2)

            -- player image
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(
                anim_data.sprs,
                quad,
                draw_x + (tr.direc == -1 and img_w or 0),
                draw_y, 0,
                (tr.direc == -1 and -1 or 1) * S,
                S
            )

            -- chunk
            love.graphics.setFont(fonts.orbitron[12])
            love.graphics.setColor(Color.CYAN)
            love.graphics.print(chunk, tr.pos.x, tr.pos.y - 60)

            -- image border (image render location)
            -- love.graphics.setColor(Color.ORANGE)
            -- love.graphics.rectangle("line", draw_x, draw_y, img_w, img_h)
            -- love.graphics.setFont(fonts.orbitron[12])
            -- love.graphics.print(img_w .. "x" .. img_h, tr.pos.x, tr.pos.y - 40)

            -- hitbox
            -- love.graphics.setColor(Color.LIME)
            -- love.graphics.rectangle("line", tr.pos.x, tr.pos.y, hitbox.w, hitbox.h)
            -- love.graphics.setFont(fonts.orbitron[12])
            -- love.graphics.print(hitbox.w .. "x" .. hitbox.h, tr.pos.x, tr.pos.y - 20)
        end

        num_rendered = num_rendered + 1

        ::continue::
    end

    return num_rendered
end

function systems.physics.process(chunks, world)
    local debug_rects = {}

    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform, comp.Sprite, comp.Hitbox)) do
        local _, _, tr, sprite, hitbox = commons.unpack(entry)

        -- make sure the hitbox has a size (the first time it is set from dynamic to something concrete)
        if hitbox.is_dynamic then
            local anim_data = anim.get(sprite.anim_skin, sprite.anim_mode)
            local _, _, w, h = anim_data.quads[math.floor(sprite.anim)]:getViewport()
            -- account for pixel art scaling
            hitbox.w = w * S
            hitbox.h = h * S
            hitbox.is_dynamic = false
        end

        -- y-collision
        tr.vel.y = tr.vel.y + tr.gravity * _G.dt
        tr.pos.y = tr.pos.y + tr.vel.y * _G.dt

        table.insert(debug_rects, {tr.pos.x, tr.pos.y, hitbox.w, hitbox.h})

        for _, block_pos in ipairs(world:get_blocks_around_pos(
            tr.pos.x + hitbox.w / 2,
            tr.pos.y + hitbox.h / 2
        )) do
            local block_hitbox = comp.Hitbox:new(BS, BS)

            table.insert(debug_rects, {block_pos.x, block_pos.y, BS, BS, {1, 0.7, 0}})

            -- entity hitbox against block hitbox (block hitbox is the argument)
            if hitbox:aabb(tr.pos.x, tr.pos.y, block_hitbox, block_pos.x, block_pos.y) then
                if tr.vel.y > 0 then
                    tr.pos.y = block_pos.y - hitbox.h
                else
                    tr.pos.y = block_pos.y + BS
                end
                tr.vel.y = 0
            end
        end

        -- x-collision
        tr.pos.x = tr.pos.x + tr.vel.x * _G.dt

        table.insert(debug_rects, {tr.pos.x, tr.pos.y, hitbox.w, hitbox.h})

        for _, block_pos in ipairs(world:get_blocks_around_pos(
            tr.pos.x + hitbox.w / 2,
            tr.pos.y + hitbox.h / 2
        )) do
            local block_hitbox = comp.Hitbox:new(BS, BS)

            table.insert(debug_rects, {block_pos.x, block_pos.y, BS, BS, {1, 0.7, 0}})

            -- entity hitbox against block hitbox (block hitbox is the argument)
            if hitbox:aabb(tr.pos.x, tr.pos.y, block_hitbox, block_pos.x, block_pos.y) then
                if tr.vel.x > 0 then
                    tr.pos.x = block_pos.x - hitbox.w
                else
                    tr.pos.x = block_pos.x + BS
                end
            end
        end
    end

    return debug_rects
end

function systems.camera.process(chunks)
    for _, entry in ipairs(ecs:get_components(chunks, comp.CameraAnchor, comp.Transform)) do
        local _, _, cam, tr = commons.unpack(entry)

        sg.fake_scroll.x = sg.fake_scroll.x + (tr.pos.x - sg.fake_scroll.x - WIDTH / 2 + 15) * cam.speed
        sg.fake_scroll.y = sg.fake_scroll.y + (tr.pos.y - sg.fake_scroll.y - HEIGHT / 2 + 15) * cam.speed

        sg.scroll.x = math.floor(sg.fake_scroll.x)
        sg.scroll.y = math.floor(sg.fake_scroll.y)
        love.graphics.translate(-sg.scroll.x, -sg.scroll.y)
    end
end

function systems.controllable.process(chunks, world)
    local Intent = comp.Intent

    for _, entry in ipairs(ecs:get_components(chunks, comp.Controllable, comp.Sprite, comp.Transform)) do
        -- controlling movement with keyboard
        local ent_id, _, ctrl, sprite, tr = commons.unpack(entry)

        if sg.keys["a"].down or sg.keys["d"].down then
            sprite.anim_mode = "run"
        else
            sprite.anim_mode = "idle"
            tr.vel.x = 0
        end

        if sg.keys["a"].down then
            tr.vel.x = -350
            tr.direc = -1
        elseif sg.keys["d"].down then
            tr.vel.x = 350
            tr.direc = 1
        end

        if sg.keys["w"].clicked then
            tr.vel.y = -740
        end
    end
end

function systems.editing.process(chunks, world)
    local Intent = comp.Intent

    -- controllable + inventory means editing (might change later idk)
    for _, entry in ipairs(ecs:get_components(chunks, comp.Inventory, comp.Controllable)) do
        local ent_id, _, inv, ctrl = commons.unpack(entry)

        -- get the mouse position and current hovering block
        local mx, my = sg.mouse.x, sg.mouse.y
        local key, block_x, block_y = world:mouse_to_timbre(mx, my, sg.scroll)
        local current = blocks.name[world:get(key, block_x, block_y)]

        -- visual block hover rectanglem
        local chunk_x, chunk_y = commons.parse_key(key)
        local rect_x = (chunk_x * CW + block_x - 1) * BS  -- bc 1-based indexing
        local rect_y = (chunk_y * CH + block_y - 1) * BS
        table.insert(sg.late_rects, {rect_x, rect_y, BS, BS, Color.ORANGE})

        -- check which action is triggered by clicking mouse
        if sg.buttons[Button.LEFT].clicked then
            if current == nil or bwand(current, BF.EMPTY) then
                ctrl.intent = Intent.PLACE
            else
                ctrl.intent = Intent.BREAK
            end
        end

        if (sg.buttons[Button.LEFT].down) then
            if ctrl.intent == Intent.PLACE then
                if current == nil or bwand(current, BF.EMPTY) then
                    world:place(key, block_x, block_y, inv.items[inv.index])
                end
            elseif ctrl.intent == Intent.BREAK then
                world:break_(key, block_x, block_y)
            end
        end
    end
end

function systems.singletons.process()
    -- mouse position
    local _x, _y = love.mouse.getPosition()
    sg.mouse = {x = _x, y = _y}

    -- all keys
    for key, state in pairs(sg.keys) do
        local is_down = love.keyboard.isDown(key)
        state.clicked = is_down and not state.down
        state.was_down = state.down
        state.down = is_down
    end

    -- all button presses AND holds
    for button_id, state in pairs(sg.buttons) do
        local is_down = love.mouse.isDown(button_id)  -- e.g. 1 or 3
        state.clicked = is_down and not state.down
        state.was_down = state.down
        state.down = is_down
    end
end

function systems.late_rects.process()
    -- draw all the late rects to the screen
    for _, rect in ipairs(sg.late_rects) do
        love.graphics.setColor(rect[5])
        love.graphics.rectangle("line", rect[1], rect[2], rect[3], rect[4])
    end
    -- clear the late rects
    sg.late_rects = {}
end

-- M I S C E L L A N E O U S  S Y S T E M S -------------------------------------------------------

function systems._misc_update.relocate.process(chunks)
    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform)) do
        local ent_id, chunk, tr = commons.unpack(entry)

        local chunk_x, chunk_y = commons.parse_key(chunk)
        local perc_x = ((tr.pos.x / BS) - (chunk_x * CW)) / CW
        local perc_y = ((tr.pos.y / BS) - (chunk_y * CH)) / CH

        if perc_x < 0 then
            ecs:relocate_entity(ent_id, chunk, chunk_x - 1, chunk_y)
        elseif perc_x >= 1 then
            ecs:relocate_entity(ent_id, chunk, chunk_x + 1, chunk_y)
        elseif perc_y < 0 then
            ecs:relocate_entity(ent_id, chunk, chunk_x, chunk_y - 1)
        elseif perc_y >= 1 then
            ecs:relocate_entity(ent_id, chunk, chunk_x, chunk_y + 1)
        end
    end
end

return systems