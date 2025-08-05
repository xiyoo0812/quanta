#pragma once
#include <set>
#include <map>
#include <format>

#include "lua_kit.h"
#include "huffman.h"

using namespace std;
using namespace luakit;

namespace lcodec {
    enum class h2_index_type : uint8_t {
        H2_INDEX = 0,   //索引头部字段
        H2_INCREMENTAL, //增量索引字面量
        H2_NONE,        //非索引字面量
        H2_NEVER,       //永不索引字面量
    };
    using enum h2_index_type;

    enum class h2_frame_type {
        H2_DATA = 0,
        H2_HEADES,
        H2_PRIORITY,
        H2_RST_STREAM,
        H2_SETTINGS,
        H2_PUSH_PROMISE,
        H2_PING,
        H2_GOAWAY,
        H2_WINDOW_UPDATE,
        H2_CONTINUATION,
        H2_MAX,
    };
    using enum h2_frame_type;

    enum class h2_stream_state : uint8_t {
        H2S_IDLE = 0,
        H2S_OPEN,
        H2S_HALF_CLOSED,
        H2S_CLOSED,
    };
    using enum h2_stream_state;

    struct h2_header {
        uint16_t insert_c = 0;
        string key;
        string value;
        bool operator<(const h2_header& h) const { return key > h.key; }
    };
    using h2_header_vec = vector<h2_header*>;
    using h2_header_set = multiset<h2_header>;

    static inline h2_header_vec STATIC_HEADERS  = {};
    static inline h2_header_set STATIC_INDEXS   = {
            h2_header {1, ":authority"},
        h2_header {2, ":method", "GET"},
        h2_header {3, ":method", "POST"},
        h2_header {4, ":path", "/"},
        h2_header {5, ":path", "/index.html"},
        h2_header {6, ":scheme", "http"},
        h2_header {7, ":scheme", "https"},
        h2_header {8, ":status", "200"},
        h2_header {9, ":status", "204"},
        h2_header {10, ":status", "206"},
        h2_header {11, ":status", "304"},
        h2_header {12, ":status", "400"},
        h2_header {13, ":status", "404"},
        h2_header {14, ":status", "500"},
        h2_header {15, "accept-charset"},
        h2_header {16, "accept-encoding", "gzip, deflate"},
        h2_header {17, "accept-language"},
        h2_header {18, "accept-ranges"},
        h2_header {19, "accept"},
        h2_header {20, "access-control-allow-origin"},
        h2_header {21, "age"},
        h2_header {22, "allow"},
        h2_header {23, "authorization"},
        h2_header {24, "cache-control"},
        h2_header {25, "content-disposition"},
        h2_header {26, "content-encoding"},
        h2_header {27, "content-language"},
        h2_header {28, "content-length"},
        h2_header {29, "content-location"},
        h2_header {30, "content-range"},
        h2_header {31, "content-type"},
        h2_header {32, "cookie"},
        h2_header {33, "date"},
        h2_header {34, "etag"},
        h2_header {35, "expect"},
        h2_header {36, "expires"},
        h2_header {37, "from"},
        h2_header {38, "host"},
        h2_header {39, "if-match"},
        h2_header {40, "if-modified-since"},
        h2_header {41, "if-none-match"},
        h2_header {42, "if-range"},
        h2_header {43, "if-unmodified-since"},
        h2_header {44, "last-modified"},
        h2_header {45, "link"},
        h2_header {46, "location"},
        h2_header {47, "max-forwards"},
        h2_header {48, "proxy-authenticate"},
        h2_header {49, "proxy-authorization"},
        h2_header {50, "range"},
        h2_header {51, "referer"},
        h2_header {52, "refresh"},
        h2_header {53, "retry-after"},
        h2_header {54, "server"},
        h2_header {55, "set-cookie"},
        h2_header {56, "strict-transport-security"},
        h2_header {57, "transfer-encoding"},
        h2_header {58, "user-agent"},
        h2_header {59, "vary"},
        h2_header {60, "via"},
        h2_header {61, "www-authenticate"}
    };

    #pragma pack(push, 1)
    struct h2_frame_header {
        union {
            uint32_t length;
            struct {
                uint32_t length     : 24;
                h2_frame_type type  : 8;
            } head;
        };
        union {
            uint8_t flags;
            struct {
                uint8_t end_stream  : 1;    //0x01
                uint8_t unused_2_3  : 2;
                uint8_t padded      : 1;    //0x08
                uint8_t unused_5_8  : 4;
            } data;
            struct {
                uint8_t end_stream  : 1;    //0x01
                uint8_t unused_2    : 1;
                uint8_t end_header  : 1;    //0x04
                uint8_t padded      : 1;    //0x08
                uint8_t unused_5    : 1;
                uint8_t priority    : 1;    //0x20
                uint8_t unused_7_8  : 2;
            } headers;
            struct {
                uint8_t ack         : 1;    //0x1
                uint8_t unused_2_8  : 7;
            } settings;
            struct {
                uint8_t ack         : 1;    //0x1
                uint8_t unused_2_8  : 7;
            } ping;
            struct {
                uint8_t unused_1_2  : 2;
                uint8_t end_header  : 1;    //0x04
                uint8_t unused_4_8  : 5;
            } continuation ;
            struct {
                uint8_t unused_1_2  : 2;
                uint8_t end_header  : 1;    //0x04
                uint8_t padded      : 1;    //0x08
                uint8_t unused_5_8  : 4;
            } pushpromise ;
        };
        union {
            uint32_t stream_id;
            struct {
                uint32_t id         : 31;    //0x04
                uint32_t reserved   : 1;
            } stream;
        };
    };
    #pragma pack(pop)
    constexpr size_t DYNAMIC_IDX_MIN = 62;
    constexpr size_t H2_FRAME_LEN = sizeof(h2_frame_header);

    struct h2_dynamic {
        uint16_t size = 0;
        uint16_t capacity = 4096;
        uint16_t insert_count = 0;
        h2_header_vec headers;
        h2_header_set indexs;
        inline uint16_t max_index() {
            return headers.size() + DYNAMIC_IDX_MIN - 1;
        }
        inline uint16_t indexof(const h2_header& header) {
            return DYNAMIC_IDX_MIN + (insert_count - header.insert_c);
        }
    };

    inline uint32_t get_header_size(string_view name, string_view val) {
        return name.size() + val.size() + 32;
    }

    inline h2_header* index_header(h2_dynamic& dynamic, uint16_t index) {
        if (index == 0) throw lua_exception("index_header index is zero");
        if (index >= dynamic.max_index()) throw lua_exception("index_header index out of range");
        if (index < DYNAMIC_IDX_MIN) return STATIC_HEADERS[index - 1];
        return *(&dynamic.headers.back() - (index - DYNAMIC_IDX_MIN));
    }

    inline tuple<bool, uint16_t> get_dynamic_index(h2_dynamic& dynamic, string_view name, string_view val) {
        auto [b, e] = dynamic.indexs.equal_range(h2_header{ 0, string(name) });
        for (; b != e; ++b) {
            auto index = dynamic.indexof(*b);
            if(b->value == val) return tuple(true, index);
            return tuple(false, index);
        }
        return tuple(false, 0);
    }

    inline tuple<bool, uint16_t> get_static_index(h2_header_set& indexs, string_view name, string_view val) {
        auto [b, e] = indexs.equal_range(h2_header{ 0, string(name) });
        if (b != indexs.end()) {
            for (auto c = b; c != e; ++c) if (c->value == val) return tuple(true, c->insert_c);
            return tuple(false, b->insert_c);
        }
        return tuple(false, 0);
    }

    inline void encode_integer(luabuf* buf, uint8_t mask, uint8_t bit, uint32_t val) {
        uint8_t* data = buf->peek_space(5);
        uint8_t limit = (1 << bit) - 1; // 2^N - 1
        if (val < limit) {
            *data = static_cast<uint8_t>(mask | val);
            buf->pop_space(1);
            return;
        }
        size_t len = 0;
        data[len++] = static_cast<uint8_t>(mask | val);
        val -= limit;
        while (val >= 0x80) {
            data[len++] = static_cast<uint8_t>((val & 0x7F) | 0x80);
            val >>= 7;
        }
        data[len++] = static_cast<uint8_t>(val);
        buf->pop_space(len);
    }

    inline uint32_t decode_integer(slice* slice, uint8_t bits) {
        size_t len = 0;
        auto head = slice->data(&len);
        if (len == 0) throw length_error("decode_integer buffer length not engugh");
        uint8_t max = (1 << bits) - 1;
        uint8_t val = head[0] & max;
        if (val < max) {
            slice->erase(1);
            return val;
        }
        for (int i = 1; i < len; i++) {
            val |= (head[i] & 0x7f) << (7 * i);
            if ((head[i] & 0x80) == 0) {
                slice->erase(i + 1);
                return val;
            }
        }
        throw length_error("decode_integer invalid binrary");
    }

    inline void encode_string_iteral(luabuf* buf, string_view value) {
        int huffman_size = huffman_len(value);
        if (huffman_size < value.size()) {
            encode_integer(buf, 0x80, 7, huffman_size);     // H=1
            huffman_encode(buf, value, huffman_size);
        } else {
            encode_integer(buf, 0x00, 7, value.size());     // H=0
            buf->write(value);
        }
    }

    inline void encode_literal(luabuf* buf, string_view name, string_view value, h2_index_type idx_type, uint16_t index) {
        uint8_t mask, prefix_bits;
        switch (idx_type) {
        case H2_INCREMENTAL: // 01xxxxxx
            mask = 0x40; prefix_bits = 6; break;
        case H2_NONE:        // 0000xxxx
            mask = 0x00; prefix_bits = 4; break;
        case H2_NEVER:       // 0001xxxx
            mask = 0x10; prefix_bits = 4; break;
        }
        encode_integer(buf, mask, prefix_bits, index);
        if (index == 0) encode_string_iteral(buf, name);
        encode_string_iteral(buf, value);
    }

    inline string decode_string_literal(slice* slice, luabuf* buf) {
        size_t len = 0;
        auto head = slice->data(&len);
        if (len == 0) throw length_error("decode_string_iteral buffer length not engugh");
        bool huffman = (head[0] & 0x80) == 0x80;
        size_t length = decode_integer(slice, 7);
        if (len < length)  throw length_error("decode_string_iteral buffer length not engugh");
        auto data = slice->erase(length); 
        if (huffman) {
            auto decdata = buf->peek_space(length * 2);
            huffman_decode(data, length, decdata, length * 2);
            return string((char*)decdata, length);
        }
        return string((char*)data, length);
    }

    void add_dynmic_header(h2_dynamic& dynamic, string_view name, string_view val) {
        auto header_size = get_header_size(name, val);
        //若新条目大小超过当前动态表剩余空间，则​​清空整个动态表​​
        if (header_size > dynamic.capacity) {
            dynamic.size = 0;
            dynamic.insert_count = 0;
            dynamic.headers.clear();
            dynamic.indexs.clear();
            return;
        }
        // 驱逐旧条目
        size_t i = 0;
        auto& headers = dynamic.headers;
        for (; dynamic.size + header_size > dynamic.capacity; ++i) {
            auto header = headers[i];
            dynamic.size -= get_header_size(header->key, header->value);
            erase_if(dynamic.indexs, [header](auto& h) { return h.insert_c == header->insert_c; });
        }
        headers.erase(headers.begin(), headers.begin() + i);
        auto it = dynamic.indexs.insert(h2_header(++dynamic.insert_count, string(name), string(val)));
        headers.push_back((h2_header*)&*it);
        dynamic.size += header_size;
    }

    class h2_stream {
    public:
        h2_stream(uint32_t id) : stream_id(id) {}
        virtual bool is_complete() = 0;
        virtual void parse_packet(lua_State* L, codec_base* codec) {};
        virtual void parse_frame(h2_dynamic& dynamic, h2_frame_header* header, slice* slice) {};
    protected:
        uint32_t stream_id = 0;
    };

    class h2g_stream :public h2_stream {
    public:
        h2g_stream() : h2_stream(0) {}
        bool is_complete() { return true; }
        void parse_ctrl_frame(lua_State* L, h2_frame_header* header, slice* slice) {
            int index = 1;
            lua_createtable(L, 4, 0);
            lua_pushinteger(L, stream_id);
            lua_seti(L, -2, index++);
            lua_pushinteger(L, (int)header->head.type);
            lua_seti(L, -2, index++);
            switch (header->head.type) {
            case H2_SETTINGS:
                lua_pushboolean(L, header->settings.ack);
                lua_seti(L, -2, index++);
                lua_createtable(L, 0, 4);
                for (int i = 0; i < slice->size() / 6; ++i) {
                    lua_pushinteger(L, byteswap2(*slice->read<uint16_t>()));
                    lua_pushinteger(L, byteswap4(*slice->read<uint32_t>()));
                    lua_settable(L, -3);
                }
                lua_seti(L, -2, index);
                break;
            case H2_GOAWAY:
                lua_pushinteger(L, byteswap4(*slice->read<uint32_t>()));
                lua_seti(L, -2, index++);
                lua_pushinteger(L, byteswap4(*slice->read<uint32_t>()));
                lua_seti(L, -2, index++);
                slice->string(L);
                lua_seti(L, -2, index);
                break;
            case H2_PING:
                lua_pushinteger(L, byteswap8(*slice->read<uint64_t>()));
                lua_seti(L, -2, index);
                break;
            case H2_WINDOW_UPDATE:
                lua_pushinteger(L, *slice->read<int32_t>());
                lua_seti(L, -2, index);
                break;
            }
        }
    };

    class h2c_stream :public h2_stream {
    public:
        h2c_stream(uint32_t id) : h2_stream(id) {}
        bool is_complete() { return state == H2S_CLOSED; }
        void parse_packet(lua_State* L, codec_base* codec) {
            int index = 1;
            lua_createtable(L, 0, 8);
            lua_pushinteger(L, stream_id);
            lua_seti(L, -2, index++);
            lua_pushinteger(L, errorcode);
            lua_seti(L, -2, index++);
            if (errorcode <= 0) {
                if (lua_stringtonumber(L, status.c_str()) == 0) {
                    lua_pushlstring(L, status.c_str(), status.size());
                }
                lua_seti(L, -2, index++);
                parse_header_body(L, codec, index);
            }
        }

        void parse_frame(h2_dynamic& dynamic, h2_frame_header* header, slice* slice) {
            auto type = header->head.type;
            update_state(type);
            switch (type) {
            case H2_HEADES:
                decode_header(dynamic, slice, luakit::get_buff());
                if (header->headers.end_stream) state = H2S_CLOSED;
                header_complete = header->headers.end_header;
                break;
            case H2_PUSH_PROMISE:
                decode_header(dynamic, slice, luakit::get_buff());
                header_complete = header->pushpromise.end_header;
                break;
            case H2_CONTINUATION:
                decode_header(dynamic, slice, luakit::get_buff());
                header_complete = header->continuation.end_header;
                break;
            case H2_DATA:
                if (header->data.end_stream) state = H2S_CLOSED;
                body.append(slice->contents());
                break;
            case H2_RST_STREAM:
                errorcode = byteswap4(*slice->read<uint32_t>());
                break;
            }
        }

    protected:
        void update_state(h2_frame_type type) {
            if (type == H2_RST_STREAM) {
                state = H2S_CLOSED;
                return;
            }
            switch (state) {
            case H2S_IDLE:
                if (type != H2_HEADES && type != H2_PUSH_PROMISE) throw lua_exception("invalid frame type");
                state = H2S_OPEN;
                break;
            case H2S_OPEN:
            case H2S_HALF_CLOSED:
                if (type != H2_HEADES && type != H2_DATA && type != H2_CONTINUATION) throw lua_exception("invalid frame type");
                if (header_complete && type != H2_DATA) throw lua_exception("invalid frame type");
                break;
            case H2S_CLOSED: throw lua_exception("invalid frame type"); break;
            };
        }

        void parse_header_body(lua_State* L, codec_base* codec, int index) {
            if (codec) {
                try {
                    auto mslice = luakit::slice((uint8_t*)body.c_str(), body.size());
                    codec->set_slice(&mslice);
                    codec->decode(L);
                } catch (...) {
                    lua_pushlstring(L, body.c_str(), body.size());
                }
                return;
            }
            lua_pushlstring(L, body.c_str(), body.size());
            lua_seti(L, -2, index++);
            native_to_lua(L, headers);
            lua_seti(L, -2, index);
        }

        void save_header(const string& key, const string& value) {
            if (key == ":status") { status = value; return; }
            headers.insert({ key, value });
        }

        void decode_header(h2_dynamic& dynamic, slice* slice, luabuf* buf) {
            while (!slice->empty()) {
                auto head = slice->head()[0];
                if ((head & 0x80) == 0x80) { //bit7
                    uint16_t index = decode_integer(slice, 7);
                    auto header = index_header(dynamic, index);
                    save_header(header->key, header->value);
                    continue;
                }
                if ((head & 0xc0) == 0x40) { //bit6
                    if (head == 0x40) {
                        slice->erase(1);
                        auto key = decode_string_literal(slice, buf);
                        auto val = decode_string_literal(slice, buf);
                        add_dynmic_header(dynamic, key, val);
                        save_header(key, val);
                        continue;
                    }
                    uint16_t index = decode_integer(slice, 6);
                    auto header = index_header(dynamic, index);
                    auto val = decode_string_literal(slice, buf);
                    add_dynmic_header(dynamic, header->key, val);
                    save_header(header->key, val);
                    continue;
                }
                if ((head & 0xf0) == 0x0 || (head & 0xf0) == 0x10) { //bit4
                    if (head == 0x0 || head == 0x10) {
                        slice->erase(1);
                        auto key = decode_string_literal(slice, buf);
                        auto val = decode_string_literal(slice, buf);
                        save_header(key, val);
                        continue;
                    }
                    uint16_t index = decode_integer(slice, 4);
                    auto header = index_header(dynamic, index);
                    auto val = decode_string_literal(slice, buf);
                    save_header(header->key, val);
                    continue;
                }
                // if ((head & 0xe0) == 0x20) { //bit5
                //     uint16_t length = decode_integer(slice, 5);
                //     continue;
                // }
            }
        }

    protected:
        string body = "";
        string status = "";
        uint32_t errorcode = 0;
        bool header_complete = false;
        h2_stream_state state = H2S_IDLE;
        map<string, string> headers;
    };

    class h2d_stream :public h2c_stream {
    public:
        h2d_stream(uint32_t id) : h2c_stream(id) {}
        void parse_packet(lua_State* L, codec_base* codec) {
            int index = 1;
            lua_createtable(L, 0, 8);
            lua_pushinteger(L, stream_id);
            lua_seti(L, -2, index++);
            lua_pushlstring(L, path.c_str(), path.size());
            lua_seti(L, -2, index++);
            lua_pushlstring(L, method.c_str(), method.size());
            lua_seti(L, -2, index++);
            parse_header_body(L, codec, index);
        }

    protected:
        void save_header(const string& key, const string& value) {
            if (key == ":path") { path = value; return; }
            if (key == ":method") { method = value; return; }
            headers.insert({ key, value });
        }

    protected:
        string path = "";
        string method = "";
    };

    class http2codec : public codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            size_t offset = 0;
            while (offset < data_len) {
                auto header = (h2_frame_header*)m_slice->peek(H2_FRAME_LEN, offset);
                if (!header) break;
                uint32_t len = byteswap3(header->head.length);
                auto body = m_slice->peek(len, offset + H2_FRAME_LEN);
                if (!body && len > 0) break;
                frames.push_back(tuple(slice(body, len), header));
                offset += (H2_FRAME_LEN + len);
            }
            m_packet_len = offset;
            return m_packet_len;
        }

        void set_codec(codec_base* codec) {
            codec = codec;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            uint32_t stream_id = lua_tointeger(L, index++);
            if (stream_id == 0) {
                return encode_ctrl_frame(L, index, len);
            }
            h2_frame_header h2hf_header = {};
            h2hf_header.headers.end_header = 1;
            h2hf_header.head.type = H2_HEADES;
            h2hf_header.stream.id = byteswap4(stream_id);
            m_buf->hold_place(H2_FRAME_LEN);
            //url,method,status
            format_http(L, &index);
            //headers
            lua_pushnil(L);
            while (lua_next(L, index) != 0) {
                encode_header(lua_tostring(L, -2), lua_tostring(L, -1));
                lua_pop(L, 1);
            }
            //body
            uint8_t* body = nullptr;
            if (lua_type(L, index + 1) == LUA_TTABLE) {
                if (!codec) luaL_error(L, "http json not suppert, con't use lua table!");
                body = codec->encode(L, index + 1, len);
            } else {
                body = (uint8_t*)lua_tolstring(L, index + 1, len);
            }
            h2hf_header.head.length = byteswap3(m_buf->size() - H2_FRAME_LEN);
            h2hf_header.headers.end_stream = 1;
            if (*len > 0) {
                h2hf_header.headers.end_stream = 0;
                h2_frame_header h2df_header = {};
                h2df_header.headers.end_stream = 1;
                h2df_header.head.type = H2_DATA;
                h2df_header.head.length = byteswap3(*len);
                h2df_header.stream.id = byteswap4(stream_id);
                m_buf->push_data((uint8_t*)&h2df_header, H2_FRAME_LEN);
                m_buf->push_data(body, *len);
            }
            m_buf->copy(0, (uint8_t*)&h2hf_header, H2_FRAME_LEN);
            return m_buf->data(len);
        }

        virtual size_t decode(lua_State* L) {
            int index = 1;
            int top = lua_gettop(L);
            lua_pushstring(L, "HTTP2");
            lua_createtable(L, 0, 8);
            for (auto [slice, header] : frames) {
                auto stream_id = byteswap4(header->stream.id);
                if (stream_id > 0) {
                    h2_stream* stream = nullptr;
                    if (auto it = streams.find(stream_id); it != streams.end()) {
                        stream = it->second;
                    } else {
                        stream = create_stream(stream_id);
                        streams.insert({ stream_id, stream });
                    }
                    stream->parse_frame(recver, header, &slice);
                    if (stream->is_complete()) {
                        stream->parse_packet(L, codec);
                        streams.erase(stream_id);
                        lua_seti(L, -2, index++);
                        delete stream;
                    }
                } else {
                    ctrl_stream.parse_ctrl_frame(L, header, &slice);
                    lua_seti(L, -2, index++);
                }
            }
            frames.clear();
            m_slice->erase(m_packet_len);
            return lua_gettop(L) - top;
        }

    protected:
        virtual h2_stream* create_stream(uint32_t id) = 0;
        virtual void format_http(lua_State* L, int* index) = 0;
        
        uint8_t* encode_ctrl_frame(lua_State* L, int index, size_t* len) {
            m_buf->hold_place(H2_FRAME_LEN);
            auto type = (h2_frame_type)lua_tointeger(L, index++);
            h2_frame_header h2cf_header = {};
            h2cf_header.head.type = type;
            h2cf_header.stream.id = 0;
            switch (type) {
            case H2_PING:
                h2cf_header.settings.ack = lua_toboolean(L, index++);
                h2cf_header.head.length = byteswap3(8);
                m_buf->write(lua_tointeger(L, index));
                break;
            case H2_GOAWAY:
                m_buf->write<uint32_t>(lua_tointeger(L, index++));
                m_buf->write<uint32_t>(lua_tointeger(L, index++));
                m_buf->write(luaL_optlstring(L, index, "", len));
                h2cf_header.head.length = byteswap3(*len + 8);
                break;
            case H2_SETTINGS:
                if (lua_istable(L, index)) {
                    lua_pushnil(L);
                    while (lua_next(L, -2)) {
                        m_buf->write<uint16_t>(lua_tointeger(L, -2));
                        m_buf->write<uint32_t>(lua_tointeger(L, -1));
                        lua_pop(L, 1);
                    }
                    h2cf_header.head.length = byteswap3(m_buf->size() - H2_FRAME_LEN);
                }
                break;
            }
            m_buf->copy(0, (uint8_t*)&h2cf_header, H2_FRAME_LEN);
            return m_buf->data(len);
        }

        void encode_header(string_view name, string_view value, bool sensitive = false) {
            auto [match_dyn, index_dyn] = get_dynamic_index(sender, name, value);
            if (sensitive) {
                encode_literal(m_buf, name, value, H2_NEVER, index_dyn);
                return;
            }
            if (sender.capacity == 0) {
                auto [match, index] = get_static_index(STATIC_INDEXS, name, value);
                if (match) {
                    encode_integer(m_buf, 0x80, 7, index);
                } else {
                    encode_literal(m_buf, name, value, H2_NONE, index);
                }
                return;
            }
            if (match_dyn) {
                encode_integer(m_buf, 0x80, 7, index_dyn);
            } else {
                auto [match, index] = get_static_index(STATIC_INDEXS, name, value);
                if (match) {
                    encode_integer(m_buf, 0x80, 7, index);
                } else {
                    encode_literal(m_buf, name, value, H2_INCREMENTAL, index);
                    add_dynmic_header(sender, name, value);
                }
            }
        }

    protected:
        h2_dynamic sender;
        h2_dynamic recver;
        h2g_stream ctrl_stream;
        codec_base* codec = nullptr;
        map<uint32_t, h2_stream*> streams;
        vector<tuple<slice, h2_frame_header*>> frames;
    };

    class http2ccodec : public http2codec {
    protected:
        virtual void format_http(lua_State* L, int* index) {
            encode_header(":scheme", "https");
            encode_header(":path", lua_tostring(L, (*index)++));
            encode_header(":method", lua_tostring(L, (*index)++));
        }
        virtual h2_stream* create_stream(uint32_t id) {
            return new h2c_stream(id);
        }
    };

    class http2dcodec : public http2codec {
    protected:
        virtual void format_http(lua_State* L, int* index) {
            encode_header(":scheme", "https");
            encode_header(":status", lua_tostring(L, (*index)++));
        }
        virtual h2_stream* create_stream(uint32_t id) {
            return new h2d_stream(id);
        }
    };
}
