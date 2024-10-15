#define LUA_LIB

#include "lminiz.h"

namespace lminiz {

    static zip_file zfile;

    static int find_zip_file(lua_State* L, std::string filename) {
        size_t start_pos = 0;
        luakit::lua_guard g(L);
        lua_getglobal(L, LUA_LOADLIBNAME);
        lua_getfield(L, -1, "path");
        std::string path = lua_tostring(L, -1);
        while ((start_pos = filename.find(".", start_pos)) != std::string::npos) {
            filename.replace(start_pos, strlen("."), LUA_DIRSEP);
            start_pos += strlen(LUA_DIRSEP);
        }
        start_pos = 0;
        while ((start_pos = path.find(LUA_PATH_MARK, start_pos)) != std::string::npos) {
            path.replace(start_pos, strlen(LUA_PATH_MARK), filename);
            start_pos += filename.size();
        }
        start_pos = 0;
        while ((start_pos = path.find(LUA_DIRSEP, start_pos)) != std::string::npos) {
            path.replace(start_pos, strlen(LUA_DIRSEP), "/");
            start_pos += strlen("/");
        }
        size_t cur = 0, pos = 0;
        mz_zip_archive* archive = zfile.archive();
        while ((pos = path.find(LUA_PATH_SEP, cur)) != std::string::npos) {
            std::string sub = path.substr(cur, pos - cur);
            int index = mz_zip_reader_locate_file(archive, sub.c_str(), nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
            if (index > 0) {
                return index;
            }
            cur = pos + strlen(LUA_PATH_SEP);
        }
        if (path.size() > cur) {
            std::string sub = path.substr(cur);
            return mz_zip_reader_locate_file(archive, sub.c_str(), nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
        }
        return -1;
    }

    bool zip_exist(const char* fname) {
        return mz_zip_reader_locate_file(zfile.archive(), fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE) > 0;
    }

    static int zip_read(lua_State* L, const char* fname) {
        int index = mz_zip_reader_locate_file(zfile.archive(), fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (index <= 0) return 0;
        size_t size = 0;
        const char* data = (const char*)mz_zip_reader_extract_to_heap(zfile.archive(), index, &size, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (!data) return 0;
        lua_pushlstring(L, data, size);
        delete[] data;
        return 1;
    }

    static int load_zip_data(lua_State* L, const char* filename, int index) {
        size_t size = 0;
        const char* data = (const char*)mz_zip_reader_extract_to_heap(zfile.archive(), index, &size, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (!data) {
            lua_pushstring(L, "file read failed!");
            return LUA_ERRERR;
        }
        int status = luaL_loadbufferx(L, data, size, filename, luaL_optstring(L, 2, nullptr));
        delete[] data;
        return status;
    }

    static int load_zip_file(lua_State* L) {
        const char* fname = luaL_optstring(L, 1, nullptr);
        int index = mz_zip_reader_locate_file(zfile.archive(), fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (index <= 0) {
            luaL_Buffer buf;
            luaL_buffinit(L, &buf);
            luaL_addstring(&buf, fname);
            luaL_addstring(&buf, " not found in zip");
            luaL_pushresult(&buf);
            return LUA_ERRERR;
        }
        return load_zip_data(L, fname, index);
    }

    bool load_zip(lua_State* L, const char* zipfile) {
        if (!zfile.open(zipfile)) {
            return false;
        }
        luakit::kit_state lua(L);
        lua.set_searchers([&](lua_State* L) {
            const char* fname = luaL_checkstring(L, 1);
            int index = find_zip_file(L, fname);
            if (index < 0) {
                luaL_Buffer buf;
                luaL_buffinit(L, &buf);
                luaL_addstring(&buf, fname);
                luaL_addstring(&buf, " not found in zip");
                luaL_pushresult(&buf);
                return 1;
            }
            if (load_zip_data(L, fname, index) == LUA_OK) {
                lua_pushstring(L, fname);  /* will be 2nd argument to module */
                return 2;  /* return open function and file name */
            }
            return luaL_error(L, "error loading module '%s' from file '%s':\n\t%s", lua_tostring(L, 1), fname, lua_tostring(L, -1));
        });
        lua.set_function("dofile", [&](lua_State* L) {
            lua_settop(L, 1);
            if (load_zip_file(L) != LUA_OK) {
                return lua_error(L);
            }
            auto kf = [](lua_State* L, int d1, lua_KContext d2) { return lua_gettop(L) - 1; };
            lua_callk(L, 0, LUA_MULTRET, 0, kf);
            return kf(L, 0, 0);
        });
        lua.set_function("loadfile", [&](lua_State* L) {
            int env = (!lua_isnone(L, 3) ? 3 : 0);  /* 'env' index or 0 if no 'env' */
            if (load_zip_file(L) == LUA_OK) {
                if (env != 0) {  /* 'env' parameter? */
                    lua_pushvalue(L, env);  /* environment for loaded function */
                    if (!lua_setupvalue(L, -2, 1))  /* set it as 1st upvalue */
                        lua_pop(L, 1);  /* remove 'env' if not used by previous call */
                }
                return 1;
            }
            //error(message is on top of the stack)* /
            lua_pushnil(L);
            lua_insert(L, -2);
            return 2;
        });
        return true;
    }

    luakit::lua_table open_lminiz(lua_State* L) {
        luakit::kit_state kit_state(L);
        luakit::lua_table miniz = kit_state.new_table("zip");
        miniz.set_function("exist", zip_exist);
        miniz.set_function("read", zip_read);
        miniz.set_function("load", load_zip);
        return miniz;
    }
}

extern "C" {
    LUALIB_API int luaopen_lminiz(lua_State* L) {
        auto miniz = lminiz::open_lminiz(L);
        return miniz.push_stack();
    }
}
