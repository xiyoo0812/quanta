--test.lua
import("kernel.lua")

local sformat = string.format
local log_err = logger.err
local log_info = logger.info

quanta.startup(function()
    require("ljson")

    --辅助进程编号: 该 index 的 test 进程只运行辅助用例
    local ASSIST_INDEX = 2
    --全局参数: 是否在用例执行后清理中间产物(bin/temp 下的文件)
    local CLEANUP = false

    --全量用例注册表(map格式, key=模块名同时作为用例名, value=用例配置)
    local ALL_TEST_CASES = {
        etcd        = { enable = true, path = "test/database/etcd_test.lua", addr = "http://127.0.0.1:2379" },
        redis       = { enable = true, path = "test/database/redis_test.lua", addr = "redis://root:123456@127.0.0.1:6379" },
        redis_clu   = { enable = false, path = "test/database/redis_clu_test.lua", addr = "redis://root:123456@127.0.0.1:6379" },
        mysql       = { enable = true, path = "test/database/mysql_test.lua", addr = "mysql://root:123456@127.0.0.1:3306/quanta_1" },
        mongo       = { enable = true, path = "test/database/mongo_test.lua", addr = "mongodb://root:123456@127.0.0.1:27017/quanta_1" },
        pgsql       = { enable = true, path = "test/database/pgsql_test.lua", addr = "pgsql://postgres:123456@127.0.0.1:5432/quanta_1" },
        clickhouse  = { enable = false, path = "test/database/clickhouse_test.lua", addr = "mysql://root:123456@127.0.0.1:9004" },
        sqlite      = { enable = true, path = "test/database/sqlite_test.lua" },
        lmdb        = { enable = true, path = "test/database/lmdb_test.lua" },
        --basic
        log         = { enable = true, path = "test/basic/log_test.lua" },
        stdfs       = { enable = true, path = "test/basic/stdfs_test.lua" },
        timer       = { enable = true, path = "test/basic/timer_test.lua" },
        luakit      = { enable = true, path = "test/basic/luakit_test.lua" },
        cmdline     = { enable = true, path = "test/basic/cmdline_test.lua" },
        --codec
        codec       = { enable = true, path = "test/codec/codec_test.lua" },
        zip         = { enable = true, path = "test/codec/zip_test.lua" },
        tls         = { enable = true, path = "test/codec/tls_test.lua" },
        --network
        tcp         = { enable = true, path = "test/network/tcp_test.lua" },
        udp         = { enable = true, path = "test/network/udp_test.lua" },
        socket      = { enable = true, path = "test/network/socket_test.lua" },
        kcp         = { enable = true, path = "test/network/kcp_test.lua" },
        ws          = { enable = true, path = "test/network/ws_test.lua" },
        http        = { enable = true, path = "test/network/http_test.lua" },
        --feature
        lock        = { enable = true, path = "test/feature/lock_test.lua" },
        detour      = { enable = true, path = "test/feature/detour_test.lua" },
        worker      = { enable = true, path = "test/feature/worker_test.lua" },
        profile     = { enable = true, path = "test/feature/profile_test.lua" },
        protobuf    = { enable = true, path = "test/feature/protobuf_test.lua" },
        ip          = { enable = true, path = "test/feature/ip_test.lua", addr = "./data/ip2region_v4.xdb" },
        rpc         = { enable = true, path = "test/feature/rpc_test.lua" },
        trace       = { enable = true, path = "test/feature/trace_test.lua" },
        --config
        csv         = { enable = true, path = "test/config/csv_test.lua" },
        xml         = { enable = true, path = "test/config/xml_test.lua" },
        json        = { enable = true, path = "test/config/json_test.lua" },
        toml        = { enable = true, path = "test/config/toml_test.lua" },
        xlsx        = { enable = true, path = "test/config/xlsx_test.lua", addr = "./data/test.xlsx" },
    }

    --辅助用例注册表
    local MODULE_ASSIST_CASE = {
        rpc         = { enable = true, path = "test/assist/rpc_test.lua" },
        trace       = { enable = true, path = "test/assist/trace_test.lua" },
    }

    --单模块测试配置
    local MODULE_TEST_CASE = { name = "rpc", enable = true }

    --测试套件配置
    local TestSuite = import("test/suite.lua")
    local suite = TestSuite()

    --辅助函数: 添加用例
    local function add_case(name, conf)
        local ok, case_or_err = pcall(function()
            --import 在文件缺失/语法错误/依赖dll缺失时返回 nil(sandbox 内部已打印详细原因)
            local CASE = import(conf.path)
            if not CASE then
                error(sformat("import failed(nil): %s, 可能原因: 详见上一条 sandbox 日志", conf.path))
            end
            return CASE(name, conf.addr, CLEANUP)
        end)
        if ok then
            suite:add_case(case_or_err)
        else
            log_err("[TEST] load case failed: name={}, path={}, err={}", name, conf.path, case_or_err)
            suite:add_error(name, case_or_err)
        end
    end

    --添加用例
    if quanta.index == ASSIST_INDEX then
        if MODULE_TEST_CASE.enable and MODULE_TEST_CASE.name then
            local name = MODULE_TEST_CASE.name
            local conf = MODULE_ASSIST_CASE[name]
            if conf and conf.enable then
                log_info("[TEST] index={} assist case for module: {}", quanta.index, name)
                add_case(name, conf)
            else
                log_info("[TEST] index={} module {} has no assist case, skip", quanta.index, name)
            end
        else
            for name, conf in pairs(MODULE_ASSIST_CASE) do
                if conf.enable then
                    log_info("[TEST] index={} assist case: {}", quanta.index, name)
                    add_case(name, conf)
                end
            end
        end
    elseif MODULE_TEST_CASE.enable and MODULE_TEST_CASE.name then
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
