-- http_test.lua

local log_info      = logger.info
local sformat       = string.format

local thread_mgr    = quanta.get("thread_mgr")

local LOCAL_PORT    = 18988

local TestCase      = import("test/case.lua")
local HttpTest      = class(TestCase)

function HttpTest:run()
    local HttpClient = import("network/http_client.lua")

    ------------------------------------------------------------------
    --1. 本地 HTTP server: GET/POST/PUT/DEL 往返
    ------------------------------------------------------------------
    local HttpServer = import("network/http_server.lua")
    local server = HttpServer()
    server:listen("127.0.0.1", LOCAL_PORT)
    server:register_get("*", function(path, body, params)
        return { method = "GET", path = path, echo = params }
    end)
    server:register_post("*", function(path, body, params)
        return { method = "POST", path = path, body = body }
    end)
    server:register_put("*", function(path, body, params)
        return { method = "PUT", path = path, body = body }
    end)
    server:register_del("*", function(path, body, params)
        return { method = "DELETE", path = path }
    end)
    self:report("http server listen", server.listener ~= nil, server.listener ~= nil, true)

    --等 server 就绪
    thread_mgr:sleep(200)

    local h1 = HttpClient()          --HTTP/1.1
    local base = sformat("http://127.0.0.1:%d", LOCAL_PORT)
    local gok, gstatus, gbody = h1:call_get(base .. "/get", { key = "v" })
    self:report("local GET", gok == true and gstatus == 200 and type(gbody) == "table",
        { gok, gstatus, type(gbody) }, { false, gstatus })

    local pok, pstatus, pbody = h1:call_post(base .. "/post", { hello = "world" })
    self:report("local POST", pok == true and pstatus == 200 and type(pbody) == "table",
        { pok, pstatus, type(pbody) }, { false, pstatus })

    local uok, ustatus, ubody = h1:call_put(base .. "/put", { hello = "put" })
    self:report("local PUT", uok == true and ustatus == 200 and type(ubody) == "table",
        { uok, ustatus, type(ubody) }, { false, ustatus })

    local dok, dstatus = h1:call_del(base .. "/del")
    self:report("local DELETE", dok == true and dstatus == 200, { dok, dstatus }, { true, 200 })

    ------------------------------------------------------------------
    --2. 外网 HTTPS(HTTP/1.1)
    ------------------------------------------------------------------
    local sok, sstatus, sbody = h1:call_get("https://www.baidu.com", nil, nil, nil, 8000)
    self:report("external HTTPS", sok == true and sstatus == 200,
        { sok, sstatus, type(sbody) }, { false, sstatus })

    ------------------------------------------------------------------
    --3. Chunked 传输
    ------------------------------------------------------------------
    local cok, cstatus, cbody = h1:call_get("https://httpbin.org/stream/3", nil, nil, nil, 10000)
    self:report("chunked transfer", cok == true and cstatus == 200,
        { cok, cstatus, type(cbody) }, { false, cstatus })

    ------------------------------------------------------------------
    --4. HTTP/2 客户端创建与配置验证
    ------------------------------------------------------------------
    local h2 = HttpClient("h2")
    local h2ok, h2status, h2body = h2:call_get("https://yuanbao.tencent.com/download")
    self:report("external HTTP/2", h2ok == true and h2status == 200,
        { h2ok, h2status, type(h2body) }, { false, h2status })

    ------------------------------------------------------------------
    --5. 本地 HTTPS server 证书配置
    ------------------------------------------------------------------
    -- local tls = require("luatls")
    -- local cfile = io.open("./data/https_server.crt", "rb")
    -- if cfile then
    --     cfile:close()
    --     local cert_ok = pcall(tls.init_cert, "./data/https_server.crt", "./data/https_server.key")
    --     self:report("local https cert load", cert_ok == true, cert_ok, true)
    -- else
    --     --证书不存在时跳过(可用 openssl req -x509 -newkey rsa:2048 -nodes ... 生成)
    --     log_info("[http] skip local https cert test: data/https_server.crt not found")
    -- end

    log_info("[http] done: local CRUD + external HTTPS + chunked + h2 client")
end

return HttpTest
