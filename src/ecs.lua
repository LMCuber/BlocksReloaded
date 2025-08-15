commons = require("src.commons")

local entity_manager = {
    counter = 0,
    entities = {},
}

function entity_manager:get_id()
    self.counter = self.counter + 1
    return self.counter - 1
end

local component_manager = {
    cache = {},
    components = {},
}

ecs = {}


function ecs:_get_components(chunk, ...)
    -- if chunk does not exist, return nothing
    if not component_manager.components[chunk] then
        return {}
    end

    local comp_types = {...}

    local ret = {}
    
    -- get all possible collection of entities (based on component type) before intersecting them
    local possible_entities = {}

    for _, comp_type in ipairs(comp_types) do
        local comp_name = comp_type._name

        if component_manager.components[chunk][comp_name] ~= nil then
            table.insert(possible_entities, component_manager.components[chunk][comp_name])
        end
    end

    -- intersect them
    local intersected_entities = commons.intersect_n(commons.unpack(possible_entities))

    -- get the components from the all the intersected entities
    local final_entity_data = {}
    for _, ent_id in ipairs(intersected_entities) do
        local comp_objects = {}
        for _, comp_type in ipairs(comp_types) do
            local comp_name = comp_type._name
            table.insert(comp_objects, entity_manager.entities[ent_id][comp_name])
        end

        local entity_data = {chunk, ent_id}
        for i = 1, #comp_objects do
            table.insert(entity_data, comp_objects[i])
        end
        table.insert(final_entity_data, entity_data)
    end

    return final_entity_data

end

function ecs:get_components(chunks, ...)
    local comp_types = {...}
    local ret = {}

    for _, chunk in ipairs(chunks) do
        local entity_data = self:_get_components(chunk, commons.unpack(comp_types))
        commons.extend(ret, entity_data)
    end

    return ret
end

function ecs:create_entity(chunk, ...)
    local comp_objects = {...}

    local ent_id = entity_manager:get_id()
    entity_manager.entities[ent_id] = {}

    for _, comp_obj in ipairs(comp_objects) do
        comp_name = comp_obj._name

        if not component_manager.components[chunk] then
            component_manager.components[chunk] = {}
        end

        if not component_manager.components[chunk][comp_name] then
            component_manager.components[chunk][comp_name] = {}
        end

        table.insert(component_manager.components[chunk][comp_name], ent_id)

        entity_manager.entities[ent_id][comp_name] = comp_obj

    end
    -- clear_cache()
end

return ecs