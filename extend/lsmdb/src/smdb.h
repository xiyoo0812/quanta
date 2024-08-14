#pragma once
#include <set>
#include <map>
#include <vector>
#include <string>
#include <unordered_map>

#ifdef WIN32
#include <io.h>
#include <fcntl.h>
#include <stdio.h>
#define fileno _fileno
#define ftruncate _chsize_s
#define filelength _filelength
#define strncasecmp _strnicmp
#else
#include <unistd.h>
#include <sys/stat.h>
long filelength(int fd) {
    struct stat st;
    fstat(fd, &st);
    return st.st_size;
}
#endif

using namespace std;

namespace smdb {
    const uint16_t DB_FLAG_SIZE     = 4;            //DB文件前置标记
    const uint16_t DB_PAGE_MAX      = USHRT_MAX;    //DB文件最大页数
    const uint16_t DB_PAGE_SIZE     = USHRT_MAX;    //页的bytes
    const uint8_t  KEY_SIZE_MAX     = 0x3f;         //KEY的最大长度，二进制00111111
    const uint8_t  KEY_CHECK_FLAG   = 0xc0;         //KEY的校验标记，二进制11000000
    const uint16_t VAL_SZIE_MAX     = 65400;        //VALUE的最大长度
    const uint16_t PAGE_VAL_MAX     = 1500;         //每页VALUE的最大数量
    const uint16_t PAGE_VAL_FREE    = 64;           //每页FREE标志bytes

#pragma pack(1)
 /*+------------+----------+----------+----------+---------+
 * |  3 bytes   |  5 bytes | 16 bytes |  n bytes | n bytes |
 * +------------+----------+----------+----------+---------+
 * | check flag | key size | val size |    key   |   val   |
 * +------------+----------+----------+----------+---------+*/
    struct keyheader {
        uint8_t ksize = 0;              //key的长度，前3字节为校验标记，后5bytes
        uint16_t vsize = 0;             //value的长度，ksize为0则表示空位置长度
    };

    struct pageheader {
        uint16_t num = 0;               //页内KV数量
        uint32_t offset = 0;            //页在文件内的偏移
    };

    struct dbheader {
        char fmt[DB_FLAG_SIZE] = {};    //文件格式标志位
        uint16_t page_num = 0;          //当前页数
        uint32_t filesize = 0;          //当前文件大小
    };

    struct pagekey {
        uint16_t offset = 0;
        uint16_t voffset = 0;
        uint16_t vsize = 0;
    };
#pragma pack()

    class page;
    class mapping {
    public:
        bool open(const char* path) {
            file = fopen(path, "rb+");
            if (!file) {
                file = fopen(path, "wb+");
                if (!file) return false;
            }
            fd = fileno(file);
            if (fd < 0) return false;
            uint32_t size = filelength(fd);
            if (size == 0) {
                //空文件,添加文件头
                size = sizeof(dbheader);
                dbheader header{ { 'S', 'M', 'D', 'B' }, 0, size };
                fwrite(&header, 1, size, file);
                fflush(file);
            }
            return atach(size);
        }

        void close() {
            m_keys.clear();
            if (file) fclose(file);
            if (data) free(data);
        }

        bool atach(uint32_t size) {
            data = (char*)realloc(data, size);
            if (data == nullptr) return false;
            fseek(file, 0, SEEK_SET);
            if (fread(data, 1, size, file) < 0) return false;
            return true;
        }

        //扩展数据页
        bool extend_page(uint32_t& offset) {
            if (data == nullptr) return false;
            dbheader* header = (dbheader*)data;
            if (header->page_num >= DB_PAGE_MAX) return false;
            uint32_t fsize = header->filesize;
            uint32_t nfsize = fsize + DB_PAGE_SIZE;
            offset = fsize;
            //写入dbheader
            header->page_num++;
            header->filesize = nfsize;
            fseek(file, 0, SEEK_SET);
            fwrite(header, 1, sizeof(dbheader), file);
            //写入pageheader
            fseek(file, fsize, SEEK_SET);
            pageheader hpage{ 0, offset };
            fwrite((char*)&hpage, 1, sizeof(pageheader), file);
            //更改文件大小
            ftruncate(fd, nfsize);
            fflush(file);
            return atach(nfsize);
        }

        //回收数据页
        bool shrink_page(uint16_t page_num) {
            dbheader* header = (dbheader*)data;
            if (header->page_num > page_num) {
                //修改内存
                uint32_t fsize = header->filesize - page_num * DB_PAGE_SIZE;
                header->page_num -= page_num;
                header->filesize = fsize;
                //写入文件
                fseek(file, 0, SEEK_SET);
                fwrite(header, 1, sizeof(dbheader), file);
                //重新分配内存,因为是减少,所以不需要读文件
                data = (char*)realloc(data, fsize);
                //更改文件大小
                ftruncate(fd, fsize);
                fflush(file);
                return true;
            }
            return false;
        }

        string_view add_key(string& key, page* pg) {
            auto rc = m_keys.emplace(key, pg);
            return rc.first->first;
        }

        void erase_key(string& key) {
            m_keys.erase(key);
        }

        page* first(string& key) {
            m_iter = m_keys.begin();
            if (m_iter != m_keys.end()) {
                key = m_iter->first;
                return m_iter->second;
            }
            return nullptr;
        }

        page* next(string& key) {
            m_iter++;
            if (m_iter != m_keys.end()) {
                key = m_iter->first;
                return m_iter->second;
            }
            return nullptr;
        }

        FILE* file = 0;
        uint32_t fd = 0;
        char* data = nullptr;
        unordered_map<string, page*> m_keys;    //KEY索引列表
        unordered_map<string, page*>::iterator m_iter;   //KEY索引迭代器
    };

    class page {
    friend class smdb;
    public:
        //自定义比较函数
        bool operator<(const page& b) {
            uint16_t bufsza = m_remain + m_waste;
            uint16_t bufszb = b.m_remain + b.m_waste;
            if (bufsza == bufszb) return m_id > b.m_id;
            return bufsza > bufszb;
        }

        page(mapping* map, uint16_t id, uint32_t offset) : m_id(id), m_offset(offset), m_mapping(map){}

        bool isempty() { return count() == 0; }
        bool available() { return count() < PAGE_VAL_MAX && (m_remain + m_waste) > PAGE_VAL_FREE; }

        uint16_t count() {
            char* cursor = m_mapping->data + m_offset;
            pageheader* header = (pageheader*)cursor;
            return header->num;
        }

        //加载数据页面
        bool read_keys() {
            char* cursor = m_mapping->data + m_offset;
            pageheader* header = (pageheader*)cursor;
            uint16_t offset = sizeof(pageheader);
            if (header->num > 0) {
                uint16_t load_num = 0;
                while (load_num < header->num){
                    keyheader* hkey = (keyheader*)(cursor + offset);
                    if ((hkey->ksize & KEY_CHECK_FLAG) != KEY_CHECK_FLAG) return false;
                    uint8_t ksize = hkey->ksize & KEY_SIZE_MAX;
                    if (ksize == 0) {
                        //占位空间
                        m_waste += hkey->vsize;
                        offset += hkey->vsize;
                        continue;
                    }
                    pagekey pkey = { offset, (uint16_t)(sizeof(keyheader) + ksize), hkey->vsize };
                    offset += sizeof(keyheader);
                    string skey = string(cursor + offset, ksize);
                    auto vkey = m_mapping->add_key(skey, this);
                    m_keys.emplace(vkey, pkey);
                    offset += (ksize + hkey->vsize);
                    load_num++;
                }
            }
            m_remain = DB_PAGE_SIZE - offset;
            arrange();
            return true;
        }

        //尝试更新
        bool update(string& key, string_view val) {
            if (!canput(val.size())) {
                del(key);
                return false;
            }
            auto it = m_keys.find(key);
            if (it == m_keys.end()) {
                m_mapping->erase_key(key);
                return false;
            }
            //清除旧数据
            uint8_t ksize = (uint8_t)key.size();
            keyheader* ohkey = (keyheader*)(m_mapping->data + m_offset + it->second.offset);
            ohkey->vsize = it->second.vsize + ksize + sizeof(keyheader);
            ohkey->ksize = KEY_CHECK_FLAG;
            m_waste += ohkey->vsize;
            //更新索引
            uint16_t offset = DB_PAGE_SIZE - m_remain;
            char* cursor = m_mapping->data + m_offset;
            keyheader* hkey = (keyheader*)(cursor + offset);
            hkey->ksize = (ksize & KEY_SIZE_MAX) | KEY_CHECK_FLAG;
            hkey->vsize = (uint16_t)val.size();
            it->second.offset = offset;
            it->second.vsize = hkey->vsize;
            //写入key/val
            offset += sizeof(keyheader);
            memcpy(cursor + offset, key.data(), ksize);
            offset += ksize;
            memcpy(cursor + offset, val.data(), hkey->vsize);
            offset += hkey->vsize;
            m_remain = DB_PAGE_SIZE - offset;
            //更新文件
            flush();
            return true;
        }

        //插入KV
        bool put(string& key, string_view val) {
            uint16_t offset = DB_PAGE_SIZE - m_remain;
            char* cursor = m_mapping->data + m_offset;
            pageheader* header = (pageheader*)cursor;
            //更新索引
            uint8_t ksize = (uint8_t)key.size();
            keyheader* hkey = (keyheader*)(cursor + offset);
            hkey->ksize = (ksize & KEY_SIZE_MAX) | KEY_CHECK_FLAG;
            hkey->vsize = (uint16_t)val.size();
            auto vkey = m_mapping->add_key(key, this);
            m_keys.emplace(vkey, pagekey{ offset, (uint16_t)(sizeof(keyheader) + ksize), hkey->vsize });
            header->num++;
            //写入key/val
            offset += sizeof(keyheader);
            memcpy(cursor + offset, key.data(), ksize);
            offset += ksize;
            memcpy(cursor + offset, val.data(), hkey->vsize);
            offset += hkey->vsize;
            m_remain = DB_PAGE_SIZE - offset;
            //更新文件
            flush();
            return true;
        }

        //查询KV
        string_view get(string& key) {
            auto it = m_keys.find(key);
            if (it == m_keys.end()) return "";
            char* cursor = m_mapping->data + m_offset + it->second.offset;
            return string_view(cursor + it->second.voffset, it->second.vsize);
        }

        //删除KV
        void del(string key, bool sync = true) {
            auto it = m_keys.find(key);
            if (it == m_keys.end()) {
                m_mapping->erase_key(key);
                return;
            }
            char* cursor = m_mapping->data + m_offset;
            pageheader* header = (pageheader*)cursor;
            //清空KV索引，修改内存
            cursor += it->second.offset;
            keyheader* hkey = (keyheader*)cursor;
            hkey->vsize = it->second.vsize + (uint8_t)key.size() + sizeof(keyheader);
            hkey->ksize = KEY_CHECK_FLAG;
            //修改索引
            m_waste += hkey->vsize;
            m_keys.erase(it);
            m_mapping->erase_key(key);
            header->num--;
            //刷新文件
            if (sync) flush();
        }

        //能否插入
        bool canput(size_t size) {
            auto need_sz = size + sizeof(pagekey);
            if ((m_remain + m_waste) < need_sz) return false;
            if (m_remain < need_sz) arrange();
            return true;
        }

        //重定向
        void relocation(uint32_t off) {
            char* dst = m_mapping->data + off;
            char* src = m_mapping->data + m_offset;
            pageheader* header = (pageheader*)src;
            header->offset = off;
            m_offset = off;
            migrate(src, dst);
        }

    protected:
        //整理数据
        void arrange() {
            if (m_waste == 0) return;
            char* buf = (char*)malloc(DB_PAGE_SIZE);
            char* cursor = m_mapping->data + m_offset;
            memcpy(buf, cursor, DB_PAGE_SIZE);
            migrate(buf, cursor);
            free(buf);
        }

        //转移数据
        void migrate(char* source, char* target) {
            memset(target, 0, DB_PAGE_SIZE);
            uint16_t offset = sizeof(pageheader);
            memcpy(target, source, sizeof(pageheader));
            for (auto& [key, pkey] : m_keys) {
                //内存复制
                uint8_t ksize = (uint8_t)key.size();
                uint16_t kvsize = sizeof(keyheader) + ksize + pkey.vsize;
                memcpy(target + offset, source + pkey.offset, kvsize);
                //修改索引
                pkey.offset = offset;
                offset += kvsize;
            }
            //整理数据
            m_remain = DB_PAGE_SIZE - offset;
            m_waste = 0;
            //刷新文件
            flush();
        }

        //刷内存到文件
        void flush() {
            char* cursor = m_mapping->data + m_offset;
            fseek(m_mapping->file, m_offset, SEEK_SET);
            fwrite(cursor, 1, DB_PAGE_SIZE, m_mapping->file);
        }

    protected:
        uint16_t m_id = 0;
        uint16_t m_waste = 0;
        uint16_t m_remain = 0;
        uint32_t m_offset = 0;
        mapping* m_mapping = nullptr;
        unordered_map<string_view, pagekey> m_keys;
    };

    class smdb {
    public:
        bool open(const char* path) {
            if (!m_mapping.open(path)) return false;
            m_dbheader = (dbheader*)m_mapping.data;
            uint32_t offset = sizeof(dbheader);
            for (uint16_t i = 0; i < m_dbheader->page_num; ++i) {
                pageheader* hpage = (pageheader*)(m_mapping.data + offset);
                if (offset != hpage->offset) return false;
                if (offset + DB_PAGE_SIZE > m_dbheader->filesize) return false;
                auto page = load_page(hpage->offset);
                if (!page) return false;
                add_available(page);
                offset += DB_PAGE_SIZE;
            }
            arrange();
            return true;
        }

        void close() {
            m_mapping.close();
            m_availables.clear();
            for (auto& [_, page] : m_pages) {
                delete page;
            }
            m_pages.clear();
        }

        bool put(string& key, string_view val) {
            if (key.size() > KEY_SIZE_MAX) return false;
            if (val.size() > VAL_SZIE_MAX) return false;
            page* opage = find_page(key, true);
            if (opage) {
                bool ok = opage->update(key, val);
                add_available(opage);
                if (ok) return true;
            }
            page* npage = choose_page(key.size() + val.size());
            if (!npage) return false;
            bool ok = npage->put(key, val);
            add_available(npage);
            return ok;
        }

        string_view get(string& key) {
            page* page = find_page(key);
            return page ? page->get(key) : "";
        }

        void del(string& key) {
            page* page = find_page(key, true);
            if (!page) return;
            page->del(key);
            add_available(page);
        }

        bool first(string& key, string& val) {
            auto page = m_mapping.first(key);
            if (!page) return false;
            val = page->get(key);
            return true;
        }

        bool next(string& key, string& val) {
            auto page = m_mapping.next(key);
            if (!page) return false;
            val = page->get(key);
            return true;
        }

        void arrange(bool timely = false) {
            vector<page*> deletes;
            map<uint32_t, page*> migrates;
            auto rit = m_pages.rbegin();
            for (auto it = m_pages.begin(); it != m_pages.end() && rit != m_pages.rend();) {
                page *lpage = it->second, *rpage = rit->second;
                //相遇退出循环
                if (lpage->m_id >= rpage->m_id) break;
                //right页面为空，进删除列表
                if (rpage->isempty()) {
                    deletes.push_back(rpage);
                    rit++;
                    continue;
                }
                //left页面为空，将right迁移到left，left进删除列表，right进迁移列表
                if (lpage->isempty()) {
                    rpage->relocation(lpage->m_offset);
                    migrates.emplace(lpage->m_id, rpage);
                    deletes.push_back(lpage);
                    rit++;
                }
                it++;
            }
            //删除标记删除的页面
            for (auto& page : deletes) {
                m_pages.erase(page->m_id);
                m_availables.erase(page);
                delete page;
            }
            //重新插入迁移的页面
            for (auto& [id, page]: migrates) {
                m_pages.erase(page->m_id);
                m_pages.emplace(id, page);
                page->m_id = id;
            }
            //剪裁文件
            m_mapping.shrink_page(deletes.size());
        }

    protected:
        page* choose_page(size_t need_size) {
            for (auto it = m_availables.begin(); it != m_availables.end(); ++it) {
                auto page = *it;
                if (page->canput(need_size)) {
                    m_availables.erase(it);
                    return page;
                }
            }
            uint32_t offset = 0;
            if (!m_mapping.extend_page(offset)) return nullptr;
            return load_page(offset);
        }

        page* find_page(string& key, bool pop = false) {
            auto it = m_mapping.m_keys.find(key);
            if (it != m_mapping.m_keys.end()) {
                auto pge = it->second;
                if (pop) m_availables.erase(pge);
                return pge;
            }
            return nullptr;
        }

        page* load_page(uint32_t offset) {
            uint16_t page_id = m_page_id++;
            auto pge = new page(&m_mapping, page_id, offset);
            if (!pge->read_keys()) {
                delete pge;
                return nullptr;
            }
            m_pages.emplace(page_id, pge);
            return pge;
        }

        void add_available(page* pge) {
            if (pge->available()) m_availables.insert(pge);
        }

    protected:
        mapping m_mapping;                      //文件内容映射
        uint16_t m_page_id = 0;                 //页起始id
        set<page*> m_availables;                //可用的页列表
        map<uint16_t, page*> m_pages;           //页列表
        dbheader* m_dbheader = nullptr;         //DB文件头
    };
}
