-- mongo_test.lua
import("kernel/store/mongo_agent.lua")
local ljson = require("luacjson")

local log_err       = logger.err
local serialize     = logger.serialize
local check_failed  = utility.check_failed

local thread_mgr    = quanta.thread_mgr
local mongo_agent   = quanta.mongo_agent

ljson.encode_sparse_array(true)
--local json_encode   = ljson.encode

local player_id = 689620221291398145
local row_data  = {bag_items={[2]=1},player_id=689620221291398145}

local MongoTest = singleton()
function MongoTest:__init()
    self:setup()
end

function MongoTest:setup()
    thread_mgr:fork(function()
        while true do
            thread_mgr:sleep(3000)
            log_err("db request begin")
            --log_err("%s", json_encode(row_data))
            --[[
            local ok, code, res = mongo_agent:find(quanta.id, {"test_table", })
            if not ok or check_failed(code) then
                log_err("find: code: %s, res: %s", code, serialize(res))
            end

            local ok1, code1, res1 = mongo_agent:find_one(quanta.id, {"test_table", })
            if not ok1 or check_failed(code1) then
                log_err("find_one: code: %s, res: %s", code1, serialize(res1))
            end
            ]]
            local update_cmd = {}
            update_cmd.table_name = "player_bag"
            update_cmd.key_name   = "player_id"
            update_cmd.key_value  = player_id
            update_cmd.row_data   = row_data
            local ok1, code1, res1 = mongo_agent:update(player_id, {update_cmd.table_name, row_data, {player_id = player_id}, false})
            if not ok1 or check_failed(code1) then
                log_err("find_one: code: %s, res: %s", code1, serialize(res1))
            end
            log_err("db request end")
        end
    end)
end

-- export
quanta.mongo_test = MongoTest()

return MongoTest
