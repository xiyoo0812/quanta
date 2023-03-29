--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local service = config_mgr:get_table("service")

--导出配置内容
service:upsert({
    id = 1,
    name = 'lobby',
    enum_key = 'LOBBY',
})

service:upsert({
    id = 2,
    name = 'scene',
    enum_key = 'SCENE',
})

service:upsert({
    id = 3,
    name = 'team',
    enum_key = 'TEAM',
})

service:upsert({
    id = 4,
    name = 'friend',
    enum_key = 'FRIEND',
})

service:upsert({
    id = 5,
    name = 'chat',
    enum_key = 'CHAT',
})

service:upsert({
    id = 6,
    name = 'room',
    enum_key = 'ROOM',
})

service:upsert({
    id = 7,
    name = 'task',
    enum_key = 'TASK',
})

service:upsert({
    id = 8,
    name = 'match',
    enum_key = 'MATCH',
})

service:upsert({
    id = 9,
    name = 'activity',
    enum_key = 'ACTIVITY',
})

service:upsert({
    id = 18,
    name = 'login',
    enum_key = 'LOGIN',
})

service:upsert({
    id = 19,
    name = 'gateway',
    enum_key = 'GATEWAY',
})

service:upsert({
    id = 20,
    name = 'online',
    enum_key = 'ONLINE',
})

service:upsert({
    id = 23,
    name = 'router',
    enum_key = 'ROUTER',
})

service:upsert({
    id = 24,
    name = 'tool',
    enum_key = 'TOOL',
})

service:upsert({
    id = 25,
    name = 'monitor',
    enum_key = 'MONITOR',
})

service:upsert({
    id = 26,
    name = 'test',
    enum_key = 'TEST',
})

service:upsert({
    id = 27,
    name = 'cache',
    enum_key = 'CACHE',
})

service:upsert({
    id = 28,
    name = 'admin',
    enum_key = 'ADMIN',
})

service:upsert({
    id = 29,
    name = 'mongo',
    enum_key = 'MONGO',
})

service:upsert({
    id = 30,
    name = 'mysql',
    enum_key = 'MYSQL',
})

service:upsert({
    id = 31,
    name = 'redis',
    enum_key = 'REDIS',
})

service:update()
