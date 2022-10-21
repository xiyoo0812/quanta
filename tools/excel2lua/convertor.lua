--convertor.lua
local lcrypt    = require('lcrypt')
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
local lmd5          = lcrypt.md5
local sfind         = string.find
local sgsub         = string.gsub
local sformat       = string.format
local tconcat       = table.concat
local tunpack       = table.unpack
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

--28800 => 3600 * 8
--86400 => 3600 * 24
--25569 => 1970.1.1 0:0:0
--根据fmtCode和fmtId解析自定义格式
local function cell_value_fmt_parse(cell)
    if cell.type == "date" then
        if cell.fmtId == 14 then
            return 86400 * (cell.value - 25569) - 28800
        end
    elseif cell.type == "custom" then
        if sfind(cell.fmtCode, "yy") then
            return 86400 * (cell.value - 25569) - 28800
        end
        if sfind(cell.fmtCode, "mm:ss") then
            return 86400 * cell.value
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
    ["array"] = function(value)
        value = slower(value)
        if sfind(value, '[(]') then
            -- 替换'('&')' 为 '{' & '}'
            return sgsub(value, '[(.*)]', function (s)
                return s == '(' and '{' or '}'
            end)
        else
            return '{' .. value .. '}'
        end
    end,
}

--获取cell value
local function get_sheet_value(sheet, row, col, field_type, header)
    local cell = sheet:cell(row, col)
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
    lines[#lines + 1] = sformat("--%s.lua", table_name)
    lines[#lines + 1] = "--luacheck: ignore 631\n"
    lines[#lines + 1] = '--获取配置表\nlocal config_mgr = quanta.get("config_mgr")'
    lines[#lines + 1] = sformat('local %s = config_mgr:get_table("%s")\n', title, title)

    lines[#lines + 1] = "--导出配置内容"
    for _, record in pairs(records) do
        for index, info in ipairs(record) do
            local key, value, ftype = tunpack(info)
            if index == 1 then
                lines[#lines + 1] = sformat("%s:upsert({", title)
            end
            if type(value) == "string" and ftype ~= "array" then
                value = "'" .. value .. "'"
                value = sgsub(value, "\n", "\\n")
            end
            lines[#lines + 1] = sformat("    %s = %s,", key, tostring(value))
        end
        lines[#lines + 1] = "})\n"
    end

    local output_data = tconcat(lines, "\n")
    export_file:write(sformat("%s\n--general md5 version\n", output_data))
    export_file:write(sformat("%s:set_version('%s')", title, lmd5(output_data, 1)))
    export_file:close()
    print(sformat("export %s success!", filename))
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
    lines[#lines + 1] = sformat("--%s.lua", table_name)
    lines[#lines + 1] = "--luacheck: ignore 631\n"

    lines[#lines + 1] = "--导出配置内容"
    lines[#lines + 1] = sformat('local %s = {', title)
    for _, record in pairs(records) do
        for index, info in ipairs(record) do
            local key, value, ftype = tunpack(info)
            if index == 1 then
                lines[#lines + 1] =  "    {"
            end
            if type(value) == "string" and ftype ~= "array" then
                value = "'" .. value .. "'"
                value = sgsub(value, "\n", "\\n")
            end
            lines[#lines + 1] = sformat("        %s = %s,", key, tostring(value))
        end
        lines[#lines + 1] = "    },"
    end
    lines[#lines + 1] = sformat('}\n\nreturn %s\n', title)

    local output_data = tconcat(lines, "\n")
    export_file:write(output_data)
    export_file:close()
    print(sformat("export %s success!", filename))
end

--导出到lua table
local function export_sheet_to_table(sheet, output, title, dim)
    local header     = {}
    local field_type = {}
    for col = dim.firstCol, dim.lastCol do
        -- 读取类型行，作为筛选条件
        field_type[col] = get_sheet_value(sheet, type_line, col)
        -- 读取第四行作为表头
        header[col] = get_sheet_value(sheet, 4, col)
    end
    --定位起始行
    local end_line = dim.lastRow
    for row = start_line, end_line do
        local start_tag = get_sheet_value(sheet, row, 1)
        if start_tag and start_tag == "Start" then
            start_line = row
            break
        end
    end
    for row = start_line, end_line do
        local end_tag = get_sheet_value(sheet, row, 1)
        if end_tag and end_tag == "End" then
            end_line = row
            break
        end
    end
    -- 开始处理
    local records = {}
    for row = start_line, end_line do
        local record = {}
        -- 遍历每一列
        for col = 2, dim.lastCol do
            -- 过滤掉没有配置的行
            local ftype = field_type[col]
            if ftype then
                local value = get_sheet_value(sheet, row, col, ftype, header[col])
                if value ~= nil then
                    record[#record + 1] = {header[col], value, ftype}
                end
            end
        end
        if #record > 0 then
            records[#records + 1] = record
        end
    end
    export_method(output, title, records)
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
            --只导出sheet1
            local sheets = workbook:sheets()
            for _, sheet in pairs(sheets) do
                local dim = sheet:dimension()
                local sheet_name = sheet:name()
                if dim.lastRow < 4 or dim.lastCol <= 0 then
                    print(sformat("export excel %s sheet %s empty!", file, sheet_name))
                else
                    local title = slower(sheet_name)
                    export_sheet_to_table(sheet, output, title, dim)
                end
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
