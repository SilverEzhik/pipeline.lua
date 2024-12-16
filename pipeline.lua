-- made by Ezhik (https://ezhik.me)
-- geared towards hammerspoon 
-- also you probably want to supply a function called `p`, `p = print` at a minimum

local _, fns, metatable

local function parseKeys(keys)
    -- If keys is not a string, return it directly in the specified format
    if type(keys) ~= "string" then
        return { { key = keys, method = false } }
    end

    local result = {}

    -- Prepend a '.' if the string doesn't start with '.' or ':'
    if keys:sub(1, 1) ~= '.' and keys:sub(1, 1) ~= ':' then
        keys = '.' .. keys
    end

    for segment in keys:gmatch("[^%.:%[]+") do
        local key
        local method = keys:sub(keys:find(segment) - 1, keys:find(segment) - 1) == ":"

        -- Remove '()' from method segments if they exist
        if segment:sub(-2) == "()" then
            segment = segment:sub(1, -3)
        end

        if segment:match("^.-%]$") then
            key = tonumber(segment:sub(1, -2)) -- Convert string inside [] to number
        else
            key = segment
        end

        table.insert(result, { key = key, method = method })
    end

    return result
end

fns = {
    identity = function(x) return x end,
    p = function(...)
        p(...)
        return ...
    end,
    shallowCopy = function(tbl)
        local result = {}
        for k, v in pairs(tbl) do
            result[k] = v
        end
        setmetatable(result, getmetatable(tbl))
        return result
    end,
    map = function(tbl, fn)
        local result = {}
        for k, v in pairs(tbl) do
            table.insert(result, fn(v, k))
        end
        return result
    end,
    filter = function(tbl, fn)
        local result = {}
        for k, v in ipairs(tbl) do
            if fn(v, k) then
                table.insert(result, v)
            end
        end
        return result
    end,
    reduce = function(tbl, fn, acc)
        local iter, obj, start = pairs(tbl)
        if acc == nil then
            start, acc = iter(obj, start)
        end
        for _, v in iter, obj, start do
            acc = fn(acc, v)
        end
        return acc
    end,
    toArray = function(tbl)
        local result = {}
        for k, v in pairs(tbl) do
            table.insert(result, v)
        end
        return result
    end,
    indexOf = function(tbl, obj)
        for k, v in pairs(tbl) do
            if v == obj then
                return k
            end
        end
    end,
    first = function(tbl, fn)
        for _, v in ipairs(tbl) do
            if fn(v) then
                return v
            end
        end
    end,
    sort = function(tbl, fn)
        tbl = fns.shallowCopy(tbl)
        table.sort(tbl, fn)
        return tbl
    end,
    concat = function(...)
        local result = {}
        for _, tbl in ipairs { ... } do
            for k, v in pairs(tbl) do
                if type(k) == "number" then
                    table.insert(result, v)
                else
                    result[k] = v
                end
            end
        end
        return result
    end,
    any = function(tbl, fn)
        for _, v in pairs(tbl) do
            if fn(v, k) then
                return true
            end
        end
        return false
    end,
    all = function(tbl, fn)
        for _, v in pairs(tbl) do
            if not fn(v, k) then
                return false
            end
        end
        return true
    end,
    flatten = function(tbl)
        local result = {}
        for _, v in pairs(tbl) do
            if type(v) == "table" then
                for _, vv in pairs(fns.flatten(v)) do
                    table.insert(result, vv)
                end
            else
                table.insert(result, v)
            end
        end
        return result
    end,
    includes = function(obj, item)
        if type(obj) == "string" then
            return string.find(obj, item, 1, true) ~= nil
        else
            return fns.any(obj, function(v) return v == item end)
        end
    end,
    keys = function(tbl)
        return fns.map(tbl, function(_, k) return k end)
    end,
    values = function(tbl)
        return fns.map(tbl, function(v) return v end)
    end,
    entries = function(tbl)
        return fns.map(tbl, function(v, k) return { k = k, v = v } end)
    end,
    fromEntries = function(tbl)
        local result = {}
        for _, entry in pairs(tbl) do
            local k = entry.k or entry[1]
            local v = entry.v or entry[2]
            result[k] = v
        end
        return result
    end,
    apply = function(obj, fn, ...)
        local args = { ... }
        local placeholderUsed = false
        for i, v in ipairs(args) do
            if v == _ then
                args[i] = obj
                placeholderUsed = true
            end
        end
        if not placeholderUsed then
            table.insert(args, 1, obj)
        end
        return fn(table.unpack(args))
    end,
    eq = function(a, b)
        if type(a) ~= type(b) then
            return false
        elseif type(a) ~= "table" then
            return a == b
        else
            local keys = fns.concat(fns.keys(a), fns.keys(b))
            return fns.all(keys, function(k)
                return fns.eq(a[k], b[k])
            end)
        end
    end,
    at = function(obj, keys)
        if type(keys) == "string" then keys = parseKeys(keys) end
        for _, k in ipairs(keys) do
            if obj == nil then
                return nil
            elseif k.method then
                obj = obj[k.key](obj)
            else
                obj = obj[k.key]
            end
        end
        return obj
    end,
    pluck = function(obj, keys)
        keys = parseKeys(keys)
        return fns.map(obj, function(v)
            return fns.at(v, keys)
        end)
    end,
    unique = function(tbl)
        local seen = {}
        local result = {}
        for _, v in pairs(tbl) do
            if not seen[v] then
                seen[v] = true
                table.insert(result, v)
            end
        end
        return result
    end,
    sum = function(tbl)
        return fns.reduce(tbl, function(a, b) return a + b end, 0)
    end,
    keyBy = function(tbl, key)
        local result = {}

        if type(key) == "string" and key:match("^:") then
            local key = key:gsub("^:", "")
            for _, i in pairs(tbl) do
                local v = i[key](i)
                result[v] = i
                result[tostring(v)] = i
            end
        else
            for _, i in pairs(tbl) do
                result[i[key]] = i
                result[tostring(i[key])] = i
            end
        end

        return result
    end,
    rotate = function(tbl, positions)
        tbl = fns.shallowCopy(tbl)
        if #tbl == 0 then
            return tbl
        end

        if positions == nil then
            positions = 1
        elseif positions < 0 then
            positions = positions + #tbl
        end

        for _ = 1, positions do
            table.insert(tbl, table.remove(tbl, 1))
        end
        return tbl
    end,
    toJson = function(obj)
        if type(obj) ~= "table" then
            return hs.json.encode({ obj }):sub(2, -2)
        end

        return hs.json.encode(obj)
    end,
    fromJson = hs.json.decode,
    push = function(tbl, item)
        table.insert(tbl, item)
        return tbl
    end,
    join = function(tbl, sep)
        return table.concat(tbl, sep or " ")
    end,
}

local function new()
    local t = { __actions = {}, __description = {} }
    return setmetatable(t, metatable)
end

metatable = {
    __call = function(self, obj)
        for _, action in ipairs(self.__actions) do
            obj = fns[action.fn](obj, table.unpack(action.args))
        end
        return obj
    end,
    __tostring = function(self)
        return string.format("pipeline(%s)", fns.join(fns.pluck(self.__actions, ".fn"), " -> "))
    end,
    __shr = function(obj, self)
        return self(obj)
    end,
    fns = fns
}
metatable.__index = metatable

for name, _ in pairs(fns) do
    metatable[name] = function(self, ...)
        local args = { ... }
        local t = new()
        t.__actions = fns.shallowCopy(self.__actions)
        table.insert(t.__actions, { fn = name, args = args })
        return t
    end
end

_ = new()
return _
