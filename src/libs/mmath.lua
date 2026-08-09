local mmath = {}

function mmath.mat4_identity()
    return {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}
end

function mmath.mat4_scale(sx, sy, sz)
    return {
        sx, 0,  0,  0,
        0,  sy, 0,  0,
        0,  0,  sz, 0,
        0,  0,  0,  1
    }
end

function mmath.mat4_multiply(a, b)
    local r = {}
    for col = 0, 3 do
        for row = 0, 3 do
            local sum = 0
            for k = 0, 3 do
                sum = sum + a[k*4 + row + 1] * b[col*4 + k + 1]
            end
            r[col*4 + row + 1] = sum
        end
    end
    return r
end

function mmath.mat4_perspective(fovy, aspect, near, far)
    local f = 1 / math.tan(fovy / 2)
    local m = {}
    for i = 1, 16 do m[i] = 0 end
    m[1]  = f / aspect
    m[6]  = f
    m[11] = (far + near) / (near - far)
    m[12] = -1
    m[15] = (2 * far * near) / (near - far)
    m[16] = 0
    return m
end

function mmath.mat4_ortho(left, right, bottom, top, near, far)
    local rl = right - left
    local tb = top - bottom
    local fn = far - near

    return {
        2 / rl,          0,               0,               0,
        0,               2 / tb,          0,               0,
        0,               0,              -2 / fn,          0,
        -(right+left)/rl, -(top+bottom)/tb, -(far+near)/fn,  1
    }
end

function mmath.vec3_sub(a, b) return {a[1]-b[1], a[2]-b[2], a[3]-b[3]} end
function mmath.vec3_cross(a, b)
    return {
        a[2]*b[3] - a[3]*b[2],
        a[3]*b[1] - a[1]*b[3],
        a[1]*b[2] - a[2]*b[1]
    }
end
function mmath.vec3_dot(a, b) return a[1]*b[1] + a[2]*b[2] + a[3]*b[3] end
function mmath.vec3_normalize(a)
    local len = math.sqrt(mmath.vec3_dot(a, a))
    return {a[1]/len, a[2]/len, a[3]/len}
end

function mmath.mat4_lookAt(eye, target, up)
    local forward = mmath.vec3_normalize(mmath.vec3_sub(target, eye))
    local right = mmath.vec3_normalize(mmath.vec3_cross(forward, up))
    local camUp = mmath.vec3_cross(right, forward)

    local m = {}
    m[1]=right[1];   m[2]=camUp[1];   m[3]=-forward[1]; m[4]=0
    m[5]=right[2];   m[6]=camUp[2];   m[7]=-forward[2]; m[8]=0
    m[9]=right[3];   m[10]=camUp[3];  m[11]=-forward[3];m[12]=0
    m[13]=-mmath.vec3_dot(right, eye)
    m[14]=-mmath.vec3_dot(camUp, eye)
    m[15]=mmath.vec3_dot(forward, eye)
    m[16]=1
    return m
end

function mmath.mat4_rotateY(a)
    local c, s = math.cos(a), math.sin(a)
    return {
        c,0,-s,0,
        0,1,0,0,
        s,0,c,0,
        0,0,0,1
    }
end

function mmath.mat4_rotateX(a)
    local c, s = math.cos(a), math.sin(a)
    return {
        1,0,0,0,
        0,c,s,0,
        0,-s,c,0,
        0,0,0,1
    }
end

function mmath.mat4_rotateZ(a)
    local c, s = math.cos(a), math.sin(a)
    return {
        c, s, 0, 0,
       -s, c, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end

-- Converts column-major flat array to row-major format required by love.graphics.newShader:send()
function mmath.mat4_transpose(m)
    return {
        m[1], m[5], m[9],  m[13],
        m[2], m[6], m[10], m[14],
        m[3], m[7], m[11], m[15],
        m[4], m[8], m[12], m[16]
    }
end

function mmath.mat4_translate(x, y, z)
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        x, y, z, 1
    }
end

return mmath
