local Color = require("src.color")
local fonts = require("src.fonts")
local commons = require("src.libs.commons")

local imgui = {}
local state = {
    -- defaults
    padding = 8,
    -- rest
    cursor_x = 0,
    cursor_y = 0,
    width = 0,
    height = 0,
    was_pressed = false,
    font = nil,
    font_size = 16,
}

-- LIFETIME

function imgui.begin(window_name, cursor_x, cursor_y, width, height)
    -- setup
    state.cursor_x = cursor_x
    state.cursor_y = cursor_y + state.padding
    state.width = width
    state.height = height
    -- bg
    love.graphics.setColor{0.1, 0.1, 0.1, 0.8}
    love.graphics.rectangle("fill", state.cursor_x, state.cursor_y, width, height)
end

function imgui.end_()
    state.was_pressed = love.mouse.isDown(1)
end

-- CONFIG

function imgui.setNextFont(font)
    state.font = font
end

function imgui.setNextFontSize(font_size)
    state.font_size = font_size
end

-- WIDGETS

function imgui.hbar()
    local h = 20
    love.graphics.setColor(Color.WHITE)
    love.graphics.line(state.cursor_x + 2, state.cursor_y + h / 2, state.cursor_x + state.width - 2, state.cursor_y + h / 2)
    state.cursor_y = state.cursor_y + h
end

function imgui.label(text)
    if state.font == nil then
        error "Set font using setNextFont first"
    end

    local h = state.font_size + 8

    love.graphics.setColor(Color.WHITE)
    love.graphics.setFont(state.font[state.font_size])
    love.graphics.print(text, state.cursor_x + state.padding, state.cursor_y)
    state.cursor_y = state.cursor_y + h
end

function imgui.checkbox(text, config, attr)
    -- locals
    local w, h = 120, 24
    local cw = h - 6  -- cw is the checkbox width
    local co = (h - cw) / 2  -- dist between checkbox and left side of text

    -- bg
    love.graphics.setColor(Color.DARK_GRAY)
    love.graphics.rectangle("fill", state.cursor_x, state.cursor_y, w, h)

    -- checkbox
    local checkbox = {state.cursor_x + state.padding, state.cursor_y + co, cw, cw}
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
    love.graphics.setFont(fonts.orbitron[state.font_size])
    love.graphics.print(text, state.cursor_x + cw + state.padding * 2, state.cursor_y)

    -- advance cursor
    state.cursor_y = state.cursor_y + h

    -- return if it is pressed
    local is_pressed = love.mouse.isDown(1)
    if is_col and is_pressed and not state.was_pressed then
        config[attr] = not config[attr]
    end
end

return imgui