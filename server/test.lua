--test.lua
import("kernel.lua")

local log_err = logger.err

quanta.startup(function()
    require("ljson")

    --全量用例注册表(map格式, key=模块名同时作为用例名, value=用例配置)
    local ALL_TEST_CASES = {
        etcd        = { enable = true, path = "test/database/etcd_test.lua", addr = "http://127.0.0.1:2379" },
        redis       = { enable = true, path = "test/database/redis_test.lua", addr = "redis://root:123456@127.0.0.1:6379" },
        redis_clu   = { enable = false, path = "test/database/redis_clu_test.lua", addr = "redis://root:123456@127.0.0.1:6379" },
        mysql       = { enable = true, path = "test/database/mysql_test.lua", addr = "mysql://root:123456@127.0.0.1:3306/quanta_1" },
        mongo       = { enable = true, path = "test/database/mongo_test.lua", addr = "mongodb://root:123456@127.0.0.1:27017/quanta_1" },
        pgsql       = { enable = true, path = "test/database/pgsql_test.lua", addr = "pgsql://postgres:123456@127.0.0.1:5432/quanta_1" },
        clickhouse  = { enable = false, path = "test/database/clickhouse_test.lua", addr = "mysql://root:123456@127.0.0.1:9004" },
        sqlite      = { enable = true, path = "test/database/sqlite_test.lua", addr = "./sqlite/test.db" },
        --basic
        log         = { enable = true, path = "test/basic/log_test.lua" },
        stdfs       = { enable = true, path = "test/basic/stdfs_test.lua" },
        timer       = { enable = true, path = "test/basic/timer_test.lua" },
        luakit      = { enable = true, path = "test/basic/luakit_test.lua" },
        profile     = { enable = true, path = "test/basic/profile_test.lua" },
    }

    --单模块测试配置
    local MODULE_TEST_CASE = { name = "redis", enable = true }

    --测试套件配置
    local TestSuite = import("test/suite.lua")
    local suite = TestSuite()

    --辅助函数: 添加用例
    local function add_case(name, conf)
        local CASE = import(conf.path)
        if CASE then
            suite:add_case(CASE(name, conf.addr))
        else
            log_err("[TEST] load case failed: {}", conf.path)
        end
    end

    --添加用例
    if MODULE_TEST_CASE.enable and MODULE_TEST_CASE.name then
        local name = MODULE_TEST_CASE.name
        local conf = ALL_TEST_CASES[name]
        if conf then
            add_case(name, conf)
        end
    else
        for name, conf in pairs(ALL_TEST_CASES) do
            if conf.enable then
                add_case(name, conf)
            end
        end
    end

    --运行所有用例
    suite:run_all()
end)
