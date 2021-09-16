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
    group = 1,
    index = 1,
    driver = 'mongo',
    db = 'quanta_pub',
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'publish',
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'quanta_rmsg_pub',
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'develop',
    group = 1,
    index = 1,
    driver = 'mongo',
    db = 'quanta_dev',
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'develop',
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'quanta_rmsg_dev',
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'local',
    group = 1,
    index = 1,
    driver = 'mongo',
    db = 'quanta_loc',
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'local',
    group = 1,
    index = 2,
    driver = 'mysql',
    db = 'quanta_loc',
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 3306,
})

database:upsert({
    quanta_deploy = 'local',
    group = 1,
    index = 2,
    driver = 'redis',
    db = 'quanta_loc',
    host = '9.134.163.87',
    user = 'root',
    passwd = '123456',
    port = 6380,
})

database:upsert({
    quanta_deploy = 'local',
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'quanta_rmsg_loc',
    host = '127.0.0.1',
    user = 'root',
    passwd = '123456',
    port = 27017,
})
