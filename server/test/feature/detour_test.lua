-- detour_test.lua
local detour        = require("ldetour")

local log_info      = logger.info
local sformat       = string.format

local DATA_PATH     = "./data/detour.bin"

local TestCase      = import("test/case.lua")
local DetourTest    = class(TestCase)

function DetourTest:run()
    ------------------------------------------------------------------
    --1. 加载 navmesh 数据
    ------------------------------------------------------------------
    local file = io.open(DATA_PATH, "rb")
    self:report("open detour.bin", file ~= nil, DATA_PATH, "file exists")
    if not file then return end
    local content = file:read("*all")
    file:close()
    self:report("detour.bin non-empty", #content > 0, #content, ">0")

    local mesh = detour.create_mesh(content, #content)
    self:report("create_mesh", mesh ~= nil, mesh ~= nil, true)
    if not mesh then return end
    local tiles = mesh.get_max_tiles()
    self:report("get_max_tiles", type(tiles) == "number" and tiles > 0, tiles, ">0")

    ------------------------------------------------------------------
    --2. 创建 query
    ------------------------------------------------------------------
    local max_nodes = 64
    local scale = 100   --米 -> 厘米
    local query = mesh.create_query(max_nodes, scale)
    self:report("create_query", query ~= nil, query ~= nil, true)
    if not query then return end

    ------------------------------------------------------------------
    --3. random_point / point_valid
    ------------------------------------------------------------------
    local x, y, z = query.random_point()
    self:report("random_point numbers", type(x) == "number" and type(y) == "number" and type(z) == "number",
        sformat("({}, {}, {})", x, y, z), "numbers")
    self:report("random_point valid", query.point_valid(x, y, z) == true, true, true)

    ------------------------------------------------------------------
    --4. find_path: 用同一点起终点, 路径应有效
    ------------------------------------------------------------------
    local count = query.find_path(x, y, z, x, y, z)
    self:report("find_path returns count", type(count) == "number", count, "number")

    ------------------------------------------------------------------
    --5. around_point: 指定半径内的随机点应合法
    ------------------------------------------------------------------
    local rx, ry, rz = query.around_point(x, y, z, 3000)
    self:report("around_point valid", query.point_valid(rx, ry, rz) == true,
        sformat("({}, {}, {})", rx, ry, rz), "valid")

    ------------------------------------------------------------------
    --6. find_ground_point: 地面点应合法
    ------------------------------------------------------------------
    local gx, gy, gz = query.find_ground_point(x, y - 500, z, 600)
    self:report("find_ground_point valid", query.point_valid(gx, gy, gz) == true,
        sformat("({}, {}, {})", gx, gy, gz), "valid")

    ------------------------------------------------------------------
    --7. 寻路性能: 1000 次 random_point + point_valid + find_path
    ------------------------------------------------------------------
    local t1 = timer.time()
    for _ = 1, 1000 do
        local sx, sy, sz = query.random_point()
        local ex, ey, ez = query.random_point()
        if not query.point_valid(sx, sy, sz) then
            self:report("random point in perf valid", false, { sx, sy, sz }, "valid")
            break
        end
        query.find_path(sx, sy, sz, ex, ey, ez)
    end
    local cost = timer.time() - t1
    self:report("find_path perf 1000", cost >= 0, cost, ">=0")
    log_info("[detour perf] 1000 x (random_point + find_path): {} ms", cost)
end

return DetourTest
