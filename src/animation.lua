
local yaml = require("src.libs.yaml")

local anim = {
    data = {}
}
local entity_types = {"statics", "player_animations", "mobs"}
for _, entity_type in ipairs(entity_types) do
    local content, _ = love.filesystem.read("res/data/" .. entity_type .. ".yaml")
    local yaml_data = yaml.eval(content)

    for skin, _ in pairs(yaml_data) do
        anim.data[skin] = {}

        for mode, _ in pairs(yaml_data[skin]) do
            anim.data[skin][mode] = {}
            anim.data[skin][mode]["frames"] = yaml_data[skin][mode]["frames"]
            anim.data[skin][mode]["speed"] = yaml_data[skin][mode]["speed"] or 11
            anim.data[skin][mode]["offset"] = yaml_data[skin][mode]["offset"]
            
            anim.data[skin][mode]["sprs"] = love.graphics.newImage(string.format(
                "res/images/%s/%s/%s.png",  -- stupid fucking lua
                entity_type, skin, mode
            ))
            anim.data[skin][mode]["sprs"]:setFilter("nearest", "nearest")
         
            anim.data[skin][mode]["quads"] = {}
            for i = 1, anim.data[skin][mode]["frames"] do
                local w = anim.data[skin][mode]["sprs"]:getWidth() / anim.data[skin][mode]["frames"]
                local h = anim.data[skin][mode]["sprs"]:getHeight()
                local x = (i - 1) * w
                table.insert(
                    anim.data[skin][mode]["quads"],
                    love.graphics.newQuad(
                        x, 0, w, h,
                        anim.data[skin][mode]["sprs"]:getWidth(),
                        anim.data[skin][mode]["sprs"]:getHeight()
                    )
                )
            end
        end
    end
end

function anim.get(skin, mode)
    return {
        sprs = anim.data[skin][mode]["sprs"],
        quads = anim.data[skin][mode]["quads"],
        frames = anim.data[skin][mode]["frames"],
        speed = anim.data[skin][mode]["speed"],
        offset = anim.data[skin][mode]["offset"],
    }
end

return anim