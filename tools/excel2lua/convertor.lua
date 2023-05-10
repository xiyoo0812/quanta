--convertor.lua
local lstdfs    = require('lstdfs')
local lexcel    = require('luaxlsx')

local type          = type
local pairs         = pairs
local tostring      = tostring
local iopen         = io.open
local ldir          = lstdfs.dir
local lmkdir        = lstdfs.mkdir
local lappend       = lstdfs.append
local lconcat       = lstdfs.concat
local lfilename     = lstdfs.filename
local lcurdir       = lstdfs.current_path
local sfind         = string.find
local sgsub         = string.gsub
local sformat       = string.format
local sgmatch       = string.gmatch
local tsort         = table.sort
local tconcat       = table.concat
local tunpack       = table.unpack
local tinsert       = table.insert
local mfloor        = math.floor
local mtointeger    = math.tointeger
local slower        = string.lower
local ogetenv       = os.getenv

--指定导出函数
local export_method = nil
--类型定义行，默认2
local type_line     = 2
--配置起始行，默认5
local start_line    = 5

--设置utf8
if quanta.platform == "linux" then
    local locale = os.setlocale("C.UTF-8")
    if not locale then
        print("switch utf8 mode failed!")
    end
else
    local locale = os.setlocale(".UTF8")
    if not locale then
        print("switch utf8 mode failed!")
    end
end

local function conv_integer(v)
    return mtointeger(v) or v
end

local function conv_number(v)
    return mtointeger(v) or tonumber(v) or v
end

local function tsize(t)
    local c = 0
    for _ in pairs(t or {}) do
        c = c + 1
    end
    return c
end

--28800 => 3600 * 8
--86400 => 3600 * 24
--25569 => 1970.1.1 0:0:0
--根据fmt_code和fmt_id解析自定义格式
local function cell_value_fmt_parse(cell)
    if cell.type == "date" then
        return mfloor(86400 * (cell.value - 25569) - 28800)
    elseif cell.type == "custom" then
        if sfind(cell.fmt_code, "yy") then
            return mfloor(86400 * (cell.value - 25569) - 28800)
        end
        if sfind(cell.fmt_code, "mm:ss") then
            return mfloor(86400 * cell.value)
        end
    end
end

local value_func = {
    ["int"] = conv_number,
    ["float"] = conv_number,
    ["byte"] = conv_integer,
    ["bool"] = function(value)
        return value == "1"
    end,
    ["string"] = function(value)
        value = "'" .. value .. "'"
        return sgsub(value, "\n", "\\n")
    end,
    ["map"] = function(value)
        value = sgsub(value, '|', ']=')
        value = sgsub(value, ',', ',[')
        return '{[' .. value .. '}'
    end,
    ["smap"] = function(value)
        value = sgsub(value, '|', '=')
        return '{' .. value .. '}'
    end,
    ["array"] = function(value)
        value = sgsub(value, '|', ',')
        if sfind(value, '[(]') then
            -- 替换'('&')' 为 '{' & '}'
            return sgsub(value, '[(.*)]', function (s)
                return s == '(' and '{' or '}'
            end)
        end
        if sfind(value, '[{]') then
            return value
        end
        return '{' .. value .. '}'
    end,
    ["sarray"] = function(value)
        value = sgsub(value, '|', ',')
        value = sgsub(value, ',', "','")
        if sfind(value, '[(]') then
            -- 替换'('&')' 为 '{' & '}'
            return sgsub(value, '[(.*)]', function (s)
                return s == '(' and "{'" or "'}"
            end)
        end
        if sfind(value, '[{]') then
            return sgsub(value, '[{.*}]', function (s)
                return s == '{' and "{'" or "'}"
            end)
        end
        return "{'" .. value .. "'}"
    end,
}

--获取cell value
local function get_sheet_value(sheet, row, col, field_type, header)
    local cell = sheet.get_cell(row, col)
    if cell and cell.type ~= "blank" then
        local value = cell.value
        local fvalue = cell_value_fmt_parse(cell)
        if fvalue then
            value = fvalue
        end
        if field_type then
            local func = value_func[field_type]
            if func then
                return func(value)
            end
        end
        return value
    end
end

local function mapsort(src)
    local dst = {}
    for key, value in pairs(src or {}) do
        tinsert(dst, { key, value })
    end
    tsort(dst, function(a, b) return a[1] < b[1] end)
    return dst
end

--格式化Table
local function serialize(tab, prefix)
    local function table2str(t, lines, tprefix)
        local tt = mapsort(t)
        for _, info in pairs(tt) do
            local k, v = tunpack(info)
            if type(v) == "table" then
                tinsert(lines, sformat("%s[%s] = {\n", tprefix, k))
                table2str(v, lines, tprefix .. "    ")
                tinsert(lines, sformat("%s},\n", tprefix))
            else
                local key = mtointeger(k)
                if key then
                    tinsert(lines, sformat("%s[%s] = %s,\n", tprefix, key, v))
                else
                    tinsert(lines, sformat("%s%s = %s,\n", tprefix, k, v))
                end
            end
        end
    end
    local lines = {"{\n"}
    table2str(tab, lines, prefix .. "    ")
    tinsert(lines, prefix .. "}")
    return tconcat(lines)
end

-- 合并记录
local function merge_record(record, prefix)
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
            tinsert(rec, info)
            goto continue
        end
        if not merge[field] then
            merge[field] = {}
        end
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
        tinsert(rec, { key, serialize(value, prefix), "struct" })
    end
    return rec
end

--导出到lua
--使用configmgr结构
local function export_records_to_struct(output, title, records)
    local table_name = sformat("%s_cfg", title)
    local filename = lappend(output, lconcat(table_name, ".lua"))
    local export_file = iopen(filename, "w")
    if not export_file then
        print(sformat("open output file %s failed!", filename))
        return
    end
    local lines = {}
    tinsert(lines, sformat("--%s.lua", table_name))
    tinsert(lines, "--luacheck: ignore 631\n")
    tinsert(lines, '--获取配置表\nlocal config_mgr = quanta.get("config_mgr")')
    tinsert(lines, sformat('local %s = config_mgr:get_table("%s")\n', title, title))

    tinsert(lines, "--导出配置内容")
    for _, rec in pairs(records) do
        if #rec > 0 then
            local record = merge_record(rec, "    ")
            for index, info in ipairs(record) do
                local key, value = tunpack(info)
                if index == 1 then
                    tinsert(lines, sformat("%s:upsert({", title))
                end
                tinsert(lines, sformat("    %s = %s,", key, tostring(value)))
            end
            tinsert(lines, "})\n")
        end
    end
    tinsert(lines, sformat("%s:update()\n", title))
    export_file:write(tconcat(lines, "\n"))
    export_file:close()
end

--导出到lua
--使用luatable
local function export_records_to_table(output, title, records)
    local table_name = sformat("%s_cfg", title)
    local filename = lappend(output, lconcat(table_name, ".lua"))
    local export_file = iopen(filename, "w")
    if not export_file then
        print(sformat("open output file %s failed!", filename))
        return
    end
    local lines = {}
    tinsert(lines, sformat("--%s.lua", table_name))
    tinsert(lines, "--luacheck: ignore 631\n")

    tinsert(lines, "--导出配置内容")
    tinsert(lines, sformat('local %s = {', title))
    for _, rec in pairs(records) do
        if #rec > 0 then
            local record = merge_record(rec, "        ")
            for index, info in ipairs(record) do
                local key, value = tunpack(info)
                if index == 1 then
                    tinsert(lines,  "    {")
                end
                tinsert(lines, sformat("        %s = %s,", key, tostring(value)))
            end
            tinsert(lines, "    },")
        end
    end
    tinsert(lines, sformat('}\n\nreturn %s\n', title))

    local output_data = tconcat(lines, "\n")
    export_file:write(output_data)
    export_file:close()
end

local function find_sheet_data_struct(sheet)
    local header = {}
    local field_type = {}
    local head_line = start_line - 1
    for col = sheet.first_col, sheet.last_col do
        -- 读取类型行，作为筛选条件
        field_type[col] = get_sheet_value(sheet, type_line, col)
        -- 读取第四行作为表头
        header[col] = get_sheet_value(sheet, head_line, col)
    end
    return header, field_type
end

--导出到lua table
local function export_sheet_to_table(sheet, output, fullname, title)
    local header, field_type = find_sheet_data_struct(sheet)
    if tsize(field_type) == 1 then
        --未定义数据定义，不导出此sheet
        print(sformat("export excel %s sheet %s not need export!", fullname, title))
        return
    end
    --定位起始行
    local read_len = start_line
    local end_line = sheet.last_row
    for row = read_len, end_line do
        local start_tag = get_sheet_value(sheet, row, 1)
        if start_tag == "Start" then
            read_len = row
            break
        end
    end
    for row = read_len, end_line do
        local end_tag = get_sheet_value(sheet, row, 1)
        local fkey = get_sheet_value(sheet, row, 2)
        if end_tag == "End" or not fkey or fkey == "" then
            end_line = row
            break
        end
    end
    -- 开始处理
    local records = {}
    for row = read_len, end_line do
        local record = {}
        -- 遍历每一列
        for col = 2, sheet.last_col do
            -- 过滤掉没有配置的行
            if field_type[col] and header[col] then
                local value = get_sheet_value(sheet, row, col, field_type[col], header[col])
                if value ~= nil then
                    tinsert(record, {header[col], value, field_type[col]})
                end
            end
        end
        tinsert(records, record)
    end
    export_method(output, title, records)
    print(sformat("export file: %s sheet: %s success!", fullname, title))
end

local function is_excel_file(file)
    if sfind(file, "~") then
        return false
    end
    local pos = sfind(file, "%.xlsm")
    if pos then
        return true
    end
    pos = sfind(file, "%.xlsx")
    if pos then
        return true
    end
    return false
end

--入口函数
local function export_excel(input, output)
    local files = ldir(input)
    for _, file in pairs(files) do
        local fullname = file.name
        if file.type == "directory" then
            if fullname == output then
                goto continue
            end
            local fname = lfilename(fullname)
            local soutput = lappend(output, fname)
            lmkdir(soutput)
            export_excel(fullname, soutput)
            goto continue
        end
        if is_excel_file(fullname) then
            local workbook = lexcel.open(fullname)
            if not workbook then
                print(sformat("open excel %s failed!", fullname))
                goto continue
            end
            local sheets = workbook.sheets()
            for _, sheet in pairs(sheets) do
                local title = slower(sheet.name)
                if title == "remarks" then
                    print(sformat("export excel %s sheet %s is remarks!", fullname, title))
                    goto next
                end
                if sheet.last_row < 4 or sheet.last_col <= 0 then
                    print(sformat("export excel %s sheet %s empty!", fullname, title))
                    goto next
                end
                export_sheet_to_table(sheet, output, fullname, title)
                :: next ::
            end
        end
        :: continue ::
    end
end

--检查配置
local function export_config()
    local input = lcurdir()
    local output = lcurdir()
    local env_input = ogetenv("QUANTA_INPUT")
    if not env_input or #env_input == 0 then
        print("input dir not config!")
        input = input
    else
        input = lappend(input, env_input)
    end
    local env_output = ogetenv("QUANTA_OUTPUT")
    if not env_output or #env_output == 0 then
        print("output dir not config!")
        output = output
    else
        output = lappend(output, env_output)
        lmkdir(output)
    end
    local env_typline = ogetenv("QUANTA_TYPLINE")
    if env_typline then
        type_line = mtointeger(env_typline)
    end
    local env_staline = ogetenv("QUANTA_STALINE")
    if env_staline then
        start_line = mtointeger(env_staline)
    end
    local env_format = ogetenv("QUANTA_FORMAT")
    export_method = export_records_to_struct
    if env_format and env_format == "table" then
        export_method = export_records_to_table
    end
    return input, output
end

print("useage: quanta.exe [--entry=convertor] [--input=xxx] [--output=xxx]")
print("begin export excels to lua!")
local input, output = export_config()
local ok, err = pcall(export_excel, input, output)
if not ok then
    print("export excel to lua failed:", err)
end
print("success export excels to lua!")
