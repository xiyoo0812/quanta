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
    name = 'monitor',
    router_group = {},
})

service:upsert({
    id = 3,
    name = 'robot',
    router_group = {},
})

service:upsert({
    id = 4,
    name = 'test',
    router_group = {1},
})

service:upsert({
    id = 5,
    name = 'dbsvr',
    router_group = {1},
})

service:upsert({
    id = 6,
    name = 'proxy',
    router_group = {1},
})

service:upsert({
    id = 7,
    name = 'gateway',
    router_group = {1},
})

service:upsert({
    id = 8,
    name = 'platform',
    router_group = {1},
})
