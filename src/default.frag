extern Image palette;
extern float paletteSize;

vec3 getPaletteColor(int i) {
    float u = (float(i) + 0.5) / paletteSize;  // Center of each pixel horizontally
    return Texel(palette, vec2(u, 0.5)).rgb;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec3 original = Texel(texture, texture_coords).rgb;

    float minDist = 1000.0;
    vec3 bestColor = vec3(0.0);

    for (int i = 0; i < paletteSize; i++) {
        vec3 palColor = getPaletteColor(i);
        float dist = distance(original, palColor);
        if (dist < minDist) {
            minDist = dist;
            bestColor = palColor;
        }
    }

    return vec4(bestColor, 1.0);
}