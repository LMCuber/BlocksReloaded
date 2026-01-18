local Color = require("src.color")

local Benchmarker = {}
Benchmarker.__index = Benchmarker

function Benchmarker:new(width)
    local obj = {
        width = width or 100,
        freq = 0.5,
        times = {},
        prev_times = nil,
        last_update = love.timer.getTime(),
    }
    setmetatable(obj, Benchmarker)
    return obj
end

function Benchmarker:start(key)
    self.times[key] = love.timer.getTime()
end

function Benchmarker:finish(key)
    self.times[key] = love.timer.getTime() - self.times[key]
end

function Benchmarker:draw()
    local times
    local sum = 0
    local total_w = 0
    if self.prev_times == nil or love.timer.getTime() - self.last_update >= 0.5 then
        times = self.times
        self.prev_times = self.times
        self.last_update = love.timer.getTime()
    else
        times = self.prev_times
    end

    for _, time in pairs(times) do
        sum = sum + time
    end

    local xo = 180
    for key, time in pairs(times) do
        local w = time / sum * self.width
        love.graphics.setColor(key)
        love.graphics.rectangle("fill", xo + total_w, 46, w, 20)
        total_w = total_w + w
    end
    love.graphics.setColor(Color.BLACK)
    love.graphics.rectangle("line", xo, 46, self.width, 20)

    self.times = {}
end

return Benchmarker