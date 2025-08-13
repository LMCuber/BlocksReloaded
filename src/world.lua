blocks = require("src.blocks")

-- constants
local VIEW_PADDING = 2

-- WORLD CLASS
local world = {
    data = {},
    lightmap = {},
    batch = love.graphics.newSpriteBatch(blocks.sprs, 1000)
}

function world:key(cx, cy)
    return cx .. "," .. cy
end

function world:create_chunk(cx, cy)
    local key = self:key(cx, cy)
    if self.data[key] then return self.data[key] end

    local chunk = {}
    self.data[key] = chunk

    for rel_x = 1, CW do
        chunk[rel_x] = {}

        local block_x = cx * CW + (rel_x - 1)
        local ground_height = math.floor(32 + (love.math.noise(block_x * 0.04) - 0.6) * 2 * 15)
        local dirt_height = ground_height + 16

        local name

        for rel_y = 1, CH do
            local block_y = cy * CH + (rel_y - 1)

            if block_y < ground_height then
                name = "air"

            elseif block_y >= ground_height then
                local noise = love.math.noise(block_x * 0.05, block_y * 0.05)

                if block_y <= dirt_height then
                    if noise > 0.3 then
                        if block_y == ground_height then
                            name = "soil_f"
                        
                        elseif block_y == dirt_height then
                            name = "dynamite"

                        elseif block_y < dirt_height then
                            name = "dirt_f"
                        end
                        
                    else
                        name = "air"
                    end

                else
                    if noise > 0.5 then
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

function world:set(key, block_x, block_y, name)
    self.data[key][block_x][block_y] = blocks.id[name]
end

function world:modify_chunk(key)
    local chunk = self.data[key]
    for x = 1, CW do
        for y = 1, CH do
            local name = blocks.name[chunk[x][y]]
            if name == "soil_f" then
                -- self:set(key, x, y, "red-poppy")
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
    -- self:propagate_lighting(scroll)
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
                self.lightmap[ty][tx] = 1
                tail = tail + 1
                qx[tail], qy[tail], ql[tail] = tx, ty, 1
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
        for i = 1, 4 do
            local nx, ny = n[i][1], n[i][2]
            if self.lightmap[ny] and self.lightmap[ny][nx] ~= nil then
                local decay = 1.4 / 15
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
    local min_x = math.floor(scroll.x / BS) - 1
    local max_x = math.floor((scroll.x + WIDTH) / BS) + 1
    local min_y = math.floor(scroll.y / BS) - 1
    local max_y = math.floor((scroll.y + HEIGHT) / BS) + 1

    for ty = min_y, max_y do
        for tx = min_x, max_x do
            local tile = self:get_tile(tx, ty)
            local light = (self.lightmap[ty] and self.lightmap[ty][tx]) or 0

            if tile == blocks.id["air"] then
                -- air tile
                love.graphics.setColor(0.8, 0.8, 1)
            else
                -- normal tile
                local base = 0.36
                local l = math.min(light, 1)
                love.graphics.draw(blocks.sprs, blocks.quads[tile], tx * BS, ty * BS, 0, S, S)
                love.graphics.setColor(0, 0, 0, 1 - l)
            end
            -- love.graphics.rectangle("fill", tx * BS, ty * BS, BS, BS)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

return world
