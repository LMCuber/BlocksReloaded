ecs = require("src.ecs")
ent = require("src.entities")
commons = require("src.commons")

systems = {
    render = {},
    physics = {},
}

function systems.render:process(chunks)
    for _, entry in ipairs(ecs:get_components(chunks, ent.Transform, ent.Sprite)) do
        local chunk, ent_id, tr, sprite = commons.unpack(entry)
        
        -- print(tr.pos)
        love.graphics.draw(sprite.img, tr.pos.x, tr.pos.y)

    end
end

function systems.physics:process(chunks)
    for _, entry in ipairs(ecs:get_components(chunks, ent.Transform, ent.Sprite)) do
        local chunk, ent_id, tr, sprite = commons.unpack(entry)
        
        -- gravity
        tr.vel.y = tr.vel.y + tr.gravity
        tr.pos.y = tr.pos.y + tr.vel.y
    end
end



return systems