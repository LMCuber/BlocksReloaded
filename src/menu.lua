local Color = require("src.color")
local systems = require("src.systems")
local commons = require("src.libs.commons")

local menu = {}

menu.Anvil = {}
menu.Anvil.__index = menu.Anvil

function menu.new_menu(type)
    if type == "anvil" then
        return menu.Anvil:new()
    end
end

function menu.Anvil:new()
    local w = 260
    local h = 450
    return setmetatable({
        rect = {love.graphics.getWidth() / 2 - w / 2, love.graphics.getHeight() / 2 - h / 2, w, h}
    }, self)
end

function menu.Anvil:update()
    -- return whether should close
    local closed = false

    local sg = systems._singletons
    if sg.buttons[Button.LEFT].clicked and not sg.buttons[Button.LEFT].consumed then
        -- click out of the rectangle
        if not commons.collidepointmouse(commons.unpack(self.rect)) then
            closed = true
        end

        sg.buttons[Button.LEFT].consumed = true
    end

    return closed
end

function menu.Anvil:draw()
    love.graphics.setColor(Color.BROWN)
    love.graphics.rectangle("fill", self.rect[1], self.rect[2], self.rect[3], self.rect[4])
    love.graphics.setColor(Color.BROWN)
    love.graphics.rectangle("fill", self.rect[1], self.rect[2], self.rect[3], self.rect[4])
    love.graphics.setColor(Color.WHITE)
end

return menu