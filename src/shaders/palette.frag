extern Image palette;
extern float paletteSize;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 pixel = Texel(tex, tc) * color;

    vec3 minColor = vec3(0.0);
    float minDist = 1e9;

    for (int i = 0; i < paletteSize; i++) {
        // sample from center of pixel
        float u = (float(i) + 0.5) / paletteSize;
        vec3 paletteColor = Texel(palette, vec2(u, 0.5)).rgb;

        vec3 diff = pixel.rgb - paletteColor;  // x and y diff of triangle;
        float dist = dot(diff, diff);  // length since dot(v, v) ≡ |v|;

        if (dist < minDist) {
            minDist = dist;
            minColor = paletteColor;
        }
    }

    return vec4(minColor, pixel.a);
}