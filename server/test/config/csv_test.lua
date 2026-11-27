-- csv_test.lua
local csv       = require("luacsv")

local CSV_DATA  = [[
name,value,note
alice,10,first
bob,20,second
carol,30,third
]]

local TestCase  = import("test/case.lua")
local CsvTest   = class(TestCase)

function CsvTest:__init(name, addr, cleanup)
    self.temp_dir = "quanta_csv_test"
end
function CsvTest:setup()
    self:prepare_temp()
end

function CsvTest:on_cleanup()
    self:cleanup_temp()
end

function CsvTest:run()
    ------------------------------------------------------------------
    --1. decode: 无 key 返回数组, 每行是 {列名=值} 的 map; 数字列自动转 number
    ------------------------------------------------------------------
    local rows = csv.decode(CSV_DATA)
    self:report("decode returns array", type(rows) == "table" and #rows == 3, #rows, 3)
    self:report("row1.name", rows[1].name == "alice", rows[1].name, "alice")
    self:report("row2.value is number", rows[2].value == 20, rows[2].value, 20)
    self:report("row3.note", rows[3].note == "third", rows[3].note, "third")

    ------------------------------------------------------------------
    --2. decode with key: 第二参数指定以第 N 列做 key (1-based)
    ------------------------------------------------------------------
    local keyed = csv.decode(CSV_DATA, 1)
    self:report("keyed by name alice", keyed.alice ~= nil and keyed.alice.value == 10,
        keyed.alice and keyed.alice.value, 10)
    self:report("keyed by name carol", keyed.carol ~= nil and keyed.carol.note == "third",
        keyed.carol and keyed.carol.note, "third")

    ------------------------------------------------------------------
    --3. encode: 往返一致性(列/行顺序不保证, 用 key 定位校验数据)
    ------------------------------------------------------------------
    --encode 后列顺序不保证(实际按 map 遍历), 只能遍历数组按 name 字段定位
    local function find_by_name(list, name)
        for _, row in ipairs(list) do
            if row.name == name then return row end
        end
    end
    local text = csv.encode(rows)
    self:report("encode is string", type(text) == "string" and #text > 0, type(text), "string")
    local back = csv.decode(text)
    self:report("roundtrip count", #back == 3, #back, 3)
    local rt_bob = find_by_name(back, "bob")
    self:report("roundtrip value", rt_bob and rt_bob.value == 20, rt_bob and rt_bob.value, 20)

    ------------------------------------------------------------------
    --4. save + read: 文件往返(同样遍历定位)
    ------------------------------------------------------------------
    local path = self:temp_path("data.csv")
    local saved = csv.save(path, rows)
    self:report("save returns true", saved == true, saved, true)
    self:report("file exists after save", stdfs.exists(path) == true, stdfs.exists(path), true)
    local loaded = csv.read(path)
    local rd_alice = find_by_name(loaded, "alice")
    self:report("read alice", rd_alice and rd_alice.note == "first",
        rd_alice and rd_alice.note, "first")
    local rd_carol = find_by_name(loaded, "carol")
    self:report("read carol value", rd_carol and rd_carol.value == 30,
        rd_carol and rd_carol.value, 30)

    ------------------------------------------------------------------
    --5. open: 返回 csv_file, workbooks 可查行列数(属性用点号, 不是方法)
    ------------------------------------------------------------------
    local file = csv.open(path)
    self:report("open returns csv_file", file ~= nil, file ~= nil, true)
    if file then
        local books = file.workbooks()   --C 对象用点号
        self:report("workbooks non-empty", type(books) == "table" and #books == 1, books and #books, 1)
        local book = books[1]
        --csv 把表头也算一行, 故 1 表头 + 3 数据 = 4 行
        self:report("last_row", book.last_row == 4, book.last_row, 4)
        self:report("last_col", book.last_col == 3, book.last_col, 3)
    end
end

return CsvTest
