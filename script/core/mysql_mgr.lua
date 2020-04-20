--mysql_mgr.lua
local lmysql        = require("luamysql")
local MYSQL_CFGS    = import("config/mysql_cfg.lua")
local pairs         = pairs
local errcode       = err.Code
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local env_number    = environ.number

local timer_mgr     = quanta.timer_mgr
local router_mgr    = quanta.router_mgr
local thread_mgr = quanta.thread_mgr

local SUCCESS       = errcode.SUCCESS
local MYSQL_FAILED  = errcode.MYSQL_FAILED

local RETRY_TIME        = 3
local CONNECT_WAIT_TIME = 5
local PERIOD_UPDATE     = 1000

local MysqlMgr = singleton()
function MysqlMgr:__init()
    self.mysql_svrs = {}

    --初始化
    self:setup()
end

--初始化
function MysqlMgr:setup()
    local cfg_id = env_number("ENV_MYSQL_GROUP")
    if MYSQL_CFGS[cfg_id] then
        for id, cfg in pairs(MYSQL_CFGS[cfg_id]) do
            local agent = lmysql.create_agent(cfg.host, cfg.port, cfg.db, cfg.user, cfg.password)
            self.mysql_svrs[id] = {agent = agent, cfg = cfg, connect_tick = 0}
        end
    else
        log_err("mysql config %d is nil!!", cfg_id)
    end

    --update
    timer_mgr:loop(PERIOD_UPDATE, function()
        self:check_conns()
    end)

    --注册事件
    router_mgr:add_listener(self, "mysql_find")
    router_mgr:add_listener(self, "mysql_insert")
    router_mgr:add_listener(self, "mysql_delete")
    router_mgr:add_listener(self, "mysql_update")
    router_mgr:add_listener(self, "mysql_find_one")
end

--创建mysql连接
function MysqlMgr:create_conn(id, node)
    local conn, err = node.agent:grabconn()
    if err ~= nil then
        log_err("mysql create conn %d->(host:%s, db=%s) failed: %s!", id, node.cfg.host, node.cfg.db, err)
    else
        log_info("mysql conn %d->(host:%s, db=%s) has ready!", id, node.cfg.host, node.cfg.db)
        return conn
    end
end

--查找mysqlconn
function MysqlMgr:find_conn(id)
    local node = self.mysql_svrs[id]
    return node, node and node.conn
end

--检查mysql连接情况
function MysqlMgr:check_conns()
    for id, node in pairs(self.mysql_svrs) do
        if node.conn then
            if not node.conn:ping() then
                log_err("mysql conn %d lost: %s!", id, node.conn:error())
                node.conn:close()
                node.conn = nil
            end
        else
            if quanta.now > node.connect_tick then
                node.conn = self:create_conn(id, node)
                if not node.conn then
                    node.connect_tick = quanta.now + CONNECT_WAIT_TIME
                end
            end
        end
    end
end

--执行sql
function MysqlMgr:exec_sql(conn, sql, bquery, bone_record)
    --执行类操作
    if not bquery then
        local ok, info, insert_id = conn:execute(sql)
        if not ok then
            local err = info
            log_err("mysql exec sql %s failed: %s!", sql, err)
            return nil, err
        end
        log_debug("execute sql->info: %s, insert_id:%d", info, insert_id)
        return {info = info, insert_id = insert_id}
    end
    --查询类操作
    local result, resords_or_err = conn:query(sql)
    if not result then
        log_err("mysql exec sql %s failed: %s!", sql, resords_or_err)
        return nil, resords_or_err
    end
    --只取一条记录
    if bone_record and resords_or_err then
        return resords_or_err[1]
    else
        return resords_or_err
    end
end

--rpc事件处理
---------------------------------------------------------------------------
--请求执行数据库rpc
function MysqlMgr:exec_cmd(sql, dbid, bquery, bone_record)
    local retry = RETRY_TIME
    while retry > 0 do
        local node, conn = self:find_conn(dbid)
        if node and conn then
            --执行开始
            local records, err = self:exec_sql(conn, sql, bquery, bone_record)
            if err ~= nil then
                --返回错误
                return MYSQL_FAILED, err
            end
            return SUCCESS, records
        end
        thread_mgr:sleep(100)
        retry = retry - 1
    end
    return MYSQL_FAILED, "mysql server not vaild"
end

function MysqlMgr:mysql_find(sql, dbid)
    log_debug("MysqlMgr:mysql_find: sql->%s, dbid->%d", sql, dbid)
    return self:exec_cmd(sql, dbid, true)
end

function MysqlMgr:mysql_find_one(sql, dbid)
    log_debug("MysqlMgr:mysql_find_one: sql->%s, dbid->%d", sql, dbid)
    return self:exec_cmd(sql, dbid, true, true)
end

function MysqlMgr:mysql_update(sql, dbid)
    log_debug("MysqlMgr:mysql_update: sql->%s, dbid->%d", sql, dbid)
    return self:exec_cmd(sql, dbid, false)
end

function MysqlMgr:mysql_insert(sql, dbid)
    log_debug("MysqlMgr:mysql_insert: sql->%s, dbid->%d", sql, dbid)
    return self:exec_cmd(sql, dbid, false)
end

function MysqlMgr:mysql_delete(sql, dbid)
    log_debug("MysqlMgr:mysql_delete: sql->%s, dbid->%d", sql, dbid)
    return self:exec_cmd(sql, dbid, false)
end

return MysqlMgr
