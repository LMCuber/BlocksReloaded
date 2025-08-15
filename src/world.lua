blocks = require("src.blocks")
biomes = require("src.biome")
ecs = require("src.ecs")
ent = require("src.entities")
Vec2 = require("src.Vec2")
systems = require("src.systems")

-- constants
local VIEW_PADDING = 2
local MAX_LIGHT = 10

-- love event handlers
function love.keypressed(key, scancode, isrepeat)
    if key == "space" then
        world.lighting = not world.lighting
    end
end

-- WORLD CLASS
World = {}
World.__index = World

function World:new()
    local obj = setmetatable({}, self)

    obj.data = {}
    obj.lightmap = {}
    obj.light_surf = nil
    obj.batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
    obj.lighting = true
    obj.biome = biomes.Forest
    obj.x_seed = love.math.random()
    obj.y_seed = love.math.random()
    love.math.setRandomSeed(obj.x_seed)

    return obj
end

function World:key(cx, cy)
    return cx .. "," .. cy
end

function World:parse_key(key)
    local cx, cy = key:match("(%d+),(%d+)")
    return tonumber(cx), tonumber(cy)
end


function World:octave_noise(args)
    args = args or {}

    local x = args.x
    local y = args.y or 0
    local freq = args.freq
    local pers = args.pers or 1
    local lac = args.lac or 1
    local octaves = args.octaves or 1

    local noise = 0
    local max_value = 0

    local amp = 1

    for i = 1, octaves do
        noise = noise + amp * love.math.noise(x * freq + self.x_seed, y * freq + self.y_seed)
        max_value = max_value + amp

        amp = amp * pers
        freq = freq * lac
    end
    
    return noise / max_value
end

function World:create_chunk(cx, cy)
    -- initialize chunk metadata
    local key = self:key(cx, cy)
    local chunk = {}
    self.data[key] = chunk

    -- get the biome from noise
    local biome = biomes.Forest

    for rel_x = 1, CW do
        -- initialize empty column
        chunk[rel_x] = {}

        -- get terrain height for this column from noise
        local block_x = cx * CW + (rel_x - 1)
        local ground_height = math.floor(32 + (self:octave_noise({
            x = block_x,
            y = 1,
            freq = biome.freq
        }) - 0.6) * 2 * 15)
        local dirt_height = ground_height + 24

        local name

        for rel_y = 1, CH do
            local block_y = cy * CH + (rel_y - 1)

            if block_y < ground_height then
                name = "air"

            elseif block_y >= ground_height then
                local noise = self:octave_noise({
                    x = block_x,
                    y = block_y,
                    freq = 0.05,
                    pers = 0.5,
                    lac = 2,
                    octaves = 2
                })

                if block_y <= dirt_height then
                    if noise > 0 then
                        if block_y == ground_height then
                            name = biome.top
                        
                        elseif block_y < dirt_height then
                            name = biome.dirt
                        end
                        
                    else
                        name = "air"
                    end

                else
                    if noise > 0.45 then
                        name = "stone"
                    else
                        name = "air"
                    end
                end
            end

            self:set(key, rel_x, rel_y, name)

        end
    end

    chunk = self:modify_chunk(key)

    return chunk
end

function World:set(key, rel_x, rel_y, name)
    -- Parse the current chunk key
    local cx, cy = key:match("(-?%d+),(-?%d+)")
    cx, cy = tonumber(cx), tonumber(cy)

    local nx, ny = rel_x, rel_y
    local nkey = key

    -- Check horizontal bounds
    if nx < 1 then
        cx = cx - 1
        nx = CW + nx
    elseif nx > CW then
        cx = cx + 1
        nx = nx - CW
    end

    -- Check vertical bounds
    if ny < 1 then
        cy = cy - 1
        ny = CH + ny
    elseif ny > CH then
        cy = cy + 1
        ny = ny - CH
    end

    nkey = cx .. "," .. cy

    -- Ensure the tables exist
    self.data[nkey] = self.data[nkey] or {}
    self.data[nkey][nx] = self.data[nkey][nx] or {}

    -- Assign the block
    self.data[nkey][nx][ny] = blocks.id[name]
end

function World:modify_chunk(key)
    local function chance(n)
        return love.math.random() <= n
    end

    local chunk = self.data[key]
    for x = 1, CW do
        for y = 1, CH do
            local name = blocks.name[chunk[x][y]]

            if name == "soil_f" then
                -- flowers
                local flower = ""
                if chance(1 / 10) then
                    local c = love.math.random()
                    if c <= 0.7 then
                        flower = "red-poppy"
                    elseif c <= 0.4 then
                        flower = "yellow-poppy"
                    else
                        flower = "orchid"
                    end
                    self:set(key, x, y - 1, flower)
                end
            end

        end
    end

    return chunk
end

function World:get_tile(block_x, block_y)
    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)
    local key = self:key(chunk_x, chunk_y)
    local chunk = self.data[key]
    if not chunk then
        chunk = self:create_chunk(chunk_x, chunk_y)
    end
    local rel_x = (block_x % CW) + 1
    local rel_y = (block_y % CH) + 1
    return (chunk[rel_x] and chunk[rel_x][rel_y]) or 0
end

function World:mouse_to_block(mx, my, scroll)
    local block_x = math.floor((mx + scroll.x) / BS)
    local block_y = math.floor((my + scroll.y) / BS)

    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)

    local key = self:key(chunk_x, chunk_y)

    local rel_x = (block_x % CW) + 1
    local rel_y = (block_y % CH) + 1

    return key, rel_x, rel_y
end

function World:break_(key, block_x, block_y)
    self.data[key][block_x][block_y] = blocks.id["torch"]
end

function World:update(dt, scroll)
    if self.lighting then
        self:propagate_lighting(scroll)
    end
end

function World:propagate_lighting(scroll)
    -- determine bounds
    local min_x = math.floor(scroll.x / BS) - VIEW_PADDING
    local max_x = math.floor((scroll.x + WIDTH) / BS) + VIEW_PADDING
    local min_y = math.floor(scroll.y / BS) - VIEW_PADDING
    local max_y = math.floor((scroll.y + HEIGHT) / BS) + VIEW_PADDING

    -- reset lightmap and light surface
    self.lightmap = {}
    for ty = min_y, max_y do
        self.lightmap[ty] = {}
    end

    -- BFS queue
    local qx, qy, ql = {}, {}, {}
    local head, tail = 1, 0

    -- Init air tiles
    for ty = min_y, max_y do
        for tx = min_x, max_x do
            local name = blocks.name[self:get_tile(tx, ty)]
            if bwand(name, BF.LIGHT_SOURCE) then
                self.lightmap[ty][tx] = MAX_LIGHT
                tail = tail + 1
                qx[tail], qy[tail], ql[tail] = tx, ty, MAX_LIGHT
            else
                self.lightmap[ty][tx] = 0
            end
        end
    end

    -- BFS
    while head <= tail do
        local x, y, lv = qx[head], qy[head], ql[head]
        head = head + 1
        local n = {
            {x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}
        }
        for i = 1, #n do
            local nx, ny = n[i][1], n[i][2]
            if self.lightmap[ny] and self.lightmap[ny][nx] ~= nil then
                local decay = 1
                local pass_lv = lv - decay
                if pass_lv > (self.lightmap[ny][nx] or 0) and pass_lv > 0 then
                    self.lightmap[ny][nx] = pass_lv
                    tail = tail + 1
                    qx[tail], qy[tail], ql[tail] = nx, ny, pass_lv
                end
            end
        end
    end
end

function World:draw(scroll)
    -- B L O C K S
    local min_x = math.floor(scroll.x / BS)
    local max_x = math.floor((scroll.x + WIDTH) / BS)
    local min_y = math.floor(scroll.y / BS)
    local max_y = math.floor((scroll.y + HEIGHT) / BS)
    local size_x = max_x - min_x + 1
    local size_y = max_y - min_y + 1
    local lighting_offset = {x = 0, y = 0}

    -- clear the image batch and light surface
    self.batch:clear()
    if self.lighting then
        self.light_surf = love.image.newImageData(size_x, size_y)
    end

    for ty = min_y, max_y do
        for tx = min_x, max_x do
            local tile = self:get_tile(tx, ty)
            local light = (self.lightmap[ty] and self.lightmap[ty][tx]) or 0

            if tile ~= blocks.id["air"] then
                -- normal tile
                local base = 0.36
                light = math.min(light + 1, MAX_LIGHT)
                local l = light / MAX_LIGHT
                self.batch:add(blocks.quads[tile], tx * BS, ty * BS, 0, S, S)
                if self.lighting then
                    self.light_surf:setPixel(
                        tx - min_x, ty - min_y,
                        0, 0, 0, 1 - l
                    )
                end
            end

            if tx == min_x and ty == min_y then
                lighting_offset.x = tx * BS - scroll.x
                lighting_offset.y = ty * BS - scroll.y
            end

            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- B L O C K  L I G H T I N G
    love.graphics.draw(self.batch)

    if self.lighting then
        self.light_surf = love.graphics.newImage(self.light_surf)
        -- self.light_surf:setFilter("nearest", "nearest")
        love.graphics.draw(self.light_surf, scroll.x + lighting_offset.x, scroll.y + lighting_offset.y, 0, BS, BS)
    end

    -- E N T I T I E S
    systems.render:process()
end

local world = World:new()

ecs:create_entity(
    "0,0",
    ent.Transform:new(
        Vec2:new(0, 0),
        Vec2:new(0, 0)
    )
)

return world
