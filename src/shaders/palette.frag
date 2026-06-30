extern Image palette;
extern float paletteSize;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 pixel = Texel(tex, tc) * color;

    vec3 best_color = vec3(0.0);
    float best_dist = 1e9;

    for (int i = 0; i < int(paletteSize); i++) {
        float u = (float(i) + 0.5) / paletteSize;
        vec3 pal = Texel(palette, vec2(u, 0.5)).rgb;

        vec3 diff = pixel.rgb - pal;
        float dist = dot(diff, diff);

        if (dist < best_dist) {
            best_dist = dist;
            best_color = pal;
        }
    }

    return vec4(best_color, pixel.a);
}