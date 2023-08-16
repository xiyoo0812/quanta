-- mongo_test.lua
local log_debug     = logger.debug

local timer_mgr     = quanta.get("timer_mgr")

local MongoMgr      = import("store/mongo_mgr.lua")
local mongo_mgr     = MongoMgr()

local primary_id    = 1234567

local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")

timer_mgr:once(2000, function()
    local code, count = mongo_mgr:count(MAIN_DBID, "test_mongo_1", {pid = 123456})
    log_debug("db count code: %s, count = %s", code, count)
    local icode, ierr = mongo_mgr:insert(MAIN_DBID, primary_id, "test_mongo_1", {pid = 123456, data = {a =1, b=2}})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    icode, ierr = mongo_mgr:insert(MAIN_DBID, primary_id, "test_mongo_1", {pid = 123457, data = {a =1, b=2}})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    local fcode, res = mongo_mgr:find(MAIN_DBID, primary_id, "test_mongo_1", {}, {_id = 0})
    log_debug("db find code: %s, res = %s", fcode, res)
    local f1code, f1res = mongo_mgr:find_one(MAIN_DBID, primary_id, "test_mongo_1", {pid = 123456}, {_id = 0})
    log_debug("db find code: %s, res = %s", f1code, f1res)
    local ucode, uerr = mongo_mgr:update(MAIN_DBID, primary_id, "test_mongo_1", {pid = 123458, data = {a =1, b=4}}, {pid = 123457})
    log_debug("db update code: %s, err = %s", ucode, uerr)
    code, count = mongo_mgr:count(MAIN_DBID, "test_mongo_1", {pid = 123456})
    log_debug("db count code: %s, count = %s", code, count)
    local ecode, eres = mongo_mgr:delete(MAIN_DBID, primary_id, "test_mongo_1", {pid = 123456})
    log_debug("db delete code: %s, count = %s", ecode, eres)
    code, count = mongo_mgr:count(MAIN_DBID, "test_mongo_1", {pid = 123456})
    log_debug("db count code: %s, count = %s", code, count)
    icode, ierr = mongo_mgr:create_indexes(MAIN_DBID, "test_mongo_2", {{key={userid=1},name="test_uid", unique = true}})
    log_debug("db create_indexes code: %s, err = %s", icode, ierr)
    icode, ierr = mongo_mgr:execute(MAIN_DBID, primary_id, "listIndexes", "test_mongo_2")
    log_debug("db listIndexes code: %s, err = %s", icode, ierr)
    icode, ierr = mongo_mgr:drop_indexes(MAIN_DBID, "test_mongo_2", "test_uid")
    log_debug("db drop_indexes code: %s, err = %s", icode, ierr)

    --[[
    fcode, res = mongo_mgr:find(MAIN_DBID, "test_mongo_1", {}, {_id = 0}, {pid = 1})
    for _, v in pairs(res) do
        log_debug("db find sort code: %s, v = %s", fcode, v)
    end
    local acode, id = mongo_mgr:get_autoinc_id(MAIN_DBID, "splayer")
    log_debug("db autoinc code: %s, id = %s", acode, id)
    ]]
end)
