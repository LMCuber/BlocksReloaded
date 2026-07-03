local palette_list = {"2000", "31", "bumblebit", "century", "dusted_sunset", "gun", "raiten", "redorb", "rust_gold", "twilight"}
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
