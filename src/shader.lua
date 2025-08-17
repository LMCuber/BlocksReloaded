local palette_img = love.graphics.newImage("res/images/palettes/2000.png")

local code = love.filesystem.read("src/default.frag")
local shader = love.graphics.newShader(code)
shader:send("palette", palette_img)
shader:send("paletteSize", palette_img:getWidth())

return shader