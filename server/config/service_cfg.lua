--service_cfg.lua
--source: service.csv
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local service = config_mgr:get_table("service")

--导出配置内容
service:upsert({
    enable=true,
    enum_key='LOBBY',
    id=1,
    name='lobby',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='LOGIN',
    id=11,
    name='login',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='GATEWAY',
    id=12,
    name='gateway',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='ROUTER',
    id=13,
    name='router',
    policy=0
})

service:upsert({
    enable=true,
    enum_key='ONLINE',
    id=14,
    name='online',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='CENTER',
    id=15,
    name='center',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='DISCOVER',
    id=16,
    name='discover',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='CACHE',
    id=17,
    name='cache',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='MONGO',
    id=28,
    name='mongo',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='REDIS',
    id=29,
    name='redis',
    policy=-1
})

service:upsert({
    enable=false,
    enum_key='MYSQL',
    id=30,
    name='mysql',
    policy=-1
})

service:upsert({
    enable=true,
    enum_key='TEST',
    id=31,
    name='test',
    policy=-1
})

service:upsert({
    enable=false,
    enum_key='TOOL',
    id=32,
    name='tool',
    policy=-1
})

service:update()
