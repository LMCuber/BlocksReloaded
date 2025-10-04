local shaders = {}

local code
code = love.filesystem.read("src/shaders/default.frag")
shaders.default = love.graphics.newShader(code)
code = love.filesystem.read("src/shaders/lighting.frag")
shaders.lighting = love.graphics.newShader(code)

return shaders