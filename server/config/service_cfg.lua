--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local service = config_mgr:get_table("service")

--导出配置内容
service:upsert({
    id = 1,
    name = 'router',
})

service:upsert({
    id = 2,
    name = 'tool',
})

service:upsert({
    id = 3,
    name = 'monitor',
})

service:upsert({
    id = 4,
    name = 'robot',
})

service:upsert({
    id = 5,
    name = 'test',
})

service:upsert({
    id = 6,
    name = 'proxy',
})

service:upsert({
    id = 7,
    name = 'cachesvr',
})

service:upsert({
    id = 8,
    name = 'mongo',
})

service:upsert({
    id = 9,
    name = 'mysql',
})

service:upsert({
    id = 10,
    name = 'redis',
})

service:upsert({
    id = 11,
    name = 'online',
})

service:upsert({
    id = 12,
    name = 'admin',
})

--general md5 version
service:set_version('44c2f4429ff6629adacb4e9dbb700291')