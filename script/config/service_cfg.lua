--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.config_mgr
local service = config_mgr:get_table("service")

--导出版本号
service:set_version(10000)

--导出配置内容
service:upsert({
    router_group = {},
    id = 1,
    name = 'router',
})

service:upsert({
    router_group = {},
    id = 2,
    name = 'monitor',
})

service:upsert({
    router_group = {},
    id = 3,
    name = 'robot',
})

service:upsert({
    router_group = {1},
    id = 4,
    name = 'test',
})

service:upsert({
    router_group = {1},
    id = 5,
    name = 'dbsvr',
})

service:upsert({
    router_group = {1},
    id = 6,
    name = 'proxy',
})

service:upsert({
    router_group = {1},
    id = 7,
    name = 'gateway',
})

service:upsert({
    router_group = {1},
    id = 8,
    name = 'platform',
})
