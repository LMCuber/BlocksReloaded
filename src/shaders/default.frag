vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 og = Texel(texture, texture_coords);

    return og * color;
}