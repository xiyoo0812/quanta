--table.lua
local type      = type
local pairs     = pairs
local tsort     = table.sort
local mrandom   = math.random
local tremove   = table.remove

local function trandom(tab)
    local keys = {}
    for k in pairs(tab) do
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
    for field, value in pairs(src) do
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

-- map中的value抽出来变成array (会丢失key信息)
local function tarray(src)
    local dst = {}
    for _, value in pairs(src or {}) do
        dst[#dst + 1] = value
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

-- {key,value}array转为map
local function tmap(src)
    local dst = {}
    for _, pair in pairs(src or {}) do
        dst[pair[1]] = pair[2]
    end
    return dst
end

local function tmapsort(src)
    local dst = tkvarray(src)
    tsort(dst, function(a, b) return a[1] < b[1] end)
    return dst
end

table_ext.random        = trandom
table_ext.random_array  = trandom_array
table_ext.indexof       = tindexof
table_ext.is_array      = tis_array
table_ext.size          = tsize
table_ext.copy          = tcopy
table_ext.deep_copy     = tdeep_copy
table_ext.delete        = tdelete
table_ext.join          = tjoin
table_ext.map           = tmap
table_ext.array         = tarray
table_ext.kvarray       = tkvarray
table_ext.mapsort       = tmapsort
