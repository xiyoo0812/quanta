--robot_tree.lua
import("robot/node/login_mgr.lua")

local login_mgr = quanta.get("login_mgr")

--行为树配置
local ROBOT_TREES     = {
    -- 登录测试用例
    [1001] = login_mgr:create_login(),
    [1002] = login_mgr:create_login_test(),
}

return ROBOT_TREES
