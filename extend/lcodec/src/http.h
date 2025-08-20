#pragma once
#include <vector>

namespace lcodec {

    inline size_t       LCRLF       = 2;
    inline size_t       LCRLF2      = 4;
    inline size_t       LCHUNKEND   = 5;
    inline size_t       LCONTENTL   = 15;
    inline const char*  CRLF        = "\r\n";
    inline const char*  CRLF2       = "\r\n\r\n";
    inline const char*  CHUNKEND    = "0\r\n\r\n";
    inline const char*  CHUNKED     = "chunked";
    inline const char*  CONTENTT    = "Content-Type";
    inline const char*  CONTENTL    = "Content-Length";
    inline const char*  CONTENTE    = "Content-Encoding";
    inline const char*  TRANSFER    = "Transfer-Encoding";

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

    bool is_packet_complete(const char* buffer, size_t buffer_size) {
        const char* header_end = strstr(buffer, CRLF2);
        if (!header_end) {
            return false;
        }
        const char* body_start = header_end + LCRLF2;
        size_t body_size = buffer_size - (body_start - buffer);
        bool is_chunked = strstr(buffer, CHUNKED) != nullptr;
        if (is_chunked) {
            if (body_size < LCHUNKEND || memcmp(body_start + body_size - LCRLF2, CRLF2, LCRLF2) != 0) {
                return false;
            }
            const char* chunk_end = body_start + body_size - LCHUNKEND;
            while (chunk_end >= body_start) {
                if (memcmp(chunk_end, CHUNKEND, LCHUNKEND) == 0) {
                    return true;
                }
                chunk_end--;
            }
            return false;
        }
        size_t content_length = -1;
        const char* content_length_pos = strstr(buffer, CONTENTL);
        if (content_length_pos) {
            const char* value_start = content_length_pos + LCONTENTL;
            content_length = std::atoi(value_start);
            return body_size >= content_length;
        }
        return true;
    }
    
    class http_codec_base : public codec_base {
    public:
        virtual void set_content_codec(string_view type, codec_base* codec) {
            m_codecs.emplace(type, codec);
        }

        codec_base* get_content_codec(string_view content) {
            if (content.empty()) return nullptr;
            if (auto it = m_codecs.find(content.data()); it != m_codecs.end()) {
                return it->second;
            }
            return nullptr;
        }
    protected:
        map<string, codec_base*> m_codecs;
    };

    class httpcodec : public http_codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            if (!is_packet_complete((char*)m_slice->head(), data_len)) return 0;
            return data_len;
        }

        virtual void set_content_codec(string_view type, codec_base* codec) {
            m_codecs.emplace(type, codec);
        }

        virtual size_t decode(lua_State* L) {
            if (!m_slice) return 0;
            int top = lua_gettop(L);
            size_t osize = m_slice->size();
            string_view buf = m_slice->contents();
            parse_http_packet(L, buf);
            m_packet_len = osize - buf.size();
            return lua_gettop(L) - top;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            //url,method,status
            format_http(L, &index);
            //headers
            lua_pushnil(L);
            string_view content_type;
            while (lua_next(L, index) != 0) {
                format_http_header(lua_tostring(L, -2), lua_tostring(L, -1), &content_type);
                lua_pop(L, 1);
            }
            //body
            uint8_t* body = nullptr;
            if (lua_type(L, index + 1) == LUA_TTABLE) {
                auto codec = get_content_codec(content_type);
                if (!codec) luaL_error(L, "http json not suppert, con't use lua table!");
                body = codec->encode(L, index + 1, len);
            } else {
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

        void http_parse_body(lua_State* L, string_view header_buf, string_view& buf) {
            m_buffer.clear();
            lua_createtable(L, 0, 4);
            string_view contend_type;
            string_view contend_encoding;
            vector<string_view> header_strs = split(header_buf, CRLF);
            for (auto head_val : header_strs) {
                if (size_t pos = head_val.find(":"); pos != string_view::npos) {
                    size_t hpos = pos + 1;
                    string_view key = head_val.substr(0, pos);
                    while (hpos < head_val.size() && isspace(head_val[hpos])) ++hpos;
                    head_val.remove_prefix(hpos);
                    if (key.starts_with(CONTENTT)) {
                        contend_type = head_val;
                    }else if (key.starts_with(CONTENTE)) {
                        contend_encoding = head_val;
                    } else if (key.starts_with(CONTENTL)) {
                        size_t content_size = atol(head_val.data());
                        m_buffer.append(buf.data(), content_size);
                        buf.remove_prefix(content_size);
                    } else if (key.starts_with(TRANSFER) && head_val.starts_with(CHUNKED)) {
                        while (buf.size() > 0) {
                            char* next;
                            size_t pos = buf.find(CRLF);
                            size_t chunk_size = strtol(buf.data(), &next, 16);
                            if (chunk_size == 0) {
                                buf.remove_prefix(pos + 2 * LCRLF);
                                break;
                            }
                            m_buffer.append((const char*)next + LCRLF, chunk_size);
                            buf.remove_prefix(pos + chunk_size + 2 * LCRLF);
                        }
                    }
                    //压栈
                    lua_pushlstring(L, key.data(), key.size());
                    lua_pushlstring(L, head_val.data(), head_val.size());
                    lua_settable(L, -3);
                }
            }
            if (!buf.empty()) {
                m_buffer.append((const char*)buf.data(), buf.size());
                buf.remove_prefix(buf.size());
            }
            if (m_buffer.empty()) {
                lua_pushnil(L);
                return;
            }
            try {
                if (auto codec = get_content_codec(contend_encoding); codec) {
                    codec->decode(L, (uint8_t*)m_buffer.c_str(), m_buffer.size());
                    return;
                }
                if (auto codec = get_content_codec(contend_type); codec) {
                    codec->decode(L, (uint8_t*)m_buffer.c_str(), m_buffer.size());;
                    return;
                }
            } catch (...) {}
            lua_pushlstring(L, m_buffer.c_str(), m_buffer.size());
        }

        void format_http_header(string_view key, string_view val, string_view* type = nullptr) {
            if (type && key.starts_with(CONTENTT)) *type = val;
            m_buf->write(std::format("{}: {}\r\n", key, val));
        }

        vector<string_view> split(string_view str, string_view delim) {
            size_t cur = 0;
            vector<string_view> vecs;
            size_t step = delim.size();
            size_t pos = str.find(delim);
            while (pos != string_view::npos) {
                vecs.emplace_back(str.substr(cur, pos - cur));
                cur = pos + step;
                pos = str.find(delim, cur);
            }
            if (str.size() > cur) {
                vecs.emplace_back(str.substr(cur));
            }
            return vecs;
        }

        string_view read_line(string_view buf) {
            size_t pos = buf.find(CRLF);
            auto ss = buf.substr(0, pos);
            buf.remove_prefix(pos + LCRLF);
            return ss;
        }

    protected:
        string m_buffer;
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
            vector<string_view> parts = split(begining, " ");
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
            if (size_t pos = url.find("?"); pos != string_view::npos) {
                sparams = url.substr(pos + 1);
                url = url.substr(0, pos);
            }
            if (url.size() > 1 && url.ends_with('/')) {
                url.remove_suffix(1);
            }
            //url
            lua_pushlstring(L, url.data(), url.size());
            //params
            lua_createtable(L, 0, 4);
            if (!sparams.empty()) {
                vector<string_view> params = split(sparams, "&");
                for (string_view param : params) {
                    if (size_t pos = param.find("="); pos != string_view::npos) {
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
            session_id = lua_tointeger(L, (*index)++);
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
            vector<string_view> parts = split(begining, " ");
            if (parts.size() < 2) {
                throw lua_exception("invalid http header");
            }
            //session_id
            lua_pushinteger(L, session_id);
            //status
            string status = string(parts[1]);
            if (lua_stringtonumber(L, status.c_str()) == 0) {
                lua_pushlstring(L, status.c_str(), status.size());
            }
            //header + body
            http_parse_body(L, header, buf);
        }
    protected:
        uint32_t session_id = 0;
    };
}

