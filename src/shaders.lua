local shaders = {}

local function load_shader(name, frag_path, vert_path)
    local frag_code = love.filesystem.read(frag_path)
    if vert_path ~= nil then
        local vert_code = love.filesystem.read(vert_path)
        shaders[name] = love.graphics.newShader(frag_code, vert_code)
    else
        shaders[name] = love.graphics.newShader(frag_code)
    end
end

load_shader("model", "src/shaders/identity.frag", "src/shaders/perspective.vert")

load_shader("lighting", "src/shaders/lighting.frag")
load_shader("palette", "src/shaders/palette.frag")

return shaders