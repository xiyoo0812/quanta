#pragma once
#include <vector>
#include <string>
#include <string.h>

#include "lua_kit.h"

#ifdef WIN32
#define strncasecmp _strnicmp
#endif

using namespace std;
using namespace luakit;

namespace lcodec {

    inline size_t       LCRLF   = 2;
    inline size_t       LCRLF2  = 4;
    inline const char*  CRLF    = "\r\n";
    inline const char*  CRLF2   = "\r\n\r\n";

    #define SC_UNKNOWN          0
    #define SC_PROTOCOL         101
    #define SC_OK               200
    #define SC_NOCONTENT        204
    #define SC_PARTIAL          206
    #define SC_OBJMOVED         302
    #define SC_BADREQUEST       400
    #define SC_FORBIDDEN        403
    #define SC_NOTFOUND         404
    #define SC_BADMETHOD        405
    #define SC_SERVERERROR      500
    #define SC_SERVERBUSY       503

    class httpcodec : public codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            return data_len;
        }

        void set_codec(codec_base* codec) {
            m_jcodec = codec;
        }

        virtual size_t decode(lua_State* L) {
            if (!m_slice) return 0;
            int top = lua_gettop(L);
            size_t osize = m_slice->size();
            string_view buf = m_slice->contents();
            parse_http_packet(L, buf);
            m_packet_len = osize - buf.size();
            m_slice->erase(m_packet_len);
            return lua_gettop(L) - top;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            //status
            format_http(L, &index);
            //headers
            lua_pushnil(L);
            while (lua_next(L, index) != 0) {
                format_http_header(lua_tostring(L, -2), lua_tostring(L, -1));
                lua_pop(L, 1);
            }
            //body
            uint8_t* body = nullptr;
            if (lua_type(L, index + 1) == LUA_TTABLE) {
                if (!m_jcodec) luaL_error(L, "http json not suppert, con't use lua table!");
                body = m_jcodec->encode(L, index + 1, len);
            }
            else {
                body = (uint8_t*)lua_tolstring(L, index + 1, len);
            }
            format_http_header("Content-Length", std::to_string(*len));
            m_buf->push_data((const uint8_t*)CRLF, LCRLF);
            m_buf->push_data(body, *len);
            return m_buf->data(len);
        }

    protected:
        virtual void format_http(lua_State* L, int* index) = 0;
        virtual void parse_http_packet(lua_State* L, string_view& buf) = 0;

        void http_parse_body(lua_State* L, string_view header, string_view& buf) {
            m_buf->clean();
            bool jsonable = false;
            bool contentlenable = false;
            slice* mslice = nullptr;
            vector<string_view> headers;
            split(header, CRLF, headers);
            lua_createtable(L, 0, 4);
            for (auto header : headers) {
                size_t pos = header.find(":");
                if (pos != string_view::npos) {
                    string_view key = header.substr(0, pos);
                    header.remove_prefix(pos + 1);
                    header.remove_prefix(header.find_first_not_of(" "));
                    if (!strncasecmp(key.data(), "Content-Length", key.size())) {
                        contentlenable = true;
                        mslice = m_buf->get_slice();
                        size_t content_size = atol(header.data());
                        if (buf.size() < content_size) {
                            throw length_error("http text not full");
                        }
                        mslice->attach((uint8_t*)buf.data(), content_size);
                        buf.remove_prefix(content_size);
                    }
                    else if (!strncasecmp(key.data(), "Transfer-Encoding", key.size()) && !strncasecmp(header.data(), "chunked", header.size())) {
                        contentlenable = true;
                        bool complate = false;
                        while (buf.size() > 0) {
                            size_t pos = buf.find(CRLF);
                            if (pos == string_view::npos) {
                                throw length_error("http text not full");
                            }
                            char* next;
                            size_t chunk_size = strtol(buf.data(), &next, 16);
                            if (chunk_size == 0) {
                                complate = true;
                                break;
                            }
                            if (buf.size() < chunk_size) {
                                throw length_error("http text not full");
                            }
                            m_buf->push_data((const uint8_t*)next + LCRLF, chunk_size);
                            buf.remove_prefix(pos + chunk_size + 2 * LCRLF);
                        }
                        if (!complate) {
                            throw length_error("http text not full");
                        }
                        mslice = m_buf->get_slice();
                    }
                    else if (!strncasecmp(key.data(), "Content-Type", key.size()) && header.find("json") != string_view::npos) {
                        jsonable = true;
                    }
                    //压栈
                    lua_pushlstring(L, key.data(), key.size());
                    lua_pushlstring(L, header.data(), header.size());
                    lua_settable(L, -3);
                }
            }
            if (!contentlenable) {
                if (!buf.empty()) {
                    mslice = m_buf->get_slice();
                    mslice->attach((uint8_t*)buf.data(), buf.size());
                    buf.remove_prefix(buf.size());
                }
            }
            if (!mslice || mslice->empty()) {
                lua_pushnil(L);
                return;
            }
            if (jsonable && m_jcodec) {
                try {
                    m_jcodec->set_slice(mslice);
                    m_jcodec->decode(L);
                } catch (...) {
                    lua_pushlstring(L, (char*)mslice->head(), mslice->size());
                }
                return;
            }
            lua_pushlstring(L, (char*)mslice->head(), mslice->size());
        }

        void format_http_header(string_view key, string_view val) {
            m_buf->push_data((uint8_t*)key.data(), key.size());
            m_buf->push_data((uint8_t*)": ", LCRLF);
            m_buf->push_data((uint8_t*)val.data(), val.size());
            m_buf->push_data((const uint8_t*)CRLF, LCRLF);
        }

        void split(string_view str, string_view delim, vector<string_view>& res) {
            size_t cur = 0;
            size_t step = delim.size();
            size_t pos = str.find(delim);
            while (pos != string_view::npos) {
                res.push_back(str.substr(cur, pos - cur));
                cur = pos + step;
                pos = str.find(delim, cur);
            }
            if (str.size() > cur) {
                res.push_back(str.substr(cur));
            }
        }
    
        string_view read_line(string_view buf) {
            size_t pos = buf.find(CRLF);
            auto ss = buf.substr(0, pos);
            buf.remove_prefix(pos + LCRLF);
            return ss;
        }

    protected:
        codec_base* m_jcodec = nullptr;
    };

    class httpdcodec : public httpcodec {
    protected:
        virtual void format_http(lua_State* L, int* index) {
            size_t status = lua_tointeger(L, (*index)++);
            switch (status) {
            case SC_OK:         m_buf->write("HTTP/1.1 200 OK\r\n"); break;
            case SC_NOCONTENT:  m_buf->write("HTTP/1.1 204 No Content\r\n"); break;
            case SC_PARTIAL:    m_buf->write("HTTP/1.1 206 Partial Content\r\n"); break;
            case SC_BADREQUEST: m_buf->write("HTTP/1.1 400 Bad Request\r\n"); break;
            case SC_OBJMOVED:   m_buf->write("HTTP/1.1 302 Moved Temporarily\r\n"); break;
            case SC_NOTFOUND:   m_buf->write("HTTP/1.1 404 Not Found\r\n"); break;
            case SC_BADMETHOD:  m_buf->write("HTTP/1.1 405 Method Not Allowed\r\n"); break;
            case SC_PROTOCOL:   m_buf->write("HTTP/1.1 101 Switching Protocols\r\n"); break;
            default: m_buf->write("HTTP/1.1 500 Internal Server Error\r\n"); break;
            }
        }

        virtual void parse_http_packet(lua_State* L, string_view& buf) {
            size_t pos = buf.find(CRLF2);
            if (pos == string_view::npos) {
                throw length_error("http text not full");
            }
            string_view header = buf.substr(0, pos);
            buf.remove_prefix(pos + LCRLF2);
            auto begining = read_line(header);
            vector<string_view> parts;
            split(begining, " ", parts);
            if (parts.size() < 2) {
                throw lua_exception("invalid http header");
            }
            //method
            lua_pushlstring(L, parts[0].data(), parts[0].size());
            //url + params
            http_parse_url(L, parts[1]);
            //header + body
            http_parse_body(L, header, buf);
        }

        void http_parse_url(lua_State* L, string_view url) {
            string_view sparams;
            size_t pos = url.find("?");
            if (pos != string_view::npos) {
                sparams = url.substr(pos + 1);
                url = url.substr(0, pos);
            }
            if (url.size() > 1 && url.back() == '/') {
                url.remove_suffix(1);
            }
            //url
            lua_pushlstring(L, url.data(), url.size());
            //params
            lua_createtable(L, 0, 4);
            if (!sparams.empty()) {
                vector<string_view> params;
                split(sparams, "&", params);
                for (string_view param : params) {
                    size_t pos = param.find("=");
                    if (pos != string_view::npos) {
                        string_view key = param.substr(0, pos);
                        param.remove_prefix(pos + 1);
                        lua_pushlstring(L, key.data(), key.size());
                        lua_pushlstring(L, param.data(), param.size());
                        lua_settable(L, -3);
                    }
                }
            }
        }
    };

    class httpccodec : public httpcodec {
    protected:
        virtual void format_http(lua_State* L, int* index)  {
            char buf[CHAR_MAX];
            const char* url = lua_tostring(L, (*index)++);
            const char* method = lua_tostring(L, (*index)++);
            int len = snprintf(buf, CHAR_MAX, "%s %s HTTP/1.1\r\n", method, url);
            m_buf->push_data((const uint8_t*)buf, len);
        }

        virtual void parse_http_packet(lua_State* L, string_view& buf) {
            size_t pos = buf.find(CRLF2);
            if (pos == string_view::npos) {
                throw length_error("http text not full");
            }
            string_view header = buf.substr(0, pos);
            buf.remove_prefix(pos + LCRLF2);
            auto begining = read_line(header);
            vector<string_view> parts;
            split(begining, " ", parts);
            if (parts.size() < 2) {
                throw lua_exception("invalid http header");
            }
            //proto
            lua_pushstring(L, "HTTP");
            //status
            string status = string(parts[1]);
            if (lua_stringtonumber(L, status.c_str()) == 0) {
                lua_pushlstring(L, status.c_str(), status.size());
            }
            //header + body
            http_parse_body(L, header, buf);
        }
    };
}


