-- group.lua
local log_err       = logger.err
local qfailed       = quanta.failed
local makechan      = quanta.make_channel

local Document      = import("cache/document.lua")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local Group = class()
local prop = property(Group)
prop:reader("name", "")         -- name
prop:reader("documents", {})    -- documents
prop:reader("primary_id", nil)  -- primary id

function Group:__init(name)
    self.name = name
end

--加载DB组
function Group:load(primary_id, gconfs)
    self.primary_id = primary_id
    local channel = makechan("load_group")
    for _, conf in ipairs(gconfs) do
        local sheet = conf.sheet
        channel:push(function()
            local doc = Document(conf, primary_id)
            local code = doc:load()
            if qfailed(code) then
                log_err("[Group][load] load doc failed: tab_name={}", sheet)
                return false, code
            end
            self.documents[sheet] = doc
            return true, SUCCESS
        end)
    end
    return channel:execute()
end

function Group:get_doc(sheet)
    return self.documents[sheet]
end

--移除内存数据
function Group:clear()
    self.documents = {}
end

--flush
function Group:flush()
    for _, doc in pairs(self.documents) do
        doc:check_flush(true)
    end
    self.documents = {}
end


return Group
