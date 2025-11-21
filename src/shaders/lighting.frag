uniform Image lightTex;
uniform vec2 texelSize;
uniform float falloff;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    float current = Texel(lightTex, uv).r;
    
    // Sample 4-directional neighbors
    float up = Texel(lightTex, uv + vec2(0, texelSize.y)).r;
    float down = Texel(lightTex, uv - vec2(0, texelSize.y)).r;
    float left = Texel(lightTex, uv - vec2(texelSize.x, 0)).r;
    float right = Texel(lightTex, uv + vec2(texelSize.x, 0)).r;
    
    // Find brightest neighbor
    float maxNeighbor = max(max(up, down), max(left, right));
    
    // Apply falloff and diffuse
    float diffused = max(0.0, maxNeighbor - falloff);
    
    // Keep the brighter value
    return vec4(max(current, diffused), 0, 0, 1);
}