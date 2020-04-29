/*
** repository: https://github.com/trumanzhao/luaredis.git
** trumanzhao, 2017-10-26, trumanzhao@foxmail.com
*/

#include <iostream>
#include <string>
#include "http.h"

int client(lua_State* L)
{
    auto ptr = new http_client(L);
    lua_push_object(L, ptr);

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
