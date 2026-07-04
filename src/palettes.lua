local commons = require("src.libs.commons")

local palettes = {
    list = {
        "2000", "31", "bumblebit", "century", "dusted_sunset",
        "gun", "raiten", "redorb", "rust_gold", "twilight", "ink", "69", "pancakes"
    }
}

for _, p in ipairs(palettes.list) do
    palettes[p] = {
        img = love.graphics.newImage("res/images/palettes/" .. p .. ".png"),
    }
    palettes[p].width, palettes[p].height = palettes[p].img:getDimensions()
end

function palettes:send(shader, p)
    if palettes[p] == nil then
        error(string.format("Palette '%s' not loaded", p))
    end
    shader:send("palette", self[p].img)
    shader:send("paletteSize", self[p].width)
end

return palettes
