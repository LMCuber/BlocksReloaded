function love.load()
    -- Configuration
    local width, height = 64, 64  -- Lightmap resolution
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Create double-buffered lightmaps for ping-pong rendering
    lightmapA = love.graphics.newCanvas(width, height, {format = "r32f"})
    lightmapB = love.graphics.newCanvas(width, height, {format = "r32f"})
    
    -- Optional: occluder map (0 = passable, 1 = blocks light)
    occluderMap = love.graphics.newCanvas(width, height, {format = "r8"})
    
    -- Light diffusion shader (spreads light from neighbors)
    diffuseShader = love.graphics.newShader([[
        uniform Image lightTex;
        uniform Image occluderTex;  // Optional: remove if not using occlusion
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
            
            // Optional: check occlusion
            // float occluder = Texel(occluderTex, uv).r;
            // if (occluder > 0.5) diffused *= 0.1;  // Reduce light in solid areas
            
            // Keep the brighter value
            return vec4(max(current, diffused), 0, 0, 1);
        }
    ]])
    
    -- Configuration
    lights = {}              -- Table of {x, y, intensity}
    iterations = 50          -- Number of diffusion passes
    falloff = 1/15          -- Light falloff per iteration (lower = travels farther)
    displayScale = 16        -- Scale for rendering to screen
    
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
    local tileX = math.floor(screenX / displayScale)
    local tileY = math.floor(screenY / displayScale)
    
    local w, h = lightmapA:getWidth(), lightmapA:getHeight()
    if tileX < 0 or tileX >= w or tileY < 0 or tileY >= h then
        return
    end
    
    local tileKey = tileX .. "," .. tileY
    if lastPlacedTile == tileKey then
        return
    end
    lastPlacedTile = tileKey
    
    -- Remove light if clicking on existing one
    for i = #lights, 1, -1 do
        if lights[i].x == tileX and lights[i].y == tileY then
            table.remove(lights, i)
            return
        end
    end
    
    -- Otherwise add new light
    table.insert(lights, {x = tileX, y = tileY, intensity = 1.0})
end

player_img = love.graphics.newImage("res/images/statics/portal/idle.png")
function drawPlayer()
    -- Make sure we're drawing to the screen, not a canvas
    love.graphics.setCanvas()
    
    -- Make sure no shader is active
    love.graphics.setShader()
    
    -- Reset color to white (lighting pass may have changed it)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Reset blend mode if you changed it
    love.graphics.setBlendMode("alpha")
    
    -- Now draw your player
    -- Example:
    love.graphics.circle("fill", 400, 300, 50)
    -- or
    -- love.graphics.draw(playerSprite, playerX, playerY)
end

function love.draw()
    -- ============================================
    -- YOUR GAME RENDERING GOES HERE (BEFORE LIGHTING)
    -- ============================================
    -- Draw your tiles, sprites, background, etc.
    -- Example:
    -- drawTiles()
    -- drawEntities()
    drawPlayer()
    
    
    -- ============================================
    -- LIGHTING PASS STARTS HERE
    -- ============================================
    local w, h = lightmapA:getWidth(), lightmapA:getHeight()
    
    -- Step 1: Initialize lightmap with light sources
    love.graphics.setCanvas(lightmapA)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    
    for _, light in ipairs(lights) do
        love.graphics.setColor(light.intensity, 0, 0, 1)
        love.graphics.points(light.x, light.y)
    end
    
    -- Step 2: Diffuse light (ping-pong between buffers)
    local src = lightmapA
    local dst = lightmapB
    
    love.graphics.setShader(diffuseShader)
    diffuseShader:send("lightTex", src)
    -- diffuseShader:send("occluderTex", occluderMap)  -- Optional
    diffuseShader:send("texelSize", {1/w, 1/h})
    diffuseShader:send("falloff", falloff)
    
    for i = 1, iterations do
        love.graphics.setCanvas(dst)
        diffuseShader:send("lightTex", src)
        love.graphics.draw(src, 0, 0)
        src, dst = dst, src
    end
    
    -- Step 3: Draw lightmap to screen (for debugging/visualization)
    love.graphics.setCanvas()
    love.graphics.setShader()
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(src, 0, 0, 0, displayScale, displayScale)
    
    -- ============================================
    -- UI/HUD RENDERING (AFTER LIGHTING)
    -- ============================================
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    love.graphics.print("Lights: " .. #lights, 10, 30)
    love.graphics.print("Click to place/remove lights", 10, 50)
    love.graphics.print("Falloff: " .. string.format("%.3f", falloff) .. " (Q/A)", 10, 70)
    love.graphics.print("Iterations: " .. iterations .. " (W/S)", 10, 90)
    love.graphics.print("Press C to clear lights", 10, 110)
    love.graphics.print("Press ESC to quit", 10, 130)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "c" then
        lights = {}
    elseif key == "q" then
        falloff = math.max(0.001, falloff - 0.005)
    elseif key == "a" then
        falloff = math.min(0.5, falloff + 0.005)
    elseif key == "w" then
        iterations = math.max(10, iterations - 5)
    elseif key == "s" then
        iterations = math.min(200, iterations + 5)
    end
end

-- Example: Add a light at position (x, y)
function addLight(x, y, intensity)
    table.insert(lights, {x = x, y = y, intensity = intensity or 1.0})
end

-- Example: Clear all lights
function clearLights()
    lights = {}
end