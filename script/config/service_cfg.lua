--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.config_mgr
local service = config_mgr:get_table("service")

--导出版本号
service:set_version(10000)

--导出配置内容
service:upsert({
    id = 1,
    name = 'router',
    router_group = {},
})

service:upsert({
    id = 2,
    name = 'lobby',
    router_group = {1,3},
})

service:upsert({
    id = 3,
    name = 'dbsvr',
    router_group = {1,2},
})

service:upsert({
    id = 4,
    name = 'datasvr',
    router_group = {3},
})

service:upsert({
    id = 5,
    name = 'dirsvr',
    router_group = {1},
})

service:upsert({
    id = 6,
    name = 'matchsvr',
    router_group = {1},
})

service:upsert({
    id = 7,
    name = 'indexsvr',
    router_group = {1},
})

service:upsert({
    id = 8,
    name = 'roomsvr',
    router_group = {1,2},
})

service:upsert({
    id = 9,
    name = 'teamsvr',
    router_group = {1},
})

service:upsert({
    id = 10,
    name = 'collectsvr',
    router_group = {1},
})

service:upsert({
    id = 11,
    name = 'dscenter',
    router_group = {2},
})

service:upsert({
    id = 12,
    name = 'dsagent',
    router_group = {2},
})

service:upsert({
    id = 13,
    name = 'monitor',
    router_group = {},
})

service:upsert({
    id = 14,
    name = 'httpsvr',
    router_group = {1},
})

service:upsert({
    id = 15,
    name = 'logsvr',
    router_group = {1},
})

service:upsert({
    id = 16,
    name = 'test',
    router_group = {},
})

service:upsert({
    id = 17,
    name = 'robot',
    router_group = {1},
})

service:upsert({
    id = 31,
    name = 'gateway',
    router_group = {4},
})

service:upsert({
    id = 32,
    name = 'platform',
    router_group = {4},
})
