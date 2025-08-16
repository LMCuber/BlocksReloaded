biomes = {
    Forest = {
        top = "soil_f",
        dirt = "dirt_f",
        freq = 0.01,
    },
    
    Beach = {
        top = "sand",
        dirt = "sand",
        freq = 0.005,
    },
}

local biome_list = {}
for _, biome in pairs(biomes) do
    table.insert(biome_list, biome)
end

function biomes:get(index)
    return biome_list[index]
end

function biomes:num()
    return #biome_list
end

return biomes