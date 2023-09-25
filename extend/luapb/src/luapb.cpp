#define LUA_LIB
#include <algorithm>

#include "pb.c"
#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace luapb {

    thread_local luabuf thread_buff;

    #pragma pack(1)
    struct pb_header {
        uint16_t    len;            // 整个包的长度
        uint8_t     flag;           // 标志位
        uint8_t     type;           // 消息类型
        uint16_t    cmd_id;         // 协议ID
        uint16_t    session_id;     // sessionId
        uint8_t     crc8;           // crc8
    };
    #pragma pack()

    class pbcodec : public codec_base {
    public:
        pbcodec(const char* pbpkg, const char* pbenum) {
            m_pbpkg = pbpkg;
            m_pbenum = pbenum;
            m_pbpkg.append(".");
        }

        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            pb_header* header =(pb_header*)m_slice->peek(sizeof(pb_header));
            if (!header) return 0;
            m_packet_len = header->len;
            if (m_packet_len < sizeof(pb_header)) return -1;
            if (m_packet_len >= 0xffff) return -1;
            if (!m_slice->peek(m_packet_len)) return 0;
            if (m_packet_len > data_len) return 0;
            return m_packet_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            //header
            pb_header header;
            lpb_State *LS = lpb_lstate(L);
            //cmdid
            const pb_Type* t = pb_type_from_stack(L, LS, &header, index++);
            pb_Slice sh = pb_lslice((const char*)&header, sizeof(header));
            header.flag = (uint8_t)lua_tointeger(L, index++);
            header.type = (uint8_t)lua_tointeger(L, index++);
            header.crc8 = (uint8_t)lua_tointeger(L, index++);
            //encode
            lpb_Env e;
            e.L = L, e.LS = LS;
            pb_resetbuffer(e.b = &LS->buffer);
            lua_pushvalue(L, index);
            pb_addslice(e.b, sh);
            lpbE_encode(&e, t, -1);
            *len = pb_bufflen(e.b);
            return (uint8_t*)pb_buffer(e.b);
        }

        virtual size_t decode(lua_State* L) {
            pb_header* header =(pb_header*)m_slice->erase(sizeof(pb_header));
            //cmd_id
            lpb_State* LS = lpb_lstate(L);
            const pb_Type* t = pb_type_from_enum(L, LS, header->cmd_id);
            //data
            size_t data_len;
            const char* data = (const char*)m_slice->data(&data_len);
            pb_Slice s = pb_lslice(data, data_len);
            //decode
            lpb_Env e;
            int top = lua_gettop(L);
            lua_pushinteger(L, header->cmd_id);
            lua_pushinteger(L, header->flag);
            lua_pushinteger(L, header->type);
            lua_pushinteger(L, header->crc8);
            lpb_pushtypetable(L, LS, t);
            e.L = L, e.LS = LS, e.s = &s;
            lpbD_message(&e, t);
            return lua_gettop(L) - top;
        }

    protected:
        const pb_Type* pb_type_from_name(lua_State* L, lpb_State* LS, string cmd_name) {
            //去掉前缀 NID_
            cmd_name = cmd_name.substr(4);
            std::transform(cmd_name.begin(), cmd_name.end(), cmd_name.begin(), [](auto c) { return std::tolower(c); });
            cmd_name = m_pbpkg + cmd_name;
            return lpb_type(L, LS, pb_lslice(cmd_name.c_str(), cmd_name.size()));
        }

        const pb_Type* pb_type_from_enum(lua_State* L, lpb_State* LS, size_t cmd_id) {
            const pb_Type* t = lpb_type(L, LS, pb_lslice(m_pbenum.c_str(), m_pbenum.size()));
            const pb_Field* f = pb_field(t, cmd_id);
            if (f == nullptr) throw invalid_argument("invalid pb cmdid: " + cmd_id);
            return pb_type_from_name(L, LS, (const char*)f->name);
        }

        const pb_Type* pb_type_from_stack(lua_State* L, lpb_State* LS, pb_header* header, int index) {
            const pb_Type* t = lpb_type(L, LS, pb_lslice(m_pbenum.c_str(), m_pbenum.size()));
            const pb_Field* f = lpb_field(L, index, t);
            if (f) {
                header->cmd_id = f->number;
                return pb_type_from_name(L, LS, (const char*)f->name);
            }
            if (lua_type(L, index) == LUA_TNUMBER) {
                luaL_error(L, "invalid pb cmdid: %d", lua_tointeger(L, index));
            }
            if (lua_type(L, index) == LUA_TSTRING) {
                luaL_error(L, "invalid pb cmd: %s", lua_tostring(L, index));
            }
            luaL_error(L, "invalid pb cmd type");
            return nullptr;
        }

    protected:
        string m_pbpkg;
        string m_pbenum;
    };
    
    static codec_base* pb_codec(const char* pkgname, const char* pbenum) {
        pbcodec* codec = new pbcodec(pkgname, pbenum);
        codec->set_buff(&thread_buff);
        return codec;
    }

    luakit::lua_table open_luapb(lua_State* L) {
        luaopen_pb(L);
        lua_table luapb(L);
        luapb.set_function("pbcodec", pb_codec);
        return luapb;
    }
}

extern "C" {
    LUALIB_API int luaopen_luapb(lua_State* L) {
        auto luapb = luapb::open_luapb(L);
        return luapb.push_stack();
    }
}
