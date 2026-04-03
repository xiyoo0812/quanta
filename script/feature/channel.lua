--channel.lua
local tinsert       = table.insert
local qfailed       = quanta.failed
local lnext_id      = luakit.next_id

local thread_mgr    = quanta.get("thread_mgr")

local RPC_FAILED    = quanta.enum("KernCode", "RPC_FAILED")
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

function Channel:isfull(count)
    return (#self.executers >= count)
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
function Channel:execute(all_back)
    local all_datas = {}
    local count = #self.executers
    if count == 0 then
        return true, all_datas
    end
    local success = true
    local session_id = lnext_id()
    for i, executer in ipairs(self.executers) do
        local efailed, code = false, 0
        thread_mgr:fork(function()
            local ok, corerr, data = executer()
            all_datas[i] = data
            if not thread_mgr:try_response(session_id, ok, corerr) then
                efailed, code = qfailed(corerr, ok)
                count = count - 1
                if efailed then
                    success = false
                end
            end
        end)
        if efailed and (not all_back) then
            return false, code
        end
    end
    local time = quanta.clock_ms
    while count > 0 do
        if quanta.clock_ms - time > RPC_TIMEOUT then
            return false, RPC_FAILED
        end
        local sok, corerr = thread_mgr:yield(session_id, self.title, RPC_TIMEOUT)
        local efailed, code = qfailed(corerr, sok)
        count = count - 1
        if efailed then
            success = false
            if not all_back then
                return false, code
            end
        end
    end
    return success, all_datas
end

return Channel
