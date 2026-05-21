#pragma once

#include "lz4/lz4.h"
#include "zstd/zstd.h"
#include "miniz/miniz.h"
#include "snappy/snappy.h"

#include "lua_kit.h"

using namespace luakit;

namespace luazip {

    class zip_file {
    public:
        ~zip_file() {
            if (m_archive.m_pState) {
                mz_zip_reader_end(&m_archive);
                mz_zip_zero_struct(&m_archive);
                if (m_zip_data) {
                    free(m_zip_data);
                    m_zip_data = nullptr;
                }
            }
        }

        bool open(const char* zfile) {
            if (m_zip_data) {
                free(m_zip_data);
                m_zip_data = nullptr;
            }
            memset(&m_archive, 0, sizeof(m_archive));
            // 打开zip文件
            FILE* fp = fopen(zfile, "rb");
            if (!fp) {
                return false;
            }
            fseek(fp, 0, SEEK_END);
            size_t fsize = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            m_zip_data = (char*)malloc(fsize);
            fread(m_zip_data, 1, fsize, fp);
            fclose(fp);
            // 读取zip文件
            if (!mz_zip_reader_init_mem(&m_archive, m_zip_data, fsize, 0)) {
                return false;
            }
            return true;
        }

        mz_zip_archive* archive() {
            return &m_archive;
        }

    private:
        mz_zip_archive m_archive;
        char* m_zip_data = nullptr;
    };

    class zipcodec : public codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            m_packet_len = data_len;
            return data_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            if (m_tag == "gzip") return encode_gzip(L, index, len, MZ_DEFAULT_LEVEL);
            if (m_tag == "zlib") return encode_zlib(L, index, len, MZ_DEFAULT_LEVEL);
            if (m_tag == "zstd") return encode_zstd(L, index, len, ZSTD_defaultCLevel());
            if (m_tag == "deflate") return encode_deflate(L, index, len, MZ_DEFAULT_LEVEL);
            if (m_tag == "snappy") return encode_snappy(L, index, len, snappy::CompressionOptions::DefaultCompressionLevel());
            if (m_tag == "lz4") return encode_lz4(L, index, len);
            return nullptr;
        }

        virtual uint8_t* decode(uint8_t* data, size_t* len) {
            if (m_tag == "gzip") return decode_gzip(data, len);
            if (m_tag == "lz4") return decode_lz4(data, len);
            if (m_tag == "snappy") return decode_snappy(data, len);
            if (m_tag == "deflate") return decode_deflate(data, len);
            if (m_tag == "zlib") return decode_zlib(data, len);
            if (m_tag == "zstd") return decode_zstd(data, len);
            return nullptr;
        }

        uint8_t* encode_lz4(lua_State* L, int index, size_t* len) {
            size_t data_len = 0;
            cpchar message = luaL_checklstring(L, index, &data_len);
            int dst_len = LZ4_compressBound(data_len);
            if (dst_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dst_len);
                int comsize = LZ4_compress_default(message, (char*)dest, data_len, dst_len);
                if (comsize > 0) {
                    *len = comsize;
                    return dest;
                }
            }
            return nullptr;
        }

        uint8_t* encode_zlib(lua_State* L, int index, size_t* len, int level) {
            size_t data_len = 0;
            cpchar message = luaL_checklstring(L, index, &data_len);
            size_t dst_len = mz_compressBound(data_len);
            if (dst_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dst_len);
                *(size_t*)dest = data_len;
                uint32_t comp_flags = tdefl_create_comp_flags_from_zip_params(level, 15, MZ_DEFAULT_STRATEGY);
                *len = tdefl_compress_mem_to_mem(dest, dst_len, message, data_len, comp_flags);
                if (*len > 0) return dest;
            }
            return nullptr;
        }

        uint8_t* encode_gzip(lua_State* L, int index, size_t* len, int level) {
            size_t data_len = 0;
            cpchar message = luaL_checklstring(L, index, &data_len);
            size_t dst_len = mz_compressBound(data_len);
            size_t gzip_len = 10 + dst_len + 8;
            if (gzip_len < luakit::BUFFER_MAX) {
                pbyte gzip = m_buf->peek_space(gzip_len);
                // GZIP header
                gzip[0] = 0x1f; gzip[1] = 0x8b;  // magic
                gzip[2] = 8;                     // CM = DEFLATE
                gzip[3] = 0;                     // FLG = no extra fields
                *(uint32_t*)(gzip + 4) = 0;      // MTIME = 0 (or use time(NULL))
                gzip[8] = 0;                     // XFL = 0 (default)
                gzip[9] = 0x03;                  // OS = Unix
                //compress
                uint32_t comp_flags = tdefl_create_comp_flags_from_zip_params(level, -15, MZ_DEFAULT_STRATEGY);
                size_t deflated_size = tdefl_compress_mem_to_mem(gzip + 10, dst_len, message, data_len, comp_flags);
                if (deflated_size > 0) {
                    // Trailer: CRC32 (little-endian) + ISIZE (uncompressed size mod 2^32, little-endian)
                    auto trailer = gzip + 10 + deflated_size;
                    *(uint32_t*)(trailer) = mz_crc32(MZ_CRC32_INIT, (cpbyte)message, data_len);
                    *(uint32_t*)(trailer + 4) = (uint32_t)(data_len & 0xFFFFFFFF);
                    *len = 10 + deflated_size + 8;
                    return gzip;
                }
            }
            return nullptr;
        }

        uint8_t* encode_zstd(lua_State* L, int index, size_t* len, int level) {
            size_t data_len = 0;
            cpchar message = luaL_checklstring(L, index, &data_len);
            size_t zsize = ZSTD_compressBound(data_len);
            if (!ZSTD_isError(zsize) && zsize < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(zsize);
                size_t comp_ize = ZSTD_compress(dest, zsize, message, data_len, level);
                if (!ZSTD_isError(comp_ize)) {
                    *len = comp_ize;
                    return dest;
                }
            }
            return nullptr;
        }

        uint8_t* encode_snappy(lua_State* L, int index, size_t* len, int level) {
            size_t data_len = 0;
            cpchar message = luaL_checklstring(L, index, &data_len);
            size_t dst_len = snappy::MaxCompressedLength(data_len);
            if (dst_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dst_len);
                snappy::CompressionOptions option(level);
                snappy::RawCompress(message, data_len, (char*)dest, len, option);
                if (*len > 0) return dest;
            }
            return nullptr;
        }

        uint8_t* encode_deflate(lua_State* L, int index, size_t* len, int level) {
            size_t data_len = 0;
            cpchar message = luaL_checklstring(L, index, &data_len);
            size_t dst_len = mz_compressBound(data_len);
            if (dst_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dst_len);
                uint32_t comp_flags = tdefl_create_comp_flags_from_zip_params(level, -15, MZ_DEFAULT_STRATEGY);
                *len = tdefl_compress_mem_to_mem(dest, dst_len, message, data_len, comp_flags);
                if (*len > 0) return dest;
            }
            return nullptr;
        }

        uint8_t* decode_lz4(uint8_t* data, size_t* len) {
            size_t data_len = *len;
            size_t dest_len = data_len * 16;
            if (dest_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dest_len);
                *len = LZ4_decompress_safe((char*)data, (char*)dest, data_len, dest_len);
                if (*len > 0) return dest;
            }
            return nullptr;
        }

        uint8_t* decode_zlib(uint8_t* data, size_t* len) {
            size_t data_len = *len;
            size_t dest_len = data_len * 16;
            if (dest_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dest_len);
                size_t uncomp_size = tinfl_decompress_mem_to_mem(dest, dest_len, data, data_len, TINFL_FLAG_PARSE_ZLIB_HEADER);
                if (uncomp_size != TINFL_DECOMPRESS_MEM_TO_MEM_FAILED ) {
                    *len = uncomp_size;
                    return dest;
                }
            }
            return nullptr;
        }

        uint8_t* decode_gzip(uint8_t* data, size_t* len) {
            size_t data_len = *len;
            size_t dest_len = data_len * 16;
            if (data_len >= 18 && dest_len < luakit::BUFFER_MAX) {
                if (data[0] == 0x1f && data[1] == 0x8b && data[2] == 8) {
                    int header_len = 10;
                    uint8_t flags = data[3];
                    if (flags & 0x04) { // FEXTRA
                        if (header_len + 2 > data_len) return nullptr;
                        uint16_t extra_len = (uint16_t)(data[header_len] | (data[header_len + 1] << 8));
                        header_len += 2 + extra_len;
                    }
                    if (flags & 0x08) { // FNAME
                        while (header_len < data_len && data[header_len]) header_len++;
                        if (header_len >= data_len) return nullptr;
                        header_len++;
                    }
                    if (flags & 0x10) { // FCOMMENT
                        while (header_len < data_len && data[header_len]) header_len++;
                        if (header_len >= data_len) return nullptr;
                        header_len++;
                    }
                    if (flags & 0x02) { // FHCRC
                        header_len += 2;
                    }
                    auto deflate_data = data + header_len;
                    size_t deflate_len = data_len - header_len - 8;
                    auto dest = m_buf->peek_space(dest_len);
                    size_t out_size = tinfl_decompress_mem_to_mem(dest, dest_len, deflate_data, deflate_len, 0);
                    if (out_size != TINFL_DECOMPRESS_MEM_TO_MEM_FAILED ) {
                        mz_ulong expected_crc = *(uint32_t*)(data + header_len + deflate_len);
                        mz_ulong actual_crc = mz_crc32(MZ_CRC32_INIT, (cpbyte)dest, out_size);
                        if (expected_crc == actual_crc) {
                            *len = out_size;
                            return dest;
                        }
                    }
                }
            }
            return nullptr;
        }

        uint8_t* decode_zstd(uint8_t* data, size_t* len) {
            size_t size = ZSTD_getFrameContentSize(data, *len);
            if (!ZSTD_isError(size) && size < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(size);
                size_t dec_size = ZSTD_decompress(dest, size, data, *len);
                if (!ZSTD_isError(dec_size)) {
                    *len = dec_size;
                    return dest;
                }
            }
            return nullptr;
        }

        uint8_t* decode_snappy(uint8_t* data, size_t* len) {
            size_t dst_len = 0;
            size_t data_len = *len;
            bool success = snappy::GetUncompressedLength((char*)data, data_len, &dst_len);
            if (success && dst_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dst_len);
                if (snappy::RawUncompress((char*)data, data_len, (char*)dest)) {
                    *len = dst_len;
                    return dest;
                }
            }
            return nullptr;
        }

        uint8_t* decode_deflate(uint8_t* data, size_t* len) {
            size_t data_len = *len;
            size_t dest_len = data_len * 16;
            if (dest_len < luakit::BUFFER_MAX) {
                auto dest = m_buf->peek_space(dest_len);
                size_t uncomp_size = tinfl_decompress_mem_to_mem(dest, dest_len, data, data_len, 0);
                if (uncomp_size != TINFL_DECOMPRESS_MEM_TO_MEM_FAILED) {
                    *len = uncomp_size;
                    return dest;
                }
            }
            return nullptr;
        }
    };
}
