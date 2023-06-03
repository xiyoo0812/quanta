--group_mgr.lua
local log_info  = logger.info
local qtweak    = qtable.weak

--创建角色数据
local GroupMgr = class()
local prop = property(GroupMgr)
prop:accessor("groups", {}) --分组id列表

function GroupMgr:__init()
end

--更新服务网关
function GroupMgr:add_member(group_id, player_id, player)
    log_info("[GroupMgr][add_member] group_id(%d) player_id(%s) id(%s)!", group_id, player_id)
    local group = self.groups[group_id]
    if not group then
        self.groups[group_id] = qtweak({ [player_id] = player })
        return
    end
    group[player_id] = player
end

--更新分组信息
function GroupMgr:remove_member(group_id, player_id)
    log_info("[GroupMgr][remove_member] group_id(%d) player_id(%s) id(%s)!", group_id, player_id)
    local group = self.groups[group_id]
    if group then
        group[player_id] = nil
    end
end

--广播消息
function GroupMgr:broadcast(group_id, cmd_id, data)
    local group = self.groups[group_id]
    for _, player in pairs(group or {}) do
        player:send_message(cmd_id, data, false)
    end
end

quanta.group_mgr = GroupMgr()

return GroupMgr
