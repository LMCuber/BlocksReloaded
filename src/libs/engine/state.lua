local state = {
    states = {},
    callbacks = {},  -- {enum: list of callbacks}
    next = nil,  -- tuple(enum, value)
}

function state.register(enum, default)
    state.states[enum] = default
end

function state.callback(enum, func)
    state.callbacks[enum] = func
end

function state.get(enum)
    return state.states[enum]
end

function state.set_next(enum, value)
    state.next = {enum = enum, value = value}
end

function state.transition()
    if state.next ~= nil then
        state.states[state.next.enum] = state.next.value

        -- make sure to trigger the callback
        if state.callbacks[state.next.enum] ~= nil then
            state.callbacks[state.next.enum](state.next.value)
        end
        state.next = nil
    end
end

return state