--validate.lualog
require("lstdfs")

local pairs         = pairs
local ldir          = stdfs.dir
local lappend       = stdfs.append
local lextension    = stdfs.extension
local lfilename     = stdfs.filename
local lcurdir       = stdfs.current_path
local serialize     = string.serialize
local sformat       = string.format
local tunpack       = table.unpack
local tinsert       = table.insert
local tconcat       = table.concat
local qgetenv       = quanta.getenv
local dgetinfo      = debug.getinfo
local dtraceback    = debug.traceback
local iowrite       = io.write

--是否递归
local recursion     = false
--自定义验证文件路径
local custom_path   = "./validate/custom/"

local config_mgr    = {
    configs = {},
}

local Config = {}

local ConfigMT = {
    update = function()
    end,
    upsert = function(self, record)
        local info = dgetinfo(2)
        record.__source = sformat("%s:%s", lfilename(info.short_src), info.currentline)
        tinsert(self.records, record)
    end,
    upsert_field = function(self, name, type_str)
        self.fields[name] = type_str
    end,
    upsert_validate = function(self, validate)
        tinsert(self.validates, validate)
    end,
    set_verify_file = function(self, verify_file)
        self.verify_file = verify_file
    end,
    get_foreign = function(self, key)
        local foreign = self.foreigns[key]
        if not foreign then
            foreign = {}
            for _, record in pairs(self.records) do
                foreign[record[key]] = record
            end
            self.foreigns[key] = foreign
        end
        return foreign
    end,
    build_index = function(self, record)
        local primary_key = self.primary_key
        if not primary_key then
            primary_key = {}
            for _, validate in pairs(self.validates) do
                if validate.primary then
                    tinsert(primary_key, validate.field)
                end
            end
            self.primary_key = primary_key
        end
        local indexs = {}
        for _, field in pairs(primary_key) do
            tinsert(indexs, record[field])
        end
        if #indexs > 0 then
            local index_key = tconcat(indexs, "_")
            local source = self.index[index_key]
            if source then
                return false, source
            end
            self.index[index_key] = record.__source
        end
        return true
    end,
}

setmetatable(Config, {
    __call = function(self)
        local obj = {fields = {}, records = {}, validates = {}, index = {}, foreigns = {}, name = "" }
        setmetatable(obj, { __index = ConfigMT })
        return obj
    end
})

setmetatable(config_mgr, {
    __index = {
        get_table = function(self, name)
            local conf = self.configs[name]
            if conf then
                return conf
            end
            conf = Config()
            conf.name = name
            self.configs[name] = conf
            return conf
        end,
    },
})

quanta.get = function(name)
    if name == "config_mgr" then
        return config_mgr
    end
end

local value_funcs = {
    ["pair_key"] = function(value, verify_func, ...)
        for i = 1, #value, 2 do
            verify_func(value[i], ...)
        end
    end,
    ["pair_val"] = function(value, verify_func, ...)
        for i = 2, #value, 2 do
            verify_func(value[i], ...)
        end
    end,
    ["element"] = function(value, verify_func, ...)
        for _, val in pairs(value) do
            verify_func(val, ...)
        end
    end,
    ["map_key"] = function(value, verify_func, ...)
        for key in pairs(value) do
            verify_func(key, ...)
        end
    end,
    ["map_val"] = function(value, verify_func, ...)
        for _, val in pairs(value) do
            verify_func(val, ...)
        end
    end,
    ["elem_pair_key"] = function(value, verify_func, ...)
        for _, elem in ipairs(value) do
            for i = 1, #elem, 2 do
                verify_func(elem[i], ...)
            end
        end
    end,
    ["elem_pair_val"] = function(value, verify_func, ...)
        for _, elem in ipairs(value) do
            for i = 2, #elem, 2 do
                verify_func(elem[i], ...)
            end
        end
    end,
}

local function std_output(val, color)
    iowrite((color or "\27[31m") .. val .. "\n" .. "\27[0m")
end

local function validate_enum(value, enum_v, con_name, source, field)
    for _, val in pairs(enum_v) do
        if val == value then
            return
        end
    end
    std_output(sformat("config %s field '%s' is not in enum %s! => %s", con_name, field, serialize(enum_v), source))
end

local function validate_range(value, range, con_name, source, field)
    local min, max = tunpack(range)
    if value == nil or value < min or value > max then
        std_output(sformat("config %s field '%s' is not in <%s-%s>! => %s", con_name, field, min, max, source))
    end
end

local function validate_foreign(value, foreign_name, foreign_key, con_name, source, field)
    local conf = config_mgr:get_table(foreign_name)
    local foreign_data = conf:get_foreign(foreign_key)
    if value ~= nil and value ~= 0 and foreign_data[value] ~= nil then
        std_output(sformat("config %s field '%s' is foreign (%s.%s) not exist! => %s", con_name, field, foreign_name, foreign_key, source))
    end
end

local function validate_config_base(conf)
    local name = conf.name
    for _, record in ipairs(conf.records) do
        local source = record.__source
        local ok, isource = conf:build_index(record)
        if not ok then
            std_output(sformat("config %s primary is duplicate with %s! => %s", name, isource, source))
            goto continue_r
        end
        for _, validate in ipairs(conf.validates) do
            local field = validate.field
            local value = record[field]
            if validate.primary then
                if not value then
                    std_output(sformat("config %s primary field '%s' is nil! => %s", name, field, source))
                end
            end
            if validate.required then
                if not value then
                    std_output(sformat("config %s required field '%s' is nil! => %s", name, field, source))
                end
            end
            if not value then
                goto continue_v
            end
            local location_func
            if validate.location then
                location_func = value_funcs[validate.location]
            end
            if validate.range then
                if location_func then
                    location_func(value, validate_range, validate.range, name, source, field)
                else
                    validate_range(value, validate.range, name, source, field)
                end
            end
            local enum_v = validate.enum_i or validate.enum_s
            if enum_v then
                if location_func then
                    location_func(value, validate_enum, enum_v, name, source, field)
                else
                    validate_enum(value, enum_v, name, source, field)
                end
            end
            if validate.foreign then
                local foreign_name, foreign_key = tunpack(validate.foreign)
                if location_func then
                    location_func(value, validate_foreign, foreign_name, foreign_key, name, source, field)
                else
                    validate_foreign(value, foreign_name, foreign_key, name, source, field)
                end
            end
            :: continue_v ::
        end
        :: continue_r ::
    end
end

local function validate_config_custom(conf, verify_file)
    local name = conf.name
    local verify_path = lappend(custom_path, verify_file)
    local trunk_func, err = loadfile(verify_path)
    if not trunk_func then
        std_output(sformat("read config %s's custom verify file %s failed: %s!", name, verify_file, err))
        return
    end
    local ok, custom_func = xpcall(trunk_func, dtraceback)
    if not ok then
        std_output(sformat("load config %s's custom verify file %s failed: %s!", name, verify_file, custom_func))
        return
    end
    for _, record in ipairs(conf.records) do
        local cok, cerr = xpcall(custom_func, dtraceback, name, record, std_output, value_funcs)
        if not cok then
            std_output(sformat("execute config %s verify file %s failed: %s!", name, verify_file, cerr))
            return
        end
    end
end

local function is_config_file(ext)
    return ext == ".lua"
end

--入口函数
local function validate_config(input)
    print("validate_config:", input)
    local files = ldir(input)
    if files == 0 then
        std_output(sformat("input dir: %s not exist!", input))
    end
    for _, file in pairs(files or {}) do
        local fullname = file.name
        if file.type == "directory" then
            if not recursion then
                goto continue
            end
            validate_config(fullname)
            goto continue
        end
        local ext = lextension(fullname)
        if is_config_file(ext) then
            local trunk_func, err = loadfile(fullname)
            if not trunk_func then
                std_output(sformat("read config file %s failed: %s!", fullname, err))
                goto continue
            end
            local ok, cerr = xpcall(trunk_func, dtraceback)
            if not ok then
                std_output(sformat("load config file %s failed: %s!", fullname, cerr))
                goto continue
            end
        end
        :: continue ::
    end
    for _, conf in pairs(config_mgr.configs) do
        std_output(sformat("now begin validate config %s ...", conf.name), "\27[33m")
        if next(conf.validates) then
            validate_config_base(conf)
        end
        local verify_file = conf.verify_file
        if verify_file then
            validate_config_custom(conf, verify_file)
        end
    end
end

--检查配置
local function read_cmdline()
    local input = lcurdir()
    local env_input = qgetenv("QUANTA_INPUT")
    if not env_input or #env_input == 0 then
        std_output("input dir not config!")
    else
        input = lappend(input, env_input)
    end
    local env_recursion = qgetenv("QUANTA_RECURSION")
    if env_recursion then
        recursion = env_recursion == "true" or env_recursion == "1"
    end
    local env_custom_path = qgetenv("QUANTA_PATH")
    if env_custom_path and #env_custom_path > 0 then
        custom_path = env_custom_path
    end
    return input
end

print("usage: quanta.exe [--entry=validate] [--input=xxx] [--path=xxx]")
print("begin validate configs!")
local input = read_cmdline()
local ok, err = xpcall(validate_config, dtraceback, input)
if not ok then
    std_output(sformat("read validate config arg failed: %s!", err))
    return
end
print("finished validate configs!")
