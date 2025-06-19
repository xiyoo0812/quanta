-- mongo_test.lua
import("db/mongo_mgr.lua")

local bdate         = bson.date
local log_debug     = logger.debug

local timer_mgr     = quanta.get("timer_mgr")
local mongo_mgr     = quanta.get("mongo_mgr")

local primary_id    = 1234567

timer_mgr:once(2000, function()
    local code, count = mongo_mgr:count("test_mongo_1", {pid = 123456})
    log_debug("db count code: {}, count = {}", code, count)
    local icode, ierr = mongo_mgr:insert(primary_id, "test_mongo_1", {pid = 123456, data = {a =1, b=2}})
    log_debug("db insert code: {}, err = {}", icode, ierr)
    icode, ierr = mongo_mgr:insert(primary_id, "test_mongo_1", {pid = 123457, data = {a =1, b=2}})
    log_debug("db insert code: {}, err = {}", icode, ierr)
    local fcode, res = mongo_mgr:find(primary_id, "test_mongo_1", {}, {_id = 0})
    log_debug("db find code: {}, res = {}", fcode, res)
    local f1code, f1res = mongo_mgr:find_one(primary_id, "test_mongo_1", {pid = 123456}, {_id = 0})
    log_debug("db find code: {}, res = {}", f1code, f1res)
    local ucode, uerr = mongo_mgr:update(primary_id, "test_mongo_1", {pid = 123458, data = {a =1, b=4}}, {pid = 123457})
    log_debug("db update code: {}, err = {}", ucode, uerr)
    code, count = mongo_mgr:count("test_mongo_1", {pid = 123456})
    log_debug("db count code: {}, count = {}", code, count)
    local ecode, eres = mongo_mgr:delete(primary_id, "test_mongo_1", {pid = 123456})
    log_debug("db delete code: {}, count = {}", ecode, eres)
    code, count = mongo_mgr:count("test_mongo_1", {pid = 123456})
    log_debug("db count code: {}, count = {}", code, count)
    icode, ierr = mongo_mgr:create_indexes("test_mongo_2", {{key={userid=1},name="test_uid", unique = true}})
    log_debug("db create_indexes code: {}, err = {}", icode, ierr)
    icode, ierr = mongo_mgr:execute(primary_id, "listIndexes", "test_mongo_2")
    log_debug("db listIndexes code: {}, err = {}", icode, ierr)
    icode, ierr = mongo_mgr:drop_indexes("test_mongo_2", "test_uid")
    log_debug("db drop_indexes code: {}, err = {}", icode, ierr)

    icode, ierr = mongo_mgr:create_indexes("test_mongo_3", {{key={"pid",1,"uid",1},name="test_uid", unique = true}})
    log_debug("db create_indexes code: {}, err = {}", icode, ierr)
    icode, ierr = mongo_mgr:create_indexes("test_mongo_3", { { key = { ttl = 1 }, expireAfterSeconds = 0, name = "ttl", unique = false } })
    log_debug("db create_indexes code: {}, err = {}", icode, ierr)
    icode, ierr = mongo_mgr:insert(primary_id, "test_mongo_3", {pid = 123457, uid = 3, time = quanta.now, ttl = bdate(quanta.now + 3600*8 + 30)})
    log_debug("db insert code: {}, err = {}", icode, ierr)

    --[[
    fcode, res = mongo_mgr:find("test_mongo_1", {}, {_id = 0}, {pid = 1})
    for _, v in pairs(res) do
        log_debug("db find sort code: {}, v = {}", fcode, v)
    end
    local acode, id = mongo_mgr:autoinc_id("splayer")
    log_debug("db autoinc code: {}, id = {}", acode, id)
    ]]
    local bcode, bres = mongo_mgr:bulkwrite({
        {"insert", "test_mongo_1", "document", {pid = 123456, val = 1, data = {a =1, b=2}}},
        {"insert", "test_mongo_1", "document", {pid = 123456, val = 1, data = {a =2, b=3}}},
        {"insert", "test_mongo_1", "document", {pid = 123457, val = 1, data = {a =2, b=3}}},
        {"update", "test_mongo_1", "updateMods", {["$set"] = {val = 2}}, "filter", {pid = 123456}, "multi", true},
        {"delete", "test_mongo_1", "filter", {pid = 123457}, "multi", true},
    }, true)
    log_debug("db bulkwrite code: {}, res = {}", bcode, bres)
end)
