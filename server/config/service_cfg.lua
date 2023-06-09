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
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 2,
    name = 'scene',
    enum_key = 'SCENE',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 3,
    name = 'team',
    enum_key = 'TEAM',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 4,
    name = 'friend',
    enum_key = 'FRIEND',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 5,
    name = 'chat',
    enum_key = 'CHAT',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 6,
    name = 'room',
    enum_key = 'ROOM',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 7,
    name = 'task',
    enum_key = 'TASK',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 8,
    name = 'match',
    enum_key = 'MATCH',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 9,
    name = 'activity',
    enum_key = 'ACTIVITY',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 18,
    name = 'login',
    enum_key = 'LOGIN',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 19,
    name = 'gateway',
    enum_key = 'GATEWAY',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 20,
    name = 'online',
    enum_key = 'ONLINE',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 23,
    name = 'router',
    enum_key = 'ROUTER',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 24,
    name = 'tool',
    enum_key = 'TOOL',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 25,
    name = 'monitor',
    enum_key = 'MONITOR',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 26,
    name = 'test',
    enum_key = 'TEST',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 27,
    name = 'cache',
    enum_key = 'CACHE',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 28,
    name = 'admin',
    enum_key = 'ADMIN',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 29,
    name = 'mongo',
    enum_key = 'MONGO',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 30,
    name = 'mysql',
    enum_key = 'MYSQL',
    enable = false,
    ralloc = 0,
})

service:upsert({
    id = 31,
    name = 'redis',
    enum_key = 'REDIS',
    enable = false,
    ralloc = 0,
})

service:update()
