-- mongo_test.lua
local log_debug  = logger.debug

local DBGroup   = enum("DBGroup")

local timer_mgr = quanta.get("timer_mgr")

local MongoMgr  = import("kernel/store/mongo_mgr.lua")
local mongo_mgr = MongoMgr(DBGroup.AREA)

timer_mgr:once(2000, function()
    local icode, ierr = mongo_mgr:count(1, "test_mongo_1", {pid = 123456})
    log_debug("db count code: %s, err = %s", icode, ierr)
    icode, ierr = mongo_mgr:insert(1, "test_mongo_1", {pid = 123456, data = {a =1, b=2}})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    icode, ierr = mongo_mgr:insert(1, "test_mongo_1", {pid = 123457, data = {a =1, b=2}})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    local fcode, res = mongo_mgr:find(1, "test_mongo_1", {}, {_id = 0})
    log_debug("db find code: %s, res = %s", fcode, res)
    local f1code, f1res = mongo_mgr:find_one(1, "test_mongo_1", {pid = 123456}, {_id = 0})
    log_debug("db find code: %s, res = %s", f1code, f1res)
    local ucode, uerr = mongo_mgr:update(1, "test_mongo_1", {pid = 123458, data = {a =1, b=4}}, {pid = 123457})
    log_debug("db update code: %s, err = %s", ucode, uerr)
    icode, ierr = mongo_mgr:count(1, "test_mongo_1", {pid = 123456})
    log_debug("db count code: %s, err = %s", icode, ierr)
end)
