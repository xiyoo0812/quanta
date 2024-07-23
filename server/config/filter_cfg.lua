--filter_cfg.lua
--source: filter.csv
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local filter = config_mgr:get_table("filter")

--导出配置内容
filter:upsert({
    id=1,
    log=true,
    name='NID_HEARTBEAT_REQ'
})

filter:upsert({
    id=2,
    name='NID_LOGIN_ROLE_LOGIN_REQ',
    proto=true
})

filter:update()
