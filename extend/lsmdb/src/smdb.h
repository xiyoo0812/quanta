#pragma once
#include <set>
#include <vector>
#include <string>
#include <unordered_map>

#ifdef WIN32
#include <io.h>
#define fileno _fileno
#define ftruncate _chsize
#define filelength _filelength
#else
#include <climits>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
long filelength(int fd) {
    struct stat st;
    fstat(fd, &st);
    return st.st_size;
}
#endif

using namespace std;
using sptr = shared_ptr<string_view>;

namespace lsmdb {
    const uint8_t  KEY_SIZE_MAX     = 0xFF;         //KEY的最大长度
    const uint32_t VAL_SZIE_MAX     = 0x3FFFFF;     //VALUE的最大长度, 1 << 22 (4M-1)
    const uint32_t DB_PAGE_SIZE     = 0x20000;      //DB内存页大小 128K
    const uint32_t SHRINK_SIZE      = 0x800000;     //缩容界限尺寸 8M
    const uint32_t ARRVAGE_SIZE     = 0x800000;     //整理界限尺寸 8M
    const uint32_t EXPAND_SIZE      = 0xFFFFFF00;   //扩展界限尺寸 4G-256
    const uint32_t KEY_CHECK_FLAG   = 0xC0000000;   //KV的校验标记
    const char     TSMDB[4]         = { 'S', 'M', 'D', 'B' };   //文件格式标志位

    enum class smdb_code : uint8_t {
        SMDB_SUCCESS,
        SMDB_DB_NOT_INIT = 1,
        SMDB_DB_ITER_ING,
        SMDB_SIZE_KEY_FAIL = 11,
        SMDB_SIZE_VAL_FAIL,
        SMDB_FILE_OPEN_FAIL = 21,
        SMDB_FILE_FDNO_FAIL,
        SMDB_FILE_MMAP_FAIL,
        SMDB_FILE_HANDLE_FAIL,
        SMDB_FILE_MAPPING_FAIL,
        SMDB_FILE_EXPAND_FAIL,
    };

 /*+------------+-----------+----------+----------+---------+
 * |  2 bytes   |  22 bytes | 8 bytes  |  n bytes | n bytes |
 * +------------+-----------+----------+----------+---------+
 * | check flag |  val size | key size |    key   |   val   |
 * +------------+-----------+----------+----------+---------+*/
    struct dbval {
        uint32_t offset = 0;            //offset
        uint32_t voffset = 0;           //val offset
        uint32_t vsize = 0;             //val size
    };

    class smdb {
    public:
        smdb_code open(const char* path) {
            m_file = fopen(path, "rb+");
            if (!m_file) {
                m_file = fopen(path, "wb+");
                if (!m_file) return smdb_code::SMDB_FILE_OPEN_FAIL;
            }
            m_fd = fileno(m_file);
            if (m_fd < 0) return smdb_code::SMDB_FILE_FDNO_FAIL;
            return load_file();
        }

        void close() {
            if (m_file) {
                unmap_file();
                m_values.clear();
                fclose(m_file);
                m_file = nullptr;
            }
        }

        size_t size() { return m_offset; }
        size_t capacity() { return m_alloc; }
        size_t count() { return m_values.size(); }

        smdb_code clear() {
            if (!m_itering) {
                m_waste = 0;
                m_values.clear();
                m_offset = sizeof(TSMDB);
                memset(m_buffer + m_offset, 0, m_alloc - m_offset);
                return shrink(m_offset);
            }
            return smdb_code::SMDB_DB_ITER_ING;
        }

        smdb_code put(string& key, string_view val) {
            if (m_itering) return smdb_code::SMDB_DB_ITER_ING;
            uint32_t ksz = key.size(), vsz = val.size();
            if (ksz > KEY_SIZE_MAX) return smdb_code::SMDB_SIZE_KEY_FAIL;
            if (vsz > VAL_SZIE_MAX) return smdb_code::SMDB_SIZE_VAL_FAIL;
            uint32_t kvsize = ksz + vsz + sizeof(uint32_t);
            auto code = check_space(kvsize);
            if (is_error(code)) return code;
            uint32_t offset = m_offset;
            uint32_t voffset = offset + sizeof(uint32_t) + ksz;
            uint32_t flagsz = KEY_CHECK_FLAG | (vsz << 8) | ksz;
            memcpy(m_buffer + offset, &flagsz, sizeof(uint32_t));
            memcpy(m_buffer + offset + sizeof(uint32_t), key.data(), ksz);
            memcpy(m_buffer + voffset, val.data(), vsz);
            auto nh = m_values.extract(key);
            if (!nh.empty()) {
                //清理旧值
                auto& dval = nh.mapped();
                uint32_t osize = ksz + dval.vsize + sizeof(uint32_t);
                memcpy(m_buffer + dval.offset, &osize, sizeof(uint32_t));
                m_waste += osize;
                //更新新值
                nh.key() = key;
                dval.vsize = vsz;
                dval.offset = offset;
                dval.voffset = voffset;
                m_values.insert(std::move(nh));
            } else {
                m_values.emplace(key, dbval{ m_offset, voffset, vsz });
            }
            m_offset += kvsize;
            return smdb_code::SMDB_SUCCESS;
        }

        string_view get(string& key) {
            auto it = m_values.find(key);
            if (it != m_values.end()) {
                auto& val = it->second;
                return string_view(m_buffer + val.voffset, val.vsize);
            }
            return  "";
        }

        smdb_code del(string& key) {
            if (m_itering) return smdb_code::SMDB_DB_ITER_ING;
            auto it = m_values.find(key);
            if (it != m_values.end()) {
                auto& dval = it->second;
                uint32_t size = key.size() + dval.vsize + sizeof(uint32_t);
                memcpy(m_buffer + dval.offset, &size, sizeof(size));
                m_values.erase(it);
                m_waste += size;
            }
            return smdb_code::SMDB_SUCCESS;
        }

        bool first(string_view& key, string_view& val) {
            m_iter = m_values.begin();
            if (m_iter != m_values.end()) {
                key = m_iter->first;
                auto& dval = m_iter->second;
                val = string_view(m_buffer + dval.voffset, dval.vsize);
                m_itering = true;
                return true;
            }
            return false;
        }

        bool next(string_view& key, string_view& val) {
            m_iter++;
            if (m_iter != m_values.end()) {
                key = m_iter->first;
                auto& dval = m_iter->second;
                val = string_view(m_buffer + dval.voffset, dval.vsize);
                return true;
            }
            m_itering = false;
            return false;
        }

        void flush() {
#ifdef WIN32
            FlushViewOfFile(m_buffer, m_alloc);
#else
            msync(m_buffer, m_alloc, MS_ASYNC);
#endif
        }

        bool is_error(smdb_code code) {
            return code != smdb_code::SMDB_SUCCESS;
        }

    protected:
        smdb_code load_file() {
            uint32_t size = filelength(m_fd);
            if (size == 0) {
                //空文件,添加文件头
                size = sizeof(TSMDB);
                fwrite(TSMDB, sizeof(TSMDB), 1, m_file);
                fflush(m_file);
            }
            //映射文件
            m_alloc = (size + DB_PAGE_SIZE - 1) / DB_PAGE_SIZE * DB_PAGE_SIZE;
            auto code = map_file();
            if (is_error(code)) return code;
            //整理内存
            arrvage();
            //缩容
            return shrink(m_offset);
        }

        smdb_code map_file() {
            ftruncate(m_fd, m_alloc);
#ifdef WIN32
            HANDLE hf = (HANDLE)_get_osfhandle(m_fd);
            if (!hf) return smdb_code::SMDB_FILE_HANDLE_FAIL;
            HANDLE hfm = OpenFileMapping(FILE_MAP_ALL_ACCESS, false, "__smdb__");
            if (!hfm) hfm = CreateFileMapping(hf, 0, PAGE_READWRITE, 0, m_alloc, "__smdb__");
            if (!hfm) return smdb_code::SMDB_FILE_MAPPING_FAIL;
            m_buffer = (char*)MapViewOfFileEx(hfm, FILE_MAP_ALL_ACCESS, 0, 0, 0, 0);
            CloseHandle(hfm);
#else
            m_buffer = (char*)mmap(NULL, m_alloc, PROT_WRITE, MAP_SHARED, m_fd, 0);
#endif // WIN32
            if (!m_buffer) return smdb_code::SMDB_FILE_MMAP_FAIL;
            return smdb_code::SMDB_SUCCESS;
        }

        void unmap_file() {
#ifdef WIN32
            if (m_buffer) UnmapViewOfFile(m_buffer);
#else
            if (m_buffer) munmap(m_buffer, m_alloc);
#endif // WIN32
            m_buffer = nullptr;
        }

        smdb_code check_space(size_t size) {
            auto need = m_offset + size;
            if (m_alloc >= need) return smdb_code::SMDB_SUCCESS;
            if (m_alloc > ARRVAGE_SIZE && m_waste > m_alloc * 0.9) {
                //整理当前内存
                arrvage();
                need = m_offset + size;
                if (m_alloc >= need) {
                    //缩容检查
                    return shrink(need);
                }
            }
            //扩容
            size = (need + DB_PAGE_SIZE - 1) / DB_PAGE_SIZE * DB_PAGE_SIZE;
            if (size >= EXPAND_SIZE) return smdb_code::SMDB_FILE_EXPAND_FAIL;
            return truncate_space(size);
        }

        smdb_code truncate_space(size_t size) {
            unmap_file();
            m_alloc = size;
            return map_file();
        }

        smdb_code shrink(size_t offset) {
            if (m_alloc >= SHRINK_SIZE && offset < m_alloc * 0.3) {
                size_t size = (m_alloc / 2 + DB_PAGE_SIZE - 1) / DB_PAGE_SIZE * DB_PAGE_SIZE;
                if (size < m_alloc) {
                    return truncate_space(size);
                }
            }
            return smdb_code::SMDB_SUCCESS;
        }

        void arrvage() {
            m_values.clear();
            uint32_t offset = sizeof(TSMDB);
            uint32_t noffset = sizeof(TSMDB);
            while (true) {
                if (offset + sizeof(uint32_t) > m_alloc) break;
                uint32_t flagsz = *(uint32_t*)(m_buffer + offset);
                if (flagsz == 0) break;
                if ((flagsz & KEY_CHECK_FLAG) == 0) {
                    offset += flagsz;
                    continue;
                }
                uint8_t ksz = flagsz & KEY_SIZE_MAX;
                uint32_t vsz = (flagsz >> 8) & VAL_SZIE_MAX;
                uint32_t size = ksz + vsz + sizeof(uint32_t);
                if (offset + size > m_alloc) break;
                if (offset > noffset) {
                    memcpy(m_buffer + noffset, m_buffer + offset, size);
                }
                auto key = string_view(m_buffer + noffset + sizeof(uint32_t), ksz);
                uint32_t voffset = noffset + ksz + sizeof(uint32_t);
                m_values.emplace(key, dbval{ noffset, voffset, vsz });
                noffset += size;
                offset += size;
            }
            if (offset > noffset) {
                memset(m_buffer + noffset, 0, m_alloc - noffset);
            }
            m_offset = noffset;
            m_waste = 0;
        }

    protected:
        int32_t m_fd = 0;
        uint32_t m_waste = 0;                               //浪费的bytes
        uint32_t m_alloc = 0;                               //分配的bytes
        uint32_t m_offset = 0;                              //当前位置
        unordered_map<string, dbval> m_values;              //kv列表
        unordered_map<string, dbval>::iterator m_iter;      //迭代器
        char* m_buffer = nullptr;
        FILE* m_file = nullptr;
        bool m_itering = false;
    };
}
