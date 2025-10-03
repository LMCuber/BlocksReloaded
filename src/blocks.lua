local bit = require("bit")
local commons = require("src.commons")

-- CONSTANTS
_G.CW = 16
_G.CH = 16
_G.BPS = 10
_G.S = 3
_G.BS = BPS * S
_G.WIDTH, _G.HEIGHT = love.graphics.getDimensions()

-- BLOCK FLAGS
_G.BF = {
    NONE         = 0,  -- NOT an empty block block; just means that there is no flag
    EMPTY        = 0,  -- an empty block (empty means that if it is clicked on, the player will place a new block instead of break)
    WALKABLE     = 0,  -- anything walkable
    LIGHT_SOURCE = 0,  -- air, torch, jack-o-lantern, etc.
    ORE          = 0,  -- coal, titanium, diamond, etc.
    ORNAMENT     = 0,  -- flowers, rocks, etc. Subset of "walkable".
}
-- set the enum values from 0 to powers of 2 (they are initialized at 0 by defaylt)
local exp = 0
for block, _ in pairs(BF) do
    BF[block] = 2 ^ exp
    exp = exp + 1
end

-- flags get STRING name as input, NOT id!
local flags = {
    air              = bit.bor(BF.EMPTY, BF.WALKABLE, BF.LIGHT_SOURCE),
    torch            = bit.bor(BF.LIGHT_SOURCE, BF.WALKABLE),
    ["base-ore"]     = BF.ORE,
    ["red-poppy"]    = BF.ORNAMENT,
    ["yellow-poppy"] = BF.ORNAMENT,
    orchid           = BF.ORNAMENT,
}

-- subset flags
for name, flag in pairs(flags) do
    -- all ornaments are walkable by default
    if bit.band(flag, BF.ORNAMENT) ~= 0 then
        flags[name] = bit.bor(flag, BF.WALKABLE)
    end
end

-- functions
function _G.bwand(name, flag)
    return bit.band(flags[name] or 0, flag) ~= 0
end

function _G.nbwand(name, flag)
    return bit.band(flags[name] or 0, flag) == 0
end

function _G.pure(name)
    local base, var = commons.split(name, "_")
    return base, var
end

-- block image loading
local block_list = {
    {"air",             "bucket",           "apple",           "bamboo",          "cactus",          "watermelon",       "rock",        "chicken",     "leaf_f",       "",            "",            ""},
    {"chest",           "snow",             "coconut",         "coconut-piece",   "command-block",   "wood",             "bed",         "bed-right",   "wood_f_vrLRT", "",            "",            ""},
    {"base-pipe",       "blast-furnace",    "dynamite",        "fire",            "magic-brick",     "watermelon-piece", "grass1",      "sand",        "wood_f_vrRT",  "",            "",            ""},
    {"hay",             "base-curved-pipe", "glass",           "grave",           "depr_leaf_f",     "workbench",        "grass2",      "sandstone",   "wood_f_vrLT",  "",            "",            ""},
    {"snow-stone",      "soil",             "stone",           "vine",            "wooden-planks",   "wooden-planks_a",  "stick",       "stone",       "wood_f_vrT",   "",            "",            ""},
    {"anvil",           "furnace",          "soil_p",          "bush",            "wooden-stairs",   "",                 "base-ore",    "bread",       "wood_f_vrLR",  "wood_sv_vrN", "wood_p_vrLR", ""},
    {"blackstone",      "closed-core",      "base-core",       "lava",            "base-orb",        "magic-table",      "base-armor",  "altar",       "wood_f_vrR",   "",            "wood_p_vrR",  ""},
    {"closed-door",     "wheat_st1",        "wheat_st2",       "wheat_st3",       "wheat_st4",       "stone-bricks",     "",            "arrow",       "wood_f_vrL",   "",            "wood_p_vrL",  ""},
    {"open-door",       "lotus",            "daivinus",        "dirt_f_depr",     "grass3",          "forge-table",      "bricks",      "solar-panel", "wood_f_vrN",   "",            "wood_p_vrN",  "wood_p"},
    {"cable_vrF",       "cable_vrH",        "karabiner",       "rope",            "blue_barrel",     "red_barrel",       "gun-crafter", "torch",       "grass_f",      "",            "",            "pillar_vr3"},
    {"red-poppy",       "yellow-poppy",     "orchid",          "corn-crop_vr3.2", "corn-crop_vr4.2", "",                 "",            "",            "soil_f",       "soil_t",      "",            "pillar_vr2"},
    {"",                "corn-crop_vr1.1",  "corn-crop_vr2.1", "corn-crop_vr3.1", "corn-crop_vr4.1", "cattail-top",      "pampas-top",  "",            "dirt_f",       "dirt_t",      "",            "pillar_vr1"},
    {"corn-crop_vr0.0", "corn-crop_vr1.0",  "corn-crop_vr2.0", "corn-crop_vr3.0", "corn-crop_vr4.0", "cattail",          "pampas",      "",            "",             "",            "",            "pillar_vr0"},
}

local blocks = {
    sprs = love.graphics.newImage("res/images/spritesheets/blocks.png"),
    quads = {},
    id = {},
    name = {},
}
blocks.sprs:setFilter("nearest", "nearest")

local id = 0
for y, layer in ipairs(block_list) do
    for x, name in ipairs(layer) do
        -- save the quad
        local quad = love.graphics.newQuad(
            (x - 1) * BPS,
            (y - 1) * BPS,
            BPS,
            BPS,
            blocks.sprs:getWidth(),
            blocks.sprs:getHeight()
        )
        blocks.quads[id] = quad

        -- save the id link just created
        blocks.id[name] = id
        blocks.name[id] = name

        -- save the backgrounded block id as well
        id = id + 1
        blocks.id[name .. "|b"] = id
        blocks.name[id] = name .. "|b"

        -- bg flags
        flags[name] = flags[name] or BF.NONE
        flags[name .. "|b"] = bit.bor(flags[name], BF.WALKABLE)

        -- special flags
        local base, var = pure(name)
        

        -- next iteration
        id = id + 1
    end
end

return blocks