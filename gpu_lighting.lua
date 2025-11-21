-- In your love.load()
function love.load()
    -- Create larger canvases (textures)
    local w, h = 256, 64
    love.graphics.setDefaultFilter("nearest", "nearest")
    lightmapA = love.graphics.newCanvas(w, h, {format = "r32f"})
    lightmapB = love.graphics.newCanvas(w, h, {format = "r32f"})
    tilemap = love.graphics.newCanvas(w, h, {format = "r8"})
    
    -- Scale for display (makes it bigger on screen)
    scale = 12
    
    -- Create diffusion shader
    diffuseShader = love.graphics.newShader([[
        uniform Image lightTex;
        uniform Image tileTex;
        uniform vec2 texelSize;
        uniform float airFalloff;
        uniform float solidFalloff;
        
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            float tile = Texel(tileTex, uv).r;
            float current = Texel(lightTex, uv).r;
            
            // Sample 4 neighbors
            float up = Texel(lightTex, uv + vec2(0, texelSize.y)).r;
            float down = Texel(lightTex, uv - vec2(0, texelSize.y)).r;
            float left = Texel(lightTex, uv - vec2(texelSize.x, 0)).r;
            float right = Texel(lightTex, uv + vec2(texelSize.x, 0)).r;
            
            // Take max neighbor
            float maxNeighbor = max(max(up, down), max(left, right));
            
            // Apply falloff based on tile type
            float falloffToUse = (tile > 0.5) ? solidFalloff : airFalloff;
            float diffused = max(0.0, maxNeighbor - falloffToUse);
            
            // Keep max of current and diffused
            return vec4(max(current, diffused), 0, 0, 1);
        }
    ]])
    
    -- Render shader (for displaying)
    renderShader = love.graphics.newShader([[
        uniform Image lightTex;
        uniform Image tileTex;
        
        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
            float light = Texel(lightTex, uv).r;
            float tile = Texel(tileTex, uv).r;
            
            vec3 outColor;
            if (tile > 0.5) {
                // Dirt/Grass
                if (uv.y < 0.5) {
                    // Grass
                    outColor = vec3(0.2, 0.5, 0.1) * (0.2 + light * 0.8);
                } else {
                    // Dirt
                    outColor = vec3(0.35, 0.25, 0.15) * (0.2 + light * 0.8);
                }
            } else {
                // Air
                if (uv.y < 0.5) {
                    // Sky - always full brightness
                    outColor = vec3(0.5, 0.7, 1.0);
                } else {
                    // Underground air (caves)
                    outColor = vec3(0.05, 0.05, 0.08) + vec3(1.0, 0.85, 0.6) * light;
                }
            }
            
            return vec4(outColor, 1.0);
        }
    ]])
    
    -- Initialize tilemap: upper half = air (0), lower half = dirt/grass (1)
    love.graphics.setCanvas(tilemap)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    
    local midpoint = h / 2
    for y = 0, h-1 do
        for x = 0, w-1 do
            if y >= midpoint then
                love.graphics.points(x, y)
            end
        end
    end
    
    love.graphics.setCanvas()
    
    lights = {}
    iterations = 50
    airFalloff = 0.02      -- light falloff in air (low = travels far)
    solidFalloff = 0.15    -- light falloff in solid blocks (high = travels less)
    lightIntensity = 1.0
    
    isMouseDown = false
    lastPlacedTile = nil
end

function love.mousepressed(x, y, button)
    if button == 1 then
        isMouseDown = true
        handleLightPlacement(x, y)
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        isMouseDown = false
        lastPlacedTile = nil
    end
end

function love.update(dt)
    if isMouseDown then
        local x, y = love.mouse.getPosition()
        handleLightPlacement(x, y)
    end
end

function handleLightPlacement(screenX, screenY)
    local tileX = math.floor(screenX / scale)
    local tileY = math.floor(screenY / scale)
    
    local w, h = lightmapA:getWidth(), lightmapA:getHeight()
    if tileX < 0 or tileX >= w or tileY < 0 or tileY >= h then
        return
    end
    
    local tileKey = tileX .. "," .. tileY
    if lastPlacedTile == tileKey then
        return
    end
    lastPlacedTile = tileKey
    
    for i = #lights, 1, -1 do
        if lights[i].x == tileX and lights[i].y == tileY then
            table.remove(lights, i)
            return
        end
    end
    
    table.insert(lights, {x = tileX, y = tileY, intensity = lightIntensity})
end

function love.draw()
    local w, h = lightmapA:getWidth(), lightmapA:getHeight()
    
    -- 1. Initialize lightmap with light sources AND sky brightness
    love.graphics.setCanvas(lightmapA)
    love.graphics.clear(0, 0, 0, 1)
    
    -- Fill upper half (sky) with full brightness
    local midpoint = h / 2
    love.graphics.setColor(1, 0, 0, 1)
    for y = 0, midpoint - 1 do
        for x = 0, w - 1 do
            love.graphics.points(x, y)
        end
    end
    
    -- Add user-placed lights
    for _, light in ipairs(lights) do
        love.graphics.setColor(light.intensity, 0, 0, 1)
        love.graphics.points(light.x, light.y)
    end
    love.graphics.setColor(1, 1, 1, 1)
    
    -- 2. Diffuse iterations (ping-pong)
    local src = lightmapA
    local dst = lightmapB
    
    love.graphics.setShader(diffuseShader)
    diffuseShader:send("tileTex", tilemap)
    diffuseShader:send("texelSize", {1/w, 1/h})
    diffuseShader:send("airFalloff", airFalloff)
    diffuseShader:send("solidFalloff", solidFalloff)
    
    for i = 1, iterations do
        love.graphics.setCanvas(dst)
        diffuseShader:send("lightTex", src)
        love.graphics.draw(src, 0, 0)
        
        src, dst = dst, src
    end
    
    -- 3. Final render to screen
    love.graphics.setCanvas()
    love.graphics.setShader(renderShader)
    renderShader:send("lightTex", src)
    renderShader:send("tileTex", tilemap)
    love.graphics.draw(src, 0, 0, 0, scale, scale)
    
    love.graphics.setShader()
    
    -- Draw UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    love.graphics.print("Lights: " .. #lights, 10, 30)
    love.graphics.print("Click to place torches", 10, 50)
    love.graphics.print("Air falloff: " .. airFalloff .. " (Q/A)", 10, 70)
    love.graphics.print("Solid falloff: " .. solidFalloff .. " (W/S)", 10, 90)
    love.graphics.print("Press C to clear lights", 10, 110)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "c" then
        lights = {}
    elseif key == "q" then
        airFalloff = math.max(0.01, airFalloff - 0.01)
    elseif key == "a" then
        airFalloff = math.min(0.5, airFalloff + 0.01)
    elseif key == "w" then
        solidFalloff = math.max(0.01, solidFalloff - 0.01)
    elseif key == "s" then
        solidFalloff = math.min(0.5, solidFalloff + 0.01)
    end
end