#define LUA_LIB

#include "luapb.h"

using namespace std;
using namespace luakit;

namespace luapb {

    thread_local std::map<uint32_t, pb_message*>    pb_cmd_ids;
    thread_local std::map<std::string, pb_message*> pb_cmd_names;
    thread_local std::map<std::string, uint32_t>    pb_cmd_indexs;

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

    pb_message* pbmsg_from_cmdid(size_t cmd_id) {
        auto it = pb_cmd_ids.find(cmd_id);
        if (it == pb_cmd_ids.end()) return nullptr;
        return it->second;
    }

    pb_message* pbmsg_from_stack(lua_State* L, int index, uint16_t* cmd_id = nullptr) {
        if (lua_isnumber(L, index)) {
            auto cmdid = lua_tointeger(L, index);
            auto it = pb_cmd_ids.find(cmdid);
            if (it == pb_cmd_ids.end()) luaL_error(L, "invalid pb cmd: %d", cmdid);
            if (cmd_id) *cmd_id = cmdid;
            return it->second;
        }
        if (lua_isstring(L, index)) {
            auto cmd_name = lua_tostring(L, index);
            auto it = pb_cmd_names.find(cmd_name);
            if (it == pb_cmd_names.end()) {
                if (cmd_id == nullptr) {
                    auto msg = find_message(cmd_name);
                    if (msg == nullptr) {
                        luaL_error(L, "invalid pb cmd_name: %s", cmd_name);
                    }
                    return msg;
                }
                luaL_error(L, "invalid pb cmd_name: %s", cmd_name);
            }
            if (cmd_id) *cmd_id = pb_cmd_indexs[cmd_name];
            return it->second;
        }
        return nullptr;
    }

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
            //session_id
            header.session_id = (lua_tointeger(L, index++) & 0xffff);
            //cmdid
            pb_message* msg = pbmsg_from_stack(L, index++, &header.cmd_id);
            if (msg == nullptr) luaL_error(L, "invalid pb cmd type");
            //other
            header.flag = (uint8_t)lua_tointeger(L, index++);
            header.type = (uint8_t)lua_tointeger(L, index++);
            header.crc8 = (uint8_t)lua_tointeger(L, index++);
            //encode
            auto buf = luakit::get_buff();
            buf->clean();
            buf->hold_place(sizeof(pb_header));
            try {
                encode_message(L, buf, msg);
            } catch (const exception& e) {
                luaL_error(L, e.what());
            }
            *len = buf->size();
            header.len = *len;
            buf->copy(0, (uint8_t*)&header, sizeof(pb_header));
            return buf->head();
        }

        virtual size_t decode(lua_State* L) {
            //header
            pb_header* header = (pb_header*)m_slice->erase(sizeof(pb_header));
            //return
            int top = lua_gettop(L);
            lua_pushinteger(L, m_slice->size());
            lua_pushinteger(L, header->session_id);
            lua_pushinteger(L, header->cmd_id);
            lua_pushinteger(L, header->flag);
            lua_pushinteger(L, header->type);
            lua_pushinteger(L, header->crc8);
            //cmd_id
            pb_message* msg = pbmsg_from_cmdid(header->cmd_id);
            if (msg == nullptr) {
                throw lua_exception("pb message not define cmd: %d", header->cmd_id);
            }
            try {
                decode_message(L, m_slice, msg);
            } catch (...) {
                throw lua_exception("decode pb cmdid: %d failed: %s", header->cmd_id, lua_tostring(L, -1));
            }
            return lua_gettop(L) - top;
        }
    };

    inline codec_base* pb_codec() {
        pbcodec* codec = new pbcodec();
        codec->set_buff(luakit::get_buff());
        return codec;
    }

    int load_pb(lua_State* L) {
        size_t len;
        auto data = (uint8_t*)lua_tolstring(L, 1, &len);
        auto buf = luakit::get_buff();
        buf->push_data(data, len);
        read_file_descriptor_set(buf->get_slice());
        lua_pushboolean(L, 1);
        return 1;
    }

    int load_file(lua_State* L, const char* filename) {
        FILE* fp = fopen(filename, "rb");
        if (!fp) return 0;
        auto buf = luakit::get_buff();
        auto len = filesystem::file_size(filename);
        auto lbuf = buf->peek_space(len);
        fread(lbuf, 1, len, fp);
        buf->pop_space(len);
        read_file_descriptor_set(buf->get_slice());
        lua_pushboolean(L, 1);
        fclose(fp);
        return 1;
    }

    int pb_encode(lua_State* L) {
        auto cmd_name = lua_tostring(L, 1);
        auto msg = find_message(cmd_name);
        if (msg == nullptr) luaL_error(L, "invalid pb cmd type");
        auto buf = luakit::get_buff();
        buf->clean();
        try {
            encode_message(L, buf, msg);
        } catch (const exception& e){
            luaL_error(L, e.what());
        }
        lua_pushlstring(L, (char*)buf->head(), buf->size());
        return 1;
    }

    int pb_decode(lua_State* L) {
        size_t len;
        auto cmd_name = lua_tostring(L, 1);
        auto msg = find_message(cmd_name);
        auto val = (uint8_t*)lua_tolstring(L, 2, &len);
        slice s = slice(val, len);
        try {
            decode_message(L, &s, msg);
        } catch (const exception& e) {
            luaL_error(L, e.what());
        }
        return 1;
    }

    int pb_enum_id(lua_State* L) {
        auto efullname = lua_tostring(L, 1);
        auto penum = find_enum(efullname);
        if (penum) {
            if (lua_isstring(L, 2)) {
                auto key = lua_tostring(L, 2);
                auto it = penum->kvpair.find(key);
                if (it != penum->kvpair.end()) {
                    lua_pushinteger(L, it->second);
                    return 1;
                }
            }
            if (lua_isnumber(L, 2)) {
                int32_t key = lua_tointeger(L, 2);
                auto it = penum->vkpair.find(key);
                if (it != penum->vkpair.end()) {
                    lua_pushlstring(L, it->second.data(), it->second.size());
                    return 1;
                }
            }
        }
        return 0;
    }

    luakit::lua_table open_luapb(lua_State* L) {
        kit_state kit_state(L);
        lua_table luapb = kit_state.new_table("protobuf");
        luapb.set_function("load", load_pb);
        luapb.set_function("enum", pb_enum_id);
        luapb.set_function("enums", pb_enums);
        luapb.set_function("clear", pb_clear);
        luapb.set_function("decode", pb_decode);
        luapb.set_function("encode", pb_encode);
        luapb.set_function("pbcodec", pb_codec);
        luapb.set_function("fields", pb_fields);
        luapb.set_function("loadfile", load_file);
        luapb.set_function("messages", pb_messages);
        luapb.set_function("bind_cmd", [](uint32_t cmd_id, std::string name, std::string fullname) {
            auto message = find_message(fullname.c_str());
            if (message) {
                pb_cmd_names[name] = message;
                pb_cmd_ids[cmd_id] = message;
                pb_cmd_indexs[name] = cmd_id;
            }
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
