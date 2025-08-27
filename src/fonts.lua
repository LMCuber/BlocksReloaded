local fonts = {
    orbitron = {},
}

fonts.orbitron = {}
for i = 1, 100 do
    table.insert(fonts.orbitron, love.graphics.newFont("res/fonts/orbitron/static/orbitron-regular.ttf", i))
end

return fonts
