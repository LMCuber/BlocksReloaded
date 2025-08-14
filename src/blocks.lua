_G.CW = 16
_G.CH = 16
_G.BPS = 10
_G.S = 3
_G.BS = BPS * S
_G.WIDTH, _G.HEIGHT = love.graphics.getDimensions()

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
    {"red-poppy",       "yellow-poppy",     "",                "corn-crop_vr3.2", "corn-crop_vr4.2", "",                 "",            "",            "soil_f",       "soil_t",      "",            "pillar_vr2"},
    {"",                "corn-crop_vr1.1",  "corn-crop_vr2.1", "corn-crop_vr3.1", "corn-crop_vr4.1", "cattail-top",      "pampas-top",  "",            "dirt_f",       "dirt_t",      "",            "pillar_vr1"},
    {"corn-crop_vr0.0", "corn-crop_vr1.0",  "corn-crop_vr2.0", "corn-crop_vr3.0", "corn-crop_vr4.0", "cattail",          "pampas",      "",            "",             "",            "",            "pillar_vr0"},
}

local sprs_data = love.image.newImageData("res/blocks.png")
blocks = {
    sprs = love.graphics.newImage("res/blocks.png"),
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
        id = id + 1
    end
end
-- also create name -> id (we already have id -> name)
for name, id in pairs(blocks.id) do
    blocks.name[id] = name
end

return blocks