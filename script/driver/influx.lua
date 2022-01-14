--influx.lua
import("network/http_client.lua")
local ljson         = require("lcjson")
local lbuffer       = require("lbuffer")

local log_err       = logger.err
local log_info      = logger.info
local json_decode   = ljson.decode
local tinsert       = table.insert
local tconcat       = table.concat
local sgsub         = string.gsub
local sformat       = string.format
local lserialize    = lbuffer.serialize

local PeriodTime    = enum("PeriodTime")

local http_client   = quanta.get("http_client")

local Influx = class()
local prop = property(Influx)
prop:reader("ip", nil)          --地址
prop:reader("port", 8086)       --端口
prop:reader("org", nil)         --org
prop:reader("org_id", nil)      --org_id
prop:reader("token", nil)       --token
prop:reader("bucket", nil)      --bucket
prop:reader("org_addr", nil)    --org_addr
prop:reader("query_addr", nil)  --query_addr
prop:reader("write_addr", nil)  --query_addr
prop:reader("bucket_addr", nil) --bucket_addr
prop:reader("common_headers", nil)

function Influx:__init()
end

function Influx:setup(conf)
    self.ip = conf.host
    self.port = conf.port
    self.org = conf.user
    self.bucket = conf.db
    self.token = sformat("Token %s", conf.passwd)
    self.org_addr = sformat("http://%s:%s/api/v2/orgs", self.ip, self.port)
    self.write_addr = sformat("http://%s:%s/api/v2/write", self.ip, self.port)
    self.query_addr = sformat("http://%s:%s/api/v2/query", self.ip, self.port)
    self.bucket_addr = sformat("http://%s:%s/api/v2/buckets", self.ip, self.port)
    self.common_headers = { ["Authorization"] = self.token, ["Content-type"] = "application/json" }
    local my_org = self:find_org(conf.user)
    if my_org then
        self.org_id = my_org.id
    end
end
--line protocol
--https://docs.influxdata.com/influxdb/v2.1/api/#operation/PostBuckets
local BOOL_STR = { 't', 'T', 'true', 'True', 'TRUE', 'f', 'F', 'false', 'False', 'FALSE' }
function Influx:quote_value(value)
    local vtype = type(value)
    if vtype == "number" or vtype == "bool" then
        return value
    end
    if vtype ~= "string" then
        value = lserialize(value)
    end
    for i = 1, 10 do
        if value == BOOL_STR[i] then
            return value
        end
    end
    return sformat('"%s"', sgsub(value, '"', '\\"'))
end

function Influx:quote_field(value)
    return sgsub(sgsub(sgsub(value, '=', '\\='), ',', '\\,'), ' ', '\\ ')
end

function Influx:quote_measurement(value)
    return sgsub(sgsub(value, ',', '\\,'), ' ', '\\ ')
end

function Influx:quote_tags(measurement, tags)
    local qtags = { measurement }
    for key, value in pairs(tags) do
        tinsert(qtags, sformat("%s=%s", self:quote_field(key), self:quote_field(value)))
    end
    return tconcat(qtags)
end

function Influx:quote_fields(fields)
    local qfields = { }
    for key, value in pairs(fields) do
        tinsert(qfields, sformat("%s=%s", self:quote_field(key), self:quote_value(value)))
    end
    return tconcat(qfields)
end

--influx操作接口
--查找bucket信息
function Influx:find_bucket(bucket_name)
    local querys = { name = bucket_name }
    local ok, status, res = http_client:call_get(self.bucket_addr, querys, self.common_headers)
    if not ok then
        log_err("[Influx][find_bucket] failed! code: %s, err: %s", status, res)
        return
    end
    log_info("[Influx][find_bucket]! status: %s", status)
    local response = json_decode(res)
    local buckets = response.buckets
    if not bucket_name then
        return buckets
    end
    for _, bucket in pairs(buckets) do
        if bucket.name == bucket_name then
            return bucket
        end
    end
end

--查找org信息
function Influx:find_org(org_name)
    local querys = { org = org_name }
    local ok, status, res = http_client:call_get(self.org_addr, querys, self.common_headers)
    if not ok then
        log_err("[Influx][find_org] failed! code: %s, err: %s", status, res)
        return
    end
    log_info("[Influx][find_org]! status: %s", status)
    local response = json_decode(res)
    local orgs = response.orgs
    if not org_name then
        return orgs
    end
    for _, org in pairs(orgs) do
        if org.name == org_name then
            return org
        end
    end
end

--create bucket
function Influx:create_bucket(name, expire_time)
    local data = { name = name,  org_id = self.org_id }
    data.retentionRules = {
        type = "expire",
        shardGroupDurationSeconds = 0,
        everySeconds = expire_time or PeriodTime.DAY_S
    }
    local ok, status, res = http_client:call_post(self.bucket_addr, data, self.common_headers)
    if not ok then
        log_err("[Influx][create_bucket] failed! code: %s, err: %s", status, res)
        return
    end
    log_info("[Influx][create_bucket]! code: %s, err: %s", status, res)
end

--delete bucket
function Influx:delete_bucket(bucket_id)
    local url = sformat("%s/%s", self.bucket_addr, bucket_id)
    local ok, status, res = http_client:call_del(url, {}, self.common_headers)
    if not ok then
        log_err("[Influx][delete_bucket] failed! code: %s, err: %s", status, res)
        return
    end
    log_info("[Influx][delete_bucket]! code: %s, err: %s", status, res)
end

--写数据
function Influx:write(measurement, tags, fields)
    local prefix = self:quote_tags(measurement, tags)
    local suffix = self:quote_fields(fields)
    local line_protocol = sformat("%s:%s", prefix, suffix)
    local headers = {
        ["Accept"] = "application/json",
        ["Content-type"] = "text/plain",
        ["Authorization"] = self.common_headers["Authorization"],
    }
    local querys = { org = self.org, bucket = self.bucket }
    local ok, status, res = http_client:call_post(self.write_addr, line_protocol, headers, querys)
    if not ok then
        log_err("[Influx][write] failed! code: %s, err: %s", status, res)
        return
    end
    log_info("[Influx][write]! code: %s, res: %s", status, res)
end

function Influx:query(iql)
    local headers = {
        ["Accept"] = "application/json",
        ["Content-type"] = self.common_headers["Content-type"],
        ["Authorization"] = self.common_headers["Authorization"],
    }
    local querys = { org = self.org, database = self.bucket }
    local ok, status, res = http_client:call_get(self.query_addr, querys, headers, iql)
    if not ok then
        log_err("[Influx][query] failed! code: %s, err: %s", status, res)
        return
    end
    log_info("[Influx][query]! code: %s, res: %s", status, res)
end

function Influx:query_flux(script)
    local headers = {
        ["Accept"] = "application/json",
        ["Content-type"] = "application/vnd.flux",
        ["Authorization"] = self.common_headers["Authorization"],
    }
    local querys = { org = self.org }
    local ok, status, res = http_client:call_post(self.query_addr, script, headers, querys)
    if not ok then
        log_err("[Influx][query_flux] failed! code: %s, err: %s", status, res)
        return
    end
    log_info("[Influx][query_flux]! code: %s, res: %s", status, res)
end

return Influx
