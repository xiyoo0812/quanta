--database_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local database = config_mgr:get_table("database")

--导出配置内容
database:upsert({
    cluster = 'publish',
    driver = 'mongo',
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
    db = 'quanta_rmsg',
    default = false,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'develop',
    driver = 'mongo',
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
    db = 'quanta_rmsg',
    default = false,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'local',
    driver = 'mongo',
    db = 'quanta',
    default = true,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'local',
    driver = 'mysql',
    db = 'quanta',
    default = true,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 3306,
})

database:upsert({
    cluster = 'local',
    driver = 'redis',
    db = '0',
    default = true,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 6380,
})

database:upsert({
    cluster = 'local',
    driver = 'mongo',
    db = 'quanta_rmsg',
    default = false,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    cluster = 'local',
    driver = 'clickhouse',
    db = 'quanta',
    default = true,
    host = '9.134.163.87',
    user = 'default',
    passwd = '123456',
    port = 9004,
})

--general md5 version
database:set_version('5ffa83097c734c46fe80235e83465ef1')