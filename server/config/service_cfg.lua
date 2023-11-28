--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local service = config_mgr:get_table("service")

--导出配置内容
service:upsert({
    enable=true,
    enum_key='LOBBY',
    id=1,
    name='lobby'
})

service:upsert({
    enable=true,
    enum_key='LOGIN',
    id=11,
    name='login'
})

service:upsert({
    enable=true,
    enum_key='GATEWAY',
    id=12,
    name='gateway'
})

service:upsert({
    enable=true,
    enum_key='ROUTER',
    id=13,
    name='router'
})

service:upsert({
    enable=true,
    enum_key='ONLINE',
    id=14,
    name='online'
})

service:upsert({
    enable=true,
    enum_key='CENTER',
    id=15,
    name='center'
})

service:upsert({
    enable=true,
    enum_key='MONITOR',
    id=16,
    name='monitor'
})

service:upsert({
    enable=true,
    enum_key='CACHE',
    id=17,
    name='cache'
})

service:upsert({
    enable=true,
    enum_key='MONGO',
    id=28,
    name='mongo'
})

service:upsert({
    enable=true,
    enum_key='REDIS',
    id=29,
    name='redis'
})

service:upsert({
    enable=false,
    enum_key='MYSQL',
    id=30,
    name='mysql'
})

service:upsert({
    enable=true,
    enum_key='TEST',
    id=31,
    name='test'
})

service:upsert({
    enable=false,
    enum_key='TOOL',
    id=32,
    name='tool'
})

service:update()
