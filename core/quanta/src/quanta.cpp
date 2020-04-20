/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2017-05-13, trumanzhao@foxmail.com
*/

#include "stdafx.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <string>
#include <locale>
#include <stdint.h>
#include <signal.h>
#include "quanta.h"
#include "tools.h"
#include "lfs.h"
#include "util.h"
#if WIN32
#include <conio.h>
#endif

quanta_app* g_app = nullptr;

static void on_signal(int signo)
{
    if (g_app)
    {
        g_app->set_signal(signo);
    }
}

EXPORT_CLASS_BEGIN(quanta_app)
EXPORT_LUA_FUNCTION(get_version)
EXPORT_LUA_FUNCTION(get_file_time)
EXPORT_LUA_FUNCTION(get_full_path)
EXPORT_LUA_FUNCTION(get_time_ms)
EXPORT_LUA_FUNCTION(get_time_ns)
EXPORT_LUA_FUNCTION(get_pid)
EXPORT_LUA_FUNCTION(sleep_ms)
EXPORT_LUA_FUNCTION(daemon)
EXPORT_LUA_FUNCTION(register_signal)
EXPORT_LUA_FUNCTION(default_signal)
EXPORT_LUA_FUNCTION(ignore_signal)
EXPORT_LUA_INT64(m_signal)
EXPORT_LUA_INT(m_reload_time)
EXPORT_LUA_STD_STR_R(m_entry)
EXPORT_CLASS_END()

int quanta_app::get_version(lua_State* L)
{
    lua_pushinteger(L, MAJOR_VERSION_NUMBER);
    lua_pushinteger(L, MINOR_VERSION_NUMBER);
    lua_pushinteger(L, REVISION_NUMBER);
    return 3;
}

time_t quanta_app::get_file_time(const char* filename)
{
    return ::get_file_time(filename);
}

int quanta_app::get_full_path(lua_State* L)
{
    const char* path = lua_tostring(L, 1);
    std::string fullpath;
    if (path != nullptr && ::get_full_path(fullpath, path))
    {
        lua_pushstring(L, fullpath.c_str());
    }
    return 1;
}

int64_t quanta_app::get_time_ms()
{
    return ::get_time_ms();
}

int64_t quanta_app::get_time_ns()
{
    return ::get_time_ns();
}

int32_t quanta_app::get_pid()
{
#ifdef _MSC_VER
    return ::GetCurrentProcessId();
#else
    return ::getpid();
#endif
}

void quanta_app::sleep_ms(int ms)
{
    ::sleep_ms(ms);
}

#ifdef _MSC_VER
void quanta_app::daemon() { }
#endif

#if defined(__linux) || defined(__APPLE__)
void quanta_app::daemon()
{
    pid_t pid = fork();
    if (pid != 0)
        exit(0);

    setsid();
    umask(0);
    
    int null = open("/dev/null", O_RDWR); 
    if (null != -1)
    {
        dup2(null, STDIN_FILENO);
        dup2(null, STDOUT_FILENO);
        dup2(null, STDERR_FILENO);
        close(null);
    }
}
#endif

void quanta_app::register_signal(int n)
{
    signal(n, on_signal);
}

void quanta_app::default_signal(int n)
{
    signal(n, SIG_DFL);
}

void quanta_app::ignore_signal(int n)
{
    signal(n, SIG_IGN);
}

void quanta_app::set_signal(int n)
{
    uint64_t mask = 1;
    mask <<= n;
    m_signal |= mask;
}

static const char* g_sandbox = u8R"__(
local pcall     = pcall
local pairs     = pairs
local loadfile  = loadfile
local otime     = os.time
local mabs      = math.abs
local ssub      = string.sub
local sfind     = string.find
local sformat   = string.format
local file_time = quanta.get_file_time
local full_path = quanta.get_full_path

quanta.files      = {}
quanta.scriptpath = ""

quanta.print = function(fmt, ...)
    print(...)
end
quanta.error = function(fmt, ...)
    print(...)
end

local try_load = function(node)
    local fullpath = node.fullpath
    local filename = node.filename
    local trunk, msg = loadfile(fullpath)
    if not trunk then
        quanta.error(sformat("load file: %s ... ... [failed]", filename))
        quanta.error(msg)
        return
    end
    local ok, res_or_err = pcall(trunk)
    if not ok then
        quanta.error(sformat("exec file: %s ... ... [failed]", filename))
        quanta.error(res_or_err)
        return
    end
    if node.res then
        --使用复制方式热更新
        for field, value in pairs(res_or_err) do
            node.res[field] = value
        end
    else
        node.res = res_or_err
    end
    print(sformat("load file: %s ... ... [ok]", filename))
end

local get_filenode = function(filename)
    local withroot = quanta.scriptpath .. filename
    local fullpath = full_path(withroot) or withroot
    local node = quanta.files[fullpath]
    if node then
        return node
    end
    node = {fullpath=fullpath, filename=filename}
    quanta.files[fullpath] = node
    return node
end

quanta.import = function(filename)
    local node = get_filenode(filename)
    if node.time then
        return
    end
    node.time = file_time(node.fullpath)
    local trunk, code_err = loadfile(node.fullpath)
    if not trunk then
        quanta.error(code_err)
        return
    end
    local i, j = sfind(filename, '/')
    if i and j then
        quanta.scriptpath = ssub(filename, 1, i)
    end
    local ok, err = pcall(trunk)
    if not ok then
        quanta.error(err)
    end
end

function import(filename)
    local node = get_filenode(filename)
    if not node.time then
        node.time = file_time(node.fullpath)
        try_load(node)
    end
    return node.res
end

quanta.reload = function()
    local now = otime()
    for path, node in pairs(quanta.files) do
        local filetime = file_time(node.fullpath)
        if filetime ~= node.time and filetime ~= 0 and mabs(now - filetime) > 1 then
            node.time = filetime
            try_load(node)
        end
    end
end

quanta.input = function(cmd)
    print(cmd)
end
)__";

void quanta_app::die(const std::string& err)
{
    std::string path = m_entry + ".err";
    FILE* file = fopen(path.c_str(), "w");
    if (file != nullptr)
    {
        fwrite(err.c_str(), err.length(), 1, file);
        fclose(file);
    }
    fprintf(stderr,"%s", err.c_str());
    exit(1);
}

void quanta_app::check_input(lua_State* L)
{
#ifdef WIN32
    if (kbhit())
    {
        char cur = getch();
        if (cur == '\xE0' || cur == '\x0')
        {
            if (kbhit())
            {
                getch();
                return;
            }
        }
        lua_call_object_function(L, nullptr, this, "input", std::tie(), cur);
    }
#endif
}

void quanta_app::run(int argc, const char* argv[])
{
    lua_State* L = luaL_newstate();
    int64_t last_check = ::get_time_ms();
    const char* filename = argv[1];

    luaL_openlibs(L);
	luaopen_lfs(L);
	luaopen_util(L);
    m_entry = filename;
    lua_push_object(L, this);
    lua_push_object(L, this);
    lua_setglobal(L, "quanta");
    lua_newtable(L);
    for (int i = 1; i < argc; i++)
    {
        lua_pushinteger(L, i - 1);
        lua_pushstring(L, argv[i]);
        lua_settable(L, -3);
    }
	lua_setfield(L, -2, "args");
	lua_pushstring(L, get_platform());
	lua_setfield(L, -2, "platform");
	
    luaL_dostring(L, g_sandbox);

    std::string err;
    int top = lua_gettop(L);

    if(!lua_call_object_function(L, &err, this, "import", std::tie(), filename))
        die(err);

    while (lua_get_object_function(L, this, "run"))
    {
        check_input(L);

        if(!lua_call_function(L, &err, 0, 0))
            die(err);

        int64_t now = ::get_time_ms();
        if (now > last_check + m_reload_time)
        {
            lua_call_object_function(L, nullptr, this, "reload");
            last_check = now;
        }
        lua_settop(L, top);
    }

    lua_close(L);
}
