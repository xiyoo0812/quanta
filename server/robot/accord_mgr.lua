-- accord_mgr.lua
local log_warn      = logger.warn
local log_debug     = logger.debug
local jdecode       = json.decode
local json_pretty   = json.pretty

local HttpServer    = import("network/http_server.lua")

local robot_mgr     = quanta.get("robot_mgr")
local update_mgr    = quanta.get("update_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local accord_dao    = quanta.get("accord_dao")
local msg_mgr       = quanta.get("msg_mgr")

-- 时间单位
local SECOND_3_MS   = quanta.enum("PeriodTime", "SECOND_3_MS")

local AccordMgr = singleton()
local prop = property(AccordMgr)
prop:reader("http_server", nil)
prop:reader("accord_list", {}) -- 协议列表(添加的数据)
prop:reader("case_group", {})  -- 用例分组
prop:reader("load_db_status", false)
prop:reader("srvlist_api", environ.get("QUANTA_SRVLIST_API")) -- 服务器列表api

function AccordMgr:__init()
    -- 创建HTTP服务器
    local server = HttpServer(environ.get("QUANTA_ACCORD_HTTP"))
    server:register_get("/", "on_accord_page", self)
    server:register_get("/message", "on_message", self)
    server:register_post("/create", "on_create", self)
    server:register_post("/destory", "on_destory", self)
    server:register_post("/run", "on_run", self)
    server:register_post("/get_config", "on_get_config", self)

    -- 协议操作
    server:register_post("/case_group", "on_case_group", self)
    server:register_post("/case_group_edit", "on_case_group_edit", self)
    server:register_post("/case_group_del", "on_case_group_del", self)
    server:register_post("/accord_group", "on_accord_group", self)
    server:register_post("/accord_list", "on_accord_list", self)
    server:register_post("/accord_edit", "on_accord_edit", self)
    server:register_post("/accord_del", "on_accord_del", self)
    server:register_post("/proto_edit", "on_proto_edit", self)
    server:register_post("/proto_del", "on_proto_del", self)

    service.make_node(server:get_port())
    self.http_server = server
    -- 定时更新
    update_mgr:attach_second5(self)
    self:on_second5()
    self:load_db_data()
end

-- 加载db数据
function AccordMgr:load_db_data()
    if self.load_db_status then
        return
    end
    thread_mgr:success_call(SECOND_3_MS, function()
        -- 用例分组
        local cgp_ok, cgp_dbdata = accord_dao:load_data("case_group")
        if cgp_ok then
            for _, group in pairs(cgp_dbdata) do
                self.case_group[group.id] = group
            end
        else
            log_warn("[AccordMgr][load_db_data] case_group fail ok:{}", cgp_ok)
        end

        -- 协议配置
        local cf_ok, cf_dbdata = accord_dao:load_data("accord_conf")
        if cf_ok then
            for _, conf in pairs(cf_dbdata) do
                self.accord_list[conf.id] = {
                    id = conf.id,
                    name = tostring(conf.name),
                    openid = tostring(conf.openid),
                    passwd = tostring(conf.passwd),
                    server = conf.server or "",
                    rpt_att = conf.rpt_att,
                    protocols = {},
                    time = conf.time or 0,
                    casegroup = conf.casegroup or ""
                }
                -- 解析proto
                for _, proto in pairs(conf.protocols) do
                    self.accord_list[conf.id].protocols[tonumber(proto.id)] = proto
                end
            end
        else
            log_warn("[AccordMgr][load_db_data] accord_conf fail ok:{}", cf_ok)
        end

        if cgp_ok and cf_ok then
            self.load_db_status = true
        end
        return cgp_ok and cf_ok
    end)
end

-- 加载资源
function AccordMgr:load_html()
    self.accord_html = import("../server/robot/accord/index.lua")
end

-- 定时更新
function AccordMgr:on_second5()
    self:load_html()
end

-- http 回调
----------------------------------------------------------------------
-- accord_html
function AccordMgr:on_accord_page(url, body)
    if self.load_db_status then
        return self.accord_html, {
            ["Access-Control-Allow-Origin"] = "*"
        }
    end
    return [[
        <html>
            <head>
            </head>
            <body>
                <h1>Service loading, please refresh try...</h1>
            </body>
        </html>
    ]], {
        ["Access-Control-Allow-Origin"] = "*"
    }
end

-- 获取资源名称
function AccordMgr:get_src_name(src_path)
    local match = string.match(src_path, "[^/\\]+$")
    local src_name = string.sub(match, 1, -5)
    return src_name
end

-- 拉取日志
function AccordMgr:on_message(url, body, params)
    -- log_debug("[AccordMgr][on_message] open_id: {}", params.open_id)
    return robot_mgr:get_accord_message(params.open_id)
end

-- monitor拉取
function AccordMgr:on_create(url, body, params)
    log_debug("[AccordMgr][on_create] params:{}", params)
    return robot_mgr:create_robot(body.ip, body.port, body.open_id, body.passwd)
end

-- 后台GM调用，字符串格式
function AccordMgr:on_destory(url, body, params)
    log_debug("[AccordMgr][on_destory] body:{}", body)
    return robot_mgr:destory_robot(body.open_id)
end

-- 协议分组
function AccordMgr:on_accord_group(url, body)
    log_debug("[AccordMgr][on_accord_group] body:{}", body)
    return {
        code = 0,
        accord_group = msg_mgr.accord_group
    }, {
        ["Access-Control-Allow-Origin"] = "*"
    }
end

-- 分组列表
function AccordMgr:on_case_group(url, body)
    log_debug("[AccordMgr][on_case_group] body:{}", body)
    return { code = 0, case_group = self.case_group }
end

-- 编辑用例分组
function AccordMgr:on_case_group_edit(url, body)
    log_debug("[AccordMgr][on_case_group_edit] body:{}", body)
    if body.data then
        local data = body.data.case_group
        local id = data.id
        if self.case_group[id] then
            accord_dao:update("case_group", data)
        else
            accord_dao:insert("case_group", data)
        end
        self.case_group[id] = data
        return { code = 0 }
    end
    return { code = -1, msg = "数据格式不正确!" }
end

-- 删除用例分组
function AccordMgr:on_case_group_del(url, body)
    log_debug("[AccordMgr][on_case_group_del] body:{}", body)
    if body.data then
        local data = body.data
        local id = data.id
        local group = self.case_group[id]
        if not group then
            return { code = 0 }
        end
        for aid, accord in pairs(self.accord_list) do
            if group.name == accord.casegroup then
                accord_dao:delete("accord_conf", aid)
            end
        end
        self.case_group[id] = nil
        accord_dao:delete("case_group", id)
        return { code = 0 }
    end
    return { code = -1, msg = "数据格式不正确!" }
end

-- 协议列表
function AccordMgr:on_accord_list(url, body)
    log_debug("[AccordMgr][on_accord_list] body:{}", body)
    return { code = 0, accord_list = self.accord_list }
end

-- 编辑协议
function AccordMgr:on_accord_edit(url, body)
    log_debug("[AccordMgr][on_accord_edit] body:{}", body)
    if body.data then
        local data = body.data
        local id = data.id
        local new = false
        local accord = self.accord_list[id]
        if not accord then
            new = true
            accord = {}
            accord.protocols = {}
        end
        accord.id = data.id
        accord.name = data.name
        accord.openid = data.openid
        accord.passwd = data.passwd
        accord.server = data.server
        accord.rpt_att = data.rpt_att
        accord.casegroup = data.casegroup
        if data.protocols then
            accord.protocols = data.protocols
        end
        accord.time = data.time

        if new == false then
            accord_dao:update("accord_conf", accord)
        else
            accord_dao:insert("accord_conf", accord)
        end
        self.accord_list[id] = accord
        return { code = 0 }
    end
    return { code = -1, msg = "数据格式不正确!" }
end

-- 删除协议
function AccordMgr:on_accord_del(url, body)
    log_debug("[AccordMgr][on_accord_del] body:{}", body)
    if body.data then
        local data = body.data
        self.accord_list[data.id] = nil
        accord_dao:delete("accord_conf", data.id)
        return { code = 0 }
    end
    return { code = -1, msg = "数据格式不正确!" }
end

-- 编辑协议选项
function AccordMgr:on_proto_edit(url, body)
    log_debug("[AccordMgr][on_proto_edit] body:{}", body)
if body and body.data then
        local data = body.data
        local accord = self.accord_list[data.id]
        if not accord then
            return { code = -1, msg = "不存在的协议配置,请重新创建!" }
        end
        local proto = data.data
        -- 解析json
        proto.args = jdecode(proto.args);
        -- 格式json字符串
        proto.args = json_pretty(proto.args)
        accord.protocols[tonumber(proto.id)] = proto
        accord_dao:update("accord_conf", accord)
    end
    return { code = 0}
end

-- 删除协议选项
function AccordMgr:on_proto_del(url, body)
    log_debug("[AccordMgr][on_proto_del] body:{}", body)
    if body.data then
        local data = body.data
        local accord = self.accord_list[data.id]
        if not accord then
            return { code = -1, msg = "不存在的协议配置!" }
        end
        accord.protocols[tonumber(data.proto_id)] = nil
        accord_dao:update("accord_conf", accord)
    end
    return { code = 0}
end

-- 后台GM调用，table格式
function AccordMgr:on_run(url, body)
    local data = body.data
    if body.cmd_id ~= 1001 then
        data = jdecode(body.data)
        log_debug("[AccordMgr][on_run] body:{}", body)
    end
    return robot_mgr:run_accord_message(body.open_id, body.cmd_id, data)
end

-- 获取配置
function AccordMgr:on_get_config(url, body)
    return { code = 0, srvlist_api=self.srvlist_api}
end

quanta.accord_mgr = AccordMgr()

return AccordMgr
