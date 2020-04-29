--database_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.config_mgr
local database = config_mgr:get_table("database")

--导出版本号
database:set_version(10000)

--导出配置内容
database:upsert({
    group = 1,
    index = 1,
    driver = 'mongo',
    db = 'paperman_1',
    host = '127.0.0.1',
    port = 27017,
})

database:upsert({
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'paperman_2',
    host = '127.0.0.1',
    port = 27017,
})

database:upsert({
    group = 3,
    index = 1,
    driver = 'mongo',
    db = 'paperman_3',
    host = '127.0.0.1',
    port = 27017,
})

database:upsert({
    group = 1000,
    index = 1,
    driver = 'mongo',
    db = 'msg_queue',
    host = '127.0.0.1',
    port = 27017,
})

database:upsert({
    group = 2000,
    index = 1,
    driver = 'mongo',
    db = 'global_collect',
    host = '127.0.0.1',
    port = 27017,
})
