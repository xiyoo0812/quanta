--table.lua
local pairs         = pairs
local tsort         = table.sort
local tkeys         = table.keys
local tvals         = table.vals
local tkvals        = table.kvals
local mrandom       = math.random
local tunpack       = table.unpack
local setmetatable  = setmetatable

local function trandom(tab)
    local keys = {}
    for k in pairs(tab or {}) do
        keys[#keys + 1] = k
    end
    if #keys > 0 then
        local key = keys[mrandom(#keys)]
        return key, tab[key]
    end
end

local function trandom_array(tab)
    if #tab > 0 then
        return tab[mrandom(#tab)]
    end
end

local function tdiff(src, dst)
    local add, del = {}, {}
    for k, v in pairs(src) do
        if not dst[k] then
            del[k] = v
        end
    end
    for k, v in pairs(dst) do
        if not src[k] then
            add[k] = v
        end
    end
    return add, del
end

-- 展开table
local function tunfold(src, kv)
    if not kv or kv == "kv" then
        return tunpack(tkvals(src))
    end
    if not kv or kv == "k" then
        return tunpack(tkeys(src))
    end
    return tunpack(tvals(src))
end

-- {key,value}array转为map
local function tmap(src)
    local dst = {}
    for _, pair in pairs(src or {}) do
        dst[pair[1]] = pair[2]
    end
    return dst
end

local function tmapsort(src, func)
    local dst = tkvals(src)
    tsort(dst, func or function(a, b) return a[1] < b[1] end)
    return dst
end

--数组是否相等
local function tequal(src, dst)
    local max = #src > #dst and #src or #dst
    for i = 1, max do
        if src[i] ~= dst[i] then
            return false
        end
    end
    return true
end

--设置弱表
local function tweak(src, mode)
    return setmetatable(src, { __mode = mode or "k" })
end

qtable              = {}
qtable.map          = tmap
qtable.diff         = tdiff
qtable.weak         = tweak
qtable.equal        = tequal
qtable.unfold       = tunfold
qtable.random       = trandom
qtable.mapsort      = tmapsort
qtable.random_array = trandom_array
