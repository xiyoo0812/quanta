--math.lua
local msqrt         = math.sqrt
local mfloor        = math.floor
local mrandom       = math.random
local mtointeger    = math.tointeger

qmath = {}

--四舍五入
function qmath.round(n)
    return mfloor(0.5 + n)
end

--随机函数
function qmath.rand(a, b)
    return mrandom(a, b)
end

function qmath.random()
    return mrandom(0xffff, 0xffffffff)
end

--万分比是否命中
function qmath.ttratio(val)
    return val > mrandom(1, 10000)
end

--计算距离
function qmath.distance(x, z, nx, nz)
    local dx, dz = nx - x, nz - z
    return msqrt(dx * dx + dz * dz)
end

--判断距离
function qmath.judge_dis(x, z, nx, nz, r)
    local dx, dz = nx - x, nz - z
    return dx * dx + dz * dz <= r * r
end

--区间检查
function qmath.in_range(n, min, max)
    return n > min and n <= max
end

--区间检查
function qmath.clamp(n, min, max)
    if n < min then
        return min
    elseif n > max then
        return max
    end
    return n
end

--区间检查
function qmath.max(n, min)
    if n < min then
        return min
    end
    return n
end

function qmath.min(n, max)
    if n > max then
        return max
    end
    return n
end

--数值转换
function qmath.conv_integer(v)
    return mtointeger(v) or v
end

function qmath.conv_number(v)
    return mtointeger(v) or tonumber(v) or v
end

function qmath.conv_number(v)
    return mtointeger(v) or tonumber(v) or v
end

