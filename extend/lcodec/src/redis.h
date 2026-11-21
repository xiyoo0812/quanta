#pragma once
#include <deque>
#include <charconv>
#include <cstdlib>

namespace lcodec {
    inline size_t   CRLF_LEN    = 2;
    inline cpchar   RDS_CRLF    = "\r\n";

    class rdscodec : public codec_base {
    public:
        virtual int load_packet() {
            if (!m_slice) return 0;
            return m_slice->size();;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            int n = lua_gettop(L);
            uint32_t session_id = lua_tointeger(L, index++);
            m_buf->write(std::format("*{}\r\n", n - index + 1));
            for (int i = index; i <= n; ++i) {
                encode_bulk_string(L, i);
            }
            m_sessions.push_back(session_id);
            return m_buf->data(len);
        }

        virtual size_t decode(lua_State* L) {
            int top = lua_gettop(L);
            size_t osize = m_slice->size();
            string_view buf = m_slice->contents();
            bool is_push = (!buf.empty() && buf[0] == '>');
            lua_pushinteger(L, is_push ? 0 : (m_sessions.empty() ? 0 : m_sessions.front()));
            parse_redis_packet(L, buf, is_push);
            bool sub_ack = is_push && is_subscribe_ack(L);
            lua_pushboolean(L, is_push);
            if (!m_sessions.empty() && (!is_push || sub_ack)) m_sessions.pop_front();
            m_packet_len = osize - buf.size();
            return lua_gettop(L) - top;
        }

        bool is_subscribe_ack(lua_State* L) {
            if (!lua_istable(L, -1)) return false;
            lua_geti(L, -1, 1);
            size_t len = 0;
            cpchar kind = lua_tolstring(L, -1, &len);
            bool result = false;
            if (kind) {
                static const string_view acks[] = {
                    string_view("subscribe"), string_view("psubscribe"),
                    string_view("unsubscribe"), string_view("punsubscribe")
                };
                for (const auto& ack : acks) {
                    if (string_view(kind, len) == ack) { result = true; break; }
                }
            }
            lua_pop(L, 1);
            return result;
        }

        void set_codec(codec_base* codec) {
            m_jcodec = codec;
        }

    protected:
        void parse_redis_value(lua_State* L, string_view line, string_view& buf, bool& is_push) {
            if (line.empty()) throw lua_exception("invalid redis format");
            switch (line[0]) {
            case '+': // simple string
                lua_pushlstring(L, line.data() + 1, line.size() - 1);
                break;
            case '-': // simple error（根级 succ=false 表达，值仍按字符串返回）
                lua_pushlstring(L, line.data() + 1, line.size() - 1);
                break;
            case ':': // integer
                lua_pushinteger(L, atoll(line.data() + 1));
                break;
            case '!': // blob error
            case '$': // blob string
                parse_redis_blob(L, line.substr(1), buf);
                break;
            case '=': // verbatim string: 跳过 "txt:" 4 字节
                parse_redis_blob(L, line.substr(1), buf, 4);
                break;
            case '*': // array
            case '~': // set
                parse_redis_array(L, line.substr(1), buf, is_push);
                break;
            case '>': // push: 协议规定只出现在根级，标记后按数组解析
                is_push = true;
                parse_redis_array(L, line.substr(1), buf, is_push);
                break;
            case '%': // map
            case '|': // attribute: 简化为 map 表
                parse_redis_map(L, line.substr(1), buf, is_push);
                break;
            case '#': // boolean
                lua_pushboolean(L, line.size() > 1 && (line[1] == 't' || line[1] == 'T'));
                break;
            case ',': // double
                lua_pushnumber(L, atof(line.data() + 1));
                break;
            case '(': // big number: 保留字符串，避免精度丢失
                lua_pushlstring(L, line.data() + 1, line.size() - 1);
                break;
            case '_': // null
                lua_pushnil(L);
                break;
            default:
                throw lua_exception("invalid redis format");
                break;
            }
        }

        void parse_redis_blob(lua_State* L, string_view line, string_view& buf, int skip = 0) {
            if (int64_t length = atoll(line.data()); length >= 0) {
                string_view nline;
                if (!read_string(buf, nline, length))
                    throw length_error("redis text not full");
                if (skip > 0 && (int64_t)nline.size() >= skip) nline.remove_prefix(skip);
                if (nline.starts_with("{")) {
                    m_jcodec->decode(L, (uint8_t*)nline.data(), nline.size());
                } else {
                    lua_pushlstring(L, nline.data(), nline.size());
                }
            } else {
                lua_pushnil(L);
            }
        }

        void parse_redis_array(lua_State* L, string_view line, string_view& buf, bool& is_push) {
            if (int64_t length = atoll(line.data()); length >= 0) {
                lua_createtable(L, (int)length, 0);
                for (int64_t i = 1; i <= length; ++i) {
                    string_view item;
                    if (!read_line(buf, item)) throw length_error("redis text not full");
                    parse_redis_value(L, item, buf, is_push);
                    lua_seti(L, -2, i);
                }
            } else {
                lua_pushnil(L);
            }
        }

        void parse_redis_map(lua_State* L, string_view line, string_view& buf, bool& is_push) {
            if (int64_t length = atoll(line.data()); length >= 0) {
                lua_createtable(L, 0, (int)length);
                for (int64_t i = 0; i < length; ++i) {
                    string_view kline;
                    if (!read_line(buf, kline)) throw length_error("redis text not full");
                    parse_redis_value(L, kline, buf, is_push);
                    string_view vline;
                    if (!read_line(buf, vline)) throw length_error("redis text not full");
                    parse_redis_value(L, vline, buf, is_push);
                    lua_rawset(L, -3);
                }
            } else {
                lua_pushnil(L);
            }
        }

        void parse_redis_packet(lua_State* L, string_view& buf, bool& is_push) {
            string_view line;
            if (!read_line(buf, line)) throw length_error("redis text not full");
            if (line.empty()) throw lua_exception("invalid redis format");
            lua_pushboolean(L, line[0] != '-' && line[0] != '!');
            parse_redis_value(L, line, buf, is_push);
        }

        bool read_line(string_view& buf, string_view& line) {
            if (size_t pos = buf.find(RDS_CRLF); pos != string_view::npos) {
                line = buf.substr(0, pos);
                buf.remove_prefix(pos + CRLF_LEN);
                return true;
            }
            return false;
        }

        bool read_string(string_view& buf, string_view& line, size_t length) {
            if (buf.size() < length + CRLF_LEN) return false;
            if (buf.compare(length, CRLF_LEN, RDS_CRLF) != 0) return false;
            line = buf.substr(0, length);
            buf.remove_prefix(length + CRLF_LEN);
            return true;
        }

        void number_encode(double value) {
            auto res = to_chars(m_buffer, m_buffer + sizeof(m_buffer), value, chars_format::general, 25);
            size_t len = res.ptr - m_buffer;
            m_buf->write(std::format("${}\r\n{}\r\n", len, string_view(m_buffer, len)));
        }

        void integer_encode(int64_t integer) {
            auto res = to_chars(m_buffer, m_buffer + sizeof(m_buffer), integer);
            size_t len = res.ptr - m_buffer;
            m_buf->write(std::format("${}\r\n{}\r\n", len, string_view(m_buffer, len)));
        }

        void string_encode(lua_State* L, int idx) {
            size_t len;
            cpchar data = lua_tolstring(L, idx, &len);
            m_buf->write(std::format("${}\r\n{}\r\n", len, string_view(data, len)));
        }

        void table_encode(lua_State* L, int idx) {
            size_t len;
            char* body = (char*)m_jcodec->encode(L, idx, &len);
            m_buf->write(std::format("${}\r\n{}\r\n", len, string_view(body, len)));
        }

        void encode_bulk_string(lua_State* L, int idx) {
            switch (lua_type(L, idx)) {
            case LUA_TSTRING:
                string_encode(L, idx);
                break;
            case LUA_TBOOLEAN:
                integer_encode(lua_toboolean(L, idx) ? 1 : 0);
                break;
            case LUA_TNUMBER:
                lua_isinteger(L, idx) ? integer_encode(lua_tointeger(L, idx)) : number_encode(lua_tonumber(L, idx));
                break;
            case LUA_TTABLE:
                table_encode(L, idx);
                break;
            default:
                m_buf->write("$-1\r\n");
                break;
            }
        }

    protected:
        char m_buffer[64];
        codec_base* m_jcodec = nullptr;
        deque<uint32_t> m_sessions;
    };
}
