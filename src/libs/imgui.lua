local Color = require("src.color")
local fonts = require("src.fonts")
local commons = require("src.libs.commons")

local imgui = {}
local window = {
    x = 0,
    y = 0,
    cursor_x = 0,
    cursor_y = 0,
    was_pressed = false,
}
local was_pressed = false

function imgui.begin(window_name, cursor_x, cursor_y, width, height)
    -- setup
    window.cursor_x = cursor_x
    window.cursor_y = cursor_y
    -- bg
    love.graphics.setColor{0.1, 0.1, 0.1, 0.8}
    love.graphics.rectangle("fill", window.cursor_x, window.cursor_y, width, height)
end

function imgui.end_()
    window.was_pressed = love.mouse.isDown(1)
end

function imgui.checkbox(text, config, attr)
    -- locals
    local w, h = 120, 24
    local cw = h - 6  -- cw is the checkbox width
    local co = (h - cw) / 2  -- dist between checkbox and closest border of button

    -- bg
    love.graphics.setColor(Color.DARK_GRAY)
    love.graphics.rectangle("fill", window.cursor_x, window.cursor_y, w, h)

    -- checkbox
    local checkbox = {window.cursor_x + co, window.cursor_y + co, cw, cw}
    local is_col = commons.collidepointmouse(commons.unpack(checkbox))
    love.graphics.setColor(Color.NAVY)
    if is_col then
        love.graphics.setColor(Color.LIGHT_NAVY)
    end
    love.graphics.rectangle("fill", commons.unpack(checkbox))

    -- tickmark
    local s = 2  -- tick shrinkage w.r.t. being fully stuck to the border
    if config[attr] then
        love.graphics.setColor(Color.WHITE)
        love.graphics.line(
            checkbox[1] + s, checkbox[2] + (2 / 3) * cw,
            checkbox[1] + (1 / 3) * cw, checkbox[2] + cw - s,
            checkbox[1] + cw - s, checkbox[2] + s
        )
    end

    -- text
    love.graphics.setColor(Color.WHITE)
    love.graphics.setFont(fonts.orbitron[16])
    love.graphics.print(text, window.cursor_x + cw + co * 2 + 4, window.cursor_y)

    -- advance cursor
    window.cursor_y = window.cursor_y + h

    -- return if it is pressed
    local is_pressed = love.mouse.isDown(1)
    if is_col and is_pressed and not window.was_pressed then
        config[attr] = not config[attr]
    end
end

return imgui