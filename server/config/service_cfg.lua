--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local service = config_mgr:get_table("service")

--导出配置内容
service:upsert({
    id = 1,
    name = 'lobby',
})

service:upsert({
    id = 2,
    name = 'scene',
})

service:upsert({
    id = 3,
    name = 'team',
})

service:upsert({
    id = 4,
    name = 'friend',
})

service:upsert({
    id = 5,
    name = 'chat',
})

service:upsert({
    id = 6,
    name = 'room',
})

service:upsert({
    id = 7,
    name = 'task',
})

service:upsert({
    id = 8,
    name = 'match',
})

service:upsert({
    id = 9,
    name = 'activity',
})

service:upsert({
    id = 18,
    name = 'login',
})

service:upsert({
    id = 19,
    name = 'gateway',
})

service:upsert({
    id = 20,
    name = 'online',
})

service:upsert({
    id = 23,
    name = 'router',
})

service:upsert({
    id = 24,
    name = 'tool',
})

service:upsert({
    id = 25,
    name = 'monitor',
})

service:upsert({
    id = 26,
    name = 'test',
})

service:upsert({
    id = 27,
    name = 'cache',
})

service:upsert({
    id = 28,
    name = 'admin',
})

service:upsert({
    id = 29,
    name = 'mongo',
})

service:upsert({
    id = 30,
    name = 'mysql',
})

service:upsert({
    id = 31,
    name = 'redis',
})

service:update()
