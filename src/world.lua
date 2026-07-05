local Vec2 = require("src.libs.vec2")
local Color = require("src.color")
-- 
local blocks = require("src.blocks")
local biomes = require("src.biome")
local ecs = require("src.libs.ecs")
local comp = require("src.components")
local systems = require("src.systems")
local yaml = require("src.libs.yaml")
local config = require("src.config")
local shaders = require("src.shaders")

-- constants
local VIEW_PADDING = MAX_LIGHT + 1

-- WORLD CLASS
local World = {}
World.__index = World

--[[
    cw, ch = chunk width, chunk height
    rx, ry = 1..CW, 1..CH
    pitch = (rx, ry)
    timbre = (cw, ch, rx, ry)
]]
function World:new()
    local obj = setmetatable({}, self)

    obj.player = nil

    obj.data = {}
    obj.bg_data = {}
    obj.lightmap = {}
    obj.light_surf = nil
    -- obj.lighting = true
    obj.lighting = false
    obj.light_frames = 1
    obj.light_frame = obj.light_frames + 1  -- starts at 10 + 1 = 11 so that the first iteration 100% updates light

    obj.batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
    obj.bg_batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
    obj.biome = biomes.Forest

    obj.x_seed = love.math.random()
    obj.y_seed = love.math.random()
    obj.x_seed = 1.2
    obj.y_seed = 2.4
    obj.processed_chunks = {}

    obj:load_structures()

    love.math.setRandomSeed(obj.x_seed)

    return obj
end

function World:check_timbre(key, block_x, block_y)
    return self.data
    and self.data[key]
    and self.data[key][block_x]
    and self.data[key][block_x][block_y]
    ~= nil
end

function World:load_structures()
    self.structures = {}

    local content, _ = love.filesystem.read("res/data/structures.yaml")
    self.structures = yaml.eval(content)

end

function World:place_structure(structure, cx, cy, x, y)
    for _, block_data in ipairs(self.structures[structure]) do
        self:set(
            cx,
            cy,
            x + block_data[1],
            y + block_data[2],
            block_data[3]
        )
    end
end

function World:process_keypress(key)
end

function World:octave_noise(args)
    args = args or {}

    local x = args.x
    local y = args.y or 0
    local freq = args.freq
    local pers = args.pers or 1
    local lac = args.lac or 1
    local octaves = args.octaves or 1
    local worm = args.worm or false

    local noise = 0
    local max_value = 0

    local amp = 1

    for _ = 1, octaves do
        noise = noise + amp * love.math.noise(x * freq + self.x_seed, y * freq + self.y_seed)
        max_value = max_value + amp

        amp = amp * pers
        freq = freq * lac
    end

    local final_value = noise / max_value

    if worm then
        return -math.abs(2 * final_value - 1) + 1
    end

    return final_value
end

function World:generate_chunk(cx, cy)
    -- initialize chunks
    local chunk = {}
    local bg_chunk = {}
    if not self.data[cx] then
        self.data[cx] = {[cy] = chunk}
        self.bg_data[cx] = {[cy] = bg_chunk}
    elseif not self.data[cx][cy] then
        self.data[cx][cy] = chunk
        self.bg_data[cx][cy] = bg_chunk
    end

    -- get the biome from noise
    local biome = biomes.Forest

    for rx = 1, CW do
        -- initialize empty column
        chunk[rx] = {}
        bg_chunk[rx] = {}

        -- get terrain height for this column from noise
        local block_x = cx * CW + (rx - 1)
        local ground_height = math.floor(32 + (self:octave_noise({
            x = block_x,
            y = 1,
            freq = biome.freq,
            octaves = 1,
        }) - 0.5) * 32)
        local dirt_height = ground_height + 16
        local zero_height = 512

        for ry = 1, CH do
            -- the final data that will be saved
            -- EVERYTHING ABOVE SOIL LEVEL IS AIR BY DEFAULT
            local name = "air"
            local bg_name = "air"

            local block_y = cy * CH + (ry - 1)

            if block_y >= ground_height then
                local noise = self:octave_noise({
                    x = block_x,
                    y = block_y,
                    freq = 0.02,
                    pers = 0.5,
                    lac = 2,
                    octaves = 3,
                    worm = true,
                })

                if block_y <= dirt_height then
                    if block_y == ground_height then
                        name = biome.top
                    else
                        name = biome.dirt
                    end
                    bg_name = biome.dirt

                elseif block_y <= zero_height then
                    -- cave
                    if not (noise > 0.7) then
                        name = self:get_ore()
                    end
                    bg_name = "stone"
                else
                    -- limit
                    name = "blackstone"
                end
            end

            -- finalize the data
            if name ~= nil then
                self.data[cx][cy][rx][ry] = blocks.id[name]
            end
            if bg_name ~= nil then
                self.bg_data[cx][cy][rx][ry] = blocks.id[bg_name]
            end
        end
    end

    chunk = self:modify_chunk(cx, cy)

    return chunk
end

function World:get_ore()
    local r = love.math.random()
    if false then
    elseif r <= 0.01 then
        return "base-core"
    elseif r <= 0.02 then
        return "base-ore"
    end
    return "stone"
end

function World:get(cx, cy, rx, ry)
    local column = self.data[cx]
    local chunk = column and column[cy]
    if not chunk then
        return nil
    end
    local rel_column = chunk[rx]
    return rel_column and rel_column[ry] or nil
end

function World:get_bg(cx, cy, rx, ry)
    local column = self.bg_data[cx]
    local chunk = column and column[cy]
    if not chunk then
        return nil
    end
    local rel_column = chunk[rx]
    return rel_column and rel_column[ry] or nil
end

function World:getc(cx, cy)
    local col = self.data[cx]
    return col and col[cy] or nil
end

function World:getc_bg(cx, cy)
    local col = self.bg_data[cx]
    return col and col[cy] or nil
end

function World:set(cx, cy, rx, ry, name, safe, is_bg)
    safe = safe or false  -- safe means doesn't create new chunks if it overflows. Default is false
    is_bg = is_bg or false  -- to change the bg tile instead of the foreground tile.

    -- handle horizontal bleeding
    if rx < 1 or rx > CW then
        local offset = math.floor((rx - 1) / CW)
        cx = cx + offset
        rx = ((rx - 1) % CW) + 1
    end

    -- handle vertical bleeding
    if ry < 1 or ry > CH then
        local offset = math.floor((ry - 1) / CH)
        cy = cy + offset
        ry = ((ry - 1) % CH) + 1
    end

    local target = is_bg and self.bg_data or self.data

    if not target[cx] or not target[cx][cy] then
        if safe then return end  -- don't potentially cause an infinite loop; just exit early 
        self:generate_chunk(cx, cy)
    end

    target[cx][cy][rx][ry] = blocks.id[name]
end

function World:modify_chunk(cx, cy)
    local function chance(n)
        return love.math.random() <= n
    end

    local chunk = self:getc(cx, cy)
    if chunk == nil then
        return nil
    end

    for x = 1, CW do
        for y = 1, CH do
            local name = blocks.name[chunk[x][y]]
            local abs_x = cx * CW + x
            local abs_y = cy * CH + y

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
                    self:set(cx, cy, x, y - 1, flower)
                end

                -- tree
                if chance(1 / 45) then
                    local tree_height = love.math.random(4, 16)
                    for yo = 1, tree_height do
                        if yo == tree_height then
                            -- top tree block is triple (left-right-top)
                            self:set(cx, cy, x, y - yo, "wood_f_vrLRT")
                            self:set(cx, cy, x, y - yo - 1, "leaf_f")
                            self:set(cx, cy, x - 1, y - yo, "leaf_f")
                            self:set(cx, cy, x + 1, y - yo, "leaf_f")
                        else
                            -- otherwise, have a probability of having a branch
                            if chance(1 / 4) then
                                self:set(cx, cy, x, y - yo, "wood_f_vrR")
                                self:set(cx, cy, x + 1, y - yo, "leaf_f")
                            elseif chance(1 / 4) then
                                self:set(cx, cy, x, y - yo, "wood_f_vrL")
                                self:set(cx, cy, x - 1, y - yo, "leaf_f")
                            else
                                self:set(cx, cy, x, y - yo, "wood_f_vrN")
                            end
                        end
                    end
                end

                -- other tree
                if chance(1 / 45) then
                    local tree_height = love.math.random(4, 16)
                    for yo = 1, tree_height do
                        if yo == tree_height then
                            -- top tree block is triple (left-right-top)
                            self:set(cx, cy, x, y - yo, "wood_p_vrN")
                            self:set(cx, cy, x, y - yo - 1, "leaf_f")
                            self:set(cx, cy, x - 1, y - yo, "leaf_f")
                            self:set(cx, cy, x + 1, y - yo, "leaf_f")
                        else
                            -- otherwise, have a probability of having a branch
                            if chance(1 / 4) then
                                self:set(cx, cy, x, y - yo, "wood_p_vrR")
                                self:set(cx, cy, x + 1, y - yo, "leaf_f")
                            elseif chance(1 / 4) then
                                self:set(cx, cy, x, y - yo, "wood_p_vrL")
                                self:set(cx, cy, x - 1, y - yo, "leaf_f")
                            else
                                self:set(cx, cy, x, y - yo, "wood_p_vrN")
                            end
                        end
                    end
                end

                -- pillar
                if chance(1 / 25) then
                    local tree_height = love.math.random(4, 16)
                    for yo = 1, tree_height do
                        local pillar_index = love.math.random(0, 3)
                        self:set(cx, cy, x, y - yo, "pillar_vr" .. pillar_index)
                    end
                end

                -- pyramid
                if chance(1 / 120) then
                    local pyr_height = love.math.random(6, 20)
                    local pyr_offset = love.math.random(1, pyr_height / 4)
                    for yo = 0, pyr_height do
                        for xo = -yo, yo do
                            if xo == -yo or xo == yo or yo == pyr_height then
                                -- borders of the pyramid
                                self:set(cx, cy, x + xo, y - pyr_offset + yo, "sand")
                            else
                                -- inside of the pyramid
                                self:set(cx, cy, x + xo, y - pyr_offset + yo, "air")
                                self:set(cx, cy, x + xo, y - pyr_offset + yo, "sand", false, true)
                            end
                            -- hidden chest!
                            if yo == pyr_height - 1 and xo == 0 then
                                self:set(cx, cy, x + xo, y - pyr_offset + yo, "chest")
                            end
                        end
                    end
                end

                -- entities
                if chance(1 / 20) then
                    for i = 1, 1 do
                        ecs.create_entity(
                            cx, cy,
                            comp.Transform:new(
                                Vec2:new(abs_x * BS, (abs_y - 7 - i) * BS),
                                Vec2:new(0, 0),
                                0.2
                            ),
                            comp.Sprite:from_path("res/images/statics/portal/idle.png"),
                            comp.Hitbox:dynamic()
                        )
                    end
                end

                if chance(1 / 1000000) then
                    for _ = 1, 5 do
                        ecs.create_entity(
                            cx, cy,
                            comp.Transform:new(
                                Vec2:new(abs_x * BS, (abs_y - 7) * BS),
                                Vec2:new(100),
                                1
                            ),
                            comp.Sprite:from_path("res/images/mobs/chicken/walk.png"),
                            comp.Hitbox:dynamic()
                        )
                    end
                end

                if chance(1 / 1000) then
                    ecs.create_entity(
                        cx, cy,
                        comp.Transform:new(
                            Vec2:new(abs_x * BS, (abs_y - 3) * BS),
                            Vec2:new(0, 0),
                            0
                        ),
                        comp.Sprite:from_path("res/images/mobs/bee/walk.png"),
                        comp.Hitbox:dynamic()
                    )
                end

                if chance(1 / 10) then
                    -- self:set(cx, cy, x, y - 3, "dynamite")
                    self:place_structure("well", cx, cy, x, y)
                end
            end

            -- populate the ore veins (lmao same comment)
            if bwand(name, BF.ORE)
                    and self:get(cx, cy, x + 1, y) ~= nil and nbwand(blocks.name[self:get(cx, cy, x + 1, y)], BF.ORE)
                    and self:get(cx, cy, x - 1, y) ~= nil and nbwand(blocks.name[self:get(cx, cy, x - 1, y)], BF.ORE)
                    and self:get(cx, cy, x, y + 1) ~= nil and nbwand(blocks.name[self:get(cx, cy, x, y + 1)], BF.ORE)
                    and self:get(cx, cy, x, y - 1) ~= nil and nbwand(blocks.name[self:get(cx, cy, x, y - 1)], BF.ORE) then

                -- simple 2D brownian motion
                local num_walks = love.math.random(3, 7)
                local walk_x = x
                local walk_y = y
                for _ = 1, num_walks do
                    self:set(cx, cy, walk_x, walk_y, "base-ore", true)
                    local r = love.math.random(1, 4)
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
    local cx = math.floor(block_x / CW)
    local cy = math.floor(block_y / CH)
    return Vec2:new(cx, cy)
end

function World:abs_pos_to_tile(block_x, block_y, dont_create_if_empty)
    local cx = math.floor(block_x / CW)
    local cy = math.floor(block_y / CH)
    local chunk = self:getc(cx, cy)
    if not chunk and not dont_create_if_empty then
        chunk = self:generate_chunk(cx, cy)
    end
    local rx = (block_x % CW) + 1
    local ry = (block_y % CH) + 1
    if chunk ~= nil then
        return (chunk[rx] and chunk[rx][ry]) or nil
    end
    return nil
end

function World:abs_pos_to_bg_tile(block_x, block_y, dont_create_if_empty)
    local cx = math.floor(block_x / CW)
    local cy = math.floor(block_y / CH)
    local chunk = self:getc_bg(cx, cy)
    if not chunk and not dont_create_if_empty then
        chunk = self:generate_chunk(cx, cy)
    end
    local rx = (block_x % CW) + 1
    local ry = (block_y % CH) + 1
    if chunk ~= nil then
        return (chunk[rx] and chunk[rx][ry]) or nil
    end
    return nil
end

function World:mouse_to_timbre(mx, my, scroll)
    local block_x = math.floor((mx + scroll.x) / BS)
    local block_y = math.floor((my + scroll.y) / BS)

    local cx = math.floor(block_x / CW)
    local cy = math.floor(block_y / CH)

    local rx = (block_x % CW) + 1
    local ry = (block_y % CH) + 1

    return cx, cy, rx, ry
end

function World:place(cx, cy, rx, ry, name)
    self.data[cx][cy][rx][ry] = blocks.id[name]
end

function World:break_(cx, cy, block_x, block_y)
    local name = blocks.name[self.data[cx][cy][block_x][block_y]]
    if bwand(name, BF.UNBREAKABLE) then
        return
    end
    self.data[cx][cy][block_x][block_y] = blocks.id["air"]
end

function World:update(dt, scroll)
    self:get_processed_chunks(scroll)
    if config.cb.lighting then
        bench:start("lighting", Color.YELLOW)
        self:propagate_lighting(scroll)
        bench:finish("lighting")
    else
        _G.debug_info["light steps"] = "off"
        _G.debug_info["light N"] = "-"
    end
    return self.processed_chunks
end

function World:get_processed_chunks(scroll)  -- side effect: updates self.processed_chunks
    self.processed_chunks = {}

    -- determine bounds
    local min_x = math.floor(scroll.x / BS) - VIEW_PADDING
    local max_x = math.floor((scroll.x + WIDTH) / BS) + VIEW_PADDING
    local min_y = math.floor(scroll.y / BS) - VIEW_PADDING
    local max_y = math.floor((scroll.y + HEIGHT) / BS) + VIEW_PADDING

    -- save the topleft and bottomright chunks
    local chunk_topleft = self:abs_pos_to_chunk(min_x, min_y)
    local chunk_bottomright = self:abs_pos_to_chunk(max_x, max_y)

    -- get the intermediate chunks
    local safety = 1
    for y = chunk_topleft.y - safety, chunk_bottomright.y + safety do
        for x = chunk_topleft.x - safety, chunk_bottomright.x + safety do
            table.insert(self.processed_chunks, {x, y})
        end
    end
end

local qx, qy, ql, qd = {}, {}, {}, {}   -- x, y, light, decay

function World:propagate_lighting(scroll)
    self.light_frame = self.light_frame + 1
    _G.debug_info["light N"] = self.light_frames
    if self.light_frame < self.light_frames then
        -- skip frame if it's not the 10th (the higher, the less accurate, but the faster the lighting)
        _G.debug_info["light steps"] = "----"
        return
    end
    self.light_frame = 0

    -- bounds for light propagation
    local min_x = math.floor(scroll.x / BS) - VIEW_PADDING
    local max_x = math.floor((scroll.x + WIDTH) / BS) + VIEW_PADDING
    local min_y = math.floor(scroll.y / BS) - VIEW_PADDING
    local max_y = math.floor((scroll.y + HEIGHT) / BS) + VIEW_PADDING

    -- propagation variables
    local map_w = max_x - min_x + 1
    local map_h = max_y - min_y + 1
    self.lightmap_w = map_w
    self.lightmap_h = map_h
    self.lightmap_min_x = min_x
    self.lightmap_min_y = min_y
    self.lightmap1d = self.lightmap1d or {}  -- seems to speed up but I don't know why. I assume because some lighting can remain the same?
    local lightmap = self.lightmap1d
    local light_data = blocks.light_data
    local head, tail = 1, 0

    -- lightmap data
    self.light_data = love.image.newImageData(map_w, map_h)
    self.light_data = love.image.newImageData(map_w, map_h)
    self.light_tex = love.graphics.newImage(self.light_data)
    self.light_tex:setFilter("linear", "linear")

    -- initialize lightmap from known light sources
    for ty = min_y, max_y do
        local y_offset = (ty - min_y) * map_w
        for tx = min_x, max_x do
            local idx = y_offset + (tx - min_x) + 1

            local tile = self:abs_pos_to_tile(tx, ty, true)
            local bg_tile = self:abs_pos_to_bg_tile(tx, ty, true)

            local name = blocks.name[tile]
            local bg_name = blocks.name[bg_tile]
            local ld = light_data[name]

            if (name == "air" and bg_name == "air") or (name ~= "air" and bwand(name, BF.LIGHT_SOURCE)) then
                local lv = ld and ld.strength or MAX_LIGHT
                -- Decay of 1 is standard for "spreading"
                local d = ld and ld.decay or 1

                lightmap[idx] = lv
                tail = tail + 1
                qx[tail], qy[tail], ql[tail], qd[tail] = tx, ty, lv, d
            else
                lightmap[idx] = 0
            end
        end
    end

    -- BFS propagation
    local steps = 0
    while head <= tail do
        local x, y, lv, d = qx[head], qy[head], ql[head], qd[head]
        head = head + 1

        -- the light level for the NEXT block
        local next_lv = lv - d

        if next_lv > 0 then
            for i = 1, 4 do
                local nx, ny
                if i == 1 then nx, ny = x + 1, y
                elseif i == 2 then nx, ny = x - 1, y
                elseif i == 3 then nx, ny = x, y + 1
                else nx, ny = x, y - 1 end

                if nx >= min_x and nx <= max_x and ny >= min_y and ny <= max_y then
                    local n_idx = (ny - min_y) * map_w + (nx - min_x) + 1
                    local cur = lightmap[n_idx] or 0

                    -- only spread if the new light is brighter than this current light
                    if next_lv > cur then
                        lightmap[n_idx] = next_lv
                        tail = tail + 1
                        qx[tail], qy[tail], ql[tail], qd[tail] = nx, ny, next_lv, d
                        steps = steps + 1
                    end
                end
            end
        end
    end

    -- put lightmap1d -> light_data
    for i = 1, #lightmap do
        local lx = (i - 1) % map_w
        local ly = math.floor((i - 1) / map_w)
        -- LIGHT IS STORED IN THE RED CHANNEL!
        if lx < map_w and ly < map_h then
            local val = lightmap[i] / MAX_LIGHT
            self.light_data:setPixel(lx, ly, val, 0, 0, 1)
        end
    end
    self.light_tex:replacePixels(self.light_data)

    _G.debug_info["light steps"] = steps
end

function World:prepare_lighting_shader(scroll)
    local shader = shaders.lighting
    -- send all the tile-space arguments to the shader
    shader:send("LightMap", self.light_tex)
    shader:send("lightMapOffset", {self.lightmap_min_x, self.lightmap_min_y})
    shader:send("cameraPos", {scroll.x / BS, scroll.y / BS})
    shader:send("lightMapSize", {self.lightmap_w, self.lightmap_h})
    shader:send("blockSize", BS)
end

function World:draw(scroll)
    -- updates debug info!

    local num_rendered_entities = 0
    local num_updated_entities = 0
    local num_rendered_tiles = 0
    -- B L O C K S
    --[[
    render steps:
        - background tiles
        - foreground tiles
        - entities
        - lighting overlay
    --]]
    local min_x = math.floor(scroll.x / BS)
    local max_x = math.floor((scroll.x + WIDTH) / BS)
    local min_y = math.floor(scroll.y / BS)
    local max_y = math.floor((scroll.y + HEIGHT) / BS)
    local size_x = max_x - min_x + 1
    local size_y = max_y - min_y + 1
    local lighting_offset = Vec2:new(0, 0)

    if config.cb.lighting then
        self.light_surf = love.image.newImageData(size_x, size_y)
    end

    if config.cb.blocks then
        bench:start("blocks", Color.GREEN)

        -- clear the image batch and light surface
        self.batch:clear()
        self.bg_batch:clear()


        local lw = self.lightmap_w
        local lx = self.lightmap_min_x
        local ly = self.lightmap_min_y
        for ty = min_y, max_y do
            local y_offset = (ty - ly) * lw
            local screen_y = ty * BS

            for tx = min_x, max_x do
                -- get the (bg) tile and (bg) name of the block given absolute coordinates
                local tile = self:abs_pos_to_tile(tx, ty)
                local bg_tile = self:abs_pos_to_bg_tile(tx, ty)
                local name = blocks.name[tile]
                local bg_name = blocks.name[bg_tile]

                -- lightmap index for this block
                local idx = y_offset + (tx - lx) + 1

                -- get light value
                local light = self.lightmap1d[idx] or 0

                -- if there is foreground, draw that. Else, if background, draw that
                if tile ~= nil and name ~= "air" then
                    self.batch:add(blocks.quads[tile], tx * BS, screen_y, 0, S, S)
                    num_rendered_tiles = num_rendered_tiles + 1
                end

                -- skip drawing the background tile IFF the foreground tile is solid (has no holes)
                if nbwand(name, BF.SOLID) and bg_tile ~= nil and bg_name ~= "air" then
                    self.bg_batch:add(blocks.quads[bg_tile], tx * BS, screen_y, 0, S, S)
                    num_rendered_tiles = num_rendered_tiles + 1
                end

                -- calculate the lighting offset
                if tx == min_x and ty == min_y then
                    lighting_offset.x = tx * BS - scroll.x
                    lighting_offset.y = screen_y - scroll.y
                end

                love.graphics.setColor(Color.WHITE)
            end
        end

        local bg_light_mult = 0.5
        love.graphics.setColor(bg_light_mult, bg_light_mult, bg_light_mult, 1)
        love.graphics.draw(self.bg_batch)
        love.graphics.setColor(Color.WHITE)
        love.graphics.draw(self.batch)
    end

    -- render the entities (REGARDLESS of block render)
    if config.cb.entities then
        bench:start("entities", Color.CYAN)
        num_rendered_entities, num_updated_entities = systems.render.process(self.processed_chunks)
        bench:finish("entities")
    end

    -- render the lightmap (REGARDLESS of blocks render)
    if config.cb.lighting then
        -- calculate the lighting offset
        lighting_offset.x = min_x * BS - scroll.x
        lighting_offset.y = min_y * BS - scroll.y
        self.light_surf = love.graphics.newImage(self.light_surf)
        -- self.light_surf:setFilter("nearest", "nearest")
        love.graphics.draw(self.light_surf, scroll.x + lighting_offset.x, scroll.y + lighting_offset.y, 0, BS, BS)
    end
    love.graphics.setColor(Color.WHITE)

    -- finish block rendering segment
    if config.cb.blocks then
        bench:finish("blocks")
    end

    _G.debug_info["R. entities"] = num_rendered_entities
    _G.debug_info["U. entities"] = num_updated_entities
    _G.debug_info["tiles"] = num_rendered_tiles
end

local world = World:new()

return world
