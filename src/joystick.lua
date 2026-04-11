--[[
Support:
- DS5
]]

local joysticks = love.joystick.getJoysticks()
for i, joystick in ipairs(joysticks) do
    print(joystick:getName())
end

return joysticks