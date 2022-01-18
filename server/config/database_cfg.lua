--database_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local database = config_mgr:get_table("database")

--导出版本号
database:set_version(10000)

--导出配置内容
database:upsert({
    quanta_deploy = 'publish',
    driver = 'mongo',
    db = 'quanta',
    default = true,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'publish',
    driver = 'mongo',
    db = 'quanta_rmsg',
    default = false,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'develop',
    driver = 'mongo',
    db = 'quanta',
    default = true,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'develop',
    driver = 'mongo',
    db = 'quanta_rmsg',
    default = false,
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'local',
    driver = 'mongo',
    db = 'quanta',
    default = true,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'local',
    driver = 'mysql',
    db = 'quanta',
    default = true,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 3306,
})

database:upsert({
    quanta_deploy = 'local',
    driver = 'redis',
    db = '0',
    default = true,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 6380,
})

database:upsert({
    quanta_deploy = 'local',
    driver = 'mongo',
    db = 'quanta_rmsg',
    default = false,
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'local',
    driver = 'influx',
    db = 'quanta',
    default = true,
    host = '9.134.163.87',
    user = 'xiyoo0812',
    passwd = 'd5SUTYyl4jou8BNN4Ee2kn1U0IhWuj3P7qR7JDU_59e7UAzW0yQq_oCyLcHbFt7nX_45yYfDCsmF7beZd6LiSQ==',
    port = 8086,
})
