--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local service = config_mgr:get_table("service")

--导出版本号
service:set_version(10000)

--导出配置内容
service:upsert({
    id = 1,
    name = 'router',
    router = false,
    hash = 0,
})

service:upsert({
    id = 2,
    name = 'tool',
    router = false,
    hash = 0,
})

service:upsert({
    id = 3,
    name = 'monitor',
    router = false,
    hash = 0,
})

service:upsert({
    id = 4,
    name = 'robot',
    router = false,
    hash = 0,
})

service:upsert({
    id = 5,
    name = 'test',
    router = true,
    hash = 0,
})

service:upsert({
    id = 6,
    name = 'proxy',
    router = true,
    hash = 0,
})

service:upsert({
    id = 7,
    name = 'cachesvr',
    router = true,
    hash = 1,
})

service:upsert({
    id = 8,
    name = 'mongo',
    router = true,
    hash = 0,
})

service:upsert({
    id = 9,
    name = 'mysql',
    router = true,
    hash = 0,
})

service:upsert({
    id = 10,
    name = 'redis',
    router = true,
    hash = 0,
})

service:upsert({
    id = 11,
    name = 'online',
    router = true,
    hash = 1,
})
