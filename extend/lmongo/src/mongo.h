#pragma once
#include "buffer.h"

using namespace lcodec;

namespace lmongo {

    const uint32_t OP_MSG               = 2013;
    const uint32_t MSG_CHECKSUM_PRESENT = 1 << 0;
    const uint32_t MSG_MORE_TO_COME     = 1 << 1;
    const uint32_t MSG_HEADER_LENGTH    = sizeof(int32_t) * 5 + sizeof(int8_t);

    class mongo {
    public:
        int reply(lua_State* L, const char* buf, size_t len) {
            m_buffer.reset();
            m_buffer.push_data((uint8_t*)buf, len);
            slice* slice = m_buffer.get_slice();
            int retn = reply_slice(L, slice);
            if (retn > 0) {
                const char* data = (const char*)slice->data(&len);
                lua_pushlstring(L, data, len);
                return retn + 1;
            }
            return retn;
        }

        int reply_slice(lua_State* L, slice* buf) {
            size_t data_len = buf->size();
            //erase length + request_id
            buf->erase(sizeof(uint64_t));
            int32_t response_to = read_val<int32_t>(L, buf);
            int32_t opcode = read_val<int32_t>(L, buf);
            if (opcode != OP_MSG) {
                return luaL_error(L, "Unsupported opcode:%d", opcode);
            }
            int32_t flags = read_val<int32_t>(L, buf);
            if (flags != 0) {
                if ((flags & MSG_CHECKSUM_PRESENT) != 0) {
                    return luaL_error(L, "Unsupported OP_MSG flag checksumPresent");
                }
                if ((flags ^ MSG_MORE_TO_COME) != 0) {
                    return luaL_error(L, "Unsupported OP_MSG flag:%d", flags);
                }
            }
            uint8_t payload_type = read_val<uint8_t>(L, buf);
            if (payload_type != 0) {
                return luaL_error(L, "Unsupported OP_MSG payload type: %d", payload_type);
            }
            if (data_len - MSG_HEADER_LENGTH > buf->size()) {
                return luaL_error(L, "Unsupported OP_MSG reply: >1 section");
            }
            lua_pushboolean(L, 1);
            lua_pushinteger(L, response_to);
            return 2;
        }

        int op_msg(lua_State* L) {
            size_t len;
            const char* buf = luaL_checklstring(L, 1, &len);
            uint32_t id = luaL_checknumber(L, 2);
            uint32_t flags = luaL_checknumber(L, 3);

            m_buffer.reset();
            m_buffer.push_data((uint8_t*)buf, len);
            slice* slice = op_msg_slice(L, m_buffer.get_slice(), id, flags);
            if (!slice) return 0;

            const char* data = (const char*)slice->data(&len);
            lua_pushlstring(L, data, len);
            lua_pushinteger(L, len);
            return 2;
        }

        slice* op_msg_slice(lua_State* L, slice* buf, uint32_t id, uint32_t flags) {
            if (buf->empty()) {
                luaL_error(L, "opmsg require cmd document");
                return nullptr;
            }
            m_buffer.reset();
            uint32_t data_len = MSG_HEADER_LENGTH + buf->size();
            m_buffer.write<int32_t>(data_len);
            m_buffer.write<int32_t>(id);
            m_buffer.write<int32_t>(0);
            m_buffer.write<int32_t>(OP_MSG);
            m_buffer.write<int32_t>(flags);
            m_buffer.write<int8_t>(0);
            m_buffer.push_data(buf->head(), buf->size());
            return m_buffer.get_slice();
        }

    private:
        template<typename T>
        T read_val(lua_State* L, slice* buff) {
            T value = T();
            if (buff->pop((uint8_t*)&value, sizeof(T)) == 0) {
                luaL_error(L, "decode can't unpack one value");
            }
            return value;
        }

    private:
        var_buffer m_buffer;
    };
}