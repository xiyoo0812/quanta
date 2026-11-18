--lmake.lua
local lstdfs        = require("lstdfs")

local ldir          = lstdfs.dir
local lstem         = lstdfs.stem
local lappend       = lstdfs.append
local lconcat       = lstdfs.concat
local labsolute     = lstdfs.absolute
local lextension    = lstdfs.extension
local lcurdir       = lstdfs.current_path
local lrelativedir  = lstdfs.relative_path
local lrepextension = lstdfs.replace_extension
local sgsub         = string.gsub
local ssub          = string.sub
local sformat       = string.format
local tsort         = table.sort
local tconcat       = table.concat

local projects      = {}

--table包含
local function tcontain(tab, val)
    for i, v in pairs(tab) do
        if v == val then
            return true
        end
    end
    return false
end

--项目排序
local function project_sort(a, b)
    if tcontain(b.ALLDEPS, a.NAME) then
        return true
    end
    if tcontain(a.ALLDEPS, b.NAME) then
        return false
    end
    if #(a.ALLDEPS) == #(b.ALLDEPS) then
        return a.NAME < b.NAME
    end
    return #(a.ALLDEPS) < #(b.ALLDEPS)
end

--分组排序
local function group_sort(a, b)
    return a.INDEX > b.INDEX
end

--文件排序
local function files_sort(a, b)
    return a[1] < b[1]
end

--
local function path_fmt(paths)
    for i, path in pairs(paths) do
        paths[i] = sgsub(path, "/", "\\")
    end
    return paths
end

--XML文本转义
local function xml_escape(str)
    local ret = sgsub(tostring(str or ""), "&", "&amp;")
    ret = sgsub(ret, "<", "&lt;")
    ret = sgsub(ret, ">", "&gt;")
    ret = sgsub(ret, '"', "&quot;")
    ret = sgsub(ret, "'", "&apos;")
    return ret
end

--路径剪裁：只裁掉开头的基路径，路径中间出现同样的片段不受影响
local function path_cut(fullname, basename)
    local cutname = fullname
    if basename and #basename > 0 and ssub(fullname, 1, #basename) == basename then
        cutname = ssub(fullname, #basename + 1)
    end
    return lrelativedir(cutname)
end

--拼接路径表，生成缓存键（统一分隔符，避免 / 与 \ 造成缓存不命中）
local function paths_key(paths)
    local list = {}
    for i, path in ipairs(paths or {}) do
        list[i] = sgsub(tostring(path), "/", "\\")
    end
    return tconcat(list, ",")
end

--源文件收集的缓存键
local function sources_key(work_dir, src_dirs, args)
    args = args or {}
    return tconcat({
        tostring(work_dir),
        paths_key(src_dirs),
        tostring(args.RECURSION),
        paths_key(args.OBJS),
        paths_key(args.EXCLUDE_FILE),
    }, "|")
end

--整理依赖
--marks: 1=正在遍历 2=已完成，用于检测循环依赖
--path: 当前依赖链，仅用于报错
local function init_project_deps(project, find_name, marks, path)
    if marks[find_name] == 1 then
        path[#path + 1] = find_name
        error(sformat("circular deps detected: %s", table.concat(path, " -> ")))
        return
    end
    if marks[find_name] == 2 then
        return
    end
    marks[find_name] = 1
    path[#path + 1] = find_name
    local find_project = projects[find_name]
    if find_project then
        for _, dep_name in ipairs(find_project.DEPS or {}) do
            local all_deps = project.ALLDEPS
            all_deps[#all_deps + 1] = dep_name
            init_project_deps(project, dep_name, marks, path)
        end
    end
    path[#path] = nil
    marks[find_name] = 2
end

--初始化solution环境变量
local function init_solution_env(env)
    local groups = {}
    local sgroup = {}
    local sprojects = {}
    for _, project in pairs(projects) do
        project.ALLDEPS = {}
        local marks = { [project.NAME] = 1 }
        for _, dep_name in ipairs(project.DEPS or {}) do
            local all_deps = project.ALLDEPS
            all_deps[#all_deps + 1] = dep_name
            init_project_deps(project, dep_name, marks, { project.NAME })
        end
        sprojects[#sprojects + 1] = project
    end
    tsort(sprojects, project_sort)
    local lguid = require("lguid")
    for i, proj in ipairs(sprojects) do
        local gname = proj.GROUP
        if not groups[gname] then
            groups[gname] = { NAME = gname, PROJECTS = {} }
        end
        groups[gname].INDEX = i
        local gprojects = groups[gname].PROJECTS
        gprojects[#gprojects + 1] = proj
    end
    for _, group in pairs(groups) do
        sgroup[#sgroup + 1] = group
    end
    tsort(sgroup, group_sort)
    env.GUID_NEW = lguid.guid
    env.XML_ESCAPE = xml_escape
    env.GROUPS = sgroup
end

--合并配置：表值做一层浅拷贝，避免多个工程共用同一张默认表
local function merge_env(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            local copy = {}
            for kk, vv in pairs(v) do
                copy[kk] = vv
            end
            dst[k] = copy
        else
            dst[k] = v
        end
    end
    return dst
end

--工程类型白名单
local PROJECT_TYPES = {
    exe     = true,
    static  = true,
    dynamic = true,
}

--检查工程配置，出错时指出具体的.lmak文件
local function validate_project_env(env, mak_file)
    local project_name = env.PROJECT_NAME
    if not project_name or project_name == "" then
        error(sformat("PROJECT_NAME not config in %s", mak_file))
    end
    if env.PROJECT_TYPE == nil then
        error(sformat("PROJECT_TYPE not config in %s, expect exe/static/dynamic", mak_file))
    end
    if not PROJECT_TYPES[env.PROJECT_TYPE] then
        error(sformat("invalid PROJECT_TYPE '%s' in %s, expect exe/static/dynamic",
            tostring(env.PROJECT_TYPE), mak_file))
    end
    if not env.TARGET_NAME or env.TARGET_NAME == "" then
        error(sformat("TARGET_NAME not config in %s", mak_file))
    end
    if type(env.SRC_DIRS) ~= "table" or #env.SRC_DIRS == 0 then
        error(sformat("SRC_DIRS must be a non-empty table in %s", mak_file))
    end
    if not env.GROUP or env.GROUP == "" then
        error(sformat("GROUP not config in %s", mak_file))
    end
    return project_name
end

local function is_cpp_file(ext_name)
    return ext_name == ".c" or ext_name == ".cc" or ext_name == ".cpp" or ext_name == ".m"
end

--收集文件
local function collect_files(collect_dir, project_dir, source_dir, args, sub_dir, collects, is_hfile)
    local dir_files = ldir(collect_dir)
    for _, file in pairs(dir_files) do
        if file.type == "directory" then
            if args.RECURSION then
                local rec_sub_dir = path_cut(file.name, project_dir)
                collect_files(file.name, project_dir, source_dir, args, rec_sub_dir, collects, is_hfile)
            end
            goto continue
        end
        local fullname = file.name
        local ext_name = lextension(fullname)
        local fmt_name = path_cut(fullname, project_dir)
        local fmt_name_c = sgsub(fmt_name, '/', '\\')
        if is_hfile then
            if ext_name == ".h" or ext_name == ".hpp" then
                collects[#collects + 1] = { fmt_name_c, sub_dir }
            end
            goto continue
        end
        if is_cpp_file(ext_name) then
            local cmp_name = path_cut(fullname, source_dir)
            local is_obj = tcontain(args.OBJS, cmp_name)
            local cmp_name_c = sgsub(cmp_name, '/', '\\')
            local is_exclude = tcontain(path_fmt(args.EXCLUDE_FILE), cmp_name_c)
            if is_obj or ((#args.OBJS == 0) and not is_exclude) then
                collects[#collects + 1] = { fmt_name_c, sub_dir }
            end
        end
        :: continue ::
    end
end

--vs工程收集源文件
local function collect_sources(project_dir, src_dirs, args)
    local includes, sources = {}, {}
    for _, src_dir in ipairs(src_dirs) do
        local source_dir = lappend(project_dir, src_dir)
        local sub_dir = path_cut(source_dir, project_dir)
        collect_files(source_dir, project_dir, source_dir, args, sub_dir, includes, true)
        collect_files(source_dir, project_dir, source_dir, args, sub_dir, sources, false)
    end
    tsort(includes, files_sort)
    tsort(sources, files_sort)
    return includes, sources
end

--初始化项目环境变量
local function init_project_env(project_dir)
    local lguid = require("lguid")
    local sources_cache = {}
    local function collect_sources_cached(work_dir, src_dirs, args)
        local key = sources_key(work_dir, src_dirs, args)
        local hit = sources_cache[key]
        if not hit then
            local includes, sources = collect_sources(work_dir, src_dirs, args)
            hit = { includes, sources }
            sources_cache[key] = hit
        end
        return hit[1], hit[2]
    end
    return {
        WORK_DIR        = project_dir,
        GUID_NEW        = lguid.guid,
        COLLECT_SOURCES = collect_sources_cached,
        XML_ESCAPE      = xml_escape,
    }
end

--加载环境变量文件
local function load_env_file(file, env)
    local func, err = loadfile(file, "bt", env)
    if not func then
        error(sformat("load lmake file failed :%s", err))
        return false
    end
    local ok, res = pcall(func)
    if not ok then
        error(sformat("load lmake file failed :%s", res))
        return false
    end
    return true
end

--生成项目文件
--project_dir：项目目录
--lmake_dir：lmake工具目录
--defaults：share.lua默认配置
--conf：解决方案lmake配置
local function build_projfile(solution_dir, project_dir, lmake_dir, defaults, conf)
    local lguid = require("lguid")
    local ltmpl = require("ltemplate")
    local dir_files = ldir(project_dir)
    for _, file in pairs(dir_files) do
        local fullname = file.name
        if file.type == "directory" then
            build_projfile(solution_dir, fullname, lmake_dir, defaults, conf)
            goto continue
        end
        if lextension(fullname) == ".lmak" then
            local env = init_project_env(project_dir)
            merge_env(env, defaults)
            merge_env(env, conf)
            if not load_env_file(fullname, env) then
                error(sformat("load env %s failed", fullname))
                return
            end
            if not env.ENABLE then
                print(sformat("skip project %s : ENABLE = false", fullname))
                goto continue
            end
            local project_name = validate_project_env(env, fullname)
            if projects[project_name] then
                error(sformat("duplicated project name '%s' : %s vs %s",
                    project_name, projects[project_name].MAK, fullname))
            end
            local filename = lstem(fullname)
            local mak_dir = path_cut(project_dir, solution_dir)
            env.PLATFORM = "x64"
            ltmpl.render_file(lappend(lmake_dir, "tmpl/vcxproj.tpl"),  lrepextension(fullname, ".vcxproj"), env)
            ltmpl.render_file(lappend(lmake_dir, "tmpl/make.tpl"),  lrepextension(fullname, ".mak"), env)
            ltmpl.render_file(lappend(lmake_dir, "tmpl/filters.tpl"),  lrepextension(fullname, ".vcxproj.filters"), env)
            projects[project_name] = {
                DIR = mak_dir,
                FILE = filename,
                MAK = fullname,
                DEPS = env.DEPS,
                GROUP = env.GROUP,
                NAME = project_name,
                GUID = lguid.guid(project_name)
            }
        end
        :: continue ::
    end
end

--生成项目文件
local function build_lmak(solution_dir)
    print(sformat("build_lmak: solution_dir %s", solution_dir))
    --默认配置(share.lua)与解决方案配置(lmake)各只加载一次，避免重复执行其副作用
    local conf = {}
    if not load_env_file(lappend(solution_dir, "lmake"), conf) then
        error("load main lmake file failed")
        return
    end
    local solution = conf.SOLUTION
    if not solution or not conf.LMAKE_DIR then
        error(sformat("lmake solution or dir not config"))
        return
    end
    local lmake_dir = labsolute(lappend(solution_dir, conf.LMAKE_DIR))
    print(sformat("build_lmak: lmake_dir %s", lmake_dir))
    local defaults = {}
    if not load_env_file(lappend(lmake_dir, "share.lua"), defaults) then
        error("load share lmake file failed")
        return
    end
    package.path = sformat("%s;%s/?.lua", package.path, lmake_dir)
    local dir_files = ldir(solution_dir)
    for _, file in pairs(dir_files) do
        if file.type == "directory" then
            build_projfile(solution_dir, file.name, lmake_dir, defaults, conf)
        end
    end
    --解决方案级环境：默认配置在前，解决方案配置覆盖
    local env = merge_env({}, defaults)
    merge_env(env, conf)
    init_solution_env(env)
    local ltmpl = require("ltemplate")
    if not env.PLATFORM then
        env.PLATFORM = "x64"
        ltmpl.render_file(lappend(lmake_dir, "tmpl/makefile.tpl"), lappend(solution_dir, "Makefile"), env)
    end
    if env.MSVC_FMT_SLNX then
        ltmpl.render_file(lappend(lmake_dir, "tmpl/slnx.tpl"), lappend(solution_dir, lconcat(solution, ".slnx")), env)
        env.IGNORE_GROUP = nil
        ltmpl.render_file(lappend(lmake_dir, "tmpl/slnx.tpl"), lappend(solution_dir, "all.slnx"), env)
    else
        ltmpl.render_file(lappend(lmake_dir, "tmpl/sln.tpl"), lappend(solution_dir, lconcat(solution, ".sln")), env)
        env.IGNORE_GROUP = nil
        ltmpl.render_file(lappend(lmake_dir, "tmpl/sln.tpl"), lappend(solution_dir, "all.sln"), env)
    end
    print(sformat("build solution %s success!", solution))
end

local solution_dir = lcurdir()
if select("#", ...) == 1 then
    solution_dir = select(1, ...)
end
--生成工程
--solution_dir：工程路径
build_lmak(labsolute(solution_dir))

--工具用法
--usage
--lmake_file: lmake.lua文件路径
--solution_dir：工程路径，不传则当前路径
--bin/lua.exe ../lmake/lmake.lua ./
