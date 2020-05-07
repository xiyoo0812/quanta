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
    db = 'klbq_plat_pub',
    host = '10.72.17.44',
    port = 27017,
})

database:upsert({
    group = 2,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_rmsg_pub',
    host = '10.72.17.44',
    port = 27017,
})

database:upsert({
    group = 1000,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_dev',
    host = '10.72.17.44',
    port = 27017,
})

database:upsert({
    group = 1001,
    index = 1,
    driver = 'mongo',
    db = 'klbq_plat_rmsg_dev',
    host = '10.72.17.44',
    port = 27017,
})
