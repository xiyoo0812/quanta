--stdfs_test.lua

local log_info  = logger.info

local work_dir = stdfs.current_path()
local ltype = stdfs.filetype(work_dir)
log_info("current_path: %s, type: %s", work_dir, ltype)

local root_name = stdfs.root_name(work_dir)
local root_path = stdfs.root_path(work_dir)
log_info("root_name: %s, root_path: %s", root_name, root_path)

local parent_path = stdfs.parent_path(work_dir)
local relative_path = stdfs.relative_path(work_dir)
log_info("parent_path: %s, relative_path: %s", parent_path, relative_path)

local cur_dirs = stdfs.dir(work_dir)
for _, file in pairs(cur_dirs) do
    log_info("cur dir -> filename: %s, filetype: %s", file.name, file.type)
end

local recursive_dirs = stdfs.dir(work_dir, true)
for _, file in pairs(recursive_dirs) do
    log_info("recursive dir -> filename: %s, filetype: %s", file.name, file.type)
end

local mok, merr = stdfs.mkdir("logs/a/b/c")
log_info("mkdir -> ok: %s, err: %s", mok, merr)

local cok, cerr = stdfs.chdir("logs")
local new_dir = stdfs.current_path()
local is_dir = stdfs.is_directory(new_dir)
log_info("chdir -> ok: %s, err: %s", cok, cerr)
log_info("chdir -> new_dir: %s, is_dir: %s", new_dir, is_dir)

local absolute1 = stdfs.is_absolute(new_dir)
local absolute2 = stdfs.is_absolute(relative_path)
log_info("is_absolute -> absolute1: %s, absolute:%s", absolute1, absolute2)

local exista = stdfs.exists("a")
local existb = stdfs.exists("b")
local temp_dir = stdfs.temp_dir()
log_info("exists -> exista: %s, existb: %s, temp_dir:%s", exista, existb, temp_dir)

local splits = stdfs.split(new_dir)
for _, node in pairs(splits) do
    log_info("split dir -> node: %s", node)
end

local rok, rerr = stdfs.remove("c")
log_info("remove1 -> rok: %s, rerr: %s", rok, rerr)

local nok, nerr = stdfs.rename("a", "b")
log_info("rename -> nok:%s, nerr:%s", nok, nerr)

local rbok, rberr = stdfs.remove("b")
local raok, raerr = stdfs.remove("b", true)
log_info("remove2 -> rbok: %s, rberr: %s, raok:%s, raerr:%s", rbok, rberr, raok, raerr)

local cfok, cferr = stdfs.copy_file("test/test-2-20210820-235824.123.p11456.log", "test-2-20210820-235824.123.p11456.log")
local cfok2, cferr2 = stdfs.copy_file("test/test-2-20210821-000053.361.p7624.log", "../")
log_info("copy_file -> cfok:%s, cferr:%s, cfok2:%s, cferr2:%s", cfok, cferr, cfok2, cferr2)

local cok1, cerr1 = stdfs.copy("test", "test2")
local cok2, cerr2 = stdfs.remove("test2", true)
log_info("copy_file -> cok:%s, cerr:%s, cok2:%s, cerr2:%s", cok1, cerr1, cok2, cerr2)

local n2ok, n2err = stdfs.rename("test-2-20210820-235824.123.p11456.log", "tttt.log")
log_info("rename2 -> n2ok:%s, n2err:%s", n2ok, n2err)

local absolute = stdfs.absolute("tttt.log")
local filename = stdfs.filename(absolute)
local extension = stdfs.extension(absolute)
local stem = stdfs.stem(absolute)
log_info("info -> absolute:%s, extension:%s, filename:%s, stem:%s", absolute, extension, filename, stem)

local afile = stdfs.append(absolute, "d.log")
local apath = stdfs.append(absolute, "dc")
local afpath = stdfs.append(afile, "ff")
local concat = stdfs.concat("apath", "ff.png")
log_info("append -> afile: %s, apath: %s, afpath: %s, concat: %s", afile, apath, afpath, concat)

local time, terr = stdfs.last_write_time(absolute)
local extension2 = stdfs.replace_extension(absolute, "log2")
local filename2 = stdfs.replace_filename(absolute, "ffff.log")
local newname = stdfs.remove_filename(absolute)
log_info("info -> time:%s, terr:%s, extension2:%s, filename2:%s, newname:%s", time, terr, extension2, filename2, newname)

local rfok, rferr = stdfs.remove("tttt.log")
log_info("remove3 -> rfok: %s, rferr: %s", rfok, rferr)
