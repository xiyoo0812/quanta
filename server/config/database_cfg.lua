--database_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local database = config_mgr:get_table("database")

--导出配置内容
database:upsert({
    cluster = 'publish',
    driver = 'mongo',
    id = 1,
    db = 'quanta',
    default = true,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'publish',
    driver = 'mongo',
    id = 2,
    db = 'quanta_msg',
    default = false,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'develop',
    driver = 'mongo',
    id = 1,
    db = 'quanta',
    default = true,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'develop',
    driver = 'mongo',
    id = 2,
    db = 'quanta_msg',
    default = false,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'local',
    driver = 'mongo',
    id = 1,
    db = 'quanta',
    default = true,
    host = '123.207.26.113',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'local',
    driver = 'mysql',
    id = 3,
    db = 'quanta',
    default = true,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 3306,
})

database:upsert({
    cluster = 'local',
    driver = 'redis',
    id = 4,
    db = '0',
    default = true,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 6379,
})

--general md5 version
database:set_version('9cabf6f3680d9068e99ccc51f4c368fc')