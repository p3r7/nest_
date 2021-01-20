-- _obj_ is a base object for all the types on this page that impliments concatenative prototypical inheritance. all subtypes of _obj_ have proprer copies of the tables in the prototype rather than delegated pointers, so changes to subtype members will never propogate up the tree

-- GOTCHA: overwriting an existing table value will not format type. instead, use :replace()

local tab = require 'tabutil'

-- add ignored keys table argument
local function serialize(o, f, dof, itab)
    local tab = "    "
    itab = itab or ""
    local ntab = tab .. itab

    if type(o) == "number" then
        f(o)
    elseif type(o) == "boolean" then
        f(o and "true" or "false")
    elseif type(o) == "string" then
        f(string.format("%q", o))
    elseif type(o) == "table" then
        f("{")
        local first = true

        if #o then
            f(" ")
            for i,v in ipairs(o) do
                if type(v) == "string" or type(v) == "number" then
                    serialize(v, f, dof, ntab)
                    f(", ")
                elseif type(v) == "table" then
                    if first then
                        f("\n")
                        first = false
                    end
                    f(ntab)
                    serialize(v, f, dof, ntab)
                    f(",\n")
                end
            end
        end

        for k,v in pairs(o) do
            if type(k) == 'string' and type(v) ~= 'function' then
                if first then
                    f("\n")
                    first = false
                end
                f(ntab  .. k ..  " = ")
                serialize(v, f, dof, ntab)
                f(",\n")
            end
        end
        
        if dof then
            first = true
            for k,v in pairs(o) do
                if type(v) == 'function' then
                    if first then
                        f("\n")
                        first = false
                    end
                    --f(ntab .. k ..  "()")
                    f(ntab .. k .. " = " .. tostring(v))
                    f(",\n")
                end
            end
        end
        
        f(itab .. "}")
    end
end

local function copy(self, o, ft)
    for k,v in pairs(self) do 
        if rawget(o, k) == nil then
            if type(v) == "table" and v.is_obj then
                local clone = self[k]:new()
                o[k] = ft(o, k, clone)
            else rawset(o,k,v) end 
        end
    end
end

_obj_ = { is_obj = true }

local function formatobj(t, k, v)
    if type(v) == "table" then
        if v.is_obj then 
        elseif not v.new then
            v = _obj_:new(v)
        end
    end

    return v
end

function _obj_:new(o, clone_type)
    o = o or {}

    setmetatable(o, {
        __newindex = function(t, k, v)
            rawset(t, k, formatobj(t, k, v))
        end,
        __call = function(_, ...)
            return o:new(...)
        end,
        __tostring = function(t)
            local st = o.k and o.k .. " = " or ""
            serialize(o, function(ss)
                st = st .. ss
            end)

            return st
        end
    })
    
    for k,v in pairs(o) do 
        formatobj(o, k, v)
    end

    copy(self, o, formatobj)

    return o
end

local function formattype(t, k, v)
    if type(v) == "table" then
        if v.is_obj then 
            if v.is_nest then
                v._.p = t
                v._.k = k
            end
        elseif not v.new then -- test !
            v = _obj_:new(v)
        end

        local zsort = t._.zsort
        for i,w in ipairs(zsort) do 
            if w.k == k then table.remove(zsort, i) end
        end
        
        zsort[#zsort + 1] = v
    end

    return v
end

local nest_id = 0 -- incrimenting numeric ID assigned to every nest_ instantiated

local function nextid()
    nest_id =  nest_id + 1
    return nest_id
end

local function zcomp(a, b) 
    if type(a) == 'table' and type(b) == 'table' and a.z and b.z then
        return a.z > b.z 
    else return false end
end

local function nickname(k) 
    if k == 'v' then return 'value' else return k end
end

local function index_nickname(t, k) 
    if k == 'v' then return t.value end
end

local function format_nickname(t, k, v) 
    if k == 'v' and not rawget(t, 'value') then
        rawset(t, 'value', v)
        t['v'] = nil
    end
    
    return v
end

nest_ = {
    is_obj = true,
    is_nest = true,
    replace = function(self, k, v)
        rawset(self, k, formattype(self, k, v))
    end,
    remove = function(self, k)
        self[k] = nil

        for i,w in ipairs(self._.zsort) do 
            if w.k == k then table.remove(self.zsort, i) end
        end
    end,
    copy = function(self, o) 
        copy(self, o, formattype)

        table.sort(o.zsort, zcomp)

        return o
    end,
    init = function(self)
        for i,v in ipairs(self._.zsort) do if type(v) == 'table' then if v.init then v:init() end end end
    end,
    --init = function(self) return self end,
    each = function(self, f) 
        for k,v in pairs(self) do 
            local r = f(k, v)
            if r then self:replace(k, r) end
        end

        return self 
    end,
    update = function(self, devk, args, ob)
        if self.enabled == nil or self.p_.enabled == true then
            if self.observable then 
                for i,v in ipairs(self.ob_links) do table.insert(ob, v) end
            end 

            for i,v in ipairs(self.zsort) do 
                if v.update then
                    v:update(devk, args, ob)
                end
            end
        end
    end,
    refresh = function(self, silent)
        local ret
        for i,v in ipairs(self.zsort) do 
            if v.refresh then
                ret = v:refresh(silent) or ret
            end
        end

        return ret
    end,
    draw = function(self, devk)
        for i,v in ipairs(self.zsort) do
            if self.enabled == nil or self.p_.enabled == true then
                if v.draw then
                    v:draw(devk)
                end
            end
        end
    end,
    path = function(self, pathto)
        local p = {}

        local function look(o)
            if (not o.p) or (pathto and pathto.id == o.id) then
                return p
            else
                table.insert(p, 1, o.k)
                return look(o.p)
            end
        end

        return look(self)
    end,
    find = function(self, path)
        local p = self
        for i,k in ipairs(path) do
            if p[k] then p = p[k] 
            else 
                print(self.k or "global" .. ": can't find " .. k) 
                p = nil
                break
            end
        end

        return p
    end,
    set = function(self, t, silent) 
        for k,v in pairs(t) do
            if self[k] and type(self[k]) == 'table' and self[k].is_obj and self[k].set then
                self[k]:set(v, silent)
            end
        end
    end,
    get = function(self, silent, test)
        if test == nil or test(self) then
            local t = nest_:new()
            for i,v in ipairs(self.zsort) do
                if v.is_obj and rawget(v, 'get') then t[v.k] = v:get(silent, test) end
            end
            return t
        end
    end,
    observable = true,
    persistent = true,
    enabled = true,
    write = function(self) end,
    read = function(self) end
}

function nest_:new(o, ...)
    if o ~= nil and type(o) ~= 'table' then 
        local arg = { o, ... }
        o = {}

        if type(o) == 'number' and #arg <= 2 then 
            local min = 1
            local max = 1
            
            if #arg == 1 then max = arg[1] end
            
            if #arg == 2 then 
                min = arg[1]
                max = arg[2]
            end
            
            for i = min, max do
                o[i] = nest_:new()
            end
        else
            for _,k in arg do o[k] = nest_:new() end
        end
    end

    o = o or {}

    local _ = { -- the "instance table" - useful as it is ignored by the inheritance rules, and also hidden in subtables
        p = nil,
        k = nil,
        z = 0,
        zsort = {}, -- list of obj children sorted by descending z value
        id = nextid(),
        devs = {},
        ob_links = {},
        p_ = {}
    }   

    setmetatable(o, {
        __index = function(t, k)
            if k == "_" then return _
            elseif index_nickname(t,k) then return index_nickname(t,k)
            elseif _[k] ~= nil then return _[k] end
        end,
        __newindex = function(t, k, v)
            if _[k] ~= nil then rawset(_,k,v) 
            elseif index_nickname(t, k) then
                rawset(t, nickname(k), formattype(t, nickname(k), v)) 
            else
                rawset(t, k, formattype(t, k, v))
                
                table.sort(_.zsort, zcomp)
            end
        end,
        __call = function(_, ...)
            return o:new(...)
        end,
        __tostring = function(t)
            local st = o.k and o.k .. " = " or ""
            serialize(o, function(ss)
                st = st .. ss
            end, true)

            return st
        end
    })

    local function resolve(s, f, ...) 
        if type(f) == 'function' then
            return resolve(s, f(s, ...))
        else return f end
    end

    --[[
    the parameter proxy table - when accesed this empty table aliases to the object, but if the accesed member is a function, the return value of the function is returned, rather than the function itself
    ]]
    setmetatable(_.p_, {
        __index = function(t, k) 
            if o[k] then
                return resolve(o, o[k])
            end
        end,
        __call = function(idk, k, ...)
            if o[k] then
                return resolve(o, o[k], ...)
            end
        end,
        __newindex = function(t, k, v) o[k] = v end
    })
    
    for k,v in pairs(o) do 
        formattype(o, k, v)
        format_nickname(o, k, v)
    end

    o = self:copy(o)
    
    return o
end

setmetatable(nest_, {
    __call = function(_, ...)
        return nest_:new(...)
    end,
})
setmetatable(_obj_, {
    __call = function(_, ...)
        return _obj_:new(...)
    end,
})

_input = nest_:new {
    is_input = true,
    handler = nil,
    devk = nil,
    filter = function(self, devk, args) return args end,
    update = function(self, devk, args, ob)
        if (self.enabled == nil or self.p_.enabled == true) and self.devk == devk then
            local hargs = self:filter(args)
            
            if hargs ~= nil then
                if self.handler then 
                    return hargs, table.pack(self:handler(table.unpack(hargs)))
                end
            end
        end
    end
}

function _input:new(o)
    o = nest_.new(self, o)

    local _ = o._
    local mt = getmetatable(o)
    local mti = mt.__index
    local mtn = mt.__newindex

    -- alias calls to parent
    mt.__index = function(t, k)
        --[[
        local om = mti(t,k)
        if om ~= nil then return om
        elseif _.p ~= nil and _.p[k] ~= nil then return _.p[k] end
        --]]
        if k == "_" then return _
        elseif _[k] ~= nil then return _[k]
        else return _.p and _.p[k] end
    end

    mt.__newindex = function(t, k, v)
        local c = _.p ~= nil and _.p[k] ~= nil
    
        if c then rawset(_.p, k, v)
        else mtn(t, k, v) end
    end

    return o
end

_output = nest_:new {
    is_output = true,
    redraw = nil,
    devk = nil,
    draw = function(self, devk, t)
        if (self.enabled == nil or self.p_.enabled) and self.devk == devk then
            if self.redraw then self.devs[devk].dirty = self:redraw(self.devs[devk].object, self.v, t) or self.devs[devk].dirty end -- refactor dirty flag set
        end
    end
}

_output.new = _input.new

_observer = nest_:new {
    is_observer = true,
    --pass = function(self, sender, v, hargs, aargs) end,
    target = nil,
    capture = nil,
    init = function(self)
        if self.target then
            vv = self.p.p_.target or self.p_.target

            if type(vv) == 'table' and vv.is_nest then 
                table.insert(vv.ob_links, self)
            end
        end
    end
}

function _observer:new(o)
    o = _input.new(self, o)
    
    return o
end

local function runaction(self, aargs)
    self.v = self.action and self.action(self, table.unpack(aargs)) or aargs[1] or self.v
    self:refresh(true)
end

local function clockaction(self, aargs)
    if self.p_.clock then
        if type(self.clock) == 'number' then clock.cancel(self.clock) end
        self.clock = clock.run(runaction, self, aargs)
    else runaction(self, aargs) end
end

_affordance = nest_:new {
    is_affordance = true,
    value = 0,
    devk = nil,
    action = nil,
    init = function(self)
        self:refresh()

        nest_.init(self)
    end,
    draw = function(self, devk)
        if self.enabled == nil or self.p_.enabled == true then
            if self.output then
                self.output:draw(devk)
            end
        end
    end,
    update = function(self, devk, args, ob)
        if self.enabled == nil or self.p_.enabled == true then
            if self.observable then 
                for i,v in ipairs(self.ob_links) do table.insert(ob, v) end
            end 

            if self.input then
                local hargs, aargs = self.input:update(devk, args, ob)

                if aargs and aargs[1] then 
                    clockaction(self, aargs)
                    
                    if self.observable then
                        for i,w in ipairs(ob) do
                            if w.p.id ~= self.id then 
                                w:pass(self, self.v, hargs, aargs)
                            end
                        end
                    end
                end
            end
        end
    end,
    refresh = function(self, silent)
        if (not silent) and self.action then
            local defaults = self.arg_defaults or {}
            clockaction(self, { self.v, table.unpack(defaults) })
        else
            for i,v in ipairs(self.zsort) do 
                if v.is_output and self.devs[v.devk] then 
                    self.devs[v.devk].dirty = true
                    if v.handler then v:handler(self.v) end
                end
            end
        end
    end,
    get = function(self, silent, test)
        if test == nil or test(self) then
            local t = nest_.get(self, silent)

            t.value = type(self.value) == 'table' and self.value:new() or self.value -- watch out for value ~= _obj_ !
            if silent == false then self:refresh(false) end

            return t
        end
    end,
    set = function(self, t, silent)
        nest_.set(self, t, silence)

        if t.value then 
            if type(t.value) == 'table' then self.value = t.value:new()
            else self.value = t.value end
        end

        self:refresh(silent)
    end
    --[[
    get = function(self, silent) 
        if not silent then
            return self:refresh()
        else return self.v end
    end,
    set = function(self, v, silent)
        self:replace('v', v or self.v)
        if not self.silent then return self:refresh() end
    end
    --]]
}

function _affordance:new(o)
    o = nest_.new(self, o)

    return o
end

function _affordance:copy(o)
    o = nest_.copy(self, o)

    for k,v in pairs(o) do
        if type(v) == 'table' then if v.is_input or v.is_output or v.is_observer then
            --rawset(v._, 'affordance', o)
            v.devk = v.devk or o.devk
        end end
    end

    return o
end

_preset = _observer:new { 
    capture = 'value',
    state = nest_:new(), -- may be one or two levels deep
    --[[
    pass = function(self, sender, v)
        local o = state[self.v]:find(sender:path(self.target))
        if o then
            o.value = type(v) == 'table' and v:new() or v
        end
    end,
    --]]
    store = function(self, x, y) 
        local test = function(o) 
            return o.p_.observable and o.id ~= self.id
        end

        local target = self.p.p_.target or self.p_.target
        
        if y then
            self.state[x]:replace(y, target:get(true, test))
        else
            self.state:replace(x, target:get(true, test))
        end
    end,
    recall = function(self, x, y)
        local target = self.p.p_.target or self.p_.target
        if y then
            target:set(self.state[x][y], false)
        else
            target:set(self.state[x], false)
        end
    end,
    --[[
    clear = function(self, n)
        self.state:remove(n) --- meh, i wish zsort wasn't so annoying :/
    end,
    copy = function(self, n_src, n_dest)
        self.state:replace(n_src, self.state[n_dest]:new())
    end,
    --]]
    get = function(self, silent, test) 
        if test == nil or test(self) then
            return _obj_:new { state = self.state:new() }
        end
    end,
    set = function(self, t)
        if t.state then
            self.state = t.state:new()
        end
    end
}

local pattern_time = require 'pattern_time'

function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

_pattern = _observer:new {
    pass = function(self, sender, v, hargs, aargs) 
        local package
        if self.capture == 'value' then
            package = type(v) == 'table' and v:new() or v
        elseif self.capture == 'action' then
            package = _obj_:new()
            for i,w in ipairs(aargs) do
                package[i] = type(w) == 'table' and w:new() or w
            end
        else
            package = hargs
        end

        self:watch(_obj_:new {
            path = sender:path(self.p.p_.target or self.p_.target),
            package = package 
        })
    end,
    proc = function(self, e)
        local target = self.p.p_.target or self.p_.target
        local o = target:find(e.path)
        local p = e.package

        if o then
            if self.capture == 'value' then
                o.value = type(p) == 'table' and p:new() or p
                o:refresh(false)
            elseif self.capture == 'action' then
                clockaction(o, p)
            elseif o.input then
                local aargs = table.pack(o.input:handler(table.unpack(p)))
                
                if aargs and aargs[1] then 
                    clockaction(o, aargs)
                end
            end
        else print('_pattern: path error') end
    end,
    get = function(self, silent, test) 
        if test == nil or test(self) then
            local t = _obj_:new { event = {}, time = {}, count = self.count, step = self.step }

            for i = 1, self.count do
                t.time[i] = self.time[i]
                t.event[i] = self.event[i]:new()
            end
        end
    end,
    set = function(self, t)
        if t.event then
            self.count = t.count
            self.step = t.step
            for i = 1, t.count do
                self.time[i] = t.time[i]
                self.event[i] = t.event[i]:new()
            end
        end
    end
}

function _pattern:new(o) 
    o = _observer.new(self, o)

    local pt = pattern_time.new()
    pt.process = function(e) 
        o:proc(e) 
    end

    local mt = getmetatable(o)
    local mti = mt.__index
    local mtn = mt.__newindex

    --alias _pattern to pattern_time instance
    mt.__index = function(t, k)
        if k == 'new' then return mti(t, k)
        elseif pt[k] ~= nil then return pt[k]
        else return mti(t, k) end
    end
    
    mt.__newindex = function(t, k, v)
        if k == 'new' then mtn(t, k, v)
        elseif pt[k] ~= nil then pt[k] = v
        else mtn(t, k, v) end
    end

    return o
end

_group = _obj_:new { is_group = true }

function _group:new(o)
    o = _obj_.new(self, o)

    o.devk = ""

    local mt = getmetatable(o)
    local mtn = mt.__newindex

    mt.__newindex = function(t, k, v)
        mtn(t, k, v)

        if type(v) == "table" then
            if v.is_affordance then
                for l,w in pairs(v) do
                    if type(w) == 'table' then
                        if w.is_input or w.is_output and not w.devk then 
                            w.devk = o.devk 
                        end
                    end
                end

                v.devk = o.devk
            elseif v.is_group or v.is_input or v.is_output then
                v.devk = o.devk
            end
        end 
    end

    return o
end

_dev = _obj_:new {
    dirty = true,
    object = nil,
    redraw = nil,
    handler = nil
}
