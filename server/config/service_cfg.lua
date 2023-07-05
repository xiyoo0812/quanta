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
    id = 11,
    name = 'login',
    enum_key = 'LOGIN',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 12,
    name = 'gateway',
    enum_key = 'GATEWAY',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 13,
    name = 'router',
    enum_key = 'ROUTER',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 14,
    name = 'online',
    enum_key = 'ONLINE',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 15,
    name = 'center',
    enum_key = 'CENTER',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 16,
    name = 'monitor',
    enum_key = 'MONITOR',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 17,
    name = 'cache',
    enum_key = 'CACHE',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 28,
    name = 'mongo',
    enum_key = 'MONGO',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 29,
    name = 'redis',
    enum_key = 'REDIS',
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
    name = 'test',
    enum_key = 'TEST',
    enable = true,
    ralloc = 0,
})

service:upsert({
    id = 32,
    name = 'tool',
    enum_key = 'TOOL',
    enable = false,
    ralloc = 0,
})

service:update()
