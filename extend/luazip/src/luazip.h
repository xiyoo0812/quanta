#pragma once

#include "miniz.h"
#include "lua_kit.h"

namespace luazip {

    struct mini_gzip {
        size_t      total_len;
        size_t      data_len;
        size_t      chunk_size;

        uint16_t    fcrc;
        uint16_t    fextra_len;

        uint8_t*    hdr_ptr;
        uint8_t*    fextra_ptr;
        uint8_t*    fname_ptr;
        uint8_t*    fcomment_ptr;

        uint8_t*    data_ptr;
        uint8_t     pad[3];
    };

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
}
