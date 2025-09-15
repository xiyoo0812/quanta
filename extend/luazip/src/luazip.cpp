#define LUA_LIB

#include "lz4.h"
#include "zstd.c"

#include "luazip.h"

#define	MINI_GZ_MIN(a, b)	((a) < (b) ? (a) : (b))

namespace luazip {
    inline uint8_t* alloc_buff(size_t sz) {
        auto buf = luakit::get_buff();
        return buf->peek_space(sz);
    }

    int mini_gz_init(struct mini_gzip* gz_ptr, uint8_t* mem, size_t mem_len) {
        uint8_t* mem8_ptr = mem;
        uint8_t* hptr = mem8_ptr + 0;		// .gz header
        uint8_t* hauxptr = mem8_ptr + 10;	// auxillary header

        gz_ptr->hdr_ptr = hptr;
        gz_ptr->data_ptr = 0;
        gz_ptr->data_len = 0;
        gz_ptr->total_len = mem_len;
        gz_ptr->chunk_size = 1024;

        if (hptr[0] != 0x1F || hptr[1] != 0x8B) {
            return MZ_STREAM_ERROR;
        }
        if (hptr[2] != 8) {
            return MZ_STREAM_ERROR;
        }
        if (hptr[3] & 0x4) {
            uint16_t fextra_len = hauxptr[1] << 8 | hauxptr[0];
            gz_ptr->fextra_len = fextra_len;
            hauxptr += 2;
            gz_ptr->fextra_ptr = hauxptr;
        }
        if (hptr[3] & 0x8) {
            gz_ptr->fname_ptr = hauxptr;
            while (*hauxptr != '\0') {
                hauxptr++;
            }
            hauxptr++;
        }
        if (hptr[3] & 0x10) {
            gz_ptr->fcomment_ptr = hauxptr;
            while (*hauxptr != '\0') {
                hauxptr++;
            }
            hauxptr++;
        }
        if (hptr[3] & 0x2) /* FCRC */ {
            gz_ptr->fcrc = (*(uint16_t*)hauxptr);
            hauxptr += 2;
        }
        gz_ptr->data_ptr = hauxptr;
        gz_ptr->data_len = mem_len - (hauxptr - hptr);
        return MZ_OK;
    }

    int mini_gz_unpack(struct mini_gzip* gz_ptr, uint8_t* mem_out, size_t* mem_out_len) {
        z_stream s = {};
        inflateInit2(&s, -MZ_DEFAULT_WINDOW_BITS);
        int in_bytes_avail = gz_ptr->data_len;
        s.avail_out = *mem_out_len;
        s.next_in = gz_ptr->data_ptr;
        s.next_out = mem_out;
        for (;;) {
            int bytes_to_read = MINI_GZ_MIN(gz_ptr->chunk_size, in_bytes_avail);
            s.avail_in += bytes_to_read;
            int ret = mz_inflate(&s, MZ_SYNC_FLUSH);
            if (ret == MZ_STREAM_END) {
                break;
            }
            in_bytes_avail -= bytes_to_read;
            if (s.avail_out == 0 && in_bytes_avail != 0) {
                return MZ_MEM_ERROR;
            }
            if (ret != MZ_OK) {
                return ret;
            }
        }
        *mem_out_len = s.total_out;
        return inflateEnd(&s);
    }


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

    static int gzip_decode(lua_State* L, std::string_view src) {
        size_t src_size = src.size();
        size_t dst_size = src_size * 5;
        auto output = alloc_buff(dst_size);
        if (output == nullptr) {
            luaL_error(L, "Failed to allocate output buffer.");
        }
        struct mini_gzip gz;
        int ret = mini_gz_init(&gz, (uint8_t*)src.data(), src_size);
        if (ret != MZ_OK) {
            luaL_error(L, "Failed to init gzip header! err: %d", ret);
        }
        ret = mini_gz_unpack(&gz, output, &dst_size);
        if (ret != MZ_OK) {
            luaL_error(L, "Failed to unpack gzip! err: %d", ret);
        }
        lua_pushlstring(L, (char*)output, dst_size);
        return 1;
    }

    static int lz4_encode(lua_State* L) {
        size_t data_len = 0;
        char dest[USHRT_MAX];
        const char* message = luaL_checklstring(L, 1, &data_len);
        int out_len = LZ4_compress_default(message, dest, data_len, USHRT_MAX);
        if (out_len > 0) {
            lua_pushlstring(L, dest, out_len);
            return 1;
        }
        luaL_error(L, "lz4 compress failed!");
        return 0;
    }

    static int lz4_decode(lua_State* L) {
        size_t data_len = 0;
        char dest[USHRT_MAX];
        const char* message = luaL_checklstring(L, 1, &data_len);
        int out_len = LZ4_decompress_safe(message, dest, data_len, USHRT_MAX);
        if (out_len > 0) {
            lua_pushlstring(L, dest, out_len);
            return 1;
        }
        luaL_error(L, "lz4 decompress failed!");
        return 0;
    }

    static int zstd_encode(lua_State* L) {
        size_t data_len = 0;
        const char* message = luaL_checklstring(L, 1, &data_len);
        size_t zsize = ZSTD_compressBound(data_len);
        if (!ZSTD_isError(zsize)) {
            auto dest = alloc_buff(zsize);
            if (dest) {
                size_t comp_ize = ZSTD_compress(dest, zsize, message, data_len, ZSTD_defaultCLevel());
                if (!ZSTD_isError(comp_ize)) {
                    lua_pushlstring(L, (const char*)dest, comp_ize);
                    return 1;
                }
            }
        }
        lua_pushnil(L);
        lua_pushstring(L, "zstd compress failed!");
        return 2;
    }

    static int zstd_decode(lua_State* L) {
        size_t data_len = 0;
        const char* message = luaL_checklstring(L, 1, &data_len);
        size_t size = ZSTD_getFrameContentSize(message, data_len);
        if (!ZSTD_isError(size)) {
            auto dest = alloc_buff(size);
            if (dest) {
                size_t dec_size = ZSTD_decompress(dest, size, message, data_len);
                if (!ZSTD_isError(dec_size)) {
                    lua_pushlstring(L, (const char*)dest, dec_size);
                    return 1;
                }
            }
        }
        lua_pushnil(L);
        lua_pushstring(L, "zstd decompress failed!");
        return 2;
    }
    
    luakit::lua_table open_luazip(lua_State* L) {
        luakit::kit_state kit_state(L);
        luakit::lua_table lzip = kit_state.new_table("zip");
        lzip.set_function("exist", zip_exist);
        lzip.set_function("read", zip_read);
        lzip.set_function("load", load_zip);
        lzip.set_function("gzip_decode", gzip_decode);
        lzip.set_function("lz4_encode", lz4_encode);
        lzip.set_function("lz4_decode", lz4_decode);
        lzip.set_function("zstd_encode", zstd_encode);
        lzip.set_function("zstd_decode", zstd_decode);
        return lzip;
    }
}

extern "C" {
    LUALIB_API int luaopen_luazip(lua_State* L) {
        auto lzip = luazip::open_luazip(L);
        return lzip.push_stack();
    }
}
