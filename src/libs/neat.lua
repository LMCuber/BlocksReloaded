
---------------------------------------------------------------------

local function sigmoid(x)
  return 1 / (1 + math.exp(-x))
end

---------------------------------------------------------------------

local Link = {}
Link.__index = Link
function Link:new(left_id, right_id, weight, is_enabled)
    return setmetatable({
        left_id = left_id,
        right_id = right_id,
        weight = weight or 0,
        is_enabled = is_enabled or true
    }, self)
end

function Link:__tostring()
    return string.format("L[%d, %d, %.2f]", self.left_id, self.right_id, self.weight)
end

---------------------------------------------------------------------

local Neuron = {}
Neuron.__index = Neuron
function Neuron:new(neuron_id, bias, act)
    local obj = setmetatable({}, self)

    obj.neuron_id = neuron_id
    obj.bias = bias or 0
    obj.act = act or sigmoid  -- default

    return obj
end

function Neuron:__tostring()
    return "N[b = " .. self.bias .. "]"
end

---------------------------------------------------------------------

local Genome = {}
Genome.__index = Genome
function Genome:new(num_inputs, num_outputs)
    assert(num_inputs, "Number of inputs required")
    assert(num_outputs, "Number of outputs required")

    local obj = setmetatable({neurons = {}, links = {}}, self)
    obj.num_inputs = num_inputs
    obj.num_outputs = num_outputs

    -- initialize empty inputs and outputs
    for neuron_id = 1, num_outputs do
        obj:add_neuron(Neuron:new(neuron_id))
    end
    for i = 1, num_inputs do
        local input_id = -i
        for output_id = 1, num_outputs do
            obj:add_link(input_id, output_id)
        end
    end

    return obj
end

function Genome:add_neuron(neuron)
    table.insert(self.neurons, neuron)
end

function Genome:add_link(left_id, right_id)
    table.insert(self.links, Link:new(left_id, right_id))
end

function Genome:__tostring()
    local ret = string.format("Genome[%d, %d, %d]", self.num_inputs, #self.neurons - self.num_outputs, self.num_outputs)
    for _, neuron in ipairs(self.neurons) do
        ret = ret .. "\n\t" .. tostring(neuron)
    end
    ret = ret .. "\n"
    for _, link in ipairs(self.links) do
        ret = ret .. "\n\t" .. tostring(link)
    end
    return ret
end

---------------------------------------------------------------------

return {
    Neuron = Neuron,
    Link = Link,
    Genome = Genome,
}
