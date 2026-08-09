local commons = require("src.libs.commons")
local Color = require("src.color")

local entity_manager = {
    counter = 0,
    entities = {},
}

function entity_manager.get_id()
    entity_manager.counter = entity_manager.counter + 1
    return entity_manager.counter - 1
end

local component_manager = {
    cache = {},  -- TODO. cache
    components = {},
}

local ecs = {singletons = {}}

function ecs.try_component(ent_id, comp_type)
    return entity_manager.entities[ent_id][comp_type._name]
end

function ecs._get_components(cx, cy, ...)
    -- if chunk does not exist, return nothing (early exit)
    local column = component_manager.components[cx]
    if not column then
        return {}
    end
    local chunk = column[cy]
    if not chunk then
        return {}
    end

    local comp_types = {...}

    -- get all possible collection of entities (based on component type) before intersecting them
    local possible_entities = {}
    for _, comp_type in ipairs(comp_types) do
        local comp_name = comp_type._name
        local ent_set = component_manager.components[cx][cy][comp_name]

        -- if the given chunk has no entities of the given component <comp_name>, then there can be no entity which has an intersection of the given components. return nothing
        if not ent_set then
            return {}
        end

        table.insert(possible_entities, component_manager.components[cx][cy][comp_name])
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

        local entity_data = {ent_id, cx, cy}
        for _, comp_obj in ipairs(comp_objects) do
            table.insert(entity_data, comp_obj)
        end
        table.insert(final_entity_data, entity_data)
    end

    return final_entity_data

end

function ecs.get_components(chunks, ...)
    local comp_types = {...}
    local ret = {}

    for _, chunk in ipairs(chunks) do
        local entity_data = ecs._get_components(chunk[1], chunk[2], commons.unpack(comp_types))
        commons.extend(ret, entity_data)
    end

    return ret
end

function ecs.delete_entity(ent_id, cx, cy)
    if not entity_manager.entities[ent_id] then
        return
    end

    for comp_type, _ in pairs(entity_manager.entities[ent_id]) do
        commons.remove_by_key(component_manager.components[cx][cy][comp_type], ent_id)
    end

    entity_manager.entities[ent_id] = nil
end

function ecs.relocate_entity(ent_id, src_chunk_x, src_chunk_y, new_chunk_x, new_chunk_y)
    -- save entity objects
    local comp_objects = {}
    for _, comp_obj in pairs(entity_manager.entities[ent_id]) do
        table.insert(comp_objects, comp_obj)
    end

    -- delete said entity
    ecs.delete_entity(ent_id, src_chunk_x, src_chunk_y)

    -- create new one at new chunk position
    ecs.create_entity(new_chunk_x, new_chunk_y, commons.unpack(comp_objects))
end

function ecs.create_entity(cx, cy, ...)
    local comp_objects = {...}

    local ent_id = entity_manager.get_id()
    entity_manager.entities[ent_id] = {}

    for _, comp_obj in ipairs(comp_objects) do
        local comp_name = comp_obj._name

        -- make sure the chunk entry exists
        if not component_manager.components[cx] then
            component_manager.components[cx] = {}
        end
        if not component_manager.components[cx][cy] then
            component_manager.components[cx][cy] = {}
        end

        -- make sure the component name is key of table
        if not component_manager.components[cx][cy][comp_name] then
            component_manager.components[cx][cy][comp_name] = {}
        end

        table.insert(component_manager.components[cx][cy][comp_name], ent_id)

        entity_manager.entities[ent_id][comp_name] = comp_obj
    end
end

return ecs