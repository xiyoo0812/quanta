--group_mgr.lua
local log_info      = logger.info
local qtweak        = qtable.weak

local client_mgr    = quanta.get("client_mgr")

--创建角色数据
local GroupMgr = class()
local prop = property(GroupMgr)
prop:accessor("groups", {}) --分组id列表

function GroupMgr:__init()
end

--更新服务网关
function GroupMgr:add_member(group_id, player_id, player)
    log_info("[GroupMgr][add_member] group_id(%s) player_id(%s)!", group_id, player_id)
    local group = self.groups[group_id]
    local token = player:get_session_token()
    if not group then
        self.groups[group_id] = qtweak({ [player_id] = token })
        return
    end
    group[player_id] = token
end

--更新分组信息
function GroupMgr:remove_member(group_id, player_id)
    log_info("[GroupMgr][remove_member] group_id(%s) player_id(%s)!", group_id, player_id)
    local group = self.groups[group_id]
    if group then
        group[player_id] = nil
    end
end

--广播消息
function GroupMgr:broadcast(group_id, cmd_id, data)
    local tokens = self.groups[group_id]
    if tokens then
        client_mgr:broadcast_groups(tokens, cmd_id, data)
    end
end

quanta.group_mgr = GroupMgr()

return GroupMgr
