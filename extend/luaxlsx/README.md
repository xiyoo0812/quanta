# luaxlsx
一个使用lua解析excel的xlsx/xlsm格式的库。

# 依赖
- miniz (已经包含在库内)
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [luakit](https://github.com/xiyoo0812/luakit.git)一个luabind库
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--luaxlsx <br>
  &emsp;|--luakit

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f luaxlsx.mak

# 注意事项
- mimalloc: 参考[quanta](https://github.com/xiyoo0812/quanta.git)使用，不用则在工程文件中注释

# 用法
```lua
local lexcel = require("luaxlsx")

local workbook = lexcel.open(full_name)
if not workbook then
    rint(sformat("open excel %s failed!", file))
    return
end
--只导出sheet1
local sheets = workbook.sheets()
local sheet = sheets and sheets[1]

--sheet_name
local sheet_name = sheet.name
for row = dim.first_row_, dim.last_row_ do
    for col = dim.first_col_, dim.last_col_ do
        local cell = sheet.get_cell(row, col)
        print(cell.type, cell.value)
    end
end
```
