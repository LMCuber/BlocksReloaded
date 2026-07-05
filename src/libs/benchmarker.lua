local Color = require("src.color")
local fonts = require("src.fonts")
local commons = require("src.libs.commons")

local Benchmarker = {}
Benchmarker.__index = Benchmarker

function Benchmarker:new(width)
    local obj = {
        width = width or 100,
        freq = 0.5,
        times = {},  -- name (key) -> {time, color}
        prev_times = nil,
        last_update = love.timer.getTime(),
    }
    setmetatable(obj, Benchmarker)
    return obj
end

function Benchmarker:start(key, color)
    self.times[key] = {time = love.timer.getTime(), color = color}
end

function Benchmarker:finish(key, p)
    self.times[key].time = love.timer.getTime() - self.times[key].time
    if p then
        print(commons.round_to(self.times[key].time * 1000, 0.001) .. " / " .. 1 / love.timer.getFPS() * 1000 .. " ms")
    end
end

function Benchmarker:draw()
    local times
    local sum = 0
    local total_w = 0
    if self.prev_times == nil or love.timer.getTime() - self.last_update >= 0.2 then
        times = self.times
        self.prev_times = self.times
        self.last_update = love.timer.getTime()
    else
        times = self.prev_times
    end

    for _, payload in pairs(times) do
        sum = sum + payload.time
    end

    local xo = 180
    local m = 1
    for key, payload in pairs(times) do
        local time, color = payload.time, payload.color

        local w = time / sum * self.width
        love.graphics.setColor(color)
        love.graphics.setFont(fonts.orbitron[12])
        love.graphics.rectangle("fill", xo + total_w, 46, w, 20)

        if commons.collidepointmouse(xo + total_w, 46, w, 20) then
            love.graphics.setColor(Color.WHITE)
            local x, y = love.mouse.getPosition()
            love.graphics.setFont(fonts.orbitron[14])
            love.graphics.print(key, x - 20, y + 40)
        end

        total_w = total_w + w
        love.graphics.setColor(Color.WHITE)

        local mils = tonumber(string.format("%.1f", time * 1000))
        love.graphics.print(mils, xo + total_w - w / 2 - 12, 46 - 24 * m)

        m = -m
    end
    love.graphics.setColor(Color.BLACK)
    love.graphics.rectangle("line", xo, 46, self.width, 20)

    love.graphics.setColor(Color.WHITE)

    self.times = {}
end

return Benchmarker