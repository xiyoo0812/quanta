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
    index = 0,
    router_group = {},
})

service:upsert({
    id = 2,
    name = 'monitor',
    index = 0,
    router_group = {},
})

service:upsert({
    id = 3,
    name = 'robot',
    index = 0,
    router_group = {},
})

service:upsert({
    id = 4,
    name = 'test',
    index = 1,
    router_group = {1},
})

service:upsert({
    id = 5,
    name = 'dbsvr',
    index = 1,
    router_group = {1},
})

service:upsert({
    id = 6,
    name = 'proxy',
    index = 1,
    router_group = {1},
})

service:upsert({
    id = 7,
    name = 'gateway',
    index = 1,
    router_group = {1},
})

service:upsert({
    id = 8,
    name = 'platform',
    index = 1,
    router_group = {1},
})
