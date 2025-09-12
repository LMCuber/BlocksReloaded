-- ====== Config ======
local TILE = 30
local CHUNK_W = 16
local CHUNK_H = 16
local VIEW_PADDING_CHUNKS = 2
local MOVE_SPEED = 300 -- pixels per second

-- Lighting
local LIGHT_START = 1.0
local LIGHT_DECAY = 1/15

-- ====== World Class ======
local World = {}
World.__index = World

-- mine
tileset = love.graphics.newImage("res/images/spritesheets/blocks.png")
tileset:setFilter("nearest", "nearest")
local tileSize = 10

quads = {
    soil = love.graphics.newQuad(4 * tileSize, 0, tileSize, tileSize, tileset:getDimensions()),
}

function World:new(seedOffset)
    local w = setmetatable({}, self)
    w.seedOffset = seedOffset or 0
    w.chunks = {}   -- chunks["cx,cy"] -> chunk[y][x]
    w.lightmap = {} -- lightmap[ty][tx] = brightness
    return w
end

function World:chunkKey(cx, cy)
    return cx .. "," .. cy
end

function World:generateChunk(cx, cy)
    local key = self:chunkKey(cx, cy)
    if self.chunks[key] then return self.chunks[key] end

    local chunk = {}
    for y = 1, CHUNK_H do
        chunk[y] = {}
        local worldY = cy * CHUNK_H + (y-1)
        for x = 1, CHUNK_W do
            local worldX = cx * CHUNK_W + (x-1)
            local height = math.floor(love.math.noise((worldX + self.seedOffset) * 0.1) * 10 + 10)
            chunk[y][x] = (worldY >= height) and 1 or 0
        end
    end

    self.chunks[key] = chunk
    return chunk
end

function World:getTile(tx, ty)
    local cx = math.floor(tx / CHUNK_W)
    local cy = math.floor(ty / CHUNK_H)
    local key = self:chunkKey(cx, cy)
    local chunk = self.chunks[key]
    if not chunk then chunk = self:generateChunk(cx, cy) end
    local lx = (tx % CHUNK_W) + 1
    local ly = (ty % CHUNK_H) + 1
    return (chunk[ly] and chunk[ly][lx]) or 0
end

function World:setTile(tx, ty, value)
    local cx = math.floor(tx / CHUNK_W)
    local cy = math.floor(ty / CHUNK_H)
    local key = self:chunkKey(cx, cy)
    local chunk = self.chunks[key]
    if not chunk then chunk = self:generateChunk(cx, cy) end
    local lx = (tx % CHUNK_W) + 1
    local ly = (ty % CHUNK_H) + 1
    if chunk[ly] and chunk[ly][lx] then
        chunk[ly][lx] = value
    end
end

-- BFS Lighting
function World:propagateLighting(camera, screenW, screenH)
    local min_x = math.floor(camera.x / TILE) - 2
    local max_x = math.floor((camera.x + screenW) / TILE) + 2
    local min_y = math.floor(camera.y / TILE) - 2
    local max_y = math.floor((camera.y + screenH) / TILE) + 2

    self.lightmap = {}
    for ty = min_y, max_y do self.lightmap[ty] = {} end

    local qx, qy, ql = {}, {}, {}
    local head, tail = 1, 0

    for ty = min_y, max_y do
        for tx = min_x, max_x do
            if self:getTile(tx, ty) == 0 then
                tail = tail + 1
                qx[tail], qy[tail], ql[tail] = tx, ty, LIGHT_START
                self.lightmap[ty][tx] = LIGHT_START
            else
                self.lightmap[ty][tx] = 0
            end
        end
    end

    while head <= tail do
        local x, y, lv = qx[head], qy[head], ql[head]
        head = head + 1
        for _, n in ipairs({{x+1,y},{x-1,y},{x,y+1},{x,y-1}}) do
            local nx, ny = n[1], n[2]
            if self.lightmap[ny] and self.lightmap[ny][nx] ~= nil then
                local tile = self:getTile(nx, ny)
                local passLv = lv - LIGHT_DECAY
                if tile == 1 then passLv = lv - LIGHT_DECAY end
                if passLv > (self.lightmap[ny][nx] or 0) and passLv > 0 then
                    tail = tail + 1
                    qx[tail], qy[tail], ql[tail] = nx, ny, passLv
                    self.lightmap[ny][nx] = passLv
                end
            end
        end
    end
end

function World:draw(camera, screenW, screenH)
    local min_x = math.floor(camera.x / TILE) - 1
    local max_x = math.floor((camera.x + screenW) / TILE) + 1
    local min_y = math.floor(camera.y / TILE) - 1
    local max_y = math.floor((camera.y + screenH) / TILE) + 1

    for ty = min_y, max_y do
        for tx = min_x, max_x do
            local tile = self:getTile(tx, ty)
            local light = (self.lightmap[ty] and self.lightmap[ty][tx]) or 0
            local l = math.min(light, 1)

            if tile == 1 then
                
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(tileset, quads.soil, tx*TILE, ty*TILE, 0, 3, 3)
                love.graphics.setColor(0, 0, 0, 1 - l)
                love.graphics.rectangle("fill", tx*TILE, ty*TILE, TILE, TILE)
            end
        end
    end
end

-- ====== Global Game State ======
local world
local player = {x=100, y=100, w=TILE, h=TILE}
local camera = {x=0, y=0}
local screenW, screenH

-- ====== LÖVE Callbacks ======
function love.load()
    screenW, screenH = love.graphics.getDimensions()
    love.math.setRandomSeed(os.time())
    local seedOffset = love.math.random() * 1000
    world = World:new(seedOffset)

    -- Pre-generate chunks
    local startCx = math.floor((player.x / TILE)/CHUNK_W)
    local startCy = math.floor((player.y / TILE)/CHUNK_H)
    for cx = startCx-2, startCx+2 do
        for cy = startCy-2, startCy+2 do
            world:generateChunk(cx, cy)
        end
    end
end

function love.update(dt)
    -- Player movement
    if love.keyboard.isDown("w") then player.y = player.y - MOVE_SPEED*dt end
    if love.keyboard.isDown("s") then player.y = player.y + MOVE_SPEED*dt end
    if love.keyboard.isDown("a") then player.x = player.x - MOVE_SPEED*dt end
    if love.keyboard.isDown("d") then player.x = player.x + MOVE_SPEED*dt end

    -- Camera follows player
    camera.x = math.floor(player.x - screenW/2)
    camera.y = math.floor(player.y - screenH/2)

    -- Lighting
    world:propagateLighting(camera, screenW, screenH)

    -- Mouse block deletion
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        local tileX = math.floor((mx + camera.x) / TILE)
        local tileY = math.floor((my + camera.y) / TILE)
        world:setTile(tileX, tileY, 0)
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    -- Sky
    love.graphics.setColor(0.53, 0.80, 0.92)
    love.graphics.rectangle("fill", camera.x, camera.y, screenW, screenH)

    -- Tiles
    world:draw(camera, screenW, screenH)

    -- Draw player
    love.graphics.setColor(1,0,0)
    love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

    love.graphics.pop()

    -- FPS
    love.graphics.setColor(1,1,1)
    love.graphics.print("FPS: "..tostring(love.timer.getFPS()), 10,10)
end
