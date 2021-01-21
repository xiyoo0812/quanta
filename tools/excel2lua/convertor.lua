--convertor.lua
local lfs    = require('lfs')
local lexcel = require('luaxlsx')

local type          = type
local pairs         = pairs
local tostring      = tostring
local iopen         = io.open
local ogetenv       = os.getenv
local otime         = os.time
local ldir          = lfs.dir
local lmkdir        = lfs.mkdir
local lcurdir       = lfs.currentdir
local lattributes   = lfs.attributes
local ssub          = string.sub
local sfind         = string.find
local sgsub         = string.gsub
local sformat       = string.format
local smatch        = string.match
local tconcat       = table.concat
local tinsert       = table.insert
local tunpack       = table.unpack
local mtointeger    = math.tointeger
local slower        = string.lower

local slash         = "/"
local version       = 10000

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
    slash = "\\"
end

local function tointeger(v)
    local iv = mtointeger(v)
    return iv or v
end

local value_func = {
    ["int"] = tointeger,
    ["byte"] = tointeger,
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
local function get_sheet_value(sheet, row, col, field_type)
    local cell = sheet:cell(row, col)
    if cell and cell.type ~= "blank" then
        if field_type then
            local func = value_func[field_type]
            if func then
                return func(cell.value)
            end
        end

        local year, month, day, hour, min, sec = smatch(cell.value, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if year and month and day and hour and min and sec then
            return otime({day = day,month = month,year = year, hour = hour, min = min, sec = sec})
        end
        return cell.value
    end
end

--导出到lua
local function export_records_to_lua(output, title, records)
    local table_name = sformat("%s_cfg", title)
    local filename = sformat("%s%s%s.lua", output, slash, table_name)

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
    tinsert(lines, sformat("--导出版本号\n%s:set_version(%s)\n", title, version))

    tinsert(lines, "--导出配置内容")
    for _, record in pairs(records) do
        for index, info in ipairs(record) do
            local key, value, ftype = tunpack(info)
            if index == 1 then
                tinsert(lines, sformat("%s:upsert({", title))
            end
            if type(value) == "string" and ftype ~= "array" then
                value = "'" .. value .. "'"
                value = sgsub(value, "\n", "\\n")
            end
            tinsert(lines, sformat("    %s = %s,", key, tostring(value)))
        end
        tinsert(lines, "})\n")
    end

    local output_data = tconcat(lines, "\n")
    export_file:write(output_data)
    export_file:close()
    print(sformat("export %s success!", filename))
end

--指定导出函数
local export_method = export_records_to_lua

--导出到lua table
local function export_sheet_to_table(sheet, output, title, dim)
    local header     = {}
    local field_type = {}
    for col = dim.firstCol, dim.lastCol do
        -- 读取第二行服务器类型列，作为服务器筛选条件
        field_type[col] = get_sheet_value(sheet, 2, col)
        -- 读取第四行作为表头
        header[col] = get_sheet_value(sheet, 4, col)
    end
    local records = {}
    local search_tag = true
    -- 从第五行开始处理
    for row = 5, dim.lastRow do
        local record = {}
        -- 搜索开始标记
        if search_tag then
            local start_tag = get_sheet_value(sheet, row, 1)
            if not start_tag or start_tag ~= "Start" then
                goto continue
            end
            search_tag = false
        end
        -- 遍历每一列
        for col = 2, dim.lastCol do
            -- 过滤掉没有配置的行
            local ftype = field_type[col]
            if ftype then
                local value = get_sheet_value(sheet, row, col, ftype)
                if value ~= nil then
                    tinsert(record, {header[col], value, ftype})
                end
            end
        end
        if #record > 0 then
            tinsert(records, record)
        end
        local end_tag = get_sheet_value(sheet, row, 1)
        if end_tag and end_tag == "End" then
            break
        end
        :: continue ::
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
    for file in ldir(input) do
        if file == "." or file == ".." then
            goto continue
        end
        local full_name = input .. slash .. file
        local attr = lattributes(full_name)
        if attr.mode == "directory" then
            local soutput = output .. slash .. file
            lmkdir(soutput)
            export_excel(full_name, soutput)
            goto continue
        end
        if is_excel_file(file) then
            local workbook = lexcel.open(full_name)
            if not workbook then
                print(sformat("open excel %s failed!", file))
                goto continue
            end
            --只导出sheet1
            local sheets = workbook:sheets()
            local sheet = sheets and sheets[1]
            if not sheet then
                print(sformat("export excel %s open sheet %d failed!", file, 0))
                break
            end
            local dim = sheet:dimension()
            local sheet_name = sheet:name()
            if dim.lastRow < 4 or dim.lastCol <= 0 then
                print(sformat("export excel %s sheet %s empty!", file, sheet_name))
                break
            end
            local title = slower(sheet_name)
            export_sheet_to_table(sheet, output, title, dim)
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
        input = input .. slash .. env_input
    end
    local env_output = ogetenv("QUANTA_OUTPUT")
    if not env_output or #env_output == 0 then
        print("output dir not config!")
        output = output
    else
        output = output .. slash .. env_output
        lmkdir(output)
    end
    local env_output = ogetenv("QUANTA_OUTPUT")
    if env_version then
        version = tointeger(env_version)
    end
    return input, output
end

print("useage: quanta.exe [--input=xxx] [--output=xxx]")
print("begin export excels to lua!")
local input, output = export_config()
local ok, err = pcall(export_excel, input, output)
if not ok then
    print("export excel to lua failed:", err)
end
print("success export excels to lua!")
