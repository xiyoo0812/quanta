#pragma once

#include <deque>
#include <vector>
#include "lua_kit.h"

using namespace std;
using namespace luakit;

// http://postgres.cn/docs/12/protocol-message-formats.html
namespace lcodec {
    typedef unsigned char uchar;

    // cmd constants
    enum class cmd_type_b : uchar {
        null                    = 0,
        auth                    = 'R',
        error                   = 'E',
        notice                  = 'N',
        no_data                 = 'n',
        data_row                = 'D',
        backend_key             = 'K',
        empty_query             = 'I',
        notification            = 'A',
        function_call           = 'V',
        bind_complete           = '2',
        close_complete          = '3',
        parse_complete          = '1',
        ready_for_query         = 'Z',
        row_description         = 'T',
        parameter_status        = 'S',
        command_complete        = 'C',
        parameter_description   = 't',
    };

    enum class cmd_type_f : uchar {
        bind                    = 'B',
        sync                    = 'S',
        close                   = 'C',
        query                   = 'Q',
        parse                   = 'P',
        flush                   = 'H',
        execute                 = 'E',
        discribe                = 'D',
        password                = 'p',
        function_call           = 'F',
        startup                 = 'U',  // start up: FAKE CMD
    };

    enum class auth_type_t : uint8_t {
        ok                      = 0,
        v5                      = 2,
        cleartext               = 3,
        md5                     = 5,
        scm                     = 6,
        gss                     = 7,
        gss_continue            = 8,
        sspi                    = 9,
        sasl                    = 10,
        sasl_continue           = 11,
        sasl_final              = 12,
    };
    
    //SELECT* FROM pg_type;
    enum class pg_type_t : uint16_t {
        tundefine               = 0,
        tboolean                = 16,
        tbytea                  = 17,
        tchar                   = 18,
        tbigint                 = 20,
        tsmallint               = 21,
        tint                    = 23,
        ttext                   = 25,
        tfloat                  = 700,
        tdouble                 = 701,
        tvarchar                = 1043,
        ttimestamp              = 1114,
        tdate                   = 1082,
        ttime                   = 1083,
        tnumeric                = 1700,
    };

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
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            if (data_len < PGSQL_HEADER_LEN) return 0;
            return data_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            // cmd_type
            cmd_type_f cmd_type = (cmd_type_f)lua_tointeger(L, index++);
            // session_id
            size_t session_id = lua_tointeger(L, index++);
            switch (cmd_type) {
            case cmd_type_f::startup:
                return encode_startup(L, session_id, index, len);
                break;
            default:
                return comand_encode(L, cmd_type, session_id, index, len);
                break;
            }
        }

        virtual size_t decode(lua_State* L) {
            size_t osize = m_slice->size();
            if (check_idle_cmd_type()) {
                m_packet_len = osize - m_slice->size();
                throw length_error("pgsql empty packet");
            }
            int top = lua_gettop(L);
            if (sessions.empty()) {
                throw lua_exception("invalid pgsql data");
            }
            cmd_type_b cmd_type = recv_packet();
            size_t session_id = sessions.front();
            lua_pushinteger(L, session_id);
            lua_pushboolean(L, cmd_type != cmd_type_b::error);
            if (cmd_type != cmd_type_b::auth) {
                command_decode(L, cmd_type);
            } else {
                auth_decode(L);
            }
            sessions.pop_front();
            m_packet_len = osize - m_slice->size();
            return lua_gettop(L) - top;
        }

    protected:
        cmd_type_b recv_packet() {
            if (m_slice->size() < PGSQL_HEADER_LEN) {
                throw length_error("pgsql text not full");
            }
            cmd_type_b cmd_type = (cmd_type_b)read_uint8(m_slice);
            size_t length = read_int32(m_slice) - sizeof(uint32_t);
            uint8_t* data = m_slice->erase(length);
            if (!data) {
                throw length_error("pgsql text not full");
            }
            m_packet.attach(data, length);
            return cmd_type;
        }

        uint8_t* comand_encode(lua_State* L, cmd_type_f cmd_type, size_t session_id, int index, size_t* len) {
            size_t data_len;
            uint8_t* query = (uint8_t*)lua_tolstring(L, index++, &data_len);
            m_buf->write<uchar>((uchar)cmd_type);
            m_buf->write<uint32_t>(byteswap4(data_len + sizeof(uint32_t)));
            m_buf->push_data(query, data_len);
            if (session_id > 0) sessions.push_back(session_id);
            return m_buf->data(len);
        }

        uint8_t* encode_startup(lua_State* L, size_t session_id, int index, size_t* len) {
            //4 byte header placeholder
            m_buf->write<uint32_t>(0);
            // 4 byte protocol_version
            m_buf->write<uint32_t>(byteswap4(PROTOCOL_VERSION));
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
            uint32_t size = byteswap4(m_buf->size());
            m_buf->copy(0, (uint8_t*)&size, 4);
            // cmd
            sessions.push_back(session_id);
            return m_buf->data(len);
        }

        void command_decode(lua_State* L, cmd_type_b cmd) {
            switch (cmd) {
            case cmd_type_b::empty_query:
            case cmd_type_b::close_complete:
            case cmd_type_b::parse_complete:
            case cmd_type_b::notification:
            case cmd_type_b::function_call:
                break;
            case cmd_type_b::error:
            case cmd_type_b::notice:
                return notice_error_decode(L);
            case cmd_type_b::row_description:
                return row_description_decode(L);
            case cmd_type_b::command_complete:
                return command_complete_decode(L);
            default: throw lua_exception("unsuppert pgsql packet type");
            }
        }

        void auth_decode(lua_State* L) {
            //auth type
            auto auth_type = (auth_type_t)read_int32(&m_packet);
            //auth args
            auto auth_args = m_packet.contents();
            lua_pushinteger(L, (uint8_t)auth_type);
            lua_pushlstring(L, auth_args.data(), auth_args.size());
            if (auth_type == auth_type_t::sasl_final) {
                wait_cmd_type(cmd_type_b::auth);
                auto ok_auth_type = (auth_type_t)read_int32(&m_packet);
                if (ok_auth_type != auth_type_t::ok) {
                    throw lua_exception("invaild pgsql auth sasl final packet");
                }
                auth_type = ok_auth_type;
            }
            if (auth_type == auth_type_t::ok) {
                auto cmdtype = recv_packet();
                if (cmdtype == cmd_type_b::error) {
                    lua_pop(L, 3);
                    lua_pushboolean(L, false);
                    notice_error_decode(L);
                    return;
                }
                lua_pushinteger(L, (uint8_t)auth_type);
                lua_replace(L, -3);
                lua_createtable(L, 4, 0);
                while (cmdtype == cmd_type_b::parameter_status) {
                    parameter_status_decode(L);
                    lua_settable(L, -3);
                    cmdtype = recv_packet();
                }
                wait_cmd_type(cmd_type_b::backend_key, cmdtype);
                backend_key_decode(L);
                return;
            }
        }

        void parameter_status_decode(lua_State* L) {
            size_t len;
            //被报告的运行时参数的名字
            auto name = read_cstring(&m_packet, len);
            lua_pushlstring(L, name, len);
            //参数的当前值
            auto value = read_cstring(&m_packet, len);
            lua_pushlstring(L, value, len);
        }

        void backend_key_decode(lua_State* L) {
            //后端的进程号
            lua_pushinteger(L, read_int32(&m_packet));
            //此后端的密钥
            lua_pushinteger(L, read_int32(&m_packet));
        }

        void notice_error_decode(lua_State* L) {
            size_t len;
            std::unordered_map<uint8_t, const char*> values;
            while (true) {
                uint8_t flag = read_uint8(&m_packet);
                if (flag == 0) break;
                values[flag] = read_cstring(&m_packet, len);
            }
            //http://www.postgres.cn/docs/current/protocol-error-fields.html
            lua_pushfstring(L, "%s(%s): %s!\0",  values['V'], values['C'], values['M']);
        }

        void command_complete_decode(lua_State* L) {
            size_t len;
            //命令标记。它通常是一个单字，标识被完成的SQL命令。
            auto msg = read_cstring(&m_packet, len);
            lua_pushlstring(L, msg, len);
        }

        void row_description_decode(lua_State* L) {
            size_t len;
            pgsql_columns cols;
            int32_t ncol = read_int16(&m_packet);
            for (size_t i = 0; i < ncol; ++i) {
                auto val = read_cstring(&m_packet, len);
                string_view name = string_view(val, len);
                //table id + index
                m_packet.erase(6);
                pg_type_t type = (pg_type_t)read_int32(&m_packet);
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
            while (cmdtype == cmd_type_b::data_row) {
                lua_createtable(L, 0, 4);
                int32_t nfield = read_int16(&m_packet);
                for (size_t i = 0; i < nfield; ++i) {
                    auto column = cols[i];
                    int32_t dlen = read_int32(&m_packet);
                    const char* data = (const char*)m_packet.erase(dlen);
                    lua_pushlstring(L, column.name.data(), column.name.size());
                    switch (column.type) {
                    case pg_type_t::tboolean:
                        lua_pushboolean(L, strtoll(data, nullptr, 10));
                        break;
                    case pg_type_t::tfloat:
                    case pg_type_t::tdouble:
                    case pg_type_t::tnumeric:
                        lua_pushnumber(L, strtod(data, nullptr));
                        break;
                    case pg_type_t::tint:
                    case pg_type_t::tchar:
                    case pg_type_t::tbigint:
                    case pg_type_t::tsmallint:
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
            wait_cmd_type(cmd_type_b::command_complete, cmdtype);
        }

        bool check_idle_cmd_type() {
            if (m_slice->size() > PGSQL_HEADER_LEN) {
                auto cmd =  *(cmd_type_b*)m_slice->peek(1);
                if (cmd == cmd_type_b::ready_for_query || cmd == cmd_type_b::bind_complete
                    || cmd == cmd_type_b::parameter_description || cmd == cmd_type_b::no_data) {
                    auto len = byteswap4(*(int32_t*)m_slice->peek(sizeof(int32_t), 1));
                    m_slice->erase(len + 1);
                    return true;
                }
            }
            return false;
        }

        void wait_cmd_type(cmd_type_b target, cmd_type_b src = cmd_type_b::null) {
            if (src == cmd_type_b::null) {
                src = recv_packet();
            }
            if (src != target) {
                throw lua_exception("invaild pgsql cmd type: %d", src);
            }
        }

        const char* read_cstring(slice* slice, size_t& l) {
            size_t sz;
            const char* dst = (const char*)slice->data(&sz);
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

        int32_t read_int32(slice* slice) {
            return byteswap4(*(int32_t*)slice->read<int32_t>());
        }

        int16_t read_int16(slice* slice) {
            return byteswap2(*(int16_t*)slice->read<int16_t>());
        }

        uint8_t read_uint8(slice* slice) {
            return *(uint8_t*)slice->read<uint8_t>();
        }

    protected:
        deque<size_t> sessions;
        slice m_packet;
    };
}
