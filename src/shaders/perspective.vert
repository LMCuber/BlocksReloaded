uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_proj;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    return u_proj * u_view * u_model * vertex_position;
}