--utility_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local utility = config_mgr:get_table("utility")

--导出配置内容
utility:upsert({
    ID=1,
    key='flush_day_hour',
    value='5'
})

utility:upsert({
    ID=2,
    key='flush_week_day',
    value='1'
})

utility:update()
