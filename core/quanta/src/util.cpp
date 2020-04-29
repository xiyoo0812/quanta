
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <sys/stat.h>
#include <list>

#ifdef _WIN32
#include <direct.h>
#include <windows.h>
#include <io.h>
#include <sys/locking.h>
#include <sys/utime.h>
#include <fcntl.h>
#include <shellapi.h>
#include <TlHelp32.h>
#else
#include <sys/wait.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/types.h>
#include <utime.h>    
#endif

#include <lua.hpp>
#include "util.h"

#define UTIL_LIBNAME "util"
#define PROC_NAME_LINE 1//名称所在行

// system(not wait result)
static int util_system(lua_State *L)
{
    const char *cmd = luaL_optstring(L, 1, NULL);
    if (nullptr == cmd)
    {
        lua_pushboolean(L, false);
        lua_pushstring(L, "cmd is nil!");
        return 2;
    }
#ifdef _WIN32
    int stat = system(cmd);
    return luaL_execresult(L, stat);
#else
    pid_t pid = fork();
    if (pid < 0)
    {
        lua_pushboolean(L, false);
        lua_pushstring(L, "fork failed!");
        return 2;
    }
    else if (pid == 0)
    {
        pid_t child_pid = fork();
        if (child_pid < 0)
        {
            exit(EXIT_FAILURE);
        }
        else if (child_pid > 0)
        {
            exit(EXIT_SUCCESS);
        }
        else
        {
            if (execl("/bin/sh", "sh", "-c", cmd, (char*)0) == -1)
            {
                exit(EXIT_FAILURE);
            }
            exit(EXIT_SUCCESS);
        }
    }
    else
    {
        waitpid(pid, NULL, 0);
        lua_pushboolean(L, true);
        return 1;
    }
#endif
}


UTILITY_EXPORT int luaopen_util(lua_State *L) {
    luaL_Reg l_util[] = 
    {
        {"system",  util_system },
        {NULL, NULL},
    };

    luaL_newlib(L, l_util);
    lua_pushvalue(L, -1);
    lua_setglobal(L, UTIL_LIBNAME);
    return 1;
}