ecs = require("src.ecs")
ent = require("src.components")
commons = require("src.commons")
yaml = require("src.libs.yaml")


-- A N I M A T I O N  L O A D I N G  E N G I N E
anim = {
    data = {}
}
local entity_types = {"statics"}
for _, entity_type in ipairs(entity_types) do
    local content, _ = love.filesystem.read("res/data/" .. entity_type .. ".yaml")
    local yaml_data = yaml.eval(content)

    for skin, _ in pairs(yaml_data) do
        anim.data[skin] = {}

        for mode, _ in pairs(yaml_data[skin]) do
            anim.data[skin][mode] = {}
            anim.data[skin][mode]["frames"] = yaml_data[skin][mode]["frames"]
            anim.data[skin][mode]["speed"] = yaml_data[skin][mode]["speed"]
            
            anim.data[skin][mode]["sprs"] = love.graphics.newImage(string.format(
                "res/images/%s/%s/%s.png",  -- stupid fucking lua
                entity_type, skin, mode
            ))
            anim.data[skin][mode]["sprs"]:setFilter("nearest", "nearest")
         
            anim.data[skin][mode]["quads"] = {}
            for i = 1, anim.data[skin][mode]["frames"] do
                local w = anim.data[skin][mode]["sprs"]:getWidth() / anim.data[skin][mode]["frames"]
                local h = anim.data[skin][mode]["sprs"]:getHeight()
                local x = (i - 1) * w
                table.insert(
                    anim.data[skin][mode]["quads"],
                    love.graphics.newQuad(
                        x, 0, w, h,
                        anim.data[skin][mode]["sprs"]:getWidth(),
                        anim.data[skin][mode]["sprs"]:getHeight()
                    )
                )
            end
        end
    end
end

function anim.get(skin, mode)
    return anim.data[skin][mode]["sprs"],
        anim.data[skin][mode]["quads"],
        anim.data[skin][mode]["speed"],
        anim.data[skin][mode]["frames"]
end

-- S Y S T E M S
systems = {
    render = {},
    physics = {},
    relocate = {},
}

function systems.render:process(chunks)
    local num_rendered = 0

    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform, comp.Sprite)) do
        local ent_id, chunk, tr, sprite = commons.unpack(entry)

        local sprs, quads, anim_speed, num_frames = anim.get(sprite.anim_skin, sprite.anim_mode)
        
        sprite.anim = sprite.anim + anim_speed * _G.dt
        if sprite.anim > num_frames then
            sprite.anim = 1
        end
        local quad = quads[math.floor(sprite.anim)]

        love.graphics.draw(sprs, quad, tr.pos.x, tr.pos.y, 0, S, S)

        num_rendered = num_rendered + 1
    end

    return num_rendered
end

function systems.physics:process(chunks)
    local debug_rects = {}

    for _, entry in ipairs(ecs:get_components(chunks, comp.Transform, comp.Sprite)) do
        local ent_id, chunk, tr, sprite = commons.unpack(entry)

        -- check if hitbox component exists: if so, check for collisions later
        local hitbox = ecs:get_component(ent_id, Hitbox)

        -- gravity
        tr.vel.y = tr.vel.y + tr.gravity * _G.dt
        tr.pos.y = tr.pos.y + tr.vel.y * _G.dt

        print(tr.vel.y)

        if hitbox ~= nil then
            if hitbox.late then
                
                local _, quads, _, _ = anim.get(sprite.anim_skin, sprite.anim_mode)
                local x, y, w, h = quads[math.floor(sprite.anim)]:getViewport()
                -- account for pixel art scaling
                hitbox.w = w * S
                hitbox.h = h * S
            end

            table.insert(debug_rects, {tr.pos.x, tr.pos.y, hitbox.w, hitbox.h})

            local o = 3
            for x = -o, o do
                for y = -o, o do
                    local tx = math.floor((tr.pos.x + hitbox.w / 2) / BS) + x
                    local ty = math.floor((tr.pos.y + hitbox.h / 2) / BS) + y
                    local block_hitbox = comp.Hitbox:new(BS, BS)
                    
                    table.insert(debug_rects, {tx * BS, ty * BS, BS, BS, {1, 0.7, 0}})

                    -- check colliding block name
                    local name = blocks.name[self.world:get_tile(tx, ty)]
                    if nbwand(name, BF.WALKABLE) then
                        -- entity hitbox against block hitbox
                        if hitbox:aabb(tr.pos.x, tr.pos.y, block_hitbox, tx * BS, ty * BS) then
                            tr.vel.y = -100
                        end
                    end
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