extern float time;
extern int levels;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    vec4 c = Texel(tex, uv);

    // Add a small sine offset per channel to animate colors
    c.r = floor(fract(c.r + sin(time * 1.0)) * float(levels)) / float(levels);
    c.g = floor(fract(c.g + sin(time * 1.5)) * float(levels)) / float(levels);
    c.b = floor(fract(c.b + sin(time * 2.0)) * float(levels)) / float(levels);

    return c * color;
}