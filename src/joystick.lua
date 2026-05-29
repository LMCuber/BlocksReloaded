--[[
Support:
- DS3
]]

local joystick = {}

joystick.joysticks = love.joystick.getJoysticks()
joystick.current = joystick.joysticks[1]
joystick.map = {
    ["Nefarius Software Solutions e.U. DS3 Compatible HID Device"] = {
        -- buttons
        bottom = 1,
        right = 2,
        left = 3,
        top = 4,
        L1 = 5,
        R1 = 6,
        BACK = 7,
        MENU = 8,
        L3 = 9,
        R3 = 10,
        -- axes
        HOR = 1,
        VER = 2,
    }
}

local function default_button_data()
    -- return all off states
    return {down = false, _was_down = false, clicked = false}
end

function joystick.is_clicked(btn_name)
    if joystick.current == nil then return false end
    return joystick.buttons[joystick.map[joystick.current:getName()][btn_name]]["clicked"]
end

function joystick.is_down(btn_name)
    if joystick.current == nil then return false end
    return joystick.buttons[joystick.map[joystick.current:getName()][btn_name]]["down"]
end

function joystick.get_axis(axis_name)
    return joystick.axes[joystick.map[joystick.current:getName()][axis_name]]
end

function joystick.axis_left(axis_name)
    if joystick.current == nil then return false end
    return joystick.get_axis(axis_name) <= -joystick.axis_threshold
end

function joystick.axis_right(axis_name)
    if joystick.current == nil then return false end;
    return joystick.get_axis(axis_name) >= joystick.axis_threshold
end

function joystick.axis_any(axis_name)
    if joystick.current == nil then return false end;
    return math.abs(joystick.get_axis(axis_name)) >= joystick.axis_threshold
end

-- init joysticks with data
joystick.buttons, joystick.axes = {}, {}
joystick.buttons = {}
if joystick.current ~= nil then
    for i = 1, joystick.current:getButtonCount() do
        joystick.buttons[i] = default_button_data()
    end
end
-- init axes with data
joystick.axes = {}
if joystick.current ~= nil then
    for i = 1, joystick.current:getAxisCount() do
        joystick.axes[i] = "none"  -- just so the singleton system can pick up the keys and update them (will never be read as "none")
    end
end
joystick.axis_threshold = 0.2

return joystick