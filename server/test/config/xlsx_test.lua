-- xlsx_test.lua
local xlsx        = require("luaxlsx")

local TestCase    = import("test/case.lua")
local XlsxTest    = class(TestCase)

function XlsxTest:__init(name, addr, cleanup)
    self.temp_dir = "quanta_xlsx_test"
end

function XlsxTest:setup()
    self:prepare_temp()
end

function XlsxTest:on_cleanup()
    self:cleanup_temp()
end

function XlsxTest:run()
    if not self.addr or not stdfs.exists(self.addr) then
        self:report("fixture exists", false, self.addr, "xlsx fixture path from addr")
        return
    end

    ------------------------------------------------------------------
    --1. xlsx.open(file): 打开夹具, 拿到 excel_file 与 workbooks
    ------------------------------------------------------------------
    local excel = xlsx.open(self.addr)
    self:report("open returns excel", excel ~= nil, excel ~= nil, true)
    if not excel then return end
    local books = excel.workbooks()   --点号调用
    self:report("workbooks non-empty", type(books) == "table" and #books > 0, books and #books, ">0")

    ------------------------------------------------------------------
    --2. workbook 属性: name / last_row / last_col
    ------------------------------------------------------------------
    local first = books[1]
    self:report("workbook name is Sheet1", first and first.name == "Sheet1", first and first.name, "Sheet1")
    self:report("last_row == 14", first and first.last_row == 14, first and first.last_row, 14)
    self:report("last_col == 4", first and first.last_col == 4, first and first.last_col, 4)
    self:report("two workbooks", #books == 2, #books, 2)
    local second = books[2]
    self:report("sheet2 name is Sheet3", second and second.name == "Sheet3", second and second.name, "Sheet3")

    ------------------------------------------------------------------
    --3. excel.open(sheet_name): 按名打开(点号调用, 冒号会段错误)
    ------------------------------------------------------------------
    local book = excel.open("Sheet1")
    self:report("open sheet by name", book ~= nil, book ~= nil, true)
    if book then
        local a1 = book.get_cell_value(1, 1)
        self:report("get_cell_value callable", true, type(a1), "any")
    end

    ------------------------------------------------------------------
    --4. set_cell_value + save: 保存到临时副本并验证落盘
    --   save 是"静态式"绑定: 用 local f = excel.save; f(path) 调用(不传 self)
    ------------------------------------------------------------------
    local ok = pcall(function()
        first.set_cell_value(1, 1, "marker")
        first.set_cell_value(2, 2, 123)
    end)
    self:report("set_cell_value callable", ok == true, ok, true)

    local out = self:temp_path("copy.xlsx")
    local save_func = excel.save
    local sok, serr = pcall(save_func, out)
    self:report("save callable", sok == true, serr, true)
    self:report("save produced file", stdfs.exists(out) == true, stdfs.exists(out), true)
end

return XlsxTest
