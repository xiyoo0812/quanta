-- stdfs_test.lua
local sformat    = string.format

local ROOT       = "quanta_stdfs_test"
local TMP        = stdfs.temp_dir()

local TestCase = import("test/case.lua")
local StdfsTest = class(TestCase)

local function temp_path(...)
    local p = stdfs.append(TMP, ROOT)
    for _, part in ipairs({ ... }) do
        p = stdfs.append(p, part)
    end
    return p
end

function StdfsTest:setup()
    --确保干净起点: 若上次残留则先清掉
    if stdfs.exists(temp_path()) then
        stdfs.remove(temp_path(), true)
    end
    stdfs.mkdir(temp_path())
end

function StdfsTest:teardown()
    if stdfs.exists(temp_path()) then
        stdfs.remove(temp_path(), true)
    end
end

function StdfsTest:run()
    ------------------------------------------------------------------
    --1. 路径解析: root_name/root_path/parent_path/filename/stem/extension
    ------------------------------------------------------------------
    local abs = temp_path("a", "b", "file.txt")
    self:report("filename file.txt", stdfs.filename(abs) == "file.txt", stdfs.filename(abs), "file.txt")
    self:report("extension .txt", stdfs.extension(abs) == ".txt", stdfs.extension(abs), ".txt")
    self:report("stem file", stdfs.stem(abs) == "file", stdfs.stem(abs), "file")
    self:report("parent path ends with b", tostring(stdfs.parent_path(abs)):match("b$") ~= nil, stdfs.parent_path(abs), ".../b")
    self:report("root_name non-empty", stdfs.root_name(abs) ~= "", stdfs.root_name(abs), "non-empty")

    ------------------------------------------------------------------
    --2. 路径判定: is_absolute/is_directory/filetype/exists
    ------------------------------------------------------------------
    self:report("is_absolute true", stdfs.is_absolute(abs) == true, stdfs.is_absolute(abs), "true")
    self:report("is_absolute false", stdfs.is_absolute("a/b/c") == false, stdfs.is_absolute("a/b/c"), "false")
    self:report("is_directory(temp root)", stdfs.is_directory(temp_path()) == true, temp_path(), "true")
    self:report("filetype directory", stdfs.filetype(temp_path()) == "directory", stdfs.filetype(temp_path()), "directory")
    self:report("exists temp root", stdfs.exists(temp_path()) == true, true, "true")
    self:report("exists missing", stdfs.exists(temp_path("nope")) == false, false, "false")

    ------------------------------------------------------------------
    --3. 路径拼接/替换: append/concat/remove_filename/replace_filename/replace_extension
    ------------------------------------------------------------------
    self:report("append", tostring(stdfs.append("a", "b")):match("b$") ~= nil, stdfs.append("a", "b"), ".../b")
    self:report("concat", stdfs.concat("ab", "cd") == "abcd", stdfs.concat("ab", "cd"), "abcd")
    --C++ std::filesystem::remove_filename() 保留尾部分隔符, 返回 "a/b/"
    self:report("remove_filename", stdfs.remove_filename("a/b/c.txt") == "a/b/",
        stdfs.remove_filename("a/b/c.txt"), "a/b/")
    self:report("replace_filename", stdfs.replace_filename("a/b/c.txt", "d.log") == "a/b/d.log",
        stdfs.replace_filename("a/b/c.txt", "d.log"), "a/b/d.log")
    self:report("replace_extension", stdfs.replace_extension("a/b/c.txt", "log") == "a/b/c.log",
        stdfs.replace_extension("a/b/c.txt", "log"), "a/b/c.log")
    self:report("split non-empty", #stdfs.split("a/b/c") >= 1, stdfs.split("a/b/c"), ">=1")

    ------------------------------------------------------------------
    --4. 目录创建/遍历/删除
    ------------------------------------------------------------------
    local ok, err = stdfs.mkdir(temp_path("x", "y", "z"))
    self:report("mkdir nested", ok == true, err, "ok")
    self:report("exists nested", stdfs.exists(temp_path("x", "y", "z")) == true, true, "true")
    local dirs = stdfs.dir(temp_path())
    local found_x = false
    for _, entry in pairs(dirs or {}) do
        --entry.name 是完整路径(entry.path()), 取 filename 才得到目录名
        if stdfs.filename(entry.name) == "x" then found_x = true end
    end
    self:report("dir lists x", found_x, sformat("found_x={}", tostring(found_x)), "true")
    local rec = stdfs.dir(temp_path(), true)
    self:report("dir recursive", type(rec) == "table" and #rec >= 3, rec and #rec, ">=3")

    ------------------------------------------------------------------
    --5. 文件写/读/大小/复制/改名/删除(借助 io 写文件)
    ------------------------------------------------------------------
    local fpath = temp_path("note.txt")
    local f = io.open(fpath, "w")
    if f then f:write("hello stdfs"); f:close() end
    self:report("file exists", stdfs.exists(fpath) == true, true, "true")
    self:report("filetype regular", stdfs.filetype(fpath) == "regular", stdfs.filetype(fpath), "regular")
    self:report("file_size 11", stdfs.file_size(fpath) == 11, stdfs.file_size(fpath), 11)
    local wt = stdfs.last_write_time(fpath)
    self:report("last_write_time > 0", type(wt) == "number" and wt > 0, wt, ">0")

    local copied = temp_path("note_copy.txt")
    local cok, cerr = stdfs.copy_file(fpath, copied)
    self:report("copy_file", cok == true, cerr, "ok")
    self:report("copy exists", stdfs.exists(copied) == true, true, "true")

    local renamed = temp_path("note_renamed.txt")
    local rok, rerr = stdfs.rename(copied, renamed)
    self:report("rename", rok == true, rerr, "ok")
    self:report("rename takes effect", stdfs.exists(renamed) == true and stdfs.exists(copied) == false, true, "true")

    local rbok = stdfs.remove(renamed)
    self:report("remove file", rbok == true, rbok, "true")
    self:report("remove takes effect", stdfs.exists(renamed) == false, true, "true")

    ------------------------------------------------------------------
    --6. chdir / current_path(测试后恢复原目录)
    ------------------------------------------------------------------
    local origin = stdfs.current_path()
    local cdk, cde = stdfs.chdir(temp_path())
    self:report("chdir", cdk == true, cde, "ok")
    self:report("current_path changed", stdfs.current_path() == temp_path(), stdfs.current_path(), temp_path())
    stdfs.chdir(origin)
    self:report("chdir restored", stdfs.current_path() == origin, stdfs.current_path(), origin)

    ------------------------------------------------------------------
    --7. temp_dir / make_preferred / relative/relative_path
    ------------------------------------------------------------------
    self:report("temp_dir non-empty", type(TMP) == "string" and #TMP > 0, TMP, "non-empty")
    self:report("make_preferred", type(stdfs.make_preferred("a/b")) == "string", stdfs.make_preferred("a/b"), "string")
    self:report("relative_path", type(stdfs.relative_path("/a/b")) == "string", stdfs.relative_path("/a/b"), "string")
end

return StdfsTest
