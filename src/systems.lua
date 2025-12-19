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

-- S Y S T E M S
local systems = {
    _misc = {
        relocate = {},
        physics = {},
    },

    _singletons = {
        fake_scroll = Vec2:new(0, 0),
        scroll = Vec2:new(0, 0),
        mouse = {x = nil, y = nil, buttons = {}},
    },

    events = {},
    render = {},
    camera = {},
    controllable = {},
}

--

function systems:process_misc_systems(chunks)
    for _, system in pairs(systems._misc) do
        system:process(chunks)
    end
end

function systems.render:process(chunks)
    local num_rendered = 0

    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform, comp.Sprite)) do
        local ent_id, _, tr, sprite = commons.unpack(entry)

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

            -- image border (image render location)
            love.graphics.setColor(Color.ORANGE)
            love.graphics.rectangle("line", draw_x, draw_y, img_w, img_h)
            love.graphics.setFont(fonts.orbitron[12])
            love.graphics.print(img_w .. "x" .. img_h, tr.pos.x, tr.pos.y - 40)

            -- hitbox
            love.graphics.setColor(Color.LIME)
            love.graphics.rectangle("line", tr.pos.x, tr.pos.y, hitbox.w, hitbox.h)
            love.graphics.setFont(fonts.orbitron[12])
            love.graphics.print(hitbox.w .. "x" .. hitbox.h, tr.pos.x, tr.pos.y - 20)
        end

        num_rendered = num_rendered + 1
    end

    return num_rendered
end

function systems._misc.physics:process(chunks)
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
        end

        -- y-collision
        tr.vel.y = tr.vel.y + tr.gravity * _G.dt
        tr.pos.y = tr.pos.y + tr.vel.y * _G.dt

        table.insert(debug_rects, {tr.pos.x, tr.pos.y, hitbox.w, hitbox.h})

        for _, block_pos in ipairs(self.world:get_blocks_around_pos(
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

        for _, block_pos in ipairs(self.world:get_blocks_around_pos(
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

function systems.camera:process(chunks)
    for _, entry in ipairs(ecs:get_components(chunks, comp.CameraAnchor, comp.Transform)) do
        local _, _, cam, tr = commons.unpack(entry)

        systems._singletons.fake_scroll.x = systems._singletons.fake_scroll.x + (tr.pos.x - systems._singletons.fake_scroll.x - WIDTH / 2 + 15) * cam.speed
        systems._singletons.fake_scroll.y = systems._singletons.fake_scroll.y + (tr.pos.y - systems._singletons.fake_scroll.y - HEIGHT / 2 + 15) * cam.speed
        systems._singletons.scroll.x = math.floor(systems._singletons.fake_scroll.x)
        systems._singletons.scroll.y = math.floor(systems._singletons.fake_scroll.y)
        love.graphics.translate(-systems._singletons.scroll.x, -systems._singletons.scroll.y)
    end
end

function systems.controllable:process(chunks, world)
    local mouse = systems._singletons.mouse
    local Intent = comp.Intent

    for _, entry in ipairs(ecs:get_components(chunks, comp.Controllable, comp.Sprite, comp.Transform)) do
        -- controlling movement with keyboard
        local _, _, ctrl, sprite, tr = commons.unpack(entry)

        if love.keyboard.isDown("a") or love.keyboard.isDown("d") then
            sprite.anim_mode = "run"
        else
            sprite.anim_mode = "idle"
            tr.vel.x = 0
        end

        if love.keyboard.isDown("a") then
            tr.vel.x = -350
            tr.direc = -1
        elseif love.keyboard.isDown("d") then
            tr.vel.x = 350
            tr.direc = 1
        end

        if love.keyboard.isDown("w") then
            tr.vel.y = -650
        end

        if love.mouse.isDown(1) then
            local key, block_x, block_y = world:mouse_to_timbre(mouse.x, mouse.y, systems._singletons.scroll)
            local current = blocks.name[world:get(key, block_x, block_y)]

            -- debug
            local mx, my = love.mouse.getPosition()
            love.graphics.setColor(Color.BLACK)
            love.graphics.print(key, 0, 0, mx, my)

            -- check if already pressing or not
            if current == nil or bwand(current, BF.EMPTY) then
                if ctrl.intent == Intent.NONE then
                    ctrl.intent = Intent.PLACE
                end
                print(1)
                if ctrl.intent == Intent.PLACE then
                    print(2)
                    world:place(key, block_x, block_y, "torch")
                end
            else
               print()
            end
        else
            ctrl.intent = Intent.NONE
        end
    end
end

function systems.events:process()
    -- local x, y = love.mouse.getPosition()
    -- systems._singletons.mouse = {
    --     x = x, y = y, buttons = {}
    -- }
end

-- M I S C E L L A N E O U S  S Y S T E M S -------------------------------------------------------

function systems._misc.relocate:process(chunks)
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