#pragma language glsl3

in vec3 vNormalView;

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords)
{
    vec3 n = normalize(vNormalView);
    float facing = max(dot(n, vec3(0.0, 0.0, 1.0)), 0.0);

    vec4 texColor = color;
    float brightness = mix(0.4, 1.0, facing);
    texColor.rgb *= brightness;

    return texColor;
}