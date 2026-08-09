local Color = require("src.color")
local commons = require("src.libs.commons")
local shaders = require("src.shaders")
local mmath = require("src.libs.mmath")
local Model = require("src.3d_model")
local Vec3 = require("src.libs.vec3")
local engine = require("src.libs.engine")

local menu = {current = nil}

menu.state = {NONE = 1, ANVIL = 2}
engine.state.register(menu.state, menu.state.NONE)
engine.state.callback(menu.state, function (new_state)
    if new_state == menu.state.ANVIL then
        menu.current = menu.Anvil:new()
    end
end)

menu.Anvil = {}
menu.Anvil.__index = menu.Anvil

function menu.Anvil:new()
    local w = 260
    local h = 450
    return setmetatable({
        rect = {love.graphics.getWidth() / 2 - w / 2, love.graphics.getHeight() / 2 - h / 2, w, h},
        model = Model:new({
            obj_path = "res/models/katana.obj",
            scale = 12,
            center = Vec3:new(love.graphics.getWidth() / 2 - 60, love.graphics.getHeight() / 2 - 40),
            angle = Vec3:new(0, 0, 0),
            avel = Vec3:new(0, 0, 0),
            points = Color.NAVY,
        }),
    }, self)
end

function menu.Anvil:update(dt, input)  -- depencency inversion for input
    -- keep track whether should close this menu when function finishes
    local closed = false

    if input.keys["escape"].clicked then
        closed = true
    end

    if input.buttons[Button.LEFT].clicked then
        -- click out of the rectangle
        if not commons.collidepointmouse(commons.unpack(self.rect)) then
            closed = true
        end
    end

    -- rotate the model based on mouse input
    local dx, dy = input.mouse_rel.x, input.mouse_rel.y
    if input.buttons[Button.LEFT].down then
        local m = 0.01
        self.model.avel = Vec3:new(0, 0, 0)
        self.model.angle.y = self.model.angle.y + dx * m
        self.model.angle.x = self.model.angle.x - dy * m
    else
        -- if player is not rotating the object, give it natural rotation
        self.model.avel = Vec3:new(0, 0.4, 0)
    end

    -- update the model
    self.model:update(dt)

    if closed then
        engine.state.set_next(menu.state, menu.state.NONE)
    end
end

function menu.Anvil:draw()
    love.graphics.setColor(Color.NAVY)
    love.graphics.rectangle("fill", self.rect[1], self.rect[2], self.rect[3], self.rect[4])
    love.graphics.setColor(Color.DARK_NAVY)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", self.rect[1], self.rect[2], self.rect[3], self.rect[4])
    love.graphics.setLineWidth(1)
    love.graphics.setColor(Color.WHITE)
end

function menu.Anvil:draw_model()
    love.graphics.setCanvas({canvas.deep, depth = true})
    love.graphics.setShader(shaders.model)
    love.graphics.clear(true, true, true)
    love.graphics.setDepthMode("lequal", true)

    shaders.model:send("uModel", mmath.mat4_transpose(self.model.model))
    shaders.model:send("uView",  mmath.mat4_transpose(self.model.view))
    shaders.model:send("uProj",  mmath.mat4_transpose(self.model.proj))

    love.graphics.draw(self.model.mesh)

    -- model -> main window
    love.graphics.setShader()
    love.graphics.setDepthMode()
    love.graphics.setCanvas(nil)
    local sx = love.graphics.getWidth() / canvas.deep:getWidth()
    local sy = love.graphics.getHeight() / canvas.deep:getHeight()
    love.graphics.draw(canvas.deep, 0, 0, 0, sx, sy)
end

return menu