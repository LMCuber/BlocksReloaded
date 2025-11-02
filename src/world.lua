local Vec2 = require("src.libs.vec2")
local Color = require("src.color")
-- 
local blocks = require("src.blocks")
local biomes = require("src.biome")
local ecs = require("src.libs.ecs")
local comp = require("src.components")
local systems = require("src.systems")
local fonts = require("src.fonts")
local commons = require("src.libs.commons")

-- constants
local VIEW_PADDING = 15
local MAX_LIGHT = 15

-- WORLD CLASS
local World = {}
World.__index = World

--[[\
    key = "1,0" (chunk key)
    chunk_pos = {1, 0}
    rel_x, rel_y = 1..CW, 1..CH
    pitch = rel_x, rel_y
    timbre = key, pitch
]]
function World:new()
    local obj = setmetatable({}, self)

    obj.player = nil

    obj.data = {}
    obj.bg_data = {}
    obj.lightmap = {}
    obj.light_surf = nil
    obj.lighting = false

    obj.batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
    obj.bg_batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
    obj.biome = biomes.Forest

    obj.x_seed = love.math.random()
    obj.y_seed = love.math.random()
    obj.processed_chunks = {}

    love.math.setRandomSeed(obj.x_seed)

    return obj
end

function World:process_keypress(key)
    if key == "space" then
        self.lighting = not self.lighting
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
    local bg_chunk = {}
    self.data[key] = chunk
    self.bg_data[key] = bg_chunk

    -- get the biome from noise
    local biome = biomes.Forest

    for rel_x = 1, CW do
        -- initialize empty column
        chunk[rel_x] = {}
        bg_chunk[rel_x] = {}

        -- get terrain height for this column from noise
        local block_x = cx * CW + (rel_x - 1)
        local ground_height = math.floor(32 + (self:octave_noise({
            x = block_x,
            y = 1,
            freq = biome.freq
        }) - 0.5) * 32)
        local dirt_height = ground_height + 16

        -- the final data that will be saved
        -- EVERYTHING ABOVE SOIL LEVEL IS AIR
        local name = "air"
        local bg_name = "air"

        for rel_y = 1, CH do
            local block_y = cy * CH + (rel_y - 1)

            if block_y >= ground_height then
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
                    bg_name = biome.dirt
                else
                    if noise > 0.45 then
                        name = self:get_ore()
                    end
                    bg_name = "stone"
                end
            end

            if name ~= nil then
                self.data[key][rel_x][rel_y] = blocks.id[name]
            end
            if bg_name ~= nil then
                self.bg_data[key][rel_x][rel_y] = blocks.id[bg_name]
            end

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

function World:set(key, rel_x, rel_y, name, safe, is_bg)
    safe = safe or false  -- safe means doesn't create new chunks if it overflows. Default is false
    is_bg = is_bg or false  -- to change the bg tile instead of the foreground tile. Previously was "|b"

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

    -- generate key by concatenating
    nkey = cx .. "," .. cy

    -- Ensure the tables exist
    -- local n = 0
    -- for k, v in pairs(self.data) do
    --     n = n + 1
    -- end
    -- print(n)
    if not self.data[nkey] then
        self:create_chunk(cx, cy)
    end

    -- Assign the block
    if is_bg then
        self.bg_data[nkey][nx][ny] = blocks.id[name]
    else
        self.data[nkey][nx][ny] = blocks.id[name]
    end
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
                if chance(1 / 40) then
                    local pyr_height = love.math.random(6, 20)
                    local pyr_offset = love.math.random(1, pyr_height / 4)
                    for yo = 0, pyr_height do
                        for xo = -yo, yo do
                            if xo == -yo or xo == yo or yo == pyr_height then
                                -- borders of the pyramid
                                self:set(key, x + xo, y - pyr_offset + yo, "sand")
                            else
                                -- inside of the pyramid
                                self:set(key, x + xo, y - pyr_offset + yo, "air")
                                self:set(key, x + xo, y - pyr_offset + yo, "sand", false, true)
                            end
                            -- hidden chest!
                            if yo == pyr_height - 1 and xo == 0 then
                                self:set(key, x + xo, y - pyr_offset + yo, "chest")
                            end
                        end
                    end
                end

                -- entities
                if chance(1 / 16) then
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

                if chance(1 / 11111111111) then
                    ecs:create_entity(
                        key,
                        comp.Transform:new(
                            Vec2:new(abs_x * BS, (abs_y - 3) * BS),
                            Vec2:new(0, 0),
                            0
                        ),
                        comp.Sprite:from_path("res/images/mobs/bee/walk.png"),
                        comp.Hitbox:late()
                    )
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

function World:abs_pos_to_chunk(block_x, block_y)
    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)
    return Vec2:new(chunk_x, chunk_y)
end

function World:abs_pos_to_tile(block_x, block_y, dont_create_if_empty)
    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)
    local key = commons.key(chunk_x, chunk_y)
    local chunk = self.data[key]
    if not chunk and not dont_create_if_empty then
        chunk = self:create_chunk(chunk_x, chunk_y)
    end
    local rel_x = (block_x % CW) + 1
    local rel_y = (block_y % CH) + 1
    return (chunk[rel_x] and chunk[rel_x][rel_y]) or nil
end

function World:abs_pos_to_bg_tile(block_x, block_y, dont_create_if_empty)
    local chunk_x = math.floor(block_x / CW)
    local chunk_y = math.floor(block_y / CH)
    local key = commons.key(chunk_x, chunk_y)
    local chunk = self.bg_data[key]
    if not chunk and not dont_create_if_empty then
        chunk = self:create_chunk(chunk_x, chunk_y)
    end
    local rel_x = (block_x % CW) + 1
    local rel_y = (block_y % CH) + 1
    return (chunk[rel_x] and chunk[rel_x][rel_y]) or nil
end

function World:mouse_to_timbre(mx, my, scroll)
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
    local positions = {}
    o = o or 3
    for yo = -o, o do
        for xo = -o, o do
            local tx = math.floor(x / BS) + xo
            local ty = math.floor(y / BS) + yo
            local name = blocks.name[self:abs_pos_to_tile(tx, ty)]

            if name ~= nil and nbwand(name, BF.WALKABLE) then
                table.insert(positions, Vec2:new(tx * BS, ty * BS))
            end
        end
    end
    return positions
end

function World:place(key, block_x, block_y, name)
    self.data[key][block_x][block_y] = blocks.id[name]
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
    local last = love.timer.getTime()
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
    bench:start(Color.RED)
    for ty = min_y, max_y do
        for tx = min_x, max_x do
            -- -- lighting stuff
            local name = blocks.name[self:abs_pos_to_tile(tx, ty)]
            local bg_name = blocks.name[self:abs_pos_to_bg_tile(tx, ty)]

            -- propagate light if the block is a light source
            if (name == "air" and bg_name == "air") or (name ~= "air" and bwand(name, BF.LIGHT_SOURCE)) then
                self.lightmap[ty][tx] = MAX_LIGHT
                tail = tail + 1
                qx[tail], qy[tail], ql[tail] = tx, ty, MAX_LIGHT
            else
                self.lightmap[ty][tx] = 0
            end

            -- save the topleft and bottomright chunks
            if tx == min_x and ty == min_y then
                chunk_topleft = self:abs_pos_to_chunk(tx, ty)
            elseif tx == max_x and ty == max_y then
                chunk_bottomright = self:abs_pos_to_chunk(tx, ty)
            end

        end
    end
    bench:finish(Color.RED)

    -- -- from the topleft and topright chunks, get intermediate chunks
    local safe = 1
    for y = chunk_topleft.y - safe, chunk_bottomright.y + safe do
        for x = chunk_topleft.x - safe, chunk_bottomright.x + safe do
            table.insert(self.processed_chunks, commons.key(x, y))
        end
    end

    -- local lightmap_a = love.graphics.newCanvas(max_x - min_x, max_y - min_y, {format = "r32f"})
    -- local lightmap_b = love.graphics.newCanvas(max_x - min_x, max_y - min_y, {format = "r32f"})

    -- love.graphics.setCanvas(lightmap_a)
    -- love.graphics.clear(0, 0, 0, 1)
    -- love.graphics.setColor(1, 1, 1, 1)
    
    -- for _, light in ipairs(lights) do
    --     love.graphics.setColor(light.intensity, 0, 0, 1)
    --     love.graphics.points(light.x, light.y)
    -- end


    -- BFS
    local steps = 0
    bench:start(Color.YELLOW)
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
                    steps = steps + 1
                    self.lightmap[ny][nx] = pass_lv
                    tail = tail + 1
                    qx[tail], qy[tail], ql[tail] = nx, ny, pass_lv
                end
            end
        end
    end
    bench:finish(Color.YELLOW)

    -- print((love.timer.getTime() - last)*1000 .. "ms")

    _G.debug_info["light steps"] = steps

    -- return the processed chunks
    return self.processed_chunks
end

function World:draw(scroll)
    bench:start(Color.LIME)

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
    local num_rendered_tiles = 0

    for ty = min_y, max_y do
        for tx = min_x, max_x do
            -- get the (bg) tile and (bg) name of the block given absolute coordinates
            local tile = self:abs_pos_to_tile(tx, ty)
            local bg_tile = self:abs_pos_to_bg_tile(tx, ty)
            local name = blocks.name[tile]
            local bg_name = blocks.name[bg_tile]

            -- if there is foreground, draw that. Else, if background, draw that
            if tile ~= nil and name ~= "air" then
                self.batch:add(blocks.quads[tile], tx * BS, ty * BS, 0, S, S)
                num_rendered_tiles = num_rendered_tiles + 1
            end
            if bg_tile ~= nil and bg_name ~= "air" then
                self.bg_batch:add(blocks.quads[bg_tile], tx * BS, ty * BS, 0, S, S)
                num_rendered_tiles = num_rendered_tiles + 1
            end
            num_rendered_tiles = num_rendered_tiles + 1

            -- only overlay block with darkness if the block itself is not a light source
            if self.lighting then
                -- get light value
                local light = (self.lightmap[ty] and self.lightmap[ty][tx]) or 0

                local norm_light = light / 15
                if nbwand(name, BF.LIGHT_SOURCE) or (name == "air" and bg_name ~= "air") then
                        self.light_surf:setPixel(
                        tx - min_x, ty - min_y,
                        0, 0, 0, 1 - norm_light
                    )
                end
                table.insert(prints, {light or 0, tx * BS, ty * BS})
            end

            -- calculate the lighting offset
            if tx == min_x and ty == min_y then
                lighting_offset.x = tx * BS - scroll.x
                lighting_offset.y = ty * BS - scroll.y
            end

            love.graphics.setColor(Color.WHITE)
        end
    end

    -- B L O C K  L I G H T I N G

    --[[
    render steps:
        - background tiles
        - foreground tiles
        - player
        - lighting overlay
    --]]

    local bg_light_mult = 0.5
    love.graphics.setColor(bg_light_mult, bg_light_mult, bg_light_mult, 1)
    love.graphics.draw(self.bg_batch)
    love.graphics.setColor(Color.WHITE)
    love.graphics.draw(self.batch)

    -- update the player
    self.player:draw(scroll)
    
    -- render the entities (render here so they work with the lightings)
    local num_rendered_entities = systems.render:process(self.processed_chunks)

    -- debugging
    -- love.graphics.setColor(1, 0.8, 0.75, 1)
    -- love.graphics.setFont(fonts.orbitron[12])
    -- for _, x in ipairs(prints) do
    --     love.graphics.print(x[1], x[2], x[3])
    -- end

    if self.lighting then
        self.light_surf = love.graphics.newImage(self.light_surf)
        -- self.light_surf:setFilter("nearest", "nearest")
        love.graphics.draw(self.light_surf, scroll.x + lighting_offset.x, scroll.y + lighting_offset.y, 0, BS, BS)
    end

    love.graphics.setColor(Color.WHITE)

    bench:finish(Color.LIME)

    _G.debug_info["entities"] = num_rendered_entities
    _G.debug_info["tiles"] = num_rendered_tiles
end

local world = World:new()

systems.physics.world = world

return world
