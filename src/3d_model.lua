local Vec3 = require("src.libs.vec3")
local mmath = require("src.libs.mmath")
-- 
local commons = require("src.libs.commons")

local Model = {}
Model.__index = Model

-- MODEL
function Model:new(kwargs)
    local obj = setmetatable({}, self)

    -- mandatory arguments
    obj.obj_path = kwargs.obj_path
    obj.center = kwargs.center
    obj.ortho_size = kwargs.ortho_size

    -- optional arguments
    obj.angle = kwargs.angle or Vec3:new(0.0, 0.0, 0.0)
    obj.avel = kwargs.avel or Vec3:new(2.0, 2.0, 2.0)
    obj:update(1)
    obj.points = kwargs.color or nil
    obj.kwargs = kwargs

    -- mesh attributes
    obj.materials = {}
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
    local unique_vertices = {}
    local vertices = {}
    local normals = {}
    local indices = {}
    local vertices_normalized = false

    -- debug information
    local faces_skipped = 0
    local face_count = 0

    -- the current indices index
    local idx = 0

    -- (current_mtl_path, current_mtl) are used to index into self.materials to get color information, etc.
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

        -- -- select specific material from the previously loaded file
        if args[1] == "usemtl" then
            current_mtl = args[2]
        end

        -- parse vertices
        if args[1] == "v" then
            local vertex_pos = {
                tonumber(args[2]),
                -tonumber(args[3]),  -- flip y because of opengl
                tonumber(args[4]),
            }
            table.insert(unique_vertices, vertex_pos)
        end

        -- parse normals for each face
        if args[1] == "vn" then
            local normal = {
                tonumber(args[2]),
                tonumber(args[3]),
                tonumber(args[4]),
            }
            table.insert(normals, normal)
        end

        -- parse faces
        if args[1] == "f" then
            -- since f appears after v, we assume that all vertices have been loaded at this point in time.
            -- so we can normalize the vertices to have maximum length of 1 (just ONCE though)
            if not vertices_normalized then
                local max_len = 0
                -- find max
                for _, vertex_pos in ipairs(vertices) do
                    local len = math.sqrt(vertex_pos[1] ^ 2 + vertex_pos[2] ^ 2 + vertex_pos[3] ^ 2)
                    if len > max_len then
                        max_len = len
                    end
                end
                -- normalize all vertices in terms of max
                for i, vertex_pos in ipairs(vertices) do
                    vertices[i] = {
                        vertex_pos[1] / max_len,
                        vertex_pos[2] / max_len,
                        vertex_pos[3] / max_len,
                    }
                end
                vertices_normalized = true
            end

            -- create new vertices (with color and normal) made possible by indexing by the vert_index INTO the unique_vertices list
            -- then bind those new vertices together with a set of triangles (and add to the indices list)
            -- so basically all faces make their own pair of vertices with their own colors and normals
            -- (naturally vertex positions are duplicated the more faces a vertex is part of)

            -- check if a material exists
            local color = nil
            if current_mtl ~= nil then
                local diffuse = self.materials[current_mtl_path][current_mtl].Kd
                color = {diffuse[1], diffuse[2], diffuse[3], 1.0}
            else
                local diffuse = commons.rand_rgb()
                color = {diffuse[1], diffuse[2], diffuse[3], 1.0}
            end
            local vert_count = 0
            for i, vert_data in ipairs(args) do
                if i > 1 then
                    -- parse the face data
                    local data, vert_index, normal
                    if string.find(vert_data, "//") then
                        -- no texture data, just vertex//normal
                        data = commons.split(vert_data, "//")
                        vert_index = tonumber(data[1])
                        normal = normals[tonumber(data[2])]
                    else
                        -- vertex/texture uv/normal
                        data = commons.split(vert_data, "/")
                        vert_index = tonumber(data[1])
                        normal = normals[tonumber(data[3])]
                    end
                    local vertex_pos = unique_vertices[vert_index]

                    -- create a new vertex with correct index and correct color for this specific face
                    local vertex = {
                        vertex_pos[1], vertex_pos[2], vertex_pos[3],
                        color[1], color[2], color[3], color[4],
                        normal[1], normal[2], normal[3]
                    }
                    table.insert(vertices, vertex)
                    vert_count = vert_count + 1
                end
            end
            -- check if we need to split face into multiple triangles
            if vert_count == 3 then
                for _, i in ipairs({1, 2, 3}) do
                    table.insert(indices, idx + i)
                end
            elseif vert_count == 4 then
                for _, i in ipairs({1, 2, 3, 1, 4, 3}) do
                    table.insert(indices, idx + i)
                end
            else
                print(face_count .. "th face skipped; had " .. vert_count .. " vertices")
                faces_skipped = faces_skipped + 1
            end
            idx = idx + vert_count
            face_count = face_count + 1
        end

        ::continue::
    end

    print("→ " .. commons.round_to(faces_skipped / face_count * 100, 0.1) .. "% of faces skipped")

    local vertexFormat = {
        {"VertexPosition", "float", 3},
        {"VertexColor", "float", 4},
        {"VertexNormal", "float", 3},
    }
    self.mesh = love.graphics.newMesh(vertexFormat, vertices, "triangles", "static")
    self.mesh:setVertexMap(indices)
end

function Model:update(dt)
    local w, h = love.graphics.getDimensions()
    local aspect = w / h

    self.angle = self.angle:add(self.avel:scale(dt))

    self.model = mmath.mat4_multiply(mmath.mat4_rotateY(self.angle.y), mmath.mat4_rotateX(self.angle.x))
    self.view = mmath.mat4_lookAt({0, 0, 12}, {0, 0, 0}, {0, 1, 0})

    self.proj = mmath.mat4_ortho(
        -self.ortho_size * aspect,
        self.ortho_size * aspect,
        -self.ortho_size,
        self.ortho_size,
        -100,
        100
    )
end

return Model
