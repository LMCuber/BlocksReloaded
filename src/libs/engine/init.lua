local engine = {}

engine.ecs = require("src.libs.engine.ecs")
engine.state = require("src.libs.engine.state")

function engine.preupdate()
    engine.state.transition()
end

return engine