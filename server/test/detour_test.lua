--detour_test.lua
local ltimer    = require("ltimer")
local ldetour   = require("ldetour")

local log_err   = logger.err
local log_debug  = logger.debug

local file<close>  = io.open("../../bin/navmesh/mesh.bin", "rb")
if not file then
    log_err("open navmesh bin file failed!")
    return
end

local content = file:read("*all")
local mesh = ldetour.create_mesh(content, #content)
if not mesh then
    log_err("create navmesh failed!")
    return
end

local tiles = mesh.get_max_tiles()
log_debug("load navmesh success, tiles : %s!", tiles)
local query = mesh.create_query(64, 1)
if not query then
    log_err("create navmesh query failed!")
    return
end

local t1 = ltimer.time()
for i = 1, 33000 do
    local x1, y1, z1 = query.random_point()
    local x2, y2, z2 = query.random_point()
    if (not query.point_valid(x1, y1, z1)) then
        log_err('point (%s, %s, %s) is not valid', x1, y1, z1)
    end
    query.find_path(x1, y1, z1, x2, y2, z2)
end
local t2 = ltimer.time()
log_debug("find_path  : %s!", t2 - t1)
