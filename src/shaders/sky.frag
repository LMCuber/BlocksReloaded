extern float time;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
    time;

    // vec4 c = Texel(tex, uv) * color;

    // float l = (sin(time * 0.1) + 1) * 0.5;
    // vec4 light = vec4(l, l, l, 1);




    vec3 nightColor = vec3(0.05, 0.05, 0.2);   // dark blue
    vec3 dayColor = vec3(0.5, 0.8, 1.0);       // bright sky blue
    vec3 sunsetColor = vec3(1.0, 0.5, 0.2);    // orange
    vec3 ret;

    float t = (sin(time) + 1) * 0.5;

    if (t < 0.25) {
        // Dawn
        ret = mix(nightColor, sunsetColor, t / 0.25);
    } else if (t < 0.5) {
        // Morning → Noon
        ret = mix(sunsetColor, dayColor, (t - 0.25) / 0.25);
    } else if (t < 0.75) {
        // Afternoon → Sunset
        ret = mix(dayColor, sunsetColor, (t - 0.5) / 0.25);
    } else {
        // Evening → Night
        ret = mix(sunsetColor, nightColor, (t - 0.75) / 0.25);
    }
    vec4 asd = vec4(ret.xyz, 1);
    return asd;

    // return c * light;
}