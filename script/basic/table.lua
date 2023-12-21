--table.lua
local type          = type
local pairs         = pairs
local tsort         = table.sort
local mrandom       = math.random
local tunpack       = table.unpack
local tremove       = table.remove
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

local function tindexof(tab, val)
    for i, v in pairs(tab) do
        if v == val then
            return i
        end
    end
end

local function tis_array(tab)
    if not tab then
        return false
    end
    local idx = 1
    for key in pairs(tab) do
        if key ~= idx then
            return false
        end
        idx = idx + 1
    end
    return true
end

local function tsize(t, filter)
    local c = 0
    for _, v in pairs(t or {}) do
        if not filter or filter(v) then
            c = c + 1
        end
    end
    return c
end

local function tcopy(src, dst)
    local ndst = dst or {}
    for field, value in pairs(src or {}) do
        ndst[field] = value
    end
    return ndst
end

local function tdeep_copy(src, dst)
    local ndst = dst or {}
    for key, value in pairs(src or {}) do
        if is_class(value) then
            ndst[key] = value()
        elseif (type(value) == "table") then
            ndst[key] = tdeep_copy(value)
        else
            ndst[key] = value
        end
    end
    return ndst
end

local function tdelete(stab, val, num)
    num = num or 1
    for i = #stab, 1, -1 do
        if stab[i] == val then
            tremove(stab, i)
            num = num - 1
            if num <= 0 then
                break
            end
        end
    end
    return stab
end

local function tjoin(src, dst)
    local ndst = dst or {}
    for _, v in pairs(src) do
        ndst[#ndst + 1] = v
    end
    return ndst
end

local function tpush(dst, ...)
    local args = {...}
    local n = select("#", ...)
    for i = 1, n do
        dst[#dst + 1] = args[i]
    end
    return dst
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

-- map中的value抽出来变成array (会丢失key信息)
local function tarray(src)
    local dst = {}
    for _, value in pairs(src or {}) do
        dst[#dst + 1] = value
    end
    return dst
end

-- map中的KEY抽出来变成array (会丢失VALUE信息)
local function tkarray(src)
    local dst = {}
    for key in pairs(src or {}) do
        dst[#dst + 1] = key
    end
    return dst
end

-- map转为{key,value}类型的array
local function tkvarray(src)
    local dst = {}
    for key, value in pairs(src or {}) do
        dst[#dst + 1] = { key, value }
    end
    return dst
end

-- 展开table的kv
local function tunfold(src, only_key)
    local dst = {}
    for key, value in pairs(src or {}) do
        dst[#dst + 1] = key
        dst[#dst + 1] = value
    end
    return tunpack(dst)
end

-- 展开table的k
local function tkeys(src)
    local dst = {}
    for key, value in pairs(src or {}) do
        dst[#dst + 1] = key
    end
    return tunpack(dst)
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
    local dst = tkvarray(src)
    tsort(dst, func or function(a, b) return a[1] < b[1] end)
    return dst
end

--截取
local function tslice(src, spos, epos)
    local dst = {}
    if not epos then
        epos = #src
    end
    if spos < epos then
        for i = spos, epos, 1 do
            dst[#dst + 1] = src[i]
        end
    end
    return dst
end

--截取
local function tweak(src, mode)
    return setmetatable(src, { __mode = mode or "kv" })
end

qtable              = _ENV.qtable or {}
qtable.random       = trandom
qtable.random_array = trandom_array
qtable.indexof      = tindexof
qtable.is_array     = tis_array
qtable.size         = tsize
qtable.copy         = tcopy
qtable.deep_copy    = tdeep_copy
qtable.delete       = tdelete
qtable.join         = tjoin
qtable.map          = tmap
qtable.keys         = tkeys
qtable.push         = tpush
qtable.diff         = tdiff
qtable.array        = tarray
qtable.unfold       = tunfold
qtable.tkarray      = tkarray
qtable.kvarray      = tkvarray
qtable.mapsort      = tmapsort
qtable.slice        = tslice
qtable.weak         = tweak

