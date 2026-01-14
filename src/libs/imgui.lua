local Color = require("src.color")
local fonts = require("src.fonts")
local commons = require("src.libs.commons")

local imgui = {}
local window = {
    x = 0,
    y = 0,
    cursor_x = 0,
    cursor_y = 0,
}

function imgui.begin(window_name, cursor_x, cursor_y, width, height)
    -- setup
    window.cursor_x = cursor_x
    window.cursor_y = cursor_y
    -- bg
    love.graphics.setColor{0.1, 0.1, 0.1, 0.8}
    love.graphics.rectangle("fill", window.cursor_x, window.cursor_y, width, height)
end

function imgui.end_()
end

function imgui.checkbox(text)
    local w, h = 120, 24
    local rw = h - 6
    local ro = (h - rw) / 2
    -- bg
    love.graphics.setColor(Color.DARK_GRAY)
    love.graphics.rectangle("fill", window.cursor_x, window.cursor_y, w, h)
    -- checkbox
    local checkbox = {window.cursor_x + ro, window.cursor_y + ro, rw, rw}
    love.graphics.setColor(Color.NAVY)
    love.graphics.rectangle("fill", commons.unpack(checkbox))
    -- text
    love.graphics.setColor(Color.WHITE)
    love.graphics.setFont(fonts.orbitron[16])
    love.graphics.print(text, window.cursor_x + rw + ro * 2, window.cursor_y)
    -- advance cursor
    window.cursor_y = window.cursor_y + h
    -- check collision
    if commons.collidepointmouse(commons.unpack(checkbox)) then
    end
end

return imgui