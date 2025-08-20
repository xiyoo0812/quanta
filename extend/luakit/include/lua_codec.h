#pragma once
#ifdef WIN32
#pragma warning(disable: 4244)
#pragma warning(disable: 4267)
#endif

#include "lua_buff.h"

namespace luakit {
    const uint8_t type_nil          = 0;
    const uint8_t type_true         = 1;
    const uint8_t type_false        = 2;
    const uint8_t type_tab_head     = 3;
    const uint8_t type_tab_tail     = 4;
    const uint8_t type_number       = 5;
    const uint8_t type_int16        = 6;
    const uint8_t type_int32        = 7;
    const uint8_t type_int64        = 8;
    const uint8_t type_string8      = 9;
    const uint8_t type_string16     = 10;
    const uint8_t type_string32     = 11;
    const uint8_t type_istring      = 12;
    const uint8_t type_strindex     = 13;
    const uint8_t type_undefine     = 14;
    const uint8_t type_max          = 15;

    const uint8_t max_encode_depth  = 16;
    const uint8_t max_share_string  = 128;
    const uint8_t max_uint8         = UCHAR_MAX - type_max;
    const uint32_t max_string_size  = 0xffffff;

    inline thread_local std::vector<std::string_view> t_sshares(max_share_string);

    int decode_one(lua_State* L, slice* slice);
    void encode_one(lua_State* L, luabuf* buff, int idx, int depth, bool isindex = false);
    void serialize_one(lua_State* L, luabuf* buff, int index, int depth, int line);

    template<typename T>
    void value_encode(luabuf* buff, T data) {
        buff->push_data((const uint8_t*)&data, sizeof(T));
    }

    inline void value_encode(luabuf* buff, const char* data, size_t len) {
        buff->push_data((const uint8_t*)data, len);
    }

    inline int8_t find_index(std::string_view& str) {
        for (int i = 0; i < t_sshares.size(); ++i) {
            if (t_sshares[i] == str) return i;
        }
        return -1;
    }

    inline std::string_view find_string(size_t index) {
        return (index < t_sshares.size()) ? t_sshares[index] : "";
    }

    inline void string_write(luabuf* buff, const char* ptr, size_t sz) {
        if (sz <= UCHAR_MAX) {
            value_encode(buff, type_string8);
            value_encode<uint8_t>(buff, sz);
        } else if (sz <= USHRT_MAX) {
            value_encode(buff, type_string16);
            value_encode<uint16_t>(buff, sz);
        } else {
            value_encode(buff, type_string32);
            value_encode<uint32_t>(buff, sz);
        }
        if (sz > 0) {
            value_encode(buff, ptr, sz);
        }
    }

    inline void string_encode(lua_State* L, luabuf* buff, int index) {
        size_t sz = 0;
        const char* ptr = lua_tolstring(L, index, &sz);
        if (sz >= max_string_size) {
            luaL_error(L, "encode string can't pack too long (%d) string", sz);
            return;
        }
        string_write(buff, ptr, sz);
    }

    inline void index_encode(lua_State* L, luabuf* buff, int index) {
        size_t sz = 0;
        const char* ptr = lua_tolstring(L, index, &sz);
        if (sz > USHRT_MAX) {
            luaL_error(L, "encode index can't pack too long (%d) string", sz);
            return;
        }
        if (sz > UCHAR_MAX || sz == 0) {
            string_write(buff, ptr, sz);
            return;
        }
        std::string_view value(ptr, sz);
        int8_t sindex = find_index(value);
        if (sindex < 0){
            if (t_sshares.size() < max_share_string) {
                value_encode(buff, type_istring);
                t_sshares.push_back(value);
            } else {
                value_encode(buff, type_string8);
            }
            value_encode<uint8_t>(buff, sz);
            value_encode(buff, ptr, sz);
            return;
        }
        value_encode(buff, type_strindex);
        value_encode<uint8_t>(buff, sindex);
    }

    inline void integer_encode(luabuf* buff, int64_t integer) {
        if (integer >= 0 && integer <= max_uint8) {
            integer += type_max;
            value_encode<uint8_t>(buff, integer);
            return;
        }
        if (integer <= SHRT_MAX && integer >= SHRT_MIN) {
            value_encode(buff, type_int16);
            value_encode<int16_t>(buff, integer);
            return;
        }
        if (integer <= INT_MAX && integer >= INT_MIN) {
            value_encode(buff, type_int32);
            value_encode<int32_t>(buff, integer);
            return;
        }
        value_encode(buff, type_int64);
        value_encode(buff, integer);
    }

    inline void number_encode(luabuf* buff, double number) {
        value_encode(buff, type_number);
        value_encode(buff, number);
    }

    inline void table_encode(lua_State* L, luabuf* buff, int index, int depth) {
        index = lua_absindex(L, index);
        value_encode(buff, type_tab_head);
        lua_pushnil(L);
        while (lua_next(L, index) != 0) {
            encode_one(L, buff, -2, depth, true);
            encode_one(L, buff, -1, depth);
            lua_pop(L, 1);
        }
        value_encode(buff, type_tab_tail);
    }

    inline void encode_one(lua_State* L, luabuf* buff, int idx, int depth, bool isindex) {
        if (depth > max_encode_depth) {
            luaL_error(L, "encode can't pack too depth table");
        }
        int type = lua_type(L, idx);
        switch (type) {
        case LUA_TNIL:
            value_encode(buff, type_nil);
            break;
        case LUA_TSTRING:
            isindex ? index_encode(L, buff, idx) : string_encode(L, buff, idx);
            break;
        case LUA_TTABLE:
            table_encode(L, buff, idx, depth + 1);
            break;
        case LUA_TBOOLEAN:
            lua_toboolean(L, idx) ? value_encode(buff, type_true) : value_encode(buff, type_false);
            break;
        case LUA_TNUMBER:
            lua_isinteger(L, idx) ? integer_encode(buff, lua_tointeger(L, idx)) : number_encode(buff, lua_tonumber(L, idx));
            break;
        default:
            value_encode(buff, type_undefine);
            break;
        }
    }

    inline slice* encode_slice(lua_State* L, luabuf* buff, size_t index, int num) {
        if (num > UCHAR_MAX || num < 0) {
            luaL_error(L, "encode can't pack too many args");
        }
        buff->clean();
        t_sshares.clear();
        buff->write<uint8_t>(num);
        for (int i = 0; i < num; i++) {
            encode_one(L, buff, index + i, 0);
        }
        return buff->get_slice();
    }

    inline int encode(lua_State* L, luabuf* buff) {
        size_t data_len = 0;
        slice* slice = encode_slice(L, buff, 1, 1);
        const char* data = (const char*)slice->data(&data_len);
        lua_pushlstring(L, data, data_len);
        return 1;
    }

    inline void string_decode(lua_State* L, uint32_t sz, slice* slice, bool isindex = false) {
        if (sz == 0) {
            lua_pushstring(L, "");
            return;
        }
        auto str = (const char*)slice->peek(sz);
        if (str == nullptr || sz > max_string_size) {
            throw lua_exception("decode string is out of range");
        }
        slice->erase(sz);
        if (isindex) t_sshares.push_back(std::string_view(str, sz));
        lua_pushlstring(L, str, sz);
    }

    inline void index_decode(lua_State* L, slice* slice) {
        uint8_t index = slice->read();
        std::string_view str = find_string(index);
        lua_pushlstring(L, str.data(), str.size());
    }

    inline void table_decode(lua_State* L, slice* slice) {
        lua_createtable(L, 0, 8);
        do {
            if (decode_one(L, slice) == type_tab_tail) {
                break;
            }
            decode_one(L, slice);
            lua_rawset(L, -3);
        } while (1);
    }

    inline void decode_value(lua_State* L, slice* slice, uint8_t type) {
        switch (type) {
        case type_nil:
            lua_pushnil(L);
            break;
        case type_true:
            lua_pushboolean(L, true);
            break;
        case type_false:
            lua_pushboolean(L, false);
            break;
        case type_number:
            lua_pushnumber(L, slice->read<double>());
            break;
        case type_string8:
            string_decode(L, slice->read(), slice);
            break;
        case type_string16:
            string_decode(L, slice->read<uint16_t>(), slice);
            break;
        case type_string32:
            string_decode(L, slice->read<uint32_t>(), slice);
            break;
        case type_istring:
            string_decode(L, slice->read(), slice, true);
            break;
        case type_strindex:
            index_decode(L, slice);
            break;
        case type_tab_head:
            table_decode(L, slice);
            break;
        case type_tab_tail:
            break;
        case type_int16:
            lua_pushinteger(L, slice->read<int16_t>());
            break;
        case type_int32:
            lua_pushinteger(L, slice->read<int32_t>());
            break;
        case type_int64:
            lua_pushinteger(L, slice->read<int64_t>());
            break;
        case type_undefine:
            lua_pushstring(L, "undefine");
            break;
        default:
            lua_pushinteger(L, type - type_max);
            break;
        }
    }

    inline int decode_one(lua_State* L, slice* slice) {
        uint8_t type = slice->read();
        decode_value(L, slice, type);
        return type;
    }

    inline int decode_slice(lua_State* L, slice* slice) {
        if (!slice) return 0;
        t_sshares.clear();
        int top = lua_gettop(L);
        uint8_t argnum = slice->read();
        lua_checkstack(L, argnum);
        while (1) {
            decode_value(L, slice, slice->read());
        }
        int getnum = lua_gettop(L) - top;
        if (argnum != getnum) {
            throw lua_exception("decode arg num expect %d, but get %d", argnum, getnum);
        }
        return getnum;
    }

    inline int decode(lua_State* L, luabuf* buff) {
        try {
            buff->clean();
            size_t data_len = 0;
            const char* buf = lua_tolstring(L, 1, &data_len);
            buff->push_data((uint8_t*)buf, data_len);
            return decode_slice(L, buff->get_slice());
        } catch (const std::exception& e){
            luaL_error(L, e.what());
        }
        return 0;
    }

    inline void serialize_value(luabuf* buff, const char* str) {
        buff->push_data((const uint8_t*)str, strlen(str));
    }

    inline void serialize_quote(luabuf* buff, const char* str, const char* l, const char* r) {
        serialize_value(buff, l);
        serialize_value(buff, str);
        serialize_value(buff, r);
    }

    inline void serialize_udata(luabuf* buff, void* data) {
        std::string udata = "userdata:" + std::to_string((size_t)data);
        serialize_quote(buff, udata.c_str(), "'", "'");
    }

    inline void serialize_crcn(luabuf* buff, int count, int line) {
        if (line > 0) {
            serialize_value(buff, "\n");
            for (int i = 1; i < count; ++i) {
                serialize_value(buff, "    ");
            }
        }
    }

    inline void serialize_string(lua_State* L, luabuf* buff, int index) {
        size_t sz;
        serialize_value(buff, "'");
        const char* str = luaL_checklstring(L, index, &sz);
        if (sz > 0) {
            buff->push_data((const uint8_t*)str, sz);
        }
        serialize_value(buff, "'");
    }

    inline void serialize_table(lua_State* L, luabuf* buff, int index, int depth, int line) {
        int size = 0;
        index = lua_absindex(L, index);
        serialize_value(buff, "{");
        if (is_lua_array(L, index)) {
            int rawlen = lua_rawlen(L, index);
            for (int i = 1; i <= rawlen; ++i){
                if (size++ > 0) {
                    serialize_value(buff, ",");
                }
                serialize_crcn(buff, depth, line);
                lua_rawgeti(L, index, i);
                serialize_one(L, buff, -1, depth, line);
                lua_pop(L, 1);
            }
        }
        else {
            if (lua_type(L, 3) == LUA_TFUNCTION) {
                lua_guard g(L);
                lua_pushvalue(L, 3);
                lua_pushvalue(L, index);
                //执行sort方法，再序列化
                if (lua_pcall(L, 1, 1, 0)) {
                    luaL_error(L, lua_tostring(L, -1));
                    return;
                }
                index = lua_absindex(L, -1);
                lua_pushnil(L);
                while (lua_next(L, index) != 0) {
                    if (size++ > 0) {
                        serialize_value(buff, ",");
                    }
                    lua_geti(L, -1, 1);
                    lua_geti(L, -2, 2);
                    serialize_crcn(buff, depth, line);
                    if (lua_type(L, -2) == LUA_TNUMBER) {
                        lua_pushvalue(L, -2);
                        serialize_quote(buff, lua_tostring(L, -1), "[", "]=");
                        lua_pop(L, 1);
                    }
                    else if (lua_type(L, -2) == LUA_TSTRING) {
                        serialize_value(buff, lua_tostring(L, -2));
                        serialize_value(buff, "=");
                    }
                    else {
                        serialize_one(L, buff, -2, depth, line);
                        serialize_value(buff, "=");
                    }
                    serialize_one(L, buff, -1, depth, line);
                    lua_pop(L, 3);
                }
            }
            else {
                lua_pushnil(L);
                while (lua_next(L, index) != 0) {
                    if (size++ > 0) {
                        serialize_value(buff, ",");
                    }
                    serialize_crcn(buff, depth, line);
                    if (lua_type(L, -2) == LUA_TNUMBER) {
                        lua_pushvalue(L, -2);
                        serialize_quote(buff, lua_tostring(L, -1), "[", "]=");
                        lua_pop(L, 1);
                    }
                    else if (lua_type(L, -2) == LUA_TSTRING) {
                        serialize_value(buff, lua_tostring(L, -2));
                        serialize_value(buff, "=");
                    }
                    else {
                        serialize_one(L, buff, -2, depth, line);
                        serialize_value(buff, "=");
                    }
                    serialize_one(L, buff, -1, depth, line);
                    lua_pop(L, 1);
                }
            }
        }
        if (size > 0) {
            serialize_crcn(buff, depth - 1, line);
        }
        serialize_value(buff, "}");
    }

    inline void serialize_one(lua_State* L, luabuf* buff, int index, int depth, int line) {
        if (depth > max_encode_depth) {
            luaL_error(L, "serialize can't pack too depth table");
        }
        int type = lua_type(L, index);
        switch (type) {
        case LUA_TNIL:
            serialize_value(buff, "nil");
            break;
        case LUA_TBOOLEAN:
            serialize_value(buff, lua_toboolean(L, index) ? "true" : "false");
            break;
        case LUA_TSTRING:
            serialize_string(L, buff, index);
            break;
        case LUA_TNUMBER:
            serialize_value(buff, lua_tostring(L, index));
            break;
        case LUA_TTABLE:
            serialize_table(L, buff, index, depth + 1, line);
            break;
        case LUA_TUSERDATA:
        case LUA_TLIGHTUSERDATA:
            serialize_udata(buff, lua_touserdata(L, index));
            break;
        default:
            serialize_quote(buff, lua_typename(L, type), "'unsupport(", ")'");
            break;
        }
    }

    inline int serialize(lua_State* L, luabuf* buff) {
        buff->clean();
        size_t data_len = 0;
        serialize_one(L, buff, 1, 1, luaL_optinteger(L, 2, 0));
        const char* data = (const char*)buff->data(&data_len);
        lua_pushlstring(L, data, data_len);
        return 1;
    }

    inline int unserialize(lua_State* L) {
        size_t data_len = 0;
        std::string temp = "return ";
        auto data = luaL_checklstring(L, 1, &data_len);
        temp.append(data, data_len);
        if (luaL_loadbufferx(L, temp.c_str(), temp.size(), "unserialize", "bt") == 0) {
            if (lua_pcall(L, 0, 1, 0) == 0) {
                return 1;
            }
        }
        lua_pushnil(L);
        lua_insert(L, -2);
        return 2;
    }

    class codec_base {
    public:
        virtual ~codec_base() {};
        virtual int load_packet(size_t data_len) = 0;
        virtual size_t decode(lua_State* L) {
            return decode_slice(L, m_slice);
        }
        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            int n = lua_gettop(L) - index + 1;
            slice* slice = encode_slice(L, m_buf, index, n);
            return slice->data(len);
        }
        size_t decode(lua_State* L, uint8_t* data, size_t len) {
            slice mslice(data, len);
            m_slice = &mslice;
            return decode(L);
        }

        virtual void error(const std::string& err) {
            m_err = err;
            m_failed = true;
        }
        virtual void set_slice(slice* slice) {
            m_err = "";
            m_slice = slice;
            m_packet_len = 0;
            m_failed = false;
        }
        virtual bool failed() { return m_failed; }
        virtual luabuf* get_buff() { return m_buf; }
        virtual const char* err() { return m_err.c_str(); }
        virtual size_t get_packet_len() { return m_packet_len; }
        virtual void set_buff(luabuf* buf) { m_buf = buf; }

    protected:
        bool m_failed = false;
        luabuf* m_buf = nullptr;
        slice* m_slice = nullptr;
        size_t m_packet_len = 0;
        std::string m_err = "";
    };

    class luacodec : public codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            uint32_t* packet_len = (uint32_t*)m_slice->peek(sizeof(uint32_t));
            if (!packet_len) return 0;
            m_packet_len = *packet_len;
            if (m_packet_len > 0xffffff) return -1;
            if (m_packet_len > data_len) return 0;
            if (!m_slice->peek(m_packet_len)) return 0;
            return m_packet_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            slice* slice = encode_slice(L, m_buf, index, 1);
            return slice->data(len);
        }
    };
}
