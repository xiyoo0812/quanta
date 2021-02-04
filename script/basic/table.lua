--table.lua
local type = type
local pairs = pairs
local mrandom = math.random
local tinsert = table.insert
local tremove = table.remove

--------------------------------------------------------------------------------
function table_ext.random(tab)
    local keys = {}
    for k in pairs(tab) do
        tinsert(keys, k)
    end
    if #keys > 0 then
        local key = keys[mrandom(#keys)]
        return key, tab[key]
    end
end

--------------------------------------------------------------------------------
function table_ext.random_array(tab)
    if #tab > 0 then
        return tab[mrandom(#tab)]
    end
end

--------------------------------------------------------------------------------
function table_ext.indexof(tab, val)
    for i, v in pairs(tab) do
        if v == val then
            return i
        end
    end
end

--------------------------------------------------------------------------------
function table_ext.is_array(tab)
    if not tab then
        return false
    end
    local idx = 1
    for f in pairs(tab) do
        if type(f) == "number" then
            if f ~= idx then
                return false
            end
        else
            return false
        end
        idx = idx + 1
    end
    return true
end

--------------------------------------------------------------------------------
function table_ext.size(t, filter)
    local c = 0
    for _, v in pairs(t or {}) do
        if not filter or filter(v) then
            c = c + 1
        end
    end
    return c
end

--------------------------------------------------------------------------------
function table_ext.copy(src, dst)
    local ndst = dst or {}
    for field, value in pairs(src) do
        ndst[field] = value
    end
    return ndst
end

--------------------------------------------------------------------------------
function table_ext.deep_copy(src, dst)
    local ndst = dst or {}
    for key, value in pairs(src or {}) do
        if is_class(value) then
            ndst[key] = value()
        elseif (type(value) == "table") then
            ndst[key] = table_ext.deep_copy(value)
        else
            ndst[key] = value
        end
    end
    return ndst
end

--------------------------------------------------------------------------------
function table_ext.delete(stab, val, num)
    num = num or #stab
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

--------------------------------------------------------------------------------
function table_ext.join(src, dst)
    local ndst = dst or {}
    for _, v in pairs(src) do
        tinsert(ndst, v)
    end
    return ndst
end

-- map转为{key,value}类型的array
function table_ext.map2array(src)
    local dst = {}
    for key, value in pairs(src or {}) do
        tinsert(dst, {key = key, value = value})
    end
    return dst
end

-- {key,value}array转为map
function table_ext.array2map(src)
    local dst = {}
    for _, pair in pairs(src or {}) do
        dst[pair.key] = pair.value
    end
    return dst
end

-- map中的value抽出来变成array (会丢失key信息)
function table_ext.mapv2array(src)
    local dst = {}
    for _, value in pairs(src or {}) do
        tinsert(dst, value)
    end
    return dst
end
