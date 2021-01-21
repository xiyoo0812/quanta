-- mongo_test.lua
import("kernel/store/mongo_mgr.lua")
import("kernel/store/db_agent.lua")

local log_info      = logger.info
local serialize     = logger.serialize
local check_failed  = utility.check_failed

local mongo_mgr     = quanta.get("mongo_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local db_agent      = quanta.get("db_agent")

local player_id = 689620221291398145
local row_data  = {bag_items={[2]=1},player_id=689620221291398145}

local MongoTest = singleton()
function MongoTest:__init()
    self:setup()
end

function MongoTest:setup()
    local index = quanta.index
    thread_mgr:fork(function()
        thread_mgr:sleep(3000)
        if index == 1 then
            log_info("db request begin")
            --log_info("%s", json_encode(row_data))
            --[[
            local ok, code, res = db_agent:find(quanta.id, {"test_table", })
            if not ok or check_failed(code) then
                log_info("find: code: %s, res: %s", code, serialize(res))
            end
            local ok1, code1, res1 = db_agent:find_one(quanta.id, {"test_table", })
            if not ok1 or check_failed(code1) then
                log_info("find_one: code: %s, res: %s", code1, serialize(res1))
            end
            ]]
            local update_cmd = {}
            update_cmd.table_name = "player_bag"
            update_cmd.key_name   = "player_id"
            update_cmd.key_value  = player_id
            update_cmd.row_data   = row_data
            local ok1, code1, res1 = db_agent:update(player_id, {update_cmd.table_name, row_data, {player_id = player_id}, false})
            if not ok1 or check_failed(code1) then
                log_info("find_one: code: %s, res: %s", code1, serialize(res1))
            end
            log_info("db request end")
        else
            local icode, ierr = mongo_mgr:game_count(1, "test_mongo_1", {pid = 123456})
            log_info("db count code: %s, err = %s", icode, serialize(ierr))
            --[[
            local icode, ierr = mongo_mgr:game_insert(1, "test_mongo_1", {pid = 123456, data = {a =1, b=2}})
            log_info("db insert code: %s, err = %s", icode, serialize(ierr))
            local icode, ierr = mongo_mgr:game_insert(1, "test_mongo_1", {pid = 123457, data = {a =1, b=2}})
            log_info("db insert code: %s, err = %s", icode, ierr)
            local fcode, res = mongo_mgr:game_find(1, "test_mongo_1", {})
            log_info("db find code: %s, res = %s", fcode, serialize(res))
            local f1code, f1res = mongo_mgr:game_find_one(1, "test_mongo_1", {pid = 123456})
            log_info("db find code: %s, res = %s", f1code, serialize(f1res))
            local ucode, uerr = mongo_mgr:game_update(1, "test_mongo_1", {pid = 123458, data = {a =1, b=4}}, {pid = 123457})
            log_info("db update code: %s, err = %s", ucode, uerr)
            local icode, ierr = mongo_mgr:game_count(1, "test_mongo_1", {pid = 123456})
            log_info("db count code: %s, err = %s", icode, serialize(ierr))
            ]]
        end
    end)
end

-- export
quanta.mongo_test = MongoTest()

return MongoTest
