#pragma language glsl3

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProj;

in vec3 VertexNormal;
out vec3 vNormalView;  // the transformed normals to be fed into the fragment shader

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    mat4 modelview = uView * uModel;
    vNormalView = mat3(modelview) * VertexNormal;
    return uProj * modelview * vertex_position;
}