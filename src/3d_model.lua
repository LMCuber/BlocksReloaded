local Vec2 = require("src.libs.vec2")
local Vec3 = require("src.libs.vec3")
local Color = require("src.color")
-- 
local commons = require("src.libs.commons")

local Model = {}
Model.__index = Model

-- LLM CODE - NOT UNIT TESTED !!!
-- ...not that you have tested non LLM code dumbas
local function centroid(points)
    local sumx, sumy, sumz = 0, 0, 0
    for _, p in ipairs(points) do
        sumx = sumx + p[1]
        sumy = sumy + p[2]
        sumz = sumz + p[3]
    end
    local n = #points
    return {sumx / n, sumy / n, sumz / n}
end

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

-- MY CODE
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
    obj.obj_path = kwargs.obj_path
    obj.center = kwargs.center
    obj.size = kwargs.size

    -- optional arguments
    obj.light = kwargs.light or {0, -1, 1}
    -- obj.light = commons.map(obj.light, function (x) return -x / commons.length(obj.light) end)
    obj.angle = kwargs.angle or Vec3:new(0.0, 0.0, 0.0)
    obj.avel = kwargs.avel or Vec3:new(2.0, 2.0, 2.0)
    obj.kwargs = kwargs

    -- material attributes
    obj.materials = {}

    -- geometry attributes
    obj.updated_vertices = {}
    obj.updated_normals = {}
    obj:load_obj()

    return obj
end

function Model:load_mtl(mtl_file)
    -- derive the file path to the material path relative to the object path
    local obj_path = commons.split(self.obj_path, "/")
    obj_path[#obj_path] = mtl_file
    local mtl_path = table.concat(obj_path, "/")

    self.materials[mtl_path] = {}
    local current_mtl = nil
    for line in love.filesystem.lines(mtl_path) do
        -- ignore comments
        if commons.startswith(line, "#") then
            goto continue
        end

        -- split line into args
        local args = commons.split(line, " ")

        -- capture start of new material
        if args[1] == "newmtl" then
            current_mtl = args[2]
            self.materials[mtl_path][current_mtl] = {}
        end

        -- get diffuse color
        if args[1] == "Kd" then
            local color = {
                tonumber(args[2]),
                tonumber(args[3]),
                tonumber(args[4]),
            }
            self.materials[mtl_path][current_mtl]["Kd"] = color
        end

        ::continue::
    end

    return mtl_path
end

function Model:load_obj()
    self.vertices = {}
    self.normals = {}
    self.faces = {}
    self.lines = {}

    local current_mtl_path = nil
    local current_mtl = nil
    for line in love.filesystem.lines(self.obj_path) do
        -- ignore comments
        if commons.startswith(line, "#") then
            goto continue
        end

        -- split line into args
        local args = commons.split(line, " ")

        -- load material file
        if args[1] == "mtllib" then
            current_mtl_path = self:load_mtl(args[2])
        end

        -- select specific material from the previously loaded file
        if args[1] == "usemtl" then
            current_mtl = args[2]
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
            -- check whether the material file had a material in it
            local mtl_color
            if current_mtl == nil then
                -- default gray with black outline
                table.insert(self.faces, {vert_indices, norm_index, {Color.LIGHT_GRAY, Color.BLACK}})
            else
                -- material albedo
                mtl_color = self.materials[current_mtl_path][current_mtl]["Kd"]
                table.insert(self.faces, {vert_indices, norm_index, {mtl_color}})
            end
        end

        if args[1] == "l" then
            local vert_indices = {
                tonumber(args[2]),
                tonumber(args[3]),
            }
            table.insert(self.lines, vert_indices)
        end

        ::continue::
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
    self.updated_vertices = {}
    for _, vertex in ipairs(self.vertices) do
        local new_vertex = m_dot_v(total_matrix, vertex)
        -- local ortho_vertex = m_dot_v(orthogonal_projection_matrix, new_vertex)
        table.insert(self.updated_vertices, new_vertex)
    end

    -- sort the faces based on the centroid of the corresponding vertex, given the vertex indices
    -- FORMAT: {{vi1, v2, vi3}, ni, {fcolor, lcolor}}
    table.sort(self.faces, function(fda, fdb)
        local ia = {fda[1][1], fda[1][2], fda[1][3]}
        local ca = centroid({
            self.updated_vertices[ia[1]],
            self.updated_vertices[ia[2]],
            self.updated_vertices[ia[3]],
        })
        local ib = {fdb[1][1], fdb[1][2], fdb[1][3]}
        local cb = centroid({
            self.updated_vertices[ib[1]],
            self.updated_vertices[ib[2]],
            self.updated_vertices[ib[3]],
        })
        return ca[3] < cb[3]
    end)

    -- sort the lines the same fashion as the faces.
    table.sort(self.lines, function(ia, ib)
        local ca = centroid({
            self.updated_vertices[ia[1]],
            self.updated_vertices[ia[2]],
        })
        local cb = centroid({
            self.updated_vertices[ib[1]],
            self.updated_vertices[ib[2]],
        })
        return ca[3] < cb[3]
    end)

    -- transform normals (just like we did the vertices)
    self.updated_normals = {}
    for _, normal in ipairs(self.normals) do
        local new_normal = m_dot_v(total_matrix, normal)
        table.insert(self.updated_normals, new_normal)
    end
end

function Model:draw()
    self.draw_vertices = {}
    -- transform all updated vertices to drawable pixel coordinates
    for _, vertex in ipairs(self.updated_vertices) do
        local draw_x = self.center.x + vertex[1] * self.size
        local draw_y = self.center.y + vertex[2] * self.size
        table.insert(self.draw_vertices, {draw_x, draw_y})
    end

    for _, face_data in ipairs(self.faces) do
        -- FORMAT: {{vi1, v2, vi3}, ni, {fcolor, lcolor}}
        -- iterate through every single face: {{vi1, vi2, vi3}, {fcolor, lcolor}}
        local face_indices = face_data[1]  -- {vi1, vi2, vi3}
        local norm_index = face_data[2]  -- ni
        local face_colors = face_data[3]  -- {fcolor, lcolor}

        -- change color based on normal
        local fill_color = face_colors[1]
        local line_color = face_colors[2]

        -- check if current normal from index exists (for some reason some model's don't fix their normals)
        if self.updated_normals[norm_index] ~= nil then
            -- there is a given surface normal so calculate light
            local normal = self.updated_normals[norm_index]
            local dot = v_dot_v(normal, self.light)
            local light_intensity = (dot + 1) / 2

            fill_color = commons.map(fill_color, function(x) return light_intensity * x end)  -- lcolor
            -- check if line color exists, if not, don't render it
            if face_colors[2] ~= nil then
                line_color = commons.map(line_color, function(x) return light_intensity * x end)  -- lcolor
            else
                line_color = nil
            end
        else
            -- no normal, so just albedo (boring)
            if face_colors[2] ~= nil then
                line_color = face_colors[2]
            else
                line_color = nil
            end
        end

        -- accumulate draw vertex data for the polygon in a callable argument format:
        -- x1, y2, x2, y2, x3, y3, ..., xn, yn
        local vertices = {}
        for _, vert_index in ipairs(face_indices) do
            local draw_pos = self.draw_vertices[vert_index]
            table.insert(vertices, draw_pos[1])
            table.insert(vertices, draw_pos[2])
        end

        -- check if face vertices have correct winding (to backface cull)
        local winding = polygon_winding(vertices)
        if winding > 0 then
            -- clockwise, so render
            love.graphics.setColor(fill_color)
            love.graphics.polygon("fill", vertices)
            if line_color ~= nil then
                love.graphics.setColor(line_color)
                love.graphics.polygon("line", vertices)
            end
        end
    end

    if self.kwargs.points then
        -- draw circles at vertices
        love.graphics.setColor(Color.RED)
        for _, vertex in ipairs(self.updated_vertices) do
            local draw_x = self.center.x + vertex[1] * self.size
            local draw_y = self.center.y + vertex[2] * self.size
            love.graphics.circle("fill", draw_x, draw_y, 12)
        end
    end

    for _, vert_indices in ipairs(self.lines) do
        local p1 = self.draw_vertices[vert_indices[1]]
        local p2 = self.draw_vertices[vert_indices[2]]
        love.graphics.setColor(Color.ORANGE)
        love.graphics.line(p1[1], p1[2], p2[1], p2[2])
        love.graphics.setColor(Color.WHITE)
    end
end

return Model
