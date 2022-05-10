# luaxlsx
一个使用lua解析excel的xlsx/xlsm格式的库。

# 依赖
- miniz (已经包含在库内)
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--luaxlsx

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f luaxlsx.mak

# 用法
```lua
local lexcel = require('luaxlsx')

local workbook = lexcel.open(full_name)
if not workbook then
    rint(sformat("open excel %s failed!", file))
    return
end
--只导出sheet1
local sheets = workbook:sheets()
local sheet = sheets and sheets[1]
--sheet dim
local dim = sheet:dimension()
--sheet_name
local sheet_name = sheet:name()
for row = dim.firstRow, dim.lastRow do
    for col = dim.firstCol, dim.lastCol do
        local cell = sheet:cell(row, col)
        print(cell.type, cell.value)
    end
end
```
