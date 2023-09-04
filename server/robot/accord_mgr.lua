-- accord_mgr.lua
local log_warn      = logger.warn
local log_debug     = logger.debug
local jdecode       = json.decode

local HttpServer    = import("network/http_server.lua")

local robot_mgr     = quanta.get("robot_mgr")
local update_mgr    = quanta.get("update_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local accord_dao    = quanta.get("accord_dao")

-- 时间单位
local SECOND_3_MS   = quanta.enum("PeriodTime", "SECOND_3_MS")

local AccordMgr = singleton()
local prop = property(AccordMgr)
prop:reader("http_server", nil)
prop:reader("accord_html", "")
prop:reader("accord_css", "")
prop:reader("server_list", {})
prop:reader("accord_list", {})
prop:reader("load_db_status", false)

function AccordMgr:__init()
    -- 创建HTTP服务器
    local server = HttpServer(environ.get("QUANTA_ACCORD_HTTP"))
    server:register_get("/", "on_accord_page", self)
    server:register_get("/style", "on_accord_css", self)
    server:register_get("/message", "on_message", self)
    server:register_post("/create", "on_create", self)
    server:register_post("/destory", "on_destory", self)
    server:register_post("/runall", "on_runall", self)
    server:register_post("/run", "on_run", self)

    -- 服务器操作
    server:register_post("/server_list", "on_server_list", self)
    server:register_post("/server_edit", "on_server_edit", self)
    server:register_post("/server_del", "on_server_del", self)

    -- 协议操作
    server:register_post("/accord_list", "on_accord_list", self)
    server:register_post("/accord_edit", "on_accord_edit", self)
    server:register_post("/accord_del", "on_accord_del", self)
    server:register_post("/upload", "on_upload", self)
    server:register_post("/proto_edit", "on_proto_edit", self)
    server:register_post("/proto_del", "on_proto_del", self)

    service.make_node(server:get_port())
    self.http_server = server
    -- 定时更新
    update_mgr:attach_second(self)
    -- 加载数据
    self:load_db_data()
    self:on_second()
end

-- 加载db数据
function AccordMgr:load_db_data()
    if self.load_db_status then
        return
    end
    thread_mgr:success_call(SECOND_3_MS, function()
        local svr_ok, srv_dbdata = accord_dao.load_server_list()
        if svr_ok then
            for _,server in pairs(srv_dbdata) do
                self.server_list[tostring(server.name)] = server
            end
        else
            log_warn("[AccordMgr][load_db_data] load_server_list fail ok(%s)", svr_ok)
        end

        local cf_ok, cf_dbdata = accord_dao.load_accord_conf()
        if cf_ok then
            for _,conf in pairs(cf_dbdata) do
                local name = tostring(conf.name)
                self.accord_list[name] = {
                    name = name,
                    openid = tostring(conf.openid),
                    passwd = tostring(conf.passwd),
                    server = conf.server or "",
                    rpt_att = conf.rpt_att,
                    protocols = {}
                }
                -- 解析proto
                for _,proto in pairs(conf.protocols) do
                    self.accord_list[name].protocols[tostring(proto.name)] = proto
                end
            end
        else
            log_warn("[AccordMgr][load_db_data] load_accord_conf fail ok(%s)", cf_ok)
        end

        if svr_ok and cf_ok then
            self.load_db_status = true
        end
        return svr_ok and cf_ok
    end)
end

-- 加载页面
function AccordMgr:load_html()
    self.accord_html = [[
        <html>
            <head>
            </head>
            <body>
                <h1>Failed to load the html file. Please check the html file(filePath:bin\accord\page.html)</h1>
            </body>
        </html>
    ]]
    local currentDir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    local file_path = currentDir .. "accord/page/page.html"
    local file = io.open(file_path, "r")
    if file then
        self.accord_html = file:read("*a")
        file:close()
    else
        log_warn("Unable to open file(file_path=bin/%s)", file_path)
    end
end

-- 加载页面
function AccordMgr:load_css()
    self.accord_css = [[
    ]]
    local currentDir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    local file_path = currentDir .. "accord/page/css/style.css"
    local file = io.open(file_path, "r")
    if file then
        self.accord_css = file:read("*a")
        file:close()
    else
        log_warn("Unable to open file(file_path=bin/%s)", file_path)
    end
end

-- 定时更新
function AccordMgr:on_second()
    -- local message_name = ".ncmd_cs.custom_status"
    -- -- 使用迭代器获取字段信息
    -- for name, number, type, cpp_type, tag, message in pb.fields(message_name) do
    --     print(string.format("Name: %s, Number: %d, Type: %s cpp_type：%s tag：%s message：%s", name, number, type, cpp_type, tag, message))
    -- end
    self:load_html()
    self:load_css()
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

-- accord_css
function AccordMgr:on_accord_css(url, body)
    return self.accord_css, {
        ["Access-Control-Allow-Origin"] = "*"
    }
end

-- 拉取日志
function AccordMgr:on_message(url, params)
    --log_debug("[AccordMgr][on_message] open_id: %s", open_id)
    return robot_mgr:get_accord_message(params.open_id)
end

-- monitor拉取
function AccordMgr:on_create(url, body)
    log_debug("[AccordMgr][on_create] body: %s", body)
    return robot_mgr:create_robot(body.ip, body.port, body.open_id, body.passwd)
end

-- 后台GM调用，字符串格式
function AccordMgr:on_destory(url, body)
    log_debug("[AccordMgr][on_destory] body: %s", body)
    return robot_mgr:destory_robot(body.open_id)
end

-- 服务器列表
function AccordMgr:on_server_list(url, body)
    log_debug("[AccordMgr][on_server_list] body: %s", body)
    return { code = 0, server_list = self.server_list}
end

-- 编辑服务器
function AccordMgr:on_server_edit(url, body)
    log_debug("[AccordMgr][on_server_edit] body: %s", body)
    if body.data then
        local data = body.data
        if self.server_list[data.name] then
            accord_dao:save_server(data)
        else
            accord_dao:add_server(data)
        end
        self.server_list[data.name] = data
        return { code = 0}
    end
    return { code = -1, msg = "数据格式不正确!"}
end

-- 删除服务器
function AccordMgr:on_server_del(url, body)
    log_debug("[AccordMgr][on_server_del] body: %s", body)
    if body.data then
        local data = body.data
        self.server_list[data.name] = nil
        accord_dao:del_server(data.name)
        return { code = 0}
    end
    return { code = -1, msg = "数据格式不正确!"}
end

-- 协议列表
function AccordMgr:on_accord_list(url, body)
    log_debug("[AccordMgr][on_accord_list] body: %s", body)
    return { code = 0, accord_list = self.accord_list}
end

-- 编辑协议
function AccordMgr:on_accord_edit(url, body)
    log_debug("[AccordMgr][on_accord_edit] body: %s", body)
    if body.data then
        local data = body.data
        local accords = data.accords
        local low_name = data.low_name
        local clone = data.clone
        -- 删除原数据
        if not clone and low_name ~= accords.name then
            self.accord_list[low_name] = nil
            accord_dao:del_accord_conf(low_name)
        end
        if self.accord_list[accords.name] then
            accord_dao:save_accord_conf(accords)
        else
            accord_dao:add_accord_conf(accords)
        end
        self.accord_list[accords.name] = accords
        return { code = 0}
    end
    return { code = -1, msg = "数据格式不正确!"}
end

-- 删除协议
function AccordMgr:on_accord_del(url, body)
    log_debug("[AccordMgr][on_accord_del] body: %s", body)
    if body.data then
        local data = body.data
        self.accord_list[data.name] = nil
        accord_dao:del_accord_conf(data.name)
        return { code = 0}
    end
    return { code = -1, msg = "数据格式不正确!"}
end

-- 客户端上传用例
function AccordMgr:on_upload(url, body)
    log_debug("[AccordMgr][on_upload] body: %s", body)
    if body.data then
        local data = jdecode(body.data);
        local add = false
        if not self.accord_list[data.name] then
            add = true
        end
        self.accord_list[data.name] = data
        if add then
            accord_dao:add_accord_conf(data)
        else
            accord_dao:save_accord_conf(data)
        end
        return { code = 0, data=data}
    end
    return { code = -1, msg = "数据格式不正确!"}
end

-- 编辑协议选项
function AccordMgr:on_proto_edit(url, body)
    log_debug("[AccordMgr][on_proto_edit] body: %s", body)
    if body.data then
        local data = body.data
        local accord = self.accord_list[data.name]
        if not accord then
            return { code = -1, msg = "不存在的协议配置,请重新创建!"}
        end
        local proto = data.data
        accord.protocols[proto.name] = proto
        accord_dao:save_accord_conf(accord)
    end
    return { code = -1, msg = "数据格式不正确!"}
end

-- 删除协议选项
function AccordMgr:on_proto_del(url, body)
    log_debug("[AccordMgr][on_proto_del] body: %s", body)
    if body.data then
        local data = body.data
        local accord = self.accord_list[data.accord_name]
        if not accord then
            return { code = -1, msg = "不存在的协议配置!"}
        end
        accord.protocols[data.proto_name] = nil
        accord_dao:save_accord_conf(accord)
    end
    return { code = -1, msg = "数据格式不正确!"}
end

-- 后台GM调用，table格式
function AccordMgr:on_run(url, body)
    if body.cmd_id ~= 1001 then
        log_debug("[AccordMgr][on_run] body: %s", body)
    end
    return robot_mgr:run_accord_message(body.open_id, body.cmd_id, body.data)
end

-- 后台GM调用，table格式
function AccordMgr:on_runall(url, body)
    log_debug("[AccordMgr][on_runall] body: %s", body)
    return robot_mgr:run_accord_messages(body.open_id, body.data)
end

quanta.accord_mgr = AccordMgr()

return AccordMgr
