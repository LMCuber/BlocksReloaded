local ecs = require("src.ecs")
local comp = require("src.components")
local commons = require("src.commons")
local anim = require("src.animation")

-- S Y S T E M S
local systems = {
    render = {},
    physics = {},
    relocate = {},
}

function systems.render:process(chunks)
    local num_rendered = 0

    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform, comp.Sprite)) do
        local _, _, tr, sprite = commons.unpack(entry)

        local anim_data = anim.get(sprite.anim_skin, sprite.anim_mode)
        
        sprite.anim = sprite.anim + anim_data.speed * _G.dt
        if sprite.anim > anim_data.frames + 1 then
            sprite.anim = 1
        end
        local quad = anim_data.quads[math.floor(sprite.anim)]

        love.graphics.draw(anim_data.sprs, quad, tr.pos.x, tr.pos.y, 0, S, S)

        num_rendered = num_rendered + 1
    end

    return num_rendered
end

function systems.physics:process(chunks)
    local debug_rects = {}

    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform, comp.Sprite)) do
        local ent_id, _, tr, sprite = commons.unpack(entry)

        -- check if hitbox component exists: if so, check for collisions later
        local hitbox = ecs:try_component(ent_id, comp.Hitbox)

        -- gravity
        tr.vel.y = tr.vel.y + tr.gravity * _G.dt
        tr.pos.y = tr.pos.y + tr.vel.y * _G.dt

        if hitbox ~= nil then
            if hitbox.late then
                local anim_data = anim.get(sprite.anim_skin, sprite.anim_mode)
                local x, y, w, h = anim_data.quads[math.floor(sprite.anim)]:getViewport()
                -- account for pixel art scaling
                hitbox.w = w * S
                hitbox.h = h * S
            end

            table.insert(debug_rects, {tr.pos.x, tr.pos.y, hitbox.w, hitbox.h})

            for _, block_pos in ipairs(self.world:get_blocks_around_pos(
                tr.pos.x + hitbox.w / 2,
                tr.pos.y + hitbox.h / 2
            )) do
                local block_hitbox = comp.Hitbox:new(BS, BS)
                
                table.insert(debug_rects, {block_pos.x, block_pos.y, BS, BS, {1, 0.7, 0}})

                -- entity hitbox against block hitbox
                if hitbox:aabb(tr.pos.x, tr.pos.y, block_hitbox, block_pos.x, block_pos.y) then
                    if tr.vel.y > 0 then
                        tr.pos.y = block_pos.y - hitbox.h
                    else
                        tr.pos.y = block_pos.y + BS
                    end
                    tr.vel.y = 0
                end
            end
        end
    end

    return debug_rects
end

function systems.relocate:process(chunks)
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