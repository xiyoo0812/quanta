
#include "internal/config.h"
#include <lua.hpp>
#include <string>
#include "encryptor.h"


static int encrypt(lua_State* L) 
{
    while (true)
    {
        int top = lua_gettop(L);
        if (1 != top)
            break;
        else if (!lua_isstring(L, 1))
            break;

        size_t data_len = 0;
        const char* data_ptr = lua_tolstring(L, 1, &data_len);
        auto bytes = encryptor::encrypt((uint8_t*)const_cast<char*>(data_ptr), data_len);

        lua_pushboolean(L, true);
        lua_pushlstring(L, (char*)bytes.data(), bytes.size());
        return 2;
    }

    lua_pushboolean(L, false);
    lua_pushstring(L, "parameter should be: data_ptr{string}");
    return 2;
}

static int decrypt(lua_State* L) 
{
    while (true)
    {
        int top = lua_gettop(L);
        if (1 != top)
            break;
        else if (!lua_isstring(L, 1))
            break;

        size_t data_len = 0;
        const char* data_ptr = lua_tolstring(L, 1, &data_len);
        auto bytes = encryptor::decrypt((uint8_t*)const_cast<char*>(data_ptr), data_len);

        lua_pushboolean(L, true);
        lua_pushlstring(L, (char*)bytes.data(), bytes.size());
        return 2;
    }

    lua_pushboolean(L, false);
    lua_pushstring(L, "parameter should be: data_ptr{string}");
    return 2;
}

static int quick_zip(lua_State* L)
{
    while (true)
    {
        int top = lua_gettop(L);
        if (1 != top)
            break;
        else if (!lua_isstring(L, 1))
            break;

        size_t data_len = 0;
        const char* data_ptr = lua_tolstring(L, 1, &data_len);
        auto bytes = encryptor::quick_zip((uint8_t*)const_cast<char*>(data_ptr), data_len);

        lua_pushboolean(L, true);
        lua_pushlstring(L, (char*)bytes.data(), bytes.size());
        return 2;
    }

    lua_pushboolean(L, false);
    lua_pushstring(L, "parameter should be: data_ptr{string}");
    return 2;
}

static int quick_unzip(lua_State* L)
{
    while (true)
    {
        int top = lua_gettop(L);
        if (1 != top)
            break;
        else if (!lua_isstring(L, 1))
            break;

        size_t data_len = 0;
        const char* data_ptr = lua_tolstring(L, 1, &data_len);
        auto bytes = encryptor::quick_unzip((uint8_t*)const_cast<char*>(data_ptr), data_len);

        lua_pushboolean(L, true);
        lua_pushlstring(L, (char*)bytes.data(), bytes.size());
        return 2;
    }

    lua_pushboolean(L, false);
    lua_pushstring(L, "parameter should be: data_ptr{string}");
    return 2;
}

extern "C" 
ENCRYPT_API int luaopen_encrypt(lua_State* L) 
{
    luaL_checkversion(L);

    luaL_Reg l[] = {
        { "encrypt", encrypt},
        { "decrypt", decrypt},
        { "quick_zip", quick_zip},
        { "quick_unzip", quick_unzip},
        { NULL, NULL },
    };

    luaL_newlib(L, l);

    return 1;
}
