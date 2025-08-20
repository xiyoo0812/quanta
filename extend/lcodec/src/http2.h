#pragma once
#include <format>
#include "hpack.h"

namespace lcodec {
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
            } continuation;
            struct {
                uint8_t unused_1_2  : 2;
                uint8_t end_header  : 1;    //0x04
                uint8_t padded      : 1;    //0x08
                uint8_t unused_5_8  : 4;
            } pushpromise;
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
    const size_t H2_FRAME_LEN = sizeof(h2_frame_header);

    class h2_stream {
    public:
        h2_stream(http_codec_base* codec, uint32_t id) :  stream_id(id), hcodec(codec){}
        virtual bool is_complete() = 0;
        virtual void push_packet(lua_State* L) = 0;
        virtual uint32_t encode_data_frame(lua_State* L, luabuf* buf, int index) { return 0; }
        virtual h2_frame_header* encode_header_frame(lua_State* L, h2_dynamic& sender, luabuf* buf, int* index) = 0;
        virtual bool decode_frame(lua_State* L, h2_frame_header* header, slice* slice, h2_dynamic* dynamic = nullptr) = 0;

    protected:
        uint32_t stream_id = 0;
        http_codec_base* hcodec = nullptr;
    };

    class h2g_stream :public h2_stream {
    public:
        h2g_stream() : h2_stream(nullptr, 0) {}
        bool is_complete() { return false; }
        virtual h2_frame_header* encode_header_frame(lua_State* L, h2_dynamic& sender, luabuf* buf, int* index) {
            auto type = (h2_frame_type)lua_tointeger(L, (*index)++);
            h2_frame_header* h2fh = (h2_frame_header*)buf->peek_space(H2_FRAME_LEN);
            memset(h2fh, 0, H2_FRAME_LEN);
            buf->pop_space(H2_FRAME_LEN);
            h2fh->head.type = type;
            h2fh->stream.id = 0;
            switch (type) {
            case H2_PING:
                h2fh->settings.ack = lua_toboolean(L, (*index)++);
                buf->write(lua_tointeger(L, *index));
                break;
            case H2_GOAWAY:
                buf->write<uint32_t>(lua_tointeger(L, (*index)++));
                buf->write<uint32_t>(lua_tointeger(L, (*index)++));
                buf->write(luaL_optstring(L, *index, ""));
                break;
            case H2_SETTINGS:
                if (lua_istable(L, *index)) {
                    lua_pushnil(L);
                    while (lua_next(L, -2)) {
                        buf->write<uint16_t>(lua_tointeger(L, -2));
                        buf->write<uint32_t>(lua_tointeger(L, -1));
                        lua_pop(L, 1);
                    }
                }
                break;
            }
            h2fh->head.length = byteswap<uint32_t>((buf->size() - H2_FRAME_LEN) << 8);
            return h2fh;
        }

        virtual bool decode_frame(lua_State* L, h2_frame_header* header, slice* slice, h2_dynamic* dynamic = nullptr) {
            switch (header->head.type) {
            case H2_PING:
                timestamp = slice->swap_read<uint64_t>(); break;
            case H2_WINDOW_UPDATE:
                win_size = slice->swap_read<int32_t>(); break;
            case H2_SETTINGS:
                setting_ack = header->settings.ack;
                for (int i = 0; i < slice->size() / 6; ++i) {
                    settings.emplace(slice->swap_read<uint16_t>() , slice->swap_read<uint32_t>());
                }
                break;
            case H2_GOAWAY:
                goaway_id = slice->swap_read<uint32_t>();
                goaway_code = slice->swap_read<uint32_t>();
                goaway_msg = slice->contents();
                break;
            }
            return true;
        }

        virtual void push_packet(lua_State* L) {
            int index = 1;
            lua_createtable(L, 4, 0);
            lua_pushinteger(L, stream_id);
            lua_seti(L, -2, index++);
            lua_pushboolean(L, setting_ack);
            lua_seti(L, -2, index++);
            native_to_lua(L, settings);
            lua_seti(L, -2, index++);
            lua_pushinteger(L, win_size);
            lua_seti(L, -2, index++);
            lua_pushinteger(L, timestamp);
            lua_seti(L, -2, index++);
            lua_pushinteger(L, goaway_id);
            lua_seti(L, -2, index++);
            lua_pushinteger(L, goaway_code);
            lua_seti(L, -2, index++);
            lua_pushstring(L, goaway_msg.c_str());
            lua_seti(L, -2, index++);
            settings.clear();
            timestamp = 0;
            win_size = 0;
        }
    protected:
        string goaway_msg;
        int32_t win_size = 0;
        uint32_t goaway_id = 0;
        uint32_t goaway_code = 0;
        uint64_t timestamp = 0;
        bool setting_ack = false;
        map<uint16_t, uint32_t> settings = {};
    };

    class h2c_stream :public h2_stream {
    public:
        h2c_stream(http_codec_base* codec, uint32_t id) : h2_stream(codec, id) {}
        virtual bool is_complete() { return state == H2S_CLOSED; }
        virtual h2_frame_header* encode_header_frame(lua_State* L, h2_dynamic& sender, luabuf* buf, int* index) {
            h2_frame_header* h2fh = (h2_frame_header*)buf->peek_space(H2_FRAME_LEN);
            memset(h2fh, 0, H2_FRAME_LEN);
            buf->pop_space(H2_FRAME_LEN);
            h2fh->head.type = H2_HEADES;
            h2fh->headers.end_header = 1;
            h2fh->headers.end_stream = 1;
            h2fh->stream.id = byteswap(stream_id);
            format_header(L, &sender, buf, index);
            lua_pushnil(L);
            while (lua_next(L, *index) != 0) {
                auto key = lua_tostring(L, -2);
                auto val = lua_tostring(L, -1);
                send_headers.emplace(key, val);
                encode_header(&sender, buf, key, val);
                lua_pop(L, 1);
            }
            h2fh->head.length = byteswap<uint32_t>((buf->size() - H2_FRAME_LEN) << 8);
            return h2fh;
        }

        virtual uint32_t encode_data_frame(lua_State* L, luabuf* buf, int index) {
            size_t len;
            uint8_t* body = encode_body(L, hcodec, index, &len);
            if (len > 0) {
                h2_frame_header h2df_header = {};
                h2df_header.headers.end_stream = 1;
                h2df_header.head.type = H2_DATA;
                h2df_header.head.length = byteswap<uint32_t>(len << 8);
                h2df_header.stream.id = byteswap(stream_id);
                buf->push_data((uint8_t*)&h2df_header, H2_FRAME_LEN);
                buf->push_data(body, len);
            }
            return len;
        }

        bool decode_frame(lua_State* L, h2_frame_header* header, slice* slice, h2_dynamic* dynamic = nullptr) {
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
                errorcode = slice->swap_read<uint32_t>();
                break;
            }
            return is_packet_complate();
        }
        
        virtual void push_packet(lua_State* L) {
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
                native_to_lua(L, recv_headers);
                lua_seti(L, -2, index++);
                if (!body.empty()) {
                    decode_body(L, index);
                }
            }
        }

    protected:
        virtual bool is_packet_complate () {
            return state == H2S_CLOSED;
        }

        virtual void decode_body(lua_State* L, int index) {
            if (auto codec = find_codec(hcodec, recv_headers, CONTENTT); codec) {
                codec->decode(L, (uint8_t*)body.c_str(), body.size());
                body.erase(0, codec->get_packet_len());
                lua_seti(L, -2, index);
                return;
            }
            lua_pushlstring(L, body.c_str(), body.size());
            lua_seti(L, -2, index);
        }

        virtual void format_header(lua_State* L, h2_dynamic* sender, luabuf* buf, int* index) {
            encode_header(sender, buf, ":scheme", "https");
            encode_header(sender, buf, ":path", lua_tostring(L, (*index)++));
            encode_header(sender, buf, ":method", lua_tostring(L, (*index)++));
        }

        virtual uint8_t* encode_body(lua_State* L, http_codec_base* hcodec, int index, size_t* len) {
            if (lua_type(L, index) == LUA_TTABLE) {
                auto codec = find_codec(hcodec, send_headers, CONTENTT);
                if (!codec) luaL_error(L, "http2 codec not suppert, con't use lua table!");
                return codec->encode(L, index, len);
            }
            return (uint8_t*)lua_tolstring(L, index, len);
        }

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
                if (header_complete && type == H2_CONTINUATION) throw lua_exception("invalid frame type");
                break;
            case H2S_CLOSED: throw lua_exception("invalid frame type"); break;
            };
        }

        void save_header(const string& key, const string& value) {
            if (key == ":status") { status = value; return; }
            recv_headers.emplace(key, value);
        }

        void encode_header(h2_dynamic* sender, luabuf* buf, string_view name, string_view value, bool sensitive = false) {
            auto [match_dyn, index_dyn] = get_dynamic_index(sender, name, value);
            if (sensitive) return encode_literal(buf, name, value, H2_NEVER, index_dyn);
            if (sender->capacity == 0) {
                auto [match, index] = get_static_index(name, value);
                if (match) return encode_integer(buf, 0x80, 7, index);
                return encode_literal(buf, name, value, H2_NONE, index);
            }
            if (match_dyn) return encode_integer(buf, 0x80, 7, index_dyn);
            auto [match, index] = get_static_index(name, value);
            if (match) return encode_integer(buf, 0x80, 7, index);
            encode_literal(buf, name, value, H2_INCREMENTAL, index);
            add_dynmic_header(sender, name, value);
        }

        void decode_header(h2_dynamic* recver, slice* slice, luabuf* buf) {
            while (!slice->empty()) {
                auto head = slice->head()[0];
                if ((head & 0x80) == 0x80) { //bit7
                    uint16_t index = decode_integer(slice, 7);
                    auto header = index_header(recver, index);
                    save_header(header->key, header->value);
                    continue;
                }
                if ((head & 0xc0) == 0x40) { //bit6
                    if (head == 0x40) {
                        slice->erase(1);
                        auto key = decode_string_literal(slice, buf);
                        auto val = decode_string_literal(slice, buf);
                        add_dynmic_header(recver, key, val);
                        save_header(key, val);
                        continue;
                    }
                    uint16_t index = decode_integer(slice, 6);
                    auto header = index_header(recver, index);
                    auto val = decode_string_literal(slice, buf);
                    add_dynmic_header(recver, header->key, val);
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
                    auto header = index_header(recver, index);
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

        codec_base* find_codec(http_codec_base* hcodec, map<string, string>& headers, const char* name) {
            if (headers.contains(name)) {
                return hcodec->get_content_codec(headers[name]);
            }
            return nullptr;
        }

    protected:
        string body = "";
        string status = "";
        uint32_t errorcode = 0;
        bool header_complete = false;
        h2_stream_state state = H2S_IDLE;
        map<string, string> send_headers;
        map<string, string> recv_headers;
    };

    class grpcc_stream : public h2c_stream {
    public:
        grpcc_stream(http_codec_base* codec, uint32_t id) : h2c_stream(codec, id) {}
        virtual uint8_t* encode_body(lua_State* L, http_codec_base* hcodec, int index, size_t* len) {
            if (lua_type(L, index) == LUA_TTABLE) {
                if (auto it = send_headers.find("x-grpc-input"); it != send_headers.end()) input_type = it->second;
                if (auto it = send_headers.find("x-grpc-output"); it != send_headers.end()) output_type = it->second;
                auto codec = find_codec(hcodec, send_headers, CONTENTT);
                if (!codec) luaL_error(L, "grpc codec not suppert, con't use lua table!");
                lua_pushstring(L, input_type.c_str());
                return codec->encode(L, index, len);
            }
            return (uint8_t*)lua_tolstring(L, index, len);
        }
    protected:
        virtual void decode_body(lua_State* L, int index) {
            if (auto codec = find_codec(hcodec, recv_headers, CONTENTT); codec) {
                lua_pushstring(L, output_type.c_str());
                codec->decode(L, (uint8_t*)body.c_str(), body.size());
                body.erase(0, codec->get_packet_len());
                lua_seti(L, -2, index);
            }
        }

        virtual bool is_packet_complate() {
            if (state == H2S_CLOSED) return true;
            auto codec = find_codec(hcodec, send_headers, CONTENTT);
            if (!codec) return true;
            slice slice((uint8_t*)body.c_str(), body.size());
            codec->set_slice(&slice);
            return codec->load_packet(body.size());
        }

    protected:
        string input_type = "";
        string output_type = "";
    };

    class h2d_stream :public h2c_stream {
    public:
        h2d_stream(http_codec_base* codec, uint32_t id) : h2c_stream(codec, id) {}
        virtual void push_packet(lua_State* L) {
            int index = 1;
            lua_createtable(L, 0, 8);
            lua_pushinteger(L, stream_id);
            lua_seti(L, -2, index++);
            lua_pushlstring(L, path.c_str(), path.size());
            lua_seti(L, -2, index++);
            lua_pushlstring(L, method.c_str(), method.size());
            lua_seti(L, -2, index++);
            native_to_lua(L, recv_headers);
            lua_seti(L, -2, index++);
            decode_body(L, index);
        }

    protected:
        void save_header(const string& key, const string& value) {
            if (key == ":path") { path = value; return; }
            if (key == ":method") { method = value; return; }
            recv_headers.emplace(key, value);
        }

        virtual void format_header(lua_State* L, h2_dynamic* sender, luabuf* buf, int* index) {
            encode_header(sender, buf, ":scheme", "https");
            encode_header(sender, buf, ":status", lua_tostring(L, (*index)++));
        }

    protected:
        string path = "";
        string method = "";
    };

    template <typename T>
    class http2codec : public http_codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            size_t offset = 0;
            while (offset < data_len) {
                auto header = (h2_frame_header*)m_slice->peek(H2_FRAME_LEN, offset);
                if (!header) break;
                uint32_t len = byteswap<uint32_t>(header->head.length << 8);
                auto body = m_slice->peek(len, offset + H2_FRAME_LEN);
                if (!body && len > 0) break;
                frames.push_back(tuple(slice(body, len), header));
                offset += (H2_FRAME_LEN + len);
            }
            m_packet_len = offset;
            return m_packet_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            uint32_t stream_id = lua_tointeger(L, index++);
            auto stream = get_stream(stream_id);
            h2_frame_header* h2hf = stream->encode_header_frame(L, sender, m_buf, &index);
            if (stream->encode_data_frame(L, m_buf, index + 1) > 0) {
                h2hf->headers.end_stream = 0;
            }
            return m_buf->data(len);
        }

        virtual size_t decode(lua_State* L) {
            map<uint32_t, h2_stream*> completes;
            for (auto [slice, header] : frames) {
                auto stream_id = byteswap(header->stream.id);
                h2_stream* stream = get_stream(stream_id);
                if (stream->decode_frame(L, header, &slice, &recver)){
                    completes.emplace(stream_id, stream);
                }
            }
            int index = 1;
            int top = lua_gettop(L);
            lua_createtable(L, 0, 8);
            for (auto& [stream_id, stream] : completes) {
                stream->push_packet(L);
                lua_seti(L, -2, index++);
                if (stream->is_complete()) {
                    streams.erase(stream_id);
                    delete stream;
                }
            }
            frames.clear();
            m_slice->erase(m_packet_len);
            return lua_gettop(L) - top;
        }

    protected:
        virtual h2_stream* get_stream(uint32_t id) {
            if (id == 0) return &ctrl_stream;
            if (auto it = streams.find(id); it != streams.end()) return it->second;
            auto stream = new T(this, id);
            streams.emplace(id, stream);
            return stream;
        }

    protected:
        h2_dynamic sender;
        h2_dynamic recver;
        h2g_stream ctrl_stream;
        map<uint32_t, h2_stream*> streams;
        vector<tuple<slice, h2_frame_header*>> frames;
    };
}
