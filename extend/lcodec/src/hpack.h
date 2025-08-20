#pragma once
#include <set>
#include <map>

using namespace std;

namespace lcodec {

    enum class h2_index_type : uint8_t {
        H2_INDEX = 0,   //索引头部字段
        H2_INCREMENTAL, //增量索引字面量
        H2_NONE,        //非索引字面量
        H2_NEVER,       //永不索引字面量
    };
    using enum h2_index_type;

    struct huffman_symbol {
        int nbits;
        uint32_t code;
    };

    struct huffman_node {
        struct huffman_node* children[256];
        unsigned char sym;
        unsigned int code;
        int code_len;
        int size;
    };
    static huffman_node HUFFMAN_ROOT;

    struct h2_header {
        uint16_t insert_c = 0;
        string key;
        string value;
    };
    inline bool case_insensitive_equal(string_view a, string_view b) {
        return a.size() == b.size() && std::equal(a.begin(), a.end(), b.begin(), [](char c1, char c2) {
            return tolower(c1) == tolower(static_cast<uint8_t>(c2));
        });
    }
    struct case_insensitive_comparator {
        bool operator()(const h2_header& h1, const h2_header& h2) const {
            return lexicographical_compare(h1.key.begin(), h1.key.end(), h2.key.begin(), h2.key.end(), [](char c1, char c2) {
                return tolower(static_cast<uint8_t>(c1)) < tolower(static_cast<uint8_t>(c2));
            });
        }
    };

    using h2_header_vec = vector<h2_header*>;
    using h2_header_set = multiset<h2_header, case_insensitive_comparator>;

    const size_t DYNAMIC_IDX_MIN = 62;
    static inline h2_header_vec STATIC_HEADERS = {};
    static inline h2_header_set STATIC_INDEXS = {
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
        h2_header {15, "Accept-Charset"},
        h2_header {16, "Accept-Encoding", "gzip, deflate"},
        h2_header {17, "Accept-Language"},
        h2_header {18, "Accept-Ranges"},
        h2_header {19, "Accept"},
        h2_header {20, "Access-Control-Allow-Origin"},
        h2_header {21, "Age"},
        h2_header {22, "Allow"},
        h2_header {23, "Authorization"},
        h2_header {24, "Cache-Control"},
        h2_header {25, "Content-Disposition"},
        h2_header {26, "Content-Encoding"},
        h2_header {27, "Content-Language"},
        h2_header {28, "Content-Length"},
        h2_header {29, "Content-Location"},
        h2_header {30, "Content-Range"},
        h2_header {31, "Content-Type"},
        h2_header {32, "Cookie"},
        h2_header {33, "Date"},
        h2_header {34, "Etag"},
        h2_header {35, "Expect"},
        h2_header {36, "Expires"},
        h2_header {37, "From"},
        h2_header {38, "Host"},
        h2_header {39, "If-Match"},
        h2_header {40, "If-Modified-Since"},
        h2_header {41, "If-none-Match"},
        h2_header {42, "If-Range"},
        h2_header {43, "If-Unmodified-Since"},
        h2_header {44, "Last-Modified"},
        h2_header {45, "Link"},
        h2_header {46, "Location"},
        h2_header {47, "Max-Forwards"},
        h2_header {48, "Proxy-Authenticate"},
        h2_header {49, "Proxy-Authorization"},
        h2_header {50, "Range"},
        h2_header {51, "Referer"},
        h2_header {52, "Refresh"},
        h2_header {53, "Retry-After"},
        h2_header {54, "Server"},
        h2_header {55, "Set-Cookie"},
        h2_header {56, "Strict-Transport-Security"},
        h2_header {57, "Transfer-Encoding"},
        h2_header {58, "User-Agent"},
        h2_header {59, "Vary"},
        h2_header {60, "Via"},
        h2_header {61, "Www-Authenticate"}
    };

    static const huffman_symbol huffman_code[]{
        {13, 0x1ff8},
        {23, 0x7fffd8},
        {28, 0xfffffe2},
        {28, 0xfffffe3},
        {28, 0xfffffe4},
        {28, 0xfffffe5},
        {28, 0xfffffe6},
        {28, 0xfffffe7},
        {28, 0xfffffe8},
        {24, 0xffffea},
        {30, 0x3ffffffc},
        {28, 0xfffffe9},
        {28, 0xfffffea},
        {30, 0x3ffffffd},
        {28, 0xfffffeb},
        {28, 0xfffffec},
        {28, 0xfffffed},
        {28, 0xfffffee},
        {28, 0xfffffef},
        {28, 0xffffff0},
        {28, 0xffffff1},
        {28, 0xffffff2},
        {30, 0x3ffffffe},
        {28, 0xffffff3},
        {28, 0xffffff4},
        {28, 0xffffff5},
        {28, 0xffffff6},
        {28, 0xffffff7},
        {28, 0xffffff8},
        {28, 0xffffff9},
        {28, 0xffffffa},
        {28, 0xffffffb},
        {6, 0x14},
        {10, 0x3f8},
        {10, 0x3f9},
        {12, 0xffa},
        {13, 0x1ff9},
        {6, 0x15},
        {8, 0xf8},
        {11, 0x7fa},
        {10, 0x3fa},
        {10, 0x3fb},
        {8, 0xf9},
        {11, 0x7fb},
        {8, 0xfa},
        {6, 0x16},
        {6, 0x17},
        {6, 0x18},
        {5, 0x0},
        {5, 0x1},
        {5, 0x2},
        {6, 0x19},
        {6, 0x1a},
        {6, 0x1b},
        {6, 0x1c},
        {6, 0x1d},
        {6, 0x1e},
        {6, 0x1f},
        {7, 0x5c},
        {8, 0xfb},
        {15, 0x7ffc},
        {6, 0x20},
        {12, 0xffb},
        {10, 0x3fc},
        {13, 0x1ffa},
        {6, 0x21},
        {7, 0x5d},
        {7, 0x5e},
        {7, 0x5f},
        {7, 0x60},
        {7, 0x61},
        {7, 0x62},
        {7, 0x63},
        {7, 0x64},
        {7, 0x65},
        {7, 0x66},
        {7, 0x67},
        {7, 0x68},
        {7, 0x69},
        {7, 0x6a},
        {7, 0x6b},
        {7, 0x6c},
        {7, 0x6d},
        {7, 0x6e},
        {7, 0x6f},
        {7, 0x70},
        {7, 0x71},
        {7, 0x72},
        {8, 0xfc},
        {7, 0x73},
        {8, 0xfd},
        {13, 0x1ffb},
        {19, 0x7fff0},
        {13, 0x1ffc},
        {14, 0x3ffc},
        {6, 0x22},
        {15, 0x7ffd},
        {5, 0x3},
        {6, 0x23},
        {5, 0x4},
        {6, 0x24},
        {5, 0x5},
        {6, 0x25},
        {6, 0x26},
        {6, 0x27},
        {5, 0x6},
        {7, 0x74},
        {7, 0x75},
        {6, 0x28},
        {6, 0x29},
        {6, 0x2a},
        {5, 0x7},
        {6, 0x2b},
        {7, 0x76},
        {6, 0x2c},
        {5, 0x8},
        {5, 0x9},
        {6, 0x2d},
        {7, 0x77},
        {7, 0x78},
        {7, 0x79},
        {7, 0x7a},
        {7, 0x7b},
        {15, 0x7ffe},
        {11, 0x7fc},
        {14, 0x3ffd},
        {13, 0x1ffd},
        {28, 0xffffffc},
        {20, 0xfffe6},
        {22, 0x3fffd2},
        {20, 0xfffe7},
        {20, 0xfffe8},
        {22, 0x3fffd3},
        {22, 0x3fffd4},
        {22, 0x3fffd5},
        {23, 0x7fffd9},
        {22, 0x3fffd6},
        {23, 0x7fffda},
        {23, 0x7fffdb},
        {23, 0x7fffdc},
        {23, 0x7fffdd},
        {23, 0x7fffde},
        {24, 0xffffeb},
        {23, 0x7fffdf},
        {24, 0xffffec},
        {24, 0xffffed},
        {22, 0x3fffd7},
        {23, 0x7fffe0},
        {24, 0xffffee},
        {23, 0x7fffe1},
        {23, 0x7fffe2},
        {23, 0x7fffe3},
        {23, 0x7fffe4},
        {21, 0x1fffdc},
        {22, 0x3fffd8},
        {23, 0x7fffe5},
        {22, 0x3fffd9},
        {23, 0x7fffe6},
        {23, 0x7fffe7},
        {24, 0xffffef},
        {22, 0x3fffda},
        {21, 0x1fffdd},
        {20, 0xfffe9},
        {22, 0x3fffdb},
        {22, 0x3fffdc},
        {23, 0x7fffe8},
        {23, 0x7fffe9},
        {21, 0x1fffde},
        {23, 0x7fffea},
        {22, 0x3fffdd},
        {22, 0x3fffde},
        {24, 0xfffff0},
        {21, 0x1fffdf},
        {22, 0x3fffdf},
        {23, 0x7fffeb},
        {23, 0x7fffec},
        {21, 0x1fffe0},
        {21, 0x1fffe1},
        {22, 0x3fffe0},
        {21, 0x1fffe2},
        {23, 0x7fffed},
        {22, 0x3fffe1},
        {23, 0x7fffee},
        {23, 0x7fffef},
        {20, 0xfffea},
        {22, 0x3fffe2},
        {22, 0x3fffe3},
        {22, 0x3fffe4},
        {23, 0x7ffff0},
        {22, 0x3fffe5},
        {22, 0x3fffe6},
        {23, 0x7ffff1},
        {26, 0x3ffffe0},
        {26, 0x3ffffe1},
        {20, 0xfffeb},
        {19, 0x7fff1},
        {22, 0x3fffe7},
        {23, 0x7ffff2},
        {22, 0x3fffe8},
        {25, 0x1ffffec},
        {26, 0x3ffffe2},
        {26, 0x3ffffe3},
        {26, 0x3ffffe4},
        {27, 0x7ffffde},
        {27, 0x7ffffdf},
        {26, 0x3ffffe5},
        {24, 0xfffff1},
        {25, 0x1ffffed},
        {19, 0x7fff2},
        {21, 0x1fffe3},
        {26, 0x3ffffe6},
        {27, 0x7ffffe0},
        {27, 0x7ffffe1},
        {26, 0x3ffffe7},
        {27, 0x7ffffe2},
        {24, 0xfffff2},
        {21, 0x1fffe4},
        {21, 0x1fffe5},
        {26, 0x3ffffe8},
        {26, 0x3ffffe9},
        {28, 0xffffffd},
        {27, 0x7ffffe3},
        {27, 0x7ffffe4},
        {27, 0x7ffffe5},
        {20, 0xfffec},
        {24, 0xfffff3},
        {20, 0xfffed},
        {21, 0x1fffe6},
        {22, 0x3fffe9},
        {21, 0x1fffe7},
        {21, 0x1fffe8},
        {23, 0x7ffff3},
        {22, 0x3fffea},
        {22, 0x3fffeb},
        {25, 0x1ffffee},
        {25, 0x1ffffef},
        {24, 0xfffff4},
        {24, 0xfffff5},
        {26, 0x3ffffea},
        {23, 0x7ffff4},
        {26, 0x3ffffeb},
        {27, 0x7ffffe6},
        {26, 0x3ffffec},
        {26, 0x3ffffed},
        {27, 0x7ffffe7},
        {27, 0x7ffffe8},
        {27, 0x7ffffe9},
        {27, 0x7ffffea},
        {27, 0x7ffffeb},
        {28, 0xffffffe},
        {27, 0x7ffffec},
        {27, 0x7ffffed},
        {27, 0x7ffffee},
        {27, 0x7ffffef},
        {27, 0x7fffff0},
        {26, 0x3ffffee},
        {30, 0x3fffffff},
    };

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
    
    inline int huffman_add_node(unsigned char sym, int code, int code_len){
        huffman_node *cur = &HUFFMAN_ROOT;
        for(; code_len > 8;){
            code_len -= 8;
            unsigned char i = (unsigned char)(code >> code_len);
            if(!cur->children[i]) cur->children[i] = new huffman_node();
            cur = cur->children[i];
        }
        int shift = (8 - code_len);
        int end	  = (1 << shift);
        int start = (unsigned char)(code << shift);
        for(int j = start; j < start + end; j++){
            if(!cur->children[j]) cur->children[j] = new huffman_node();
            cur->children[j]->sym = sym;
            cur->children[j]->code = code;
            cur->children[j]->code_len = code_len;
            cur->size++;
        }
        return 0;
    }

    inline int huffman_len(string_view str) {
        uint64_t n = 0;
        for (int i = 0; i < str.size(); i++)
            n += huffman_code[(unsigned char)str[i]].nbits;
        return (n + 7) / 8;
    }

    inline void huffman_encode(luabuf* buf, string_view str, size_t huffman_size) {
        size_t len = 0;
        int rembits = 8;
        unsigned char n = 0;
        uint8_t* data = buf->peek_space(huffman_size);
        for (int i = 0; i < str.size(); i++) {
            unsigned char c = str[i];
            int nbits = huffman_code[c].nbits;
            uint32_t code = huffman_code[c].code;
            for (;;) {
                if (rembits > nbits) {
                    n |= (code << (rembits - nbits));
                    rembits -= nbits;
                    break;
                }
                n |= ((code >> (nbits - rembits)) & 0xff);
                data[len++] = static_cast<uint8_t>(n);
                nbits -= rembits;
                rembits = 8;
                n = 0;
                if (nbits == 0) break;
            }
        }
        if (rembits < 8) {
            n |= (uint8_t)(huffman_code[256].code >> (huffman_code[256].nbits - rembits));
            data[len++] = static_cast<uint8_t>(n);
        }
        buf->pop_space(len);
    }

    inline int huffman_decode(unsigned char *enc, int enc_sz, uint8_t *out_buff, int out_sz){
        huffman_node* node = &HUFFMAN_ROOT;
        int len = 0;
        int	nbits = 0;
        unsigned int cur = 0;
        for (int i = 0; i < enc_sz; i++){
            cur = (cur << 8) | enc[i];
            nbits += 8;
            for ( ;nbits >= 8; ){
                int idx = (unsigned char)(cur >> (nbits-8));
                node = node->children[idx];
                if (!node) throw lua_exception("invalid huffmand code");
                if (node->size == 0) {
                    out_buff[len++] = node->sym; 
                    nbits -= node->code_len;
                    node = &HUFFMAN_ROOT;
                } else {
                    nbits -= 8;
                }
            }
        }
        for( ;nbits > 0; ){
            node = node->children[(unsigned char)(cur << (8 - nbits))];
            if(node->size != 0 || node->code_len > nbits) break;
            out_buff[len++] = node->sym;
            nbits -= node->code_len;
            node = &HUFFMAN_ROOT;
        }
        return len;
    }

    inline uint32_t get_header_size(string_view name, string_view val) {
        return name.size() + val.size() + 32;
    }

    inline h2_header* index_header(h2_dynamic* dynamic, uint16_t index) {
        if (index == 0) throw lua_exception("index_header index is zero");
        if (index > dynamic->max_index()) throw lua_exception("index_header index out of range");
        if (index < DYNAMIC_IDX_MIN) return STATIC_HEADERS[index - 1];
        return *(&dynamic->headers.back() - (index - DYNAMIC_IDX_MIN));
    }

    inline tuple<bool, uint16_t> get_dynamic_index(h2_dynamic* dynamic, string_view name, string_view val) {
        auto [b, e] = dynamic->indexs.equal_range(h2_header{ 0, string(name) });
        for (; b != e; ++b) {
            auto index = dynamic->indexof(*b);
            if (b->value == val) return tuple(true, index);
            return tuple(false, index);
        }
        return tuple(false, 0);
    }

    inline tuple<bool, uint16_t> get_static_index(string_view name, string_view val) {
        auto [b, e] = STATIC_INDEXS.equal_range(h2_header{ 0, string(name) });
        if (b != STATIC_INDEXS.end()) {
            for (auto c = b; c != e; ++c) {
                if (case_insensitive_equal(c->value, val)) {
                    return tuple(true, c->insert_c);
                }
            }
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
            auto slen = huffman_decode(data, length, decdata, length * 2);
            return string((char*)decdata, slen);
        }
        return string((char*)data, length);
    }

    void add_dynmic_header(h2_dynamic* dynamic, string_view name, string_view val) {
        auto header_size = get_header_size(name, val);
        //若新条目大小超过当前动态表剩余空间，则​​清空整个动态表​​
        if (header_size > dynamic->capacity) {
            dynamic->size = 0;
            dynamic->insert_count = 0;
            dynamic->headers.clear();
            dynamic->indexs.clear();
            return;
        }
        // 驱逐旧条目
        size_t i = 0;
        auto& headers = dynamic->headers;
        for (; dynamic->size + header_size > dynamic->capacity; ++i) {
            auto header = headers[i];
            dynamic->size -= get_header_size(header->key, header->value);
            erase_if(dynamic->indexs, [header](auto& h) { return h.insert_c == header->insert_c; });
        }
        headers.erase(headers.begin(), headers.begin() + i);
        auto it = dynamic->indexs.insert(h2_header(++dynamic->insert_count, string(name), string(val)));
        headers.push_back((h2_header*)&*it);
        dynamic->size += header_size;
    }

    static void init_huffman_tree() {
        for (int i = 0; i < 256; i++) {
            huffman_add_node(i, huffman_code[i].code, huffman_code[i].nbits);
        }
    }

    static void init_static_headers(luabuf* buf) {
        if (!STATIC_HEADERS.empty()) return;
        STATIC_HEADERS.resize(DYNAMIC_IDX_MIN - 1);
        for (auto& header : STATIC_INDEXS) {
            STATIC_HEADERS[header.insert_c - 1] = (h2_header*)&header;
        }
    }
}
