#pragma language glsl3

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProj;

in vec3 VertexNormal;

out vec3 vNormalView;
out vec3 vPositionView;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    mat4 modelView = uView * uModel;
    vec4 posView = modelView * vertex_position;
    vPositionView = posView.xyz;
    vNormalView = mat3(modelView) * VertexNormal;
    return uProj * posView;
}