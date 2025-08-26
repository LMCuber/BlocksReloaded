blocks = require("src.blocks")
biomes = require("src.biome")
ecs = require("src.ecs")
comp = require("src.components")
Vec2 = require("src.Vec2")
systems = require("src.systems")
fonts = require("src.fonts")

-- constants
local VIEW_PADDING = 2
local MAX_LIGHT = 15

-- WORLD CLASS
World = {}
World.__index = World

function World:new()
    local obj = setmetatable({}, self)

    obj.data = {}
    obj.lightmap = {}
    obj.light_surf = nil
    obj.batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
    obj.bg_batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
    obj.lighting = true
    obj.biome = biomes.Forest
    obj.x_seed = love.math.random()
    obj.y_seed = love.math.random()
    obj.processed_chunks = {}
    love.math.setRandomSeed(obj.x_seed)

    return obj
end

function World:process_keypress(key)
    if key == "space" then
        world.lighting = not world.lighting
    end
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

    for _ = 1, octaves do
        noise = noise + amp * love.math.noise(x * freq + self.x_seed, y * freq + self.y_seed)
        max_value = max_value + amp

        amp = amp * pers
        freq = freq * lac
    end
    
    return noise / max_value
end

function World:create_chunk(cx, cy)
    -- initialize chunk metadata
    local key = commons.key(cx, cy)
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
        }) - 0.5) * 32)
        local dirt_height = ground_height + 16

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
                    if block_y == ground_height then
                        name = biome.top
                    else 
                        name = biome.dirt
                    end

                else
                    if noise > 0.45 then
                        name = self:get_ore()
                    else
                        name = "stone|b"
                    end
                end
            end

            self:set(key, rel_x, rel_y, name)

        end
    end

    chunk = self:modify_chunk(key)

    return chunk
end

function World:get_ore()
    local r = love.math.random()
    if r <= 0.02 then
        return "base-ore"
    end
    return "stone"
end

function World:get(key, rel_x, rel_y)
    if self.data[key] and self.data[key][rel_x] and self.data[key][rel_x][rel_y] then
        return self.data[key][rel_x][rel_y]
    end
    return nil
end

function World:set(key, rel_x, rel_y, name, safe)
    -- safe means doesn't create new chunks if it overflows
    safe = safe or false

    -- Parse the current chunk key
    local cx, cy = key:match("(-?%d+),(-?%d+)")
    cx, cy = tonumber(cx), tonumber(cy)

    local nx, ny = rel_x, rel_y
    local nkey = key

    -- check horizontal bounds
    if nx < 1 or nx > CW then
        if safe then
            return
        end
        -- compute how many chunks we need to move
        local chunk_offset = math.floor((nx - 1) / CW)
        cx = cx + chunk_offset
        -- wrap nx back into 1..CW
        nx = nx - chunk_offset * CW
    end

    -- check vertical bounds
    if ny < 1 or ny > CH then
        if safe then
            return
        end
        -- compute how many chunks we need to move
        local chunk_offset = math.floor((ny - 1) / CH)
        cy = cy + chunk_offset
        -- wrap nx back into 1..CW
        ny = ny - chunk_offset * CH
    end

    nkey = cx .. "," .. cy

    -- Ensure the tables exist
    if not self.data[nkey] then
        self:create_chunk(cx, cy)
    end

    -- Assign the block
    self.data[nkey][nx][ny] = blocks.id[name]
end

function World:modify_chunk(key)
    local function chance(n)
        return love.math.random() <= n
    end

    local chunk_x, chunk_y = commons.parse_key(key)
    local chunk = self.data[key]

    for x = 1, CW do
        for y = 1, CH do
            local name = blocks.name[chunk[x][y]]
            local abs_x = chunk_x * CW + x
            local abs_y = chunk_y * CH + y

            -- F O R E S T
            if name == "soil_f" then
                -- flowers
                local flower = ""
                if chance(1 / 10) then
                    local c = love.math.random()
                    if c >= 0.7 then
                        flower = "red-poppy"
                    elseif c >= 0.4 then
                        flower = "yellow-poppy"
                    else
                        flower = "orchid"
                    end
                    self:set(key, x, y - 1, flower)
                end
                
                -- tree
                if chance(1 / 15) then
                    local tree_height = love.math.random(4, 16)
                    for yo = 1, tree_height do
                        if yo == tree_height then
                            self:set(key, x, y - yo, "wood_f_vrLRT")
                            self:set(key, x, y - yo - 1, "leaf_f")
                        else
                            self:set(key, x, y - yo, "wood_f_vrN")
                        end

                        if chance(1 / 4) or yo == tree_height then
                            self:set(key, x, y - yo, "wood_f_vrR")
                            self:set(key, x + 1, y - yo, "leaf_f")
                        elseif chance(1 / 4) or yo == tree_height then
                            self:set(key, x, y - yo, "wood_f_vrL")
                            self:set(key, x - 1, y - yo, "leaf_f")
                        end
                    end
                end

                -- pyramid
                if chance(1 / 100) then
                    local pyr_height = love.math.random(6, 20)
                    local pyr_offset = love.math.random(1, pyr_height / 4)
                    for yo = 0, pyr_height do
                        for xo = -yo, yo do
                            if xo == -yo or xo == yo or yo == pyr_height then
                                -- borders of the pyramid
                                self:set(key, x + xo, y - pyr_offset + yo, "sand")
                            else
                                -- inside of the pyramid
                                self:set(key, x + xo, y - pyr_offset + yo, "sand|b")
                            end
                            -- hidden chest!
                            if yo == pyr_height - 1 and xo == 0 then
                                self:set(key, x + xo, y - pyr_offset + yo, "chest")
                            end
                        end
                    end
                end

                -- entities
                if chance(1 / 1)
                        and string.sub(key, 1, 1) == "0" and x == 1
                        then
                    for i = 1, 1 do
                        ecs:create_entity(
                            key,
                            comp.Transform:new(
                                Vec2:new(abs_x * BS, (abs_y - 7 - i) * BS),
                                Vec2:new(0, 0)
                            ),
                            comp.Sprite:from_path("res/images/statics/portal/idle.png"),
                            comp.Hitbox:late()
                        )
                    end
                end
            end

            -- populate the ore veins (lmao same comment)
            if bwand(name, BF.ORE)
                    and self:get(key, x + 1, y) ~= nil and nbwand(blocks.name[self:get(key, x + 1, y)], BF.ORE)
                    and self:get(key, x - 1, y) ~= nil and nbwand(blocks.name[self:get(key, x - 1, y)], BF.ORE)
                    and self:get(key, x, y + 1) ~= nil and nbwand(blocks.name[self:get(key, x, y + 1)], BF.ORE)
                    and self:get(key, x, y - 1) ~= nil and nbwand(blocks.name[self:get(key, x, y - 1)], BF.ORE) then
                -- simple 2D brownian motion
                local num_walks = love.math.random(3, 7)
                local walk_x = x
                local walk_y = y
                for _ = 1, num_walks do
                    self:set(key, walk_x, walk_y, "base-ore", true)
                    r = love.math.random(1, 4)
                    if r == 1 then walk_x = walk_x + 1 end
                    if r == 2 then walk_x = walk_x - 1 end
                    if r == 3 then walk_y = walk_y + 1 end
                    if r == 4 then walk_y = walk_y - 1 end
                end
            end
        end
    end

    return chunk
end

function World:get_tile_chunk(block_x, block_y)
    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)
    return Vec2:new(chunk_x, chunk_y)
end

function World:get_tile(block_x, block_y, dont_create_if_empty)
    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)
    local key = commons.key(chunk_x, chunk_y)
    local chunk = self.data[key]
    if not chunk and not dont_create_if_empty then 
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

    local key = commons.key(chunk_x, chunk_y)

    local rel_x = (block_x % CW) + 1
    local rel_y = (block_y % CH) + 1

    return key, rel_x, rel_y
end

function World:get_blocks_around_pos(x, y, o)
    positions = {}
    o = o or 3
    for yo = -o, o do
        for xo = -o, o do
            local tx = math.floor(x / BS) + xo
            local ty = math.floor(y / BS) + yo
            local name = blocks.name[self:get_tile(tx, ty)]

            if nbwand(name, BF.WALKABLE) then
                table.insert(positions, Vec2:new(tx * BS, ty * BS))
            end
        end
    end
    return positions
end

function World:break_(key, block_x, block_y)
    self.data[key][block_x][block_y] = blocks.id["air"]
end

function World:update(dt, scroll)
    if self.lighting then
        self:propagate_lighting(scroll)
    end
    return self.processed_chunks
end

function World:propagate_lighting(scroll)
    -- determine bounds
    local min_x = math.floor(scroll.x / BS) - VIEW_PADDING
    local max_x = math.floor((scroll.x + WIDTH) / BS) + VIEW_PADDING
    local min_y = math.floor(scroll.y / BS) - VIEW_PADDING
    local max_y = math.floor((scroll.y + HEIGHT) / BS) + VIEW_PADDING

    -- empty processed chunks
    self.processed_chunks = {}
    local chunk_topleft, chunk_bottomright

    -- reset lightmap and light surface
    self.lightmap = {}
    for ty = min_y, max_y do
        self.lightmap[ty] = {}
    end

    -- BFS queue
    local qx, qy, ql = {}, {}, {}
    local head, tail = 1, 0

    -- init air tiles
    for ty = min_y, max_y do
        for tx = min_x, max_x do
            -- lighting stuff
            local name = blocks.name[self:get_tile(tx, ty)]
            if bwand(name, BF.LIGHT_SOURCE) then
                self.lightmap[ty][tx] = MAX_LIGHT
                tail = tail + 1
                qx[tail], qy[tail], ql[tail] = tx, ty, MAX_LIGHT
            else
                self.lightmap[ty][tx] = 0
            end

            -- save the topleft and bottomright chunks
            if tx == min_x and ty == min_y then
                chunk_topleft = self:get_tile_chunk(tx, ty)
            elseif tx == max_x and ty == max_y then
                chunk_bottomright = self:get_tile_chunk(tx, ty)
            end

        end
    end

    -- from the topleft and topright chunks, get intermediate chunks
    local safe = 1
    for y = chunk_topleft.y - safe, chunk_bottomright.y + safe do
        for x = chunk_topleft.x - safe, chunk_bottomright.x + safe do
            table.insert(self.processed_chunks, commons.key(x, y))
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

    -- return the processed chunks
    return self.processed_chunks
end

function World:draw(scroll)
    -- B L O C K S
    local min_x = math.floor(scroll.x / BS)
    local max_x = math.floor((scroll.x + WIDTH) / BS)
    local min_y = math.floor(scroll.y / BS)
    local max_y = math.floor((scroll.y + HEIGHT) / BS)
    local size_x = max_x - min_x + 1
    local size_y = max_y - min_y + 1
    local lighting_offset = Vec2:new(0, 0)

    -- clear the image batch and light surface
    self.batch:clear()
    self.bg_batch:clear()
    if self.lighting then
        self.light_surf = love.image.newImageData(size_x, size_y)
    end
    local prints = {}

    for ty = min_y, max_y do
        for tx = min_x, max_x do
            local tile = self:get_tile(tx, ty)
            local name = blocks.name[tile]
            local light = (self.lightmap[ty] and self.lightmap[ty][tx]) or 0

            if name ~= "air" then
                -- normal tile
                local base = 0.36
                -- light = math.min(light + 1, MAX_LIGHT)
                local l = light / MAX_LIGHT

                -- check if it's bg block to add to correct batch
                base, mods = norm(name)

                if commons.contains(mods, "b") then
                    self.bg_batch:add(blocks.quads[blocks.id[base]], tx * BS, ty * BS, 0, S, S)
                else
                    self.batch:add(blocks.quads[tile], tx * BS, ty * BS, 0, S, S)
                end

                -- add lighting to the mix
                if self.lighting then
                    self.light_surf:setPixel(
                        tx - min_x, ty - min_y,
                        0, 0, 0, 1 - l
                    )
                end
                -- table.insert(prints, {light or 0, tx * BS, ty * BS})
            end

            -- calculate the lighting offset
            if tx == min_x and ty == min_y then
                lighting_offset.x = tx * BS - scroll.x
                lighting_offset.y = ty * BS - scroll.y
            end

            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- B L O C K  L I G H T I N G
    love.graphics.draw(self.batch)
    local darkness = 0.5
    love.graphics.setColor(darkness, darkness, darkness, 1)
    love.graphics.draw(self.bg_batch)
    love.graphics.setColor(1, 1, 1, 1)

    -- debugging
    love.graphics.setColor(1, 0.8, 0.75, 1)
    love.graphics.setFont(fonts.orbitron[12])
    for _, x in ipairs(prints) do
        love.graphics.print(x[1], x[2], x[3])
    end

    if self.lighting then
        self.light_surf = love.graphics.newImage(self.light_surf)
        -- self.light_surf:setFilter("nearest", "nearest")
        love.graphics.draw(self.light_surf, scroll.x + lighting_offset.x, scroll.y + lighting_offset.y, 0, BS, BS)
    end

    -- E N T I T I E S
    local num_rendered_entities = systems.render:process(self.processed_chunks)
    return num_rendered_entities
end

local world = World:new()

systems.physics.world = world

return world
