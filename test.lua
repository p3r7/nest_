function r()
  norns.script.load(norns.state.script)
end
--norns.script.load('/home/we/dust/code/nest_/test.lua')

include 'lib/nest_/norns'
tab = require 'tabutil'

--[[
c = _control:new {
    v = 3,
    inputs = { _input:new() }
}

cc = c:new {
    v = 4
}
]]

include 'lib/nest_/grid'

n = nest_:new {
    v = _grid.value:new {
        x = function() return { 1, 16 } end,
        y = 1,
        v = 1,
        action = function(s, v) print(v) end
    },
    m = _grid.momentary:new {
        x = { 1, 16 },
        y = 2,
        v = {},
        action = function(s, v) print(v) end
    }
} :connect { g = grid.connect() }
