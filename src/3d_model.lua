local Vec2 = require("src.vec2")
local Vec3 = require("src.vec3")
local Color = require("src.color")
-- 
local commons = require("src.commons")

local Model = {}
Model.__index = Model

local function polygon_winding(points)
    local n = #points
    local area = 0

    -- iterate over edges
    for i = 1, n-2, 2 do
        local x1, y1 = points[i], points[i+1]
        local x2, y2 = points[(i+2)], points[(i+3)]
        area = area + (x2 - x1) * (y2 + y1)
    end

    -- close polygon (last to first)
    local x1, y1 = points[n-1], points[n]
    local x2, y2 = points[1], points[2]
    area = area + (x2 - x1) * (y2 + y1)

    -- area > 0 -> CW
    return area
end

local function m_dot_m(A, B)
    local rowsA = #A
    local colsA = #A[1]
    local rowsB = #B
    local colsB = #B[1]

    -- Check if multiplication is possible
    if colsA ~= rowsB then
        error("Number of columns of A must match number of rows of B")
    end

    -- Initialize result matrix with zeros
    local C = {}
    for i = 1, rowsA do
        C[i] = {}
        for j = 1, colsB do
            C[i][j] = 0
        end
    end

    -- Multiply
    for i = 1, rowsA do
        for j = 1, colsB do
            for k = 1, colsA do
                C[i][j] = C[i][j] + A[i][k] * B[k][j]
            end
        end
    end

    return C
end

local function m_dot_v(M, v)
    local result = {}
    for i = 1, #M do
        result[i] = 0
        for j = 1, #v do
            result[i] = result[i] + M[i][j] * v[j]
        end
    end
    return result
end

local function v_dot_v(v1, v2)
    local result = 0
    for i = 1, #v1 do
        result = result + v1[i] * v2[i]
    end
    return result
end

local function get_rotation_matrix_x(a)
    return {
        {1, 0, 0},
        {0, math.cos(a), -math.sin(a)},
        {0, math.sin(a), math.cos(a)},
    }
end

local function get_rotation_matrix_y(a)
    return {
        {math.cos(a), 0, math.sin(a)},
        {0, 1, 0},
        {-math.sin(a), 0, math.cos(a)},
    }
end

local function get_rotation_matrix_z(a)
    return {
        {math.cos(a), -math.sin(a), 0},
        {math.sin(a), math.cos(a), 0},
        {0, 0, 1},
    }
end

local orthogonal_projection_matrix = {
    {1, 0, 0},
    {0, 1, 0},
    {0, 0, 0},
}

-- MODEL
function Model:new(kwargs)
    local obj = setmetatable({}, self)

    -- mandatory arguments
    obj.obj_file = kwargs.obj_file
    obj.center = kwargs.center
    obj.size = kwargs.size

    -- optional arguments
    obj.light = kwargs.light or {0, 1, 1}
    obj.light = commons.map(obj.light, function (x) return -x / commons.sum(obj.light) end)  -- invert light and normalize
    obj.angle = kwargs.angle or Vec3:new(0.0, 0.0, 0.0)
    obj.avel = kwargs.avel or Vec3:new(2.0, 2.0, 2.0)

    obj.vertices = {
        {  1,  1,  1 },
        {  1,  1, -1 },
        {  1, -1,  1 },
        {  1, -1, -1 },
        { -1,  1,  1 },
        { -1,  1, -1 },
        { -1, -1,  1 },
        { -1, -1, -1 },
    }

    obj.faces = {
        {{1, 3, 4, 2}, {commons.rand_rgb(), Color.BLACK}}, -- Right face (+X) - already CW
        {{5, 6, 8, 7}, {commons.rand_rgb(), Color.BLACK}}, -- Left face (-X) - reversed
        {{1, 2, 6, 5}, {commons.rand_rgb(), Color.BLACK}}, -- Top face (+Y) - already CW  
        {{3, 7, 8, 4}, {commons.rand_rgb(), Color.BLACK}}, -- Bottom face (-Y) - already CW
        {{1, 5, 7, 3}, {commons.rand_rgb(), Color.BLACK}}, -- Front face (+Z) - already CW
        {{2, 4, 8, 6}, {commons.rand_rgb(), Color.BLACK}}, -- Back face (-Z) - already CW
    }

    obj:load_model()

    obj.draw_vertices = {}
    self.updated_normals = {}

    return obj
end

function Model:load_model()
    self.vertices = {}
    self.normals = {}
    self.faces = {}

    for line in love.filesystem.lines(self.obj_file) do
        -- ignore comments
        if commons.startswith(line, "#") then
            goto continue
        end

        -- split line into args
        local args = commons.split(line, " ")

        -- skip extra stuff
        if args[1] == "mtllib" or args[1] == "o" then
            goto continue
        end

        -- parse vertices
        if args[1] == "v" then
            local vertex = {
                tonumber(args[2]),
                -tonumber(args[3]),  -- flip y
                tonumber(args[4])
            }
            table.insert(self.vertices, vertex)
        end

        -- parse normals
        if args[1] == "vn" then
            local normal = {
                tonumber(args[2]),
                -tonumber(args[3]),
                tonumber(args[4])
            }
            table.insert(self.normals, normal)
        end

        -- parse faces
        if args[1] == "f" then
            local vert_indices = {}
            -- iterate through all vertex/tex/normal
            local norm_index
            for i, vert_data in ipairs(args) do
                if i > 1 then
                    local data = commons.split(vert_data, "/")
                    local vert_index = tonumber(data[1])
                    norm_index = tonumber(data[3])
                    table.insert(vert_indices, vert_index)
                end
            end
            table.insert(self.faces, {vert_indices, norm_index, {Color.RED}})
        end

        ::continue::
    end
end

function Model:draw()
    love.graphics.setColor(Color.RED)
    -- for _, vertex in ipairs(self.draw_vertices) do
    --     local draw_x = self.center.x + vertex[1] * self.size
    --     local draw_y = self.center.y + vertex[2] * self.size
    --     love.graphics.circle("fill", draw_x, draw_y, 5)
    -- end

    for _, face_data in ipairs(self.faces) do
        -- FORMAT: {{vi1, v2, vi3}, ni, {fcolor, lcolor}}
        -- iterate through every single face: {{vi1, vi2, vi3}, {fcolor, lcolor}}
        local face_indices = face_data[1]  -- {vi1, vi2, vi3}
        local norm_index = face_data[2]  -- ni
        local face_colors = face_data[3]  -- {fcolor, lcolor}

        -- change color based on normal
        local normal = self.updated_normals[norm_index]
        local dot = v_dot_v(normal, self.light)
        local light_intensity = (dot + 1) / 2
        local fill_color = commons.map(face_colors[1], function(x) return light_intensity * x end)  -- fcolor
        local line_color
        if face_colors[2] ~= nil then
            line_color = commons.map(face_colors[2], function(x) return light_intensity * x end)  -- lcolor
        else
            line_color = nil
        end

        -- accumulate draw vertex data for the polygon
        local vertices = {}
        for _, vert_index in ipairs(face_indices) do
            -- vert_index: 1, 4, 6, etc.
            local vertex = self.draw_vertices[vert_index]  -- e.g. {-0.21, 0.34}
            local draw_x = self.center.x + vertex[1] * self.size
            local draw_y = self.center.y + vertex[2] * self.size
            table.insert(vertices, draw_x)
            table.insert(vertices, draw_y)
        end

        -- check if face vertices have correct winding (to backface cull)
        local winding = polygon_winding(vertices)
        if winding > 0 then
            love.graphics.setColor(fill_color)
            love.graphics.polygon("fill", vertices)
            if line_color ~= nil then
                love.graphics.setColor(line_color)
                love.graphics.polygon("line", vertices)
            end
        end
    end
end

function Model:update()
    -- step the position with velocity
    self.angle = self.angle + self.avel * dt

    -- update the vertex positions
    local total_matrix = m_dot_m(
        get_rotation_matrix_z(self.angle.z),
        m_dot_m(get_rotation_matrix_x(self.angle.x), get_rotation_matrix_y(self.angle.y))
    )

    -- transform the 3d vectors to 2d positions using rotation and projection matrices
    self.draw_vertices = {}
    self.updated_normals = {}
    for i, vertex in ipairs(self.vertices) do
        local new_vertex = m_dot_v(total_matrix, vertex)
        local ortho_vertex = m_dot_v(orthogonal_projection_matrix, new_vertex)
        table.insert(self.draw_vertices, {ortho_vertex[1], ortho_vertex[2]})
    end

    -- transform face normals as well
    for i, normal in ipairs(self.normals) do
        local new_normal = m_dot_v(total_matrix, normal)
        table.insert(self.updated_normals, new_normal)
    end
end

return Model
