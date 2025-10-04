uniform vec2 pixels[8];  // positions (in texture pixels)
uniform int numPixels;
uniform vec2 imageSize;  // to convert UV → pixel coords

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 og = Texel(texture, texture_coords);

    return og * color;
}