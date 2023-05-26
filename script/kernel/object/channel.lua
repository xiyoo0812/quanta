--channel.lua
local tinsert       = table.insert
local qfailed       = quanta.failed

local thread_mgr    = quanta.get("thread_mgr")

local RPC_TIMEOUT   = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")

local Channel = class()
local prop = property(Channel)
prop:reader("title", "")
prop:reader("executers", {})    --执行器列表

function Channel:__init(title)
    self.title = title
end

function Channel:clear()
    self.executers = {}
end

function Channel:empty()
    return #self.executers == 0
end

--添加执行器
-- executer失败返回 false, err
-- executer成功返回 true, code, data
function Channel:push(executer)
    tinsert(self.executers, executer)
end

--执行
function Channel:execute(title)
    local all_datas = {}
    local count = #self.executers
    if count == 0 then
        return true, all_datas
    end
    local session_id = thread_mgr:build_session_id()
    for i, executer in ipairs(self.executers) do
        local success, corerr, data = true, 0
        thread_mgr:fork(function()
            success, corerr, data = executer()
            all_datas[i] = data
            count = count - 1
            thread_mgr:try_response(session_id, success, corerr)
        end)
        local exec_failed, code = qfailed(corerr, success)
        if exec_failed then
            return false, code
        end
    end
    while count > 0 do
        local soc, corerr = thread_mgr:yield(session_id, title or self.title, RPC_TIMEOUT)
        local exec_failed, code = qfailed(corerr, soc)
        if exec_failed then
            return false, code
        end
    end
    return true, all_datas
end

return Channel
