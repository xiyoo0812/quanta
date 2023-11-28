--gatelog_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local gatelog = config_mgr:get_table("gatelog")

--导出配置内容
gatelog:upsert({
    id=1,
    name='NID_HEARTBEAT_REQ'
})

gatelog:update()
