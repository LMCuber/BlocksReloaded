local palette_list = {"31", "rust_gold", "blessing", "bumblebit", "neon_flesh", "twilight"}
local palettes = {}

for _, p in ipairs(palette_list) do
    palettes[p] = {
        img = love.graphics.newImage("res/images/palettes/" .. p .. ".png"),
    }
    palettes[p].width, palettes[p].height = palettes[p].img:getDimensions()
end

function palettes:send(shader, p)
    shader:send("palette", self[p].img)
    shader:send("paletteSize", self[p].width)
end

return palettes
