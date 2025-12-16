--convertor.lualog
require("ljson")
require("lstdfs")
require("luacsv")
require("luaxlsx")

local pairs         = pairs
local iopen         = io.open
local ldir          = stdfs.dir
local lstem         = stdfs.stem
local lmkdir        = stdfs.mkdir
local lappend       = stdfs.append
local lconcat       = stdfs.concat
local lfilename     = stdfs.filename
local lextension    = stdfs.extension
local lcurdir       = stdfs.current_path
local jpretty       = json.pretty
local serialize     = string.serialize
local unserialize   = string.unserialize
local sfind         = string.find
local sgsub         = string.gsub
local sformat       = string.format
local sgmatch       = string.gmatch
local tconcat       = table.concat
local tunpack       = table.unpack
local tinsert       = table.insert
local tsort         = table.sort
local mtointeger    = math.tointeger
local slower        = string.lower
local qgetenv       = quanta.getenv

--指定导出函数
local export_method = nil
--起始列，默认2
local start_col     = 2
--类型定义行，默认2
local type_line     = 2
--配置起始行，默认5
local start_line    = 5
--配置表头行，默认start-1
local head_line     = nil
--是否递归
local recursion     = false
--是否导出所有workbook
local allbook      = false

local function conv_integer(v)
    return mtointeger(v) or v
end

local function conv_number(v)
    return mtointeger(v) or tonumber(v)
end

local function tsize(t)
    local c = 0
    for _ in pairs(t or {}) do
        c = c + 1
    end
    return c
end

local value_func = {
    ["int"] = conv_number,
    ["float"] = conv_number,
    ["byte"] = conv_integer,
    ["bool"] = function(value)
        return value == "1"
    end,
    ["string"] = function(value)
        value = value
        return sgsub(value, "\n", "\\n")
    end,
    ["struct"] = function(value)
        return unserialize(value)
    end,
    ["map"] = function(value)
        if sfind(value, '|') then
            value = sgsub(value, '|', ']=')
            value = sgsub(value, ',', ',[')
            return unserialize('{[' .. value .. '}')
        end
        return {}
    end,
    ["smap"] = function(value)
        value = sgsub(value, '|', '=')
        return unserialize('{' .. value .. '}')
    end,
    ["array"] = function(value)
        value = sgsub(value, '|', ',')
        if sfind(value, '[{]') then
            return unserialize(value)
        end
        return unserialize('{' .. value .. '}')
    end,
    ["arrlist"] = function(value)
        value = sgsub(value, '|', ',')
        value = sgsub(value, ';', '},{')
        return unserialize('{{' .. value .. '}}')
    end,
    ["sarray"] = function(value)
        value = sgsub(value, '|', ',')
        value = sgsub(value, ',', "','")
        if sfind(value, '[{]') then
            local array = sgsub(value, '[{.*}]', function (s)
                return s == '{' and "{'" or "'}"
            end)
            return unserialize(array)
        end
        return unserialize("{'" .. value .. "'}")
    end,
}

--获取cell value
local function get_cell_value(book, row, col, field_type)
    local value = book.get_cell_value(row, col)
    if not value or value == "" then
        return
    end
    if field_type then
        local func = value_func[slower(field_type)]
        if func then
            return func(value)
        end
    end
    return value
end

local function mapsort(src)
    local dst = {}
    for key, value in pairs(src or {}) do
        tinsert(dst, { key, value })
    end
    tsort(dst, function(a, b) return a[1] < b[1] end)
    return dst
end

-- 合并记录
local function merge_record(record)
    local rec, merge = {}, {}
    for _, info in ipairs(record) do
        local key, value = tunpack(info)
        local func = sgmatch(key, "([%a%d_]+)%[([%d]+)%].([%a%d_]+)")
        local field, index, sfield = func()
        if not field or not index then
            local func2 = sgmatch(key, "([%a%d_]+)%[([%d]+)%]")
            field, index, sfield = func2()
        end
        if not field or not index then
            rec[info[1]] = info[2]
            goto continue
        end
        if not merge[field] then
            merge[field] = {}
        end
        index = conv_integer(index)
        if sfield then
            if not merge[field][index] then
                merge[field][index] = {}
            end
            merge[field][index][sfield] = value
        else
            merge[field][index] = value
        end
        :: continue ::
    end
    for key, value in pairs(merge) do
        rec[key] = value
    end
    return rec
end

--构建数据记录
local function build_records(records)
    local result = {}
    for _, rec in pairs(records) do
        if #rec > 0 then
            tinsert(result, merge_record(rec))
        end
    end
    return result
end

--导出到lua
--使用configmgr结构
local function export_records_to_conf(output, title, fname, records)
    local table_name = sformat("%s_cfg", title)
    local filename = lappend(output, lconcat(table_name, ".lua"))
    local export_file = iopen(filename, "w")
    if not export_file then
        print(sformat("open output file %s failed!", filename))
        return
    end
    local lines = {}
    tinsert(lines, sformat("--%s.lua", table_name))
    tinsert(lines, sformat("--source: %s", fname))
    tinsert(lines, "--luacheck: ignore 631\n")
    tinsert(lines, '--获取配置表\nlocal config_mgr = quanta.get("config_mgr")')
    tinsert(lines, sformat('local %s = config_mgr:get_table("%s")\n', title, title))

    tinsert(lines, "--导出配置内容")
    for _, rec in pairs(records) do
        tinsert(lines, sformat("%s:upsert(%s)\n", title, serialize(rec, 1, mapsort)))
    end
    tinsert(lines, sformat("%s:update()\n", title))
    export_file:write(tconcat(lines, "\n"))
    export_file:close()
end

--导出到lua
--使用luatable
local function export_records_to_lua(output, title, fname, records)
    local table_name = sformat("%s_cfg", title)
    local filename = lappend(output, lconcat(table_name, ".lua"))
    local export_file = iopen(filename, "w")
    if not export_file then
        print(sformat("open output file %s failed!", filename))
        return
    end
    local lines = {}
    tinsert(lines, sformat("--%s.lua", table_name))
    tinsert(lines, sformat("--source: %s", fname))
    tinsert(lines, "--luacheck: ignore 631\n")
    tinsert(lines, "--导出配置内容")
    tinsert(lines, sformat('local %s = %s', title, serialize(records, 1, mapsort)))
    tinsert(lines, sformat('\n\nreturn %s\n', title))

    local output_data = tconcat(lines, "\n")
    export_file:write(output_data)
    export_file:close()
end

--导出到json
local function export_records_to_json(output, title, fname, records)
    local table_name = sformat("%s_cfg", title)
    local filename = lappend(output, lconcat(table_name, ".json"))
    local export_file = iopen(filename, "w")
    if not export_file then
        print(sformat("open output file %s failed!", filename))
        return
    end
    export_file:write(jpretty(records, 1))
    export_file:close()
end

local function find_workbook_data_struct(book)
    local headers = {}
    local field_types = {}
    if not head_line then
        head_line = start_line - 1
    end
    for col = 1, book.last_col do
        -- 读取第四行作为表头
        headers[col] = get_cell_value(book, head_line, col)
        -- 读取类型行，作为筛选条件
        local field_type = get_cell_value(book, type_line, col)
        if field_type and field_type ~= "" then
            field_types[col] = field_type
        end
    end
    return headers, field_types
end

--导出到目标文件
local function export_workbook_to_output(book, output, fname, bookname)
    local headers, field_types = find_workbook_data_struct(book)
    if tsize(field_types) <= 1 then
        --未定义数据定义，不导出此book
        print(sformat("export config %s workbook %s not need export!", fname, bookname))
        return
    end
    -- 开始处理
    local records = {}
    for row = start_line, book.last_row do
        local record = {}
        -- 遍历每一列
        for col = start_col, book.last_col do
            -- 过滤掉没有配置的行
            if field_types[col] and headers[col] then
                local value = get_cell_value(book, row, col, field_types[col], headers[col])
                if value ~= nil then
                    tinsert(record, {headers[col], value, field_types[col]})
                end
            end
        end
        tinsert(records, record)
    end
    local title = allbook and bookname or slower(lstem(fname))
    export_method(output, title, fname, build_records(records))
    print(sformat("export file: %s book: %s to %s success!", fname, bookname, title))
end

local function is_config_file(ext)
    return ext == ".xlsx" or ext == ".xlsm" or ext == ".csv"
end

local function load_workbook(ext, filename)
    if ext == ".xlsx" or ext == ".xlsm" then
        return xlsx.open(filename)
    end
    if ext == ".csv" then
        return csv.open(filename)
    end
end

--入口函数
local function export_config(input, output)
    print("export_config:", input, output)
    local files = ldir(input)
    if files == 0 then
        error(sformat("input dir: %s not exist!", input))
    end
    for _, file in pairs(files or {}) do
        local fullname = file.name
        if file.type == "directory" then
            if fullname == output then
                goto continue
            end
            if not recursion then
                goto continue
            end
            local fname = lfilename(fullname)
            local soutput = lappend(output, fname)
            lmkdir(soutput)
            export_config(fullname, soutput)
            goto continue
        end
        local ext = lextension(fullname)
        if is_config_file(ext) then
            local fname = lfilename(fullname)
            local workbook = load_workbook(ext, fullname)
            if not workbook then
                print(sformat("open config %s failed!", fullname))
                goto continue
            end
            local workbooks = workbook.workbooks()
            for _, book in ipairs(workbooks) do
                local bookname = slower(book.name)
                if book.last_row < start_line or book.last_col <= 0 then
                    print(sformat("export config %s book %s empty!", fullname, bookname))
                    goto next
                end
                export_workbook_to_output(book, output, fname, bookname)
                if not allbook then
                    break
                end
                :: next ::
            end
        end
        :: continue ::
    end
end

local format_methods = {
    ["lua"] = export_records_to_lua,
    ["json"] = export_records_to_json,
}

--检查配置
local function read_cmdline()
    local input = lcurdir()
    local output = lcurdir()
    local env_input = qgetenv("QUANTA_INPUT")
    if not env_input or #env_input == 0 then
        print("input dir not config!")
        input = input
    else
        input = lappend(input, env_input)
    end
    local env_output = qgetenv("QUANTA_OUTPUT")
    if not env_output or #env_output == 0 then
        print("output dir not config!")
        output = output
    else
        output = lappend(output, env_output)
        lmkdir(output)
    end
    local env_typline = qgetenv("QUANTA_TYPLINE")
    if env_typline then
        type_line = mtointeger(env_typline)
    end
    local env_staline = qgetenv("QUANTA_STALINE")
    if env_staline then
        start_line = mtointeger(env_staline)
    end
    local env_stacol = qgetenv("QUANTA_STACOL")
    if env_stacol then
        start_col = mtointeger(env_stacol)
    end
    local env_headline = qgetenv("QUANTA_HEADLINE")
    if env_headline then
        head_line = mtointeger(env_headline)
    end
    local env_recursion = qgetenv("QUANTA_RECURSION")
    if env_recursion then
        recursion = mtointeger(env_recursion)
    end
    local env_allbook = qgetenv("QUANTA_ALLSHEET")
    if env_allbook then
        allbook = mtointeger(env_allbook)
    end
    local format = qgetenv("QUANTA_FORMAT")
    export_method = format_methods[format] or export_records_to_conf
    return input, output
end

print("useage: quanta.exe [--entry=convertor] [--input=xxx] [--output=xxx]")
print("begin export configs to lua!")
local input, output = read_cmdline()
local ok, err = pcall(export_config, input, output)
if not ok then
    print("export config to lua failed:", err)
    return
end
print("success export configs to lua!")
