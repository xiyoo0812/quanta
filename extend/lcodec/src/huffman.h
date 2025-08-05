#pragma once

using namespace std;

namespace lcodec {

    struct huffman_symbol {
        int nbits;
        uint32_t code;
    };

    struct huffman_node{
        struct huffman_node *children[256];
        unsigned char sym;
        unsigned int code;
        int code_len;
        int size;
    };
    static huffman_node HUFFMAN_ROOT;

    static const huffman_symbol huffman_code[] {
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

    static void init_huffman_tree() {
        for(int i = 0; i < 256; i++) {
            huffman_add_node(i, huffman_code[i].code, huffman_code[i].nbits);
        }
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

    inline void huffman_decode(unsigned char *enc, int enc_sz, uint8_t *out_buff, int out_sz){
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
    }
}

