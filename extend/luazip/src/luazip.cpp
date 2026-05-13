#define LUA_LIB

#include "luazip.h"

#define	MINI_GZ_MIN(a, b)	((a) < (b) ? (a) : (b))

namespace luazip {

    thread_local zip_file zfile;
    thread_local zipcodec zcodec;

    bool zip_exist(cpchar fname) {
        return mz_zip_reader_locate_file(zfile.archive(), fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE) > 0;
    }

    int find_zip_file(lua_State* L, std::string filename) {
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

    int zip_read(lua_State* L, cpchar fname) {
        int index = mz_zip_reader_locate_file(zfile.archive(), fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (index <= 0) return 0;
        size_t size = 0;
        cpchar data = (cpchar)mz_zip_reader_extract_to_heap(zfile.archive(), index, &size, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (!data) return 0;
        lua_pushlstring(L, data, size);
        delete[] data;
        return 1;
    }

    int load_zip_data(lua_State* L, cpchar filename, int index) {
        size_t size = 0;
        cpchar data = (cpchar)mz_zip_reader_extract_to_heap(zfile.archive(), index, &size, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (!data) {
            lua_pushstring(L, "file read failed!");
            return LUA_ERRERR;
        }
        int status = luaL_loadbufferx(L, data, size, filename, luaL_optstring(L, 2, nullptr));
        delete[] data;
        return status;
    }

    int load_zip_file(lua_State* L) {
        cpchar fname = luaL_optstring(L, 1, nullptr);
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

    bool load_zip(lua_State* L, cpchar zipfile) {
        if (!zfile.open(zipfile)) {
            return false;
        }
        luakit::kit_state lua(L);
        lua.set_searchers([&](lua_State* L) {
            cpchar fname = luaL_checkstring(L, 1);
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

    inline codec_base* zip_codec(vstring tag) {
        zipcodec* codec = new zipcodec();
        codec->set_tag(tag);
        return codec;
    }

    inline int lz4_encode(lua_State* L) {
        size_t data_len = 0;
        auto dest = zcodec.encode_lz4(L, 1, &data_len);
        if (dest) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushstring(L, "lz4 compress failed!");
        return 2;
    }

    inline int lz4_decode(lua_State* L) {
        size_t data_len = 0;
        cpchar message = luaL_checklstring(L, 1, &data_len);
        auto dest = zcodec.decode_lz4((pbyte)message, &data_len);
        if (dest) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushstring(L, "lz4 decompress failed!");
        return 2;
    }

    inline int zstd_encode(lua_State* L) {
        size_t data_len = 0;
        int level = luaL_optinteger(L, 3, ZSTD_defaultCLevel());
        auto dest = zcodec.encode_zstd(L, 1, &data_len, level);
        if (data_len > 0) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushstring(L, "zstd compress failed!");
        return 2;
    }

    inline int zstd_decode(lua_State* L) {
        size_t data_len = 0;
        cpchar message = luaL_checklstring(L, 1, &data_len);
        auto dest = zcodec.decode_zstd((pbyte)message, &data_len);
        if (dest) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushstring(L, "zstd decompress failed!");
        return 2;
    }

    inline int deflate_encode(lua_State* L) {
        size_t data_len = 0;
        int level = luaL_optinteger(L, 3, MZ_DEFAULT_LEVEL);
        auto dest = zcodec.encode_deflate(L, 1, &data_len, level);
        if (data_len > 0) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "deflate compress failed");
        return 2;
    }

    inline int deflate_decode(lua_State* L) {
        size_t data_len = 0;
        cpchar message = luaL_checklstring(L, 1, &data_len);
        auto dest = zcodec.decode_deflate((pbyte)message, &data_len);
        if (dest) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "deflate decompress failed");
        return 2;
    }

    inline int zlib_encode(lua_State* L) {
        size_t data_len = 0;
        int level = luaL_optinteger(L, 3, MZ_DEFAULT_LEVEL);
        auto dest = zcodec.encode_zlib(L, 1, &data_len, level);
        if (data_len > 0) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "zlib compress failed");
        return 2;
    }

    inline int zlib_decode(lua_State* L) {
        size_t data_len = 0;
        cpchar message = luaL_checklstring(L, 1, &data_len);
        auto dest = zcodec.decode_zlib((pbyte)message, &data_len);
        if (dest) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "zlib decompress failed");
        return 2;
    }

    inline int gzip_encode(lua_State* L) {
        size_t data_len = 0;
        int level = luaL_optinteger(L, 3, MZ_DEFAULT_LEVEL);
        auto dest = zcodec.encode_gzip(L, 1, &data_len, level);
        if (data_len > 0) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "gzip compress: deflate failed");
        return 2;
    }

    inline int gzip_decode(lua_State* L) {
        size_t data_len = 0;
        auto message = (cpbyte)luaL_checklstring(L, 1, &data_len);
        auto dest = zcodec.decode_gzip((pbyte)message, &data_len);
        if (dest) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "gzip decompress: data too short");
        return 2;
    }

    inline int snappy_encode(lua_State* L) {
        size_t data_len = 0;
        int level = luaL_optinteger(L, 3, snappy::CompressionOptions::DefaultCompressionLevel());
        auto dest = zcodec.encode_snappy(L, 1, &data_len, level);
        if (data_len > 0) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "snappy compress: deflate failed");
        return 2;
    }

    inline int snappy_decode(lua_State* L) {
        size_t data_len = 0;
        auto message = (cpbyte)luaL_checklstring(L, 1, &data_len);
        auto dest = zcodec.decode_snappy((pbyte)message, &data_len);
        if (dest) {
            push_string(L, (char*)dest, data_len, 2, nullptr, nullptr);
            return 1;
        }
        lua_pushnil(L);
        lua_pushliteral(L, "snappy decompress: data too short");
        return 2;
    }

    luakit::lua_table open_luazip(lua_State* L) {
        luakit::kit_state kit_state(L);
        luakit::lua_table lzip = kit_state.new_table("zip");
        lzip.set_function("exist", zip_exist);
        lzip.set_function("read", zip_read);
        lzip.set_function("load", load_zip);
        lzip.set_function("zipcodec", zip_codec);
        lzip.set_function("lz4_encode", lz4_encode);
        lzip.set_function("lz4_decode", lz4_decode);
        lzip.set_function("gzip_encode", gzip_encode);
        lzip.set_function("gzip_decode", gzip_decode);
        lzip.set_function("zlib_encode", zlib_encode);
        lzip.set_function("zlib_decode", zlib_decode);
        lzip.set_function("zstd_encode", zstd_encode);
        lzip.set_function("zstd_decode", zstd_decode);
        lzip.set_function("snappy_encode", snappy_encode);
        lzip.set_function("snappy_decode", snappy_decode);
        lzip.set_function("deflate_encode", deflate_encode);
        lzip.set_function("deflate_decode", deflate_decode);
        return lzip;
    }
}

extern "C" {
    LUALIB_API int luaopen_luazip(lua_State* L) {
        auto lzip = luazip::open_luazip(L);
        return lzip.push_stack();
    }
}
