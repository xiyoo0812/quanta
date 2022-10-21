--math.lua
local mfloor        = math.floor
local mrandom       = math.random
local mtointeger    = math.tointeger

math_ext = _ENV.math_ext or {}

function math_ext.round(n)
    return mfloor(0.5 + n)
end

function math_ext.rand(n1, n2)
    return mrandom(n1 * 1000000, n2 * 1000000)/1000000
end

--区间检查
function math_ext.region(n, min, max)
    if n < min then
        return min
    elseif n > max then
        return max
    end
    return n
end

function math_ext.conv_integer(v)
    return mtointeger(v) or v
end

function math_ext.conv_number(v)
    return mtointeger(v) or tonumber(v) or v
end
