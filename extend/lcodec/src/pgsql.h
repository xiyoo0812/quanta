#pragma once

#include <deque>
#include <vector>

// http://postgres.cn/docs/12/protocol-message-formats.html
namespace lcodec {
    typedef unsigned char uchar;

    // cmd constants
    enum class cmd_type_b : uchar {
        NONE                    = 0,
        AUTH                    = 'R',
        ERROR                   = 'E',
        NOTICE                  = 'N',
        NO_DATA                 = 'n',
        DATA_ROW                = 'D',
        BACKEND_KEY             = 'K',
        EMPTY_QUERY             = 'I',
        NOTIFICATION            = 'A',
        FUNCTION_CALL           = 'V',
        BIND_COMPLETE           = '2',
        CLOSE_COMPLETE          = '3',
        PARSE_COMPLETE          = '1',
        READY_FOR_QUERY         = 'Z',
        ROW_DESCRIPTION         = 'T',
        PARAMETER_STATUS        = 'S',
        COMMAND_COMPLETE        = 'C',
        PARAMETER_DESCRIPTION   = 't',
    };
    using enum cmd_type_b;

    enum class cmd_type_f : uchar {
        BIND                    = 'B',
        SYNC                    = 'S',
        CLOSE                   = 'C',
        QUERY                   = 'Q',
        PARSE                   = 'P',
        FLUSH                   = 'H',
        EXECUTE                 = 'E',
        DISCRIBE                = 'D',
        PASSWORD                = 'p',
        FUNC_CALL               = 'F',
        STARTUP                 = 'U',  // start up: FAKE CMD
    };
    using enum cmd_type_f;

    enum class auth_type_t : uint8_t {
        OK                      = 0,
        V5                      = 2,
        CLEARTEXT               = 3,
        MD5                     = 5,
        SCM                     = 6,
        GSS                     = 7,
        GSS_CONTINUE            = 8,
        SSPI                    = 9,
        SASL                    = 10,
        SASL_CONTINUE           = 11,
        SASL_FINAL              = 12,
    };
    using enum auth_type_t;
    
    //SELECT* FROM pg_type;
    enum class pg_type_t : uint16_t {
        PTUNDEFINE              = 0,
        PTBOOLEAN               = 16,
        PTBYTEA                 = 17,
        PTCHAR                  = 18,
        PTBIGINT                = 20,
        PTSMALLINT              = 21,
        PTINT                   = 23,
        PTTEXT                  = 25,
        PTFLOAT                 = 700,
        PTDOUBLE                = 701,
        PTVARCHAR               = 1043,
        PTTIMESTAMP             = 1114,
        PTDATE                  = 1082,
        PTTIME                  = 1083,
        PTNUMERIC               = 1700,
    };
    using enum pg_type_t;

    // constants
    const uint32_t PGSQL_HEADER_LEN         = 5;
    const uint32_t PROTOCOL_VERSION         = 196608;
    const uint8_t  HEADER_USER[]            = { 'u', 's', 'e', 'r', '\0' };
    const uint8_t  HEADER_DATABASE[]        = { 'd','a','t','a','b','a','s','e','\0'};

    struct pgsql_column {
        string_view name;
        pg_type_t type;
    };
    typedef vector<pgsql_column> pgsql_columns;

    class pgsqlscodec : public codec_base {
    public:
        virtual int load_packet(bool& ignore) {
            if (!m_slice) return 0;
            int offset = 0;
            bool leading = true;
            size_t total = m_slice->size();
            while (offset + PGSQL_HEADER_LEN <= total) {
                cmd_type_b cmd_type = (cmd_type_b) * (uint8_t*)m_slice->peek(1, offset);
                int32_t length = (int32_t)byteswap(*(int32_t*)m_slice->peek(4, offset + 1));
                if (length < sizeof(uint32_t)) return -1;
                int msg_len = 1 + length;
                if (offset + msg_len > total) break; 
                if (is_ignore_cmd_type(cmd_type)) {
                    offset += msg_len;
                    continue;
                }
                if (leading) {
                    leading = false;
                    if (offset > 0) {
                        ignore = true;
                        return offset;
                    }
                }
                if (is_end_type(cmd_type, offset)) {
                    ignore = false;
                    return offset + msg_len;
                }
                offset += msg_len;
            }
            if (leading && offset > 0) {
                ignore = true;
                return offset;
            }
            return 0;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            // cmd_type
            cmd_type_f cmd_type = (cmd_type_f)lua_tointeger(L, index++);
            // session_id
            size_t session_id = lua_tointeger(L, index++);
            switch (cmd_type) {
            case STARTUP:
                return encode_startup(L, session_id, index, len);
                break;
            default:
                return comand_encode(L, cmd_type, session_id, index, len);
                break;
            }
        }

        virtual size_t decode(lua_State* L) {
            if (sessions.empty()) {
                throw lua_exception("invalid pgsql data");
            }
            int top = lua_gettop(L);
            size_t session_id = sessions.front();
            lua_pushinteger(L, session_id);
            lua_pushboolean(L, true);
            sessions.pop_front();
            do {
                cmd_type_b cmd_type = recv_packet();
                switch (cmd_type) {
                case AUTH: 
                    return auth_decode(L, top);
                case ROW_DESCRIPTION:
                    row_description_decode(L);
                    break;
                case ERROR:
                    lua_settop(L, top + 1);
                    lua_pushboolean(L, false);
                    error_decode(L);
                    break;
                case COMMAND_COMPLETE:
                    command_complete_decode(L);
                    break;
                case READY_FOR_QUERY:
                    return lua_gettop(L) - top;
                default:
                    throw lua_exception("unsuppert pgsql packet type");
                }
            } while (true);
        }

    protected:
        cmd_type_b recv_packet() {
            if (m_slice->size() < PGSQL_HEADER_LEN) {
                throw length_error("pgsql text not full");
            }
            cmd_type_b cmd_type = (cmd_type_b)m_slice->swap_read();
            size_t length = m_slice->swap_read<int32_t>() - sizeof(uint32_t);
            if (uint8_t* data = m_slice->erase(length); data) {
                m_packet_len += length + PGSQL_HEADER_LEN;
                if (is_ignore_cmd_type(cmd_type))
                    return recv_packet();
                m_packet.attach(data, length);
                return cmd_type;
            }
            throw length_error("pgsql text not full");
        }

        uint8_t* comand_encode(lua_State* L, cmd_type_f cmd_type, size_t session_id, int index, size_t* len) {
            size_t data_len;
            uint8_t* query = (uint8_t*)lua_tolstring(L, index++, &data_len);
            m_buf->write<uchar>((uchar)cmd_type);
            m_buf->swap_write<uint32_t>(data_len + sizeof(uint32_t));
            m_buf->push_data(query, data_len);
            if (session_id > 0) {
                sessions.push_back(session_id);
            }
            return m_buf->data(len);
        }

        uint8_t* encode_startup(lua_State* L, size_t session_id, int index, size_t* len) {
            //4 byte header placeholder
            m_buf->write<uint32_t>(0);
            // 4 byte protocol_version
            m_buf->swap_write(PROTOCOL_VERSION);
            // username
            m_buf->push_data(HEADER_USER, sizeof(HEADER_USER));
            uint8_t* user = (uint8_t*)lua_tolstring(L, index++, len);
            m_buf->push_data(user, *len);
            m_buf->push_data((uint8_t*)"\0", 1);
            // dbname
            m_buf->push_data(HEADER_DATABASE, sizeof(HEADER_DATABASE));
            const uint8_t* dbname = (const uint8_t*)lua_tolstring(L, index++, len);
            m_buf->push_data(dbname, *len);
            m_buf->push_data((uint8_t*)"\0", 1);
            m_buf->push_data((uint8_t*)"\0", 1);
            // header
            uint32_t size = byteswap<uint32_t>(m_buf->size());
            m_buf->copy(0, (uint8_t*)&size, 4);
            // cmd
            sessions.push_back(session_id);
            return m_buf->data(len);
        }

        size_t auth_decode(lua_State* L, int top) {
            //auth type
            auto auth_type = (auth_type_t)m_packet.swap_read<int32_t>();
            //auth args
            auto auth_args = m_packet.contents();
            lua_pushinteger(L, (uint8_t)auth_type);
            lua_pushlstring(L, auth_args.data(), auth_args.size());
            if (auth_type == SASL_FINAL) {
                wait_cmd_type(AUTH);
                auto ok_auth_type = (auth_type_t)m_packet.swap_read<int32_t>();
                if (ok_auth_type != OK) {
                    throw lua_exception("invaild pgsql auth sasl final packet");
                }
                auth_type = ok_auth_type;
            }
            if (auth_type == OK) {
                auto cmdtype = recv_packet();
                if (cmdtype == ERROR) {
                    lua_settop(L, top + 1);
                    lua_pushboolean(L, false);
                    error_decode(L);
                    return lua_gettop(L) - top;
                }
                wait_cmd_type(READY_FOR_QUERY, cmdtype);
            }
            lua_pushinteger(L, (uint8_t)auth_type);
            lua_replace(L, -3);
            return lua_gettop(L) - top;
        }

        void error_decode(lua_State* L) {
            size_t len;
            std::unordered_map<uint8_t, cpchar> values;
            while (true) {
                uint8_t flag = m_packet.swap_read();
                if (flag == 0) break;
                values[flag] = read_cstring(&m_packet, len);
            }
            auto field = [&values](uint8_t flag) -> cpchar {
                auto it = values.find(flag);
                return it == values.end() ? "" : it->second;
            };
            //http://www.postgres.cn/docs/current/protocol-error-fields.html
            lua_pushfstring(L, "%s(%s): %s!", field('V'), field('C'), field('M'));
        }

        void command_complete_decode(lua_State* L) {
            size_t len;
            auto msg = read_cstring(&m_packet, len);
            lua_pushlstring(L, msg, len);
        }

        void row_description_decode(lua_State* L) {
            size_t len;
            pgsql_columns cols;
            int32_t ncol = m_packet.swap_read<int16_t>();
            for (size_t i = 0; i < ncol; ++i) {
                auto val = read_cstring(&m_packet, len);
                string_view name = string_view(val, len);
                //table id + index
                m_packet.erase(6);
                pg_type_t type = (pg_type_t)m_packet.swap_read<int32_t>();
                //typelen + atttypmod + format
                m_packet.erase(8);
                cols.push_back( pgsql_column { name, type });
            }
            //result sets
            lua_createtable(L, 0, 4);
            //result set
            size_t row_indx = 1;
            lua_createtable(L, 0, 4);
            auto cmdtype = recv_packet();
            while (cmdtype == DATA_ROW) {
                lua_createtable(L, 0, 4);
                int32_t nfield = m_packet.swap_read<int16_t>();
                for (size_t i = 0; i < nfield; ++i) {
                    auto column = cols[i];
                    int32_t dlen = m_packet.swap_read<int32_t>();
                    cpchar data = (cpchar)m_packet.erase(dlen);
                    lua_pushlstring(L, column.name.data(), column.name.size());
                    switch (column.type) {
                    case PTBOOLEAN:
                        lua_pushboolean(L, strtoll(data, nullptr, 10));
                        break;
                    case PTFLOAT:
                    case PTDOUBLE:
                    case PTNUMERIC:
                        lua_pushnumber(L, strtod(data, nullptr));
                        break;
                    case PTINT:
                    case PTCHAR:
                    case PTBIGINT:
                    case PTSMALLINT:
                        lua_pushinteger(L, strtoll(data, nullptr, 10));
                        break;
                    default:
                        lua_pushlstring(L, data, dlen);
                        break;
                    }
                    lua_settable(L, -3);
                }
                lua_seti(L, -2, row_indx++);
                cmdtype = recv_packet();
            }
            lua_seti(L, -2, 1);
            wait_cmd_type(COMMAND_COMPLETE, cmdtype);
        }

        bool is_end_type(cmd_type_b cmd, int offset) {
            if (cmd == READY_FOR_QUERY) return true;
            if (cmd == AUTH) {
                auto auth_type = (auth_type_t)byteswap(*(int32_t*)m_slice->peek(4, offset + PGSQL_HEADER_LEN));
                return auth_type != OK && auth_type != SASL_FINAL;
            }
            return false;
        }

        bool is_ignore_cmd_type(cmd_type_b cmd) {
            switch (cmd) {
                case NOTICE:
                case NO_DATA: 
                case BACKEND_KEY:
                case EMPTY_QUERY:
                case NOTIFICATION:
                case BIND_COMPLETE:
                case PARSE_COMPLETE:
                case CLOSE_COMPLETE:
                case PARAMETER_STATUS:
                case PARAMETER_DESCRIPTION: return true;
                default: return false;
            }
        }

        void wait_cmd_type(cmd_type_b target, cmd_type_b src = NONE) {
            if (src == NONE) {
                src = recv_packet();
            }
            if (src != target) {
                throw lua_exception("invaild pgsql cmd type: {}", (int)src);
            }
        }

        cpchar read_cstring(slice* slice, size_t& l) {
            size_t sz;
            cpchar dst = (cpchar)slice->data(&sz);
            for (l = 0; l < sz; ++l) {
                if (dst[l] == '\0') {
                    slice->erase(l + 1);
                    return dst;
                }
                if (l == sz - 1) throw lua_exception("invalid pgsql block : cstring");
            }
            throw lua_exception("invalid pgsql block : cstring");
            return "";
        }

    protected:
        deque<size_t> sessions;
        slice m_packet;
    };
}
