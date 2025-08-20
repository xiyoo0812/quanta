#define LUA_LIB

#include "luapb.h"

using namespace std;
using namespace luakit;

namespace luapb {

    thread_local std::unordered_map<uint32_t, pb_message*>    pb_cmd_ids;
    thread_local std::unordered_map<std::string, pb_message*> pb_cmd_names;
    thread_local std::unordered_map<std::string, uint32_t>    pb_cmd_indexs;

    #pragma pack(1)
    struct pb_header {
        union {
            uint32_t length;
            struct {
                uint8_t flag :8;    //标志位8bit
                uint32_t len :24;   //长度24bit(16M)
            } head;
        };
        uint16_t    cmd_id;         // 协议ID
        uint16_t    session_id;     // sessionId
        uint8_t     type;           // 消息类型
        uint8_t     crc8;           // crc8
    };
    struct grpc_header {
        uint8_t compose;            //是否压缩
        uint32_t length;            //长度
    };
    #pragma pack()

    pb_message* pbmsg_from_cmdid(size_t cmd_id) {
        if (auto it = pb_cmd_ids.find(cmd_id); it != pb_cmd_ids.end()) return it->second;
        return nullptr;
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
            uint32_t len = header->head.len;
            if (len < sizeof(pb_header)) return -1;
            if (!m_slice->peek(len)) return 0;
            m_packet_len = len;
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
            header.head.flag = (uint8_t)lua_tointeger(L, index++);
            header.type = (uint8_t)lua_tointeger(L, index++);
            header.crc8 = (uint8_t)lua_tointeger(L, index++);
            //encode
            m_buf->clean();
            m_buf->hold_place(sizeof(pb_header));
            try {
                encode_message(L, index, m_buf, msg);
            } catch (const exception& e) {
                luaL_error(L, e.what());
            }
            *len = m_buf->size();
            header.head.len = *len;
            m_buf->copy(0, (uint8_t*)&header, sizeof(pb_header));
            return m_buf->head();
        }

        virtual size_t decode(lua_State* L) {
            //header
            pb_header* header = (pb_header*)m_slice->erase(sizeof(pb_header));
            //return
            int top = lua_gettop(L);
            lua_pushinteger(L, m_slice->size());
            lua_pushinteger(L, header->session_id);
            lua_pushinteger(L, header->cmd_id);
            lua_pushinteger(L, header->head.flag);
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

    class grpccodec : public codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            grpc_header* header = (grpc_header*)m_slice->peek(sizeof(grpc_header));
            if (!header) return 0;
            uint32_t len = byteswap(header->length);
            if (!m_slice->peek(len, sizeof(grpc_header))) return 0;
            m_packet_len = len + sizeof(grpc_header);
            return m_packet_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            m_buf->hold_place(sizeof(grpc_header));
            //input_type
            auto input_type = lua_tostring(L, index + 1);
            pb_message* msg = find_message(input_type);
            if (!msg) luaL_error(L, "invalid input_type: %s", input_type);
            try {
                encode_message(L, index, m_buf, msg);
            } catch (const exception& e) {
                luaL_error(L, e.what());
            }
            //header
            uint32_t size = m_buf->size() - sizeof(grpc_header);
            grpc_header header = { .compose = 0, .length = byteswap(size) };
            m_buf->copy(0, (uint8_t*)&header, sizeof(grpc_header));
            return m_buf->data(len);
        }

        virtual size_t decode(lua_State* L) {
            //output_type
            auto output_type = lua_tostring(L, -1);
            lua_pop(L, 1);
            //header
            int top = lua_gettop(L);
            grpc_header* header = (grpc_header*)m_slice->erase(sizeof(grpc_header));
            //msg
            pb_message* msg = find_message(output_type);
            if (!msg) throw lua_exception("output_type : %s not define", output_type);
            try {
                decode_message(L, m_slice, msg);
            } catch (...) {
                throw lua_exception("output_type: %s decode failed: %s", output_type, lua_tostring(L, -1));
            }
            return lua_gettop(L) - top;
        }
    };

    inline codec_base* pb_codec() {
        pbcodec* codec = new pbcodec();
        codec->set_buff(luakit::get_buff());
        return codec;
    }

    inline codec_base* grpc_codec() {
        grpccodec* codec = new grpccodec();
        codec->set_buff(luakit::get_buff());
        return codec;
    }

    int load_pb(lua_State* L) {
        size_t len;
        auto data = lua_tolstring(L, 1, &len);
        auto dslice = slice((uint8_t*)data, len);
        read_file_descriptor_set(L, &dslice);
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
        auto fslice = slice(lbuf, len);
        read_file_descriptor_set(L, &fslice);
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
            encode_message(L, 2, buf, msg);
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
        if (auto penum = find_enum(efullname); penum) {
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

    void pb_option(string_view otype, bool enable) {
        if (otype == "encode_default") {
            descriptor.encode_default = enable;
        } else if (otype == "use_mteatable") {
            descriptor.use_mteatable = enable;
        }
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
        luapb.set_function("option", pb_option);
        luapb.set_function("loadfile", load_file);
        luapb.set_function("messages", pb_messages);
        luapb.set_function("services", pb_services);
        luapb.set_function("grpccodec", grpc_codec);
        luapb.set_function("bind_cmd", [](uint32_t cmd_id, std::string name, std::string fullname) {
            if (auto message = find_message(fullname.c_str()); message) {
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
