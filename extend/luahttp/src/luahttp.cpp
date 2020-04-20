/*
** repository: https://github.com/trumanzhao/luaredis.git
** trumanzhao, 2017-10-26, trumanzhao@foxmail.com
*/

#include "stdafx.h"
#include <iostream>
#include <string>
#include "http.h"

int client(lua_State* L)
{
	int top = lua_gettop(L);
	if (top == 1)
    {
        auto hc = new http_client(L, lua_tostring(L, 1));
        lua_push_object(L, hc);
    } 
    else if (top == 2)
    {
        const char* host = lua_tostring(L, 1);
        int port = (int)lua_tointeger(L, 2);
        auto hc = new http_client(L, host, port);
        lua_push_object(L, hc);
    }
    else
    {
        const char* host = lua_tostring(L, 1);
        int port = (int)lua_tointeger(L, 2);
        time_t timeout = (time_t)lua_tointeger(L, 3);
        auto hc = new http_client(L, host, port, timeout);
        lua_push_object(L, hc);
    }
    return 1;
}

int server(lua_State* L)
{
    auto hc = new http_server(L);
    lua_push_object(L, hc);
    return 1;
}

#ifdef _MSC_VER
#define LHTTP_API _declspec(dllexport)
#else
#define LHTTP_API 
#endif

extern "C" LHTTP_API int luaopen_luahttp(lua_State* L)
{
    lua_newtable(L);
    lua_set_table_function(L, -1, "client", client);
    lua_set_table_function(L, -1, "server", server);
    return 1;
}
