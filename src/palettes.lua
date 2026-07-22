local palettes = {
    list = {
        "2000", "31",
        "gun", "redorb", "rust_gold", "twilight", "pancakes",
        "apollo", "wisteric", "tinyfolks"
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
