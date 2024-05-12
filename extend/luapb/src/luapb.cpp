#define LUA_LIB
#include <algorithm>

#include "pb.c"
#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace luapb {

    thread_local luabuf thread_buff; 
    thread_local std::map<uint32_t, std::string> pb_cmd_ids;
    thread_local std::map<std::string, uint32_t> pb_cmd_indexs;
    thread_local std::map<std::string, std::string> pb_cmd_names;

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
            //session_id
            header.session_id = (lua_tointeger(L, index++) & 0xffff);
            //cmdid
            const pb_Type* t = pb_type_from_stack(L, LS, &header, index++);
            if (t == nullptr) luaL_error(L, "pb message not define cmd: %d", header.cmd_id);
            pb_Slice sh = pb_lslice((const char*)&header, sizeof(header));
            //other
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
            ((pb_header*)pb_buffer(e.b))->len = *len;
            return (uint8_t*)pb_buffer(e.b);
        }

        virtual size_t decode(lua_State* L) {
            pb_header* header = (pb_header*)m_slice->erase(sizeof(pb_header));
            //cmd_id
            lpb_State* LS = lpb_lstate(L);
            const pb_Type* t = pb_type_from_enum(L, LS, header->cmd_id);
            if (t == nullptr) {
                throw lua_exception("pb message not define cmd: %d", header->cmd_id);
            }
            //data
            size_t data_len;
            const char* data = (const char*)m_slice->data(&data_len);
            //return
            int top = lua_gettop(L);
            lua_pushinteger(L, data_len);
            lua_pushinteger(L, header->session_id);
            lua_pushinteger(L, header->cmd_id);
            lua_pushinteger(L, header->flag);
            lua_pushinteger(L, header->type);
            lua_pushinteger(L, header->crc8);
            //decode
            lua_push_function(L, [&](lua_State* L) {
                lpb_Env e;
                pb_Slice s = pb_lslice(data, data_len);
                lpb_pushtypetable(L, LS, t);
                e.L = L, e.LS = LS, e.s = &s;
                lpbD_message(&e, t);
                return 1;
            });
            if (lua_pcall(L, 0, 1, 0)) {
                throw lua_exception("decode pb cmdid: %d failed: %s", header->cmd_id, lua_tostring(L, -1));
            }
            return lua_gettop(L) - top;
        }

    protected:
        const pb_Type* pb_type_from_enum(lua_State* L, lpb_State* LS, size_t cmd_id) {
            auto it = pb_cmd_ids.find(cmd_id);
            if (it == pb_cmd_ids.end()) throw lua_exception("pb decode invalid cmdid: %d!", cmd_id);
            return lpb_type(L, LS, pb_lslice(it->second.c_str(), it->second.size()));
        }

        const pb_Type* pb_type_from_stack(lua_State* L, lpb_State* LS, pb_header* header, int index) {
            if (lua_type(L, index) == LUA_TNUMBER) {
                header->cmd_id = lua_tointeger(L, index);
                auto it = pb_cmd_ids.find(header->cmd_id);
                if (it == pb_cmd_ids.end()) luaL_error(L, "invalid pb cmd: %d", header->cmd_id);
                return lpb_type(L, LS, pb_lslice(it->second.c_str(), it->second.size()));
            }
            if (lua_type(L, index) == LUA_TSTRING) {
                std::string cmd_name = lua_tostring(L, index);
                auto it = pb_cmd_names.find(cmd_name);
                if (it == pb_cmd_names.end()) luaL_error(L, "invalid pb cmd_name: %s", cmd_name.c_str());
                header->cmd_id = pb_cmd_indexs[cmd_name];
                return lpb_type(L, LS, pb_lslice(it->second.c_str(), it->second.size()));
            }
            luaL_error(L, "invalid pb cmd type");
            return nullptr;
        }
    };
    
    static codec_base* pb_codec() {
        pbcodec* codec = new pbcodec();
        codec->set_buff(&thread_buff);
        return codec;
    }

    luakit::lua_table open_luapb(lua_State* L) {
        luaopen_pb(L);
        lua_table luapb(L);
        kit_state kit_state(L);
        kit_state.set("protobuf", luapb);
        luapb.set_function("pbcodec", pb_codec);
        luapb.set_function("bind_cmd", [](uint32_t cmd_id, std::string name, std::string fullname) {
            pb_cmd_indexs[name] = cmd_id;
            pb_cmd_names[name] = fullname;
            pb_cmd_ids[cmd_id] = fullname;
        });
        return luapb;
    }
}

extern "C" {
    LUALIB_API int luaopen_luapb(lua_State* L) {
        auto luapb = luapb::open_luapb(L);
        return luapb.push_stack();
    }
}
