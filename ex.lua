n = nest_:new {
    gc = _grid.ctrl:new {
        x = { 1, 2 }, y = { 1, 2 }, lvl = 15, v = { x = 0, y = 0 },
        handler = function(s, x, y, z)
            if z == 1 then 
                s.v = { x = x - x[1], y = y - y[1] }
                s:a(s.v)
            end
        end,
        redraw = function(s)
            s.g:led(s.x[1] + s.v.x, s.y[1] + s.v.y, s.lvl)
        end,
        a = function(s, v)
            print(v.x, v.y)
        end
    }
}:connect { g = grid.connect() }
