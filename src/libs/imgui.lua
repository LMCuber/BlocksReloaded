local Color = require("src.color")
local fonts = require("src.fonts")
local commons = require("src.libs.commons")

local imgui = {}
local state = {
    -- defaults
    padding = {x = 8, y = 2},
    -- rest
    cursor = {x = 0, y = 0},
    width = 0,
    height = 0,
    was_pressed = false,
    font = nil,
    font_size = 16,
    bg_color = Color.DARK_GRAY
}

-- LIFETIME

function imgui.begin(window_name, cursor_x, cursor_y, width, height)
    -- setup
    state.cursor.x = cursor_x
    state.cursor.y = cursor_y + state.padding.x
    state.width = width
    state.height = height
    -- bg
    love.graphics.setColor{0.1, 0.1, 0.1, 0.8}
    love.graphics.rectangle("fill", state.cursor.x, state.cursor.y, width, height)
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

function imgui.combo(options, config, attr)
    local w, h = state.width, 24
    -- arrow width and height
    local ah = h - 6
    local aw = 18
    local ao = (h - ah) / 2  -- distance between arrow and top border of widget

    -- bg
    love.graphics.setColor(state.bg_color)
    love.graphics.rectangle("fill", state.cursor.x, state.cursor.y, w, h)

    -- left arrow
    local left_arrow = {state.cursor.x + state.padding.x, state.cursor.y + ao, aw, ah}
    local is_col_left = commons.collidepointmouse(commons.unpack(left_arrow))
    love.graphics.setColor(Color.NAVY)
    if is_col_left then
        love.graphics.setColor(Color.LIGHT_NAVY)
    end
    love.graphics.rectangle("fill", commons.unpack(left_arrow))
    love.graphics.setColor(Color.YELLOW)
    love.graphics.polygon("fill",
        left_arrow[1] + aw / 4, left_arrow[2] + ah / 2,
        left_arrow[1] + aw * (3 / 4), left_arrow[2],
        left_arrow[1] + aw * (3 / 4), left_arrow[2] + ah
    )

    -- text
    local index = config[attr]
    love.graphics.print(options[index], state.cursor.x + state.padding.x + aw + state.padding.x, state.cursor.y)

    -- right arrow
    local right_arrow = {state.cursor.x + w - aw - state.padding.x, state.cursor.y + ao, aw, ah}
    local is_col_right = commons.collidepointmouse(commons.unpack(right_arrow))
    love.graphics.setColor(Color.NAVY)
    if is_col_right then
        love.graphics.setColor(Color.LIGHT_NAVY)
    end
    love.graphics.rectangle("fill", commons.unpack(right_arrow))
    love.graphics.setColor(Color.WHITE)
    love.graphics.setColor(Color.YELLOW)
    love.graphics.polygon("fill",
        right_arrow[1] + aw * (3 / 4), right_arrow[2] + ah / 2,
        right_arrow[1] + aw / 4, right_arrow[2],
        right_arrow[1] + aw / 4, right_arrow[2] + ah
    )

    -- cleanup
    state.cursor.y = state.cursor.y + h + state.padding.y

    -- return value
    local is_pressed = love.mouse.isDown(1)
    if is_pressed and not state.was_pressed then
        if is_col_left then
            config[attr] = math.max(config[attr] - 1, 1)
        elseif is_col_right then
            config[attr] = math.min(config[attr] + 1, #options)
        end
        return true
    end
    return false
end

function imgui.hbar()
    local h = 30
    love.graphics.setColor(Color.WHITE)
    love.graphics.line(state.cursor.x, state.cursor.y + h / 2, state.width, state.cursor.y + h / 2)
    state.cursor.y = state.cursor.y + h + state.padding.y
end

function imgui.label(text)
    if state.font == nil then
        error "Set font using setNextFont first"
    end

    local h = state.font_size + 8

    love.graphics.setColor(Color.WHITE)
    love.graphics.setFont(state.font[state.font_size])
    love.graphics.print(text, state.cursor.x + state.padding.x, state.cursor.y)
    state.cursor.y = state.cursor.y + h + state.padding.y
end

function imgui.checkbox(text, config, attr)
    -- locals
    local w, h = state.width, 24
    local cw = h - 6  -- cw is the checkbox width
    local co = (h - cw) / 2

    -- bg
    love.graphics.setColor(state.bg_color)
    love.graphics.rectangle("fill", state.cursor.x, state.cursor.y, w, h)

    -- checkbox
    local checkbox = {state.cursor.x + state.padding.x, state.cursor.y + co, cw, cw}
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
    love.graphics.print(text, state.cursor.x + state.padding.x + cw + state.padding.x, state.cursor.y)

    -- advance cursor
    state.cursor.y = state.cursor.y + h + state.padding.y

    -- return if it is pressed
    local is_pressed = love.mouse.isDown(1)
    if is_col and is_pressed and not state.was_pressed then
        config[attr] = not config[attr]
        return true
    end
    return false
end

return imgui