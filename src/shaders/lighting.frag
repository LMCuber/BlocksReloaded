extern Image LightMap;
extern vec2 lightMapOffset; // worldTile min_x, min_y
extern vec2 cameraPos;      // scroll.x / BS, scroll.y / BS
extern vec2 lightMapSize;   // map_w, map_h
extern float blockSize;    // Your BS constant (e.g., 32.0)

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // 1. Get the game's color from the Canvas
    vec4 pixel = Texel(texture, texture_coords);

    // 2. Calculate how many TILES across the screen this pixel is
    // screen_coords is in pixels (0 to 1920), blockSize is pixels per tile (32)
    vec2 pixelTileOffset = screen_coords / blockSize;

    // 3. Absolute world tile position
    vec2 worldTile = cameraPos + pixelTileOffset;

    // 4. Relative position inside the LightMap texture
    // We subtract the lightMapOffset because the texture starts at min_x, not 0
    vec2 lightUV = (worldTile - lightMapOffset) / lightMapSize;

    // 5. Sample and multiply
    vec4 light = Texel(LightMap, lightUV);
    
    // We only use the Red channel (where we stored the light)
    return pixel * vec4(light.r, light.r, light.r, 1.0);
}