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
    group = 1,
    group_name = 'service_pub',
    name = 'router',
    router_group = {},
})

service:upsert({
    id = 2,
    group = 1,
    group_name = 'service_pub',
    name = 'monitor',
    router_group = {},
})

service:upsert({
    id = 3,
    group = 1,
    group_name = 'service_pub',
    name = 'gateway',
    router_group = {1},
})

service:upsert({
    id = 4,
    group = 1,
    group_name = 'service_pub',
    name = 'platform',
    router_group = {1},
})

service:upsert({
    id = 5,
    group = 1,
    group_name = 'service_pub',
    name = 'httpsvr',
    router_group = {1},
})

service:upsert({
    id = 6,
    group = 1,
    group_name = 'service_pub',
    name = 'proxy',
    router_group = {1},
})

service:upsert({
    id = 7,
    group = 1,
    group_name = 'service_pub',
    name = 'test',
    router_group = {1},
})

service:upsert({
    id = 8,
    group = 1,
    group_name = 'service_pub',
    name = 'robot',
    router_group = {1},
})

service:upsert({
    id = 1,
    group = 2,
    group_name = 'service_dev',
    name = 'router',
    router_group = {},
})

service:upsert({
    id = 2,
    group = 2,
    group_name = 'service_dev',
    name = 'monitor',
    router_group = {},
})

service:upsert({
    id = 3,
    group = 2,
    group_name = 'service_dev',
    name = 'gateway',
    router_group = {2},
})

service:upsert({
    id = 4,
    group = 2,
    group_name = 'service_dev',
    name = 'platform',
    router_group = {2},
})

service:upsert({
    id = 5,
    group = 2,
    group_name = 'service_dev',
    name = 'httpsvr',
    router_group = {2},
})

service:upsert({
    id = 6,
    group = 2,
    group_name = 'service_dev',
    name = 'proxy',
    router_group = {2},
})

service:upsert({
    id = 7,
    group = 2,
    group_name = 'service_dev',
    name = 'test',
    router_group = {2},
})

service:upsert({
    id = 8,
    group = 2,
    group_name = 'service_dev',
    name = 'robot',
    router_group = {2},
})

service:upsert({
    id = 1,
    group = 3,
    group_name = 'service_loc',
    name = 'router',
    router_group = {},
})

service:upsert({
    id = 2,
    group = 3,
    group_name = 'service_loc',
    name = 'monitor',
    router_group = {},
})

service:upsert({
    id = 3,
    group = 3,
    group_name = 'service_loc',
    name = 'gateway',
    router_group = {3},
})

service:upsert({
    id = 4,
    group = 3,
    group_name = 'service_loc',
    name = 'platform',
    router_group = {3},
})

service:upsert({
    id = 5,
    group = 3,
    group_name = 'service_loc',
    name = 'httpsvr',
    router_group = {3},
})

service:upsert({
    id = 6,
    group = 3,
    group_name = 'service_loc',
    name = 'proxy',
    router_group = {3},
})

service:upsert({
    id = 7,
    group = 3,
    group_name = 'service_loc',
    name = 'test',
    router_group = {3},
})

service:upsert({
    id = 8,
    group = 3,
    group_name = 'service_loc',
    name = 'robot',
    router_group = {3},
})
