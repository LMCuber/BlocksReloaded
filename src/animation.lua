
local yaml = require("src.libs.yaml")
local commons = require("src.libs.commons")

local anim = {
    data = {}
}
local entity_types = {"statics", "player_animations", "mobs"}
for _, entity_type in ipairs(entity_types) do
    local content, _ = love.filesystem.read("res/data/" .. entity_type .. ".yaml")
    local yaml_data = yaml.eval(content)

    -- safety for the LSP
    if type(yaml_data) ~= "table" then
        goto skip_this_ent_type
    end

    assert(yaml_data["DEFAULT"] ~= nil, "entity type '" .. entity_type .. "' must have a DEFAULT field")

    for skin, _ in pairs(yaml_data) do
        if skin == "DEFAULT" then
            goto continue
        end

        anim.data[skin] = {}

        for mode, _ in pairs(yaml_data[skin]) do
            anim.data[skin][mode] = {}
            anim.data[skin][mode]["frames"] = yaml_data[skin][mode]["frames"]
            anim.data[skin][mode]["speed"] = yaml_data[skin][mode]["speed"] or yaml_data["DEFAULT"]["speed"]
            anim.data[skin][mode]["offset"] = yaml_data[skin][mode]["offset"] or yaml_data["DEFAULT"]["offset"]

            anim.data[skin][mode]["sprs"] = love.graphics.newImage(string.format(
                "res/images/%s/%s/%s.png",
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

        ::continue::
    end

    ::skip_this_ent_type::
end

function anim.get(skin, mode)
    -- crazy error handling
    if anim.data[skin] == nil then
        error(string.format("Skin type \"%s\" doesn't exist (with mode \"%s\")", skin, mode))
    elseif anim.data[skin][mode] == nil then
        error(string.format("Mode \"%s\" doesn't exist (for skin type %s)", mode, skin))
    end

    local anim_data = anim.data[skin][mode]
    return {
        sprs = anim_data["sprs"],
        quads = anim_data["quads"],
        frames = anim_data["frames"],
        speed = anim_data["speed"],
        offset = anim_data["offset"],
    }
end

return anim