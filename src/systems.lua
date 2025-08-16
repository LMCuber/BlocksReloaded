ecs = require("src.ecs")
ent = require("src.entities")
commons = require("src.commons")

systems = {
    render = {

    }
}

function systems.render:process()
    for _, entry in ipairs(ecs:get_components({"0,0"}, ent.Transform)) do
        local chunk, ent_id, tr = commons.unpack(entry)
        -- print(chunk, ent_id, tr._name)
    end
end

return systems