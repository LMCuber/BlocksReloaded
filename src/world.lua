blocks = require("src.blocks")
biomes = require("src.biome")

-- constants
local VIEW_PADDING = 2
local MAX_LIGHT = 15

-- WORLD CLASS
local world = {
    data = {},
    lightmap = {},
    batch = love.graphics.newSpriteBatch(blocks.sprs, 1000),
    lighting = true,
    biome = biomes.Forest,
    x_seed = love.math.random(),
    y_seed = love.math.random(),
}
-- seed the RNG
love.math.setRandomSeed(world.x_seed)
print(world.x_seed, world.y_seed)

-- love event handlers
function love.keypressed(key, scancode, isrepeat)
    if key == "space" then
        world.lighting = not world.lighting
    end
end

function world:key(cx, cy)
    return cx .. "," .. cy
end

function world:parse_key(key)
    local cx, cy = key:match("(%d+),(%d+)")
    return tonumber(cx), tonumber(cy)
end


function world:octave_noise(args)
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

function world:create_chunk(cx, cy)
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
        local ground_height = math.floor(32 + (world:octave_noise({
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
                    if noise > 0.3 then
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

function world:set(key, rel_x, rel_y, name)
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


-- function world:offset(key, )

function world:modify_chunk(key)
    local function chance(n)
        return love.math.random() <= n
    end

    local chunk = self.data[key]
    for x = 1, CW do
        for y = 1, CH do
            local name = blocks.name[chunk[x][y]]



            if name == "soil_f" then
                if chance(1 / 10) then
                    self:set(key, x, y - 1, "red-poppy")
                end
            end

        end
    end

    return chunk
end

function world:get_tile(block_x, block_y)
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

function world:mouse_to_block(mx, my, scroll)
    local block_x = math.floor((mx + scroll.x) / BS)
    local block_y = math.floor((my + scroll.y) / BS)

    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)

    local key = self:key(chunk_x, chunk_y)

    local rel_x = (block_x % CW) + 1
    local rel_y = (block_y % CH) + 1

    return key, rel_x, rel_y
end

function world:break_(key, block_x, block_y)
    self.data[key][block_x][block_y] = blocks.id["air"]
end

function world:update(dt, scroll)
    if self.lighting then
        self:propagate_lighting(scroll)
    end
end

function world:propagate_lighting(scroll)
    -- Determine bounds
    local min_x = math.floor(scroll.x / BS) - VIEW_PADDING
    local max_x = math.floor((scroll.x + WIDTH) / BS) + VIEW_PADDING
    local min_y = math.floor(scroll.y / BS) - VIEW_PADDING
    local max_y = math.floor((scroll.y + HEIGHT) / BS) + VIEW_PADDING

    -- Reset lightmap
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
            if self:get_tile(tx, ty) == 0 then
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

function world:draw(scroll)
    local min_x = math.floor(scroll.x / BS)
    local max_x = math.floor((scroll.x + WIDTH) / BS)
    local min_y = math.floor(scroll.y / BS)
    local max_y = math.floor((scroll.y + HEIGHT) / BS)

    for ty = min_y, max_y do
        for tx = min_x, max_x do
            local tile = self:get_tile(tx, ty)
            local light = (self.lightmap[ty] and self.lightmap[ty][tx]) or 0

            if tile ~= blocks.id["air"] then
                -- normal tile
                local base = 0.36
                light = math.min(light + 1, MAX_LIGHT)
                local l = light / MAX_LIGHT
                love.graphics.draw(blocks.sprs, blocks.quads[tile], tx * BS, ty * BS, 0, S, S)
                love.graphics.setColor(0, 0, 0, 1 - l)
            end

            if self.lighting then
                love.graphics.rectangle("fill", tx * BS, ty * BS, BS, BS)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

return world
