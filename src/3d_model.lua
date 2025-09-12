local Model = {}
Model.__index = Model

function Model:new()
    local obj = setmetatable({}, self)

    obj.vertices = {}

    return obj
end

return Model
