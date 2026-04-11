local shaders = {}

local function load_shader(path, name)
    local code = love.filesystem.read(path)
    shaders[name] = love.graphics.newShader(code)
end

load_shader("src/shaders/default.frag", "default")
load_shader("src/shaders/lighting.frag", "lighting")
load_shader("src/shaders/sky.frag", "sky")

return shaders