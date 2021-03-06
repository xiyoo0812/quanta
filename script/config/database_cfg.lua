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
    db = 'klbq_plat_pub',
    host = '10.100.0.19',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'publish',
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_rmsg_pub',
    host = '10.100.0.19',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'devlop',
    group = 1,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_dev',
    host = '10.100.0.19',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'devlop',
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_rmsg_dev',
    host = '10.100.0.19',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'local',
    group = 1,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_loc',
    host = '10.100.0.19',
    port = 27017,
})

database:upsert({
    quanta_deploy = 'local',
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_rmsg_loc',
    host = '10.100.0.19',
    port = 27017,
})
