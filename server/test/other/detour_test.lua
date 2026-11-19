--detour_test.lua

local log_err   = logger.err
local log_debug = logger.debug

local file<close>  = io.open("../../bin/navmesh/world.bin", "rb")
if not file then
    log_err("open navmesh bin file failed!")
    return
end

local content = file:read("*all")
local mesh = detour.create_mesh(content, #content)
if not mesh then
    log_err("create navmesh failed!")
    return
end

local tiles = mesh.get_max_tiles()
log_debug("load navmesh success, tiles : {}!", tiles)
local max_nodes = 64
local scale = 100 -- 米->厘米
local query = mesh.create_query(max_nodes, scale)
if not query then
    log_err("create navmesh query failed!")
    return
end

local t1 = timer.time()
for i = 1, 33000 do
    local x1, y1, z1 = query.random_point()
    local x2, y2, z2 = query.random_point()
    if (not query.point_valid(x1, y1, z1)) then
        log_err('[random_point()] point ({}, {}, {}) is not valid', x1, y1, z1)
    end
    query.find_path(x1, y1, z1, x2, y2, z2)
end
local t2 = timer.time()
log_debug("find_path  : {}!", t2 - t1)

local pos_x, pos_y, pos_z = query.random_point()
log_debug('pos: {}', { x = pos_x, y = pos_y, z = pos_z, })
local rnd_x, rnd_y, rnd_z = query.around_point(pos_x, pos_y, pos_z, 3000)
if (not query.point_valid(rnd_x, rnd_y, rnd_z)) then
    log_err('[around_point()] point ({}, {}, {}) is not valid', rnd_x, rnd_y, rnd_z)
else
    log_debug('rnd: {}', { x = rnd_x, y = rnd_y, z = rnd_z, })
end

local g_x, g_y, g_z = query.find_ground_point(pos_x, pos_y - 500, pos_z, 600)
if (not query.point_valid(g_x, g_y, g_z)) then
    log_err('[find_ground_point()] point ({}, {}, {}) is not valid', g_x, g_y, g_z)
else
    log_debug('ground: {}', { x = g_x, y = g_y, z = g_z, })
end
