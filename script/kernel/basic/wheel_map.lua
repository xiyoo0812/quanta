-- wheel_map.lua

local mmax      = math_ext.max
local hash_code = utility.hash_code

local WheelMap = class()
local prop = property(WheelMap)
prop:reader("host_maps", {})     -- 真实的map
prop:reader("wheel_cnt", 1)     -- 轮子数量（最小为1）
prop:reader("cur_wheel_no", 1)  -- 当前轮子号


-- 根据key获取对应的轮子no
local key_to_wheel_no = function(key, wheel_cnt)
    local hkey = hash_code(key)

    return hkey % wheel_cnt + 1
end

-- 根据key获取对应的轮子
--local key_to_host_map = function(key,)

function WheelMap:__init(wheel_cnt)
    -- 默认为1个轮子
    if not wheel_cnt then
        wheel_cnt = 1
    end

    self.wheel_cnt = mmax(1, wheel_cnt)  -- 轮子个数
    for n = 1, wheel_cnt do              -- 初始化轮子
        self.host_maps[n] = {}
    end
end

-- 设置指定key的值
function WheelMap:set(key, value)
    --self.host_map[key] = value
    local wheel_no = key_to_wheel_no(key, self.wheel_cnt)
    local host_map = self.host_maps[wheel_no]
    if not host_map then
        host_map = {[key] = value}
        self.host_maps[self.wheel_no] = host_map
    else
        host_map[key] = value
    end
end

-- 获取指定key的值
function WheelMap:get(key)
    --return self.host_map[key]
    local wheel_no = key_to_wheel_no(key, self.wheel_cnt)
    local host_map = self.host_maps[wheel_no]
    if not host_map then
        return nil
    else
        return host_map[key]
    end
end

---- 获取原始map
--function WheelMap:get_raw_map()
--    return self.host_map
--end

-- 正常遍历
function WheelMap:iterator()
    local cur_wheel_no = 1
    local wheel_cnt    = self.wheel_cnt
    local key          = nil
    local host_maps    = self.host_maps
    local host_map     = self.host_maps[cur_wheel_no]
    local function iter()
        :: lab_retry ::
        key = next(host_map, key)
        if not key and cur_wheel_no < wheel_cnt then
            cur_wheel_no = cur_wheel_no + 1
            host_map = host_maps[cur_wheel_no]
            goto lab_retry
        end

        if key then
            return key, host_map[key]
        end
    end
    return iter
end

-- 带轮遍历
function WheelMap:wheel_iterator()
    local cur_wheel_no = self.cur_wheel_no
    local key          = nil
    local host_maps    = self.host_maps
    local host_map     = host_maps[cur_wheel_no]
    local function iter()
        key = next(host_map, key)
        if key then
            return key, host_map[key]
        end
    end

    if self.cur_wheel_no >= self.wheel_cnt then
        self.cur_wheel_no = 1
    else
        self.cur_wheel_no = self.cur_wheel_no + 1
    end

    return iter
end

-- export

return WheelMap
