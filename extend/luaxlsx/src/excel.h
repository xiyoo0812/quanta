#pragma once

#include <map>
#include <vector>
#include <unordered_map>

#include "miniz.h"
#include "tinyxml2.h"

#include "lua_kit.h"

using namespace std;
using namespace tinyxml2;

using XmlDocument = tinyxml2::XMLDocument;

namespace lxlsx {
    constexpr int SECOND_HOUR8  = 28800;    //3600 * 8
    constexpr int SECOND_DAY    = 86400;    //3600 * 24
    constexpr int SECOND_ROOT   = 25569;    //1970.1.1 0:0:0

    bool is_date_ime(uint32_t id) {
        return (id >= 14 && id <= 22) || (id >= 27 && id <= 36) || (id >= 45 && id <= 47)
            || (id >= 50 && id <= 58) || (id >= 71 && id <= 81);
    }

    bool is_custom(uint32_t id) {
        return id > 165;
    }

    class cell {
    public:
        cell(XMLNode* n) : elem(static_cast<XMLElement*>(n)) {}
        ~cell() { elem->GetDocument()->DeleteNode(elem); }
        XMLNode* save(XMLDocument* doc) {
            return elem->DeepClone(doc);
        }
        void merge(cell* cell) {
            mirror = cell->elem;
            fmt_id = cell->fmt_id;
            fmt_code = cell->fmt_code;
        }
        
        int set_value(lua_State* L) {
            auto ev = elem->FirstChildElement("v");
            if (!ev) ev = elem->InsertNewChildElement("v");
            switch (lua_type(L, 3)) {
            case LUA_TBOOLEAN:
                ev->SetText(lua_toboolean(L, 3) ? "true" : "false");
                elem->SetAttribute("t", "b");
                break;
            case LUA_TNUMBER:
                ev->SetText(lua_tonumber(L, 3));
                break;
            case LUA_TSTRING:
                ev->SetText(lua_tostring(L, 3));
                elem->SetAttribute("t", "str");
            default:
                break;
            }
            return 0;
        }

        int get_value(lua_State* L) {
            if (auto ev = elem->FirstChildElement("v"); ev) {
                auto v = ev->GetText();
                if (!v) return 0;
                if (fmt_id > 0) {
                    if (is_date_ime(fmt_id)) {
                        lua_pushinteger(L, SECOND_DAY * (atoi(v) - SECOND_ROOT) - SECOND_HOUR8);
                        return 1;
                    }
                    if (is_custom(fmt_id)) {
                        if (fmt_code.find_first_of("yy") != std::string::npos) {
                            lua_pushinteger(L, SECOND_DAY * (atoi(v) - SECOND_ROOT) - SECOND_HOUR8);
                            return 1;
                        }
                        if (fmt_code.find_first_of("mm:ss") != std::string::npos) {
                            lua_pushnumber(L, atof(v) * SECOND_DAY);
                            return 1;
                        }
                    }
                    lua_pushstring(L, v);
                    lua_pushinteger(L, fmt_id);
                    lua_pushstring(L, fmt_code.c_str());
                    return 3;
                }
                if (auto t = elem->Attribute("t"); t && !strcmp(t, "s")) {
                    lua_pushlstring(L, shared.c_str(), shared.size());
                    return 1;
                }
                lua_pushstring(L, v);
                return 1;
            }
            return 0;
        }

        string shared = "";
        string fmt_code = "";
        uint32_t fmt_id = 0;
        XMLElement* elem = nullptr;
        XMLElement* mirror = nullptr;
    };

    class workbook {
    public:
        ~workbook() { for (auto cell : pools){ delete cell; } }

        void __gc() {}

        cell* get_cell(uint32_t row, uint32_t col) {
            if (row < first_row || row > last_row || col < first_col || col > last_col) 
                return nullptr;
            uint32_t index = (row - 1) * (last_col - first_col + 1) + (col - first_col);
            return cells[index];
        }

        void add_cell(uint32_t row, uint32_t col, cell* co) {
             if (row < first_row || row > last_row || col < first_col || col > last_col)
                return;
            uint32_t index = (row - 1) * (last_col - first_col + 1) + (col - first_col);
            cells[index] = co;
        }

        int get_cell_value(lua_State* L, uint32_t row, uint32_t col) {
            if (auto cell = get_cell(row, col);  cell) return cell->get_value(L);
            return 0;
        }

        int set_cell_value(lua_State* L, uint32_t row, uint32_t col) {
            cell* cell = get_cell(row, col);
            if (lua_isnil(L, 3)) {
                if (cell) cell->elem->DeleteChildren();
                return 0;
            }
            if (!cell) {
                if (row <= 0 || col <= 0) return 0;
                auto elem = doc->NewElement("c");
                elem->SetAttribute("r", gen_excel_id(row, col).c_str());
                cell = new_cell(elem);
                add_cell(row, col, cell);
                if (row > last_row) last_row = row;
                if (col > last_col) last_col = col;
            }
            cell->set_value(L);
            return 0;
        }

        void save() {
            if (cells.empty()) return;
            XMLElement* root = doc->FirstChildElement("worksheet");
            XMLElement* shdata = root->FirstChildElement("sheetData");
            for (uint32_t row = first_row; row <= last_row; ++row) {
                XMLElement* xrow = doc->NewElement("row");
                xrow->SetAttribute("r", row);
                for (uint32_t col = first_col; col <= last_col; ++col) {
                    uint32_t index = (row - 1) * (last_col - first_col + 1) + (col - first_col);
                    auto cell = cells[index];
                    if (cell) xrow->InsertEndChild(cell->save(doc));
                }
                shdata->InsertEndChild(xrow);
            }
            XMLElement* dim = root->FirstChildElement("dimension");
            if (!dim) dim = root->InsertNewChildElement("dimension");
            auto ref = gen_excel_id(first_row, first_col) + ":" + gen_excel_id(last_row, last_col);
            dim->SetAttribute("ref", ref.c_str());
        }
        
        cell* new_cell(XMLNode* e) { 
            cell* c = new cell(e); 
            pools.push_back(c); 
            return c;
        }

        std::string gen_excel_id(uint32_t row, uint32_t col) {
            std::string col_part;
            while (col > 0) {
                uint32_t remainder = (col - 1) % 26;
                col_part += 'A' + remainder;
                col = (col - 1) / 26;
            }
            std::reverse(col_part.begin(), col_part.end());
            return col_part + std::to_string(row);
        }

        string rid;
        string name;
        bool visible = true;
        uint32_t last_row = 0;
        uint32_t last_col = 0;
        uint32_t first_row = 0;
        uint32_t first_col = 0;
        vector<cell*> cells = {};
        vector<cell*> pools = {};
        XMLDocument* doc = nullptr;
    };

    class excel_file {
    public:
        ~excel_file() {
            for (auto book : workbooks) { delete book; }
            for (auto& [_, doc] : excelfiles) { delete doc; }
        }

        void open(const char* filename) {
            mz_zip_archive archive;
            memset(&archive, 0, sizeof(archive));
            if (!mz_zip_reader_init_file(&archive, filename, 0)) {
                throw std::runtime_error("read zip error");
            }
            read_rels(&archive, "_rels/.rels");
            read_styles(&archive, "xl/styles.xml");
            read_sstrings(&archive, "xl/sharedStrings.xml");
            read_workbook(&archive, "xl/workbook.xml");
            open_xml(&archive, "[Content_Types].xml");
            mz_zip_reader_end(&archive);
        }
        
        void save(const char* filename) {
            mz_zip_archive archive;
            memset(&archive, 0, sizeof(archive));
            if (!mz_zip_writer_init_file(&archive, filename, 0)) {
                throw std::runtime_error("save zip error");
            }
            for (auto book : workbooks) book->save();
            for (auto& [path, doc] : excelfiles) {
                XMLPrinter printer;
                doc->Print(&printer);
                auto data = printer.CStr();
                auto size = printer.CStrSize();
                while (size > 0 && data[size - 1] == '\0') size--;
                mz_zip_writer_add_mem(&archive, path.c_str(), data, size, 5);
            }
            mz_zip_writer_finalize_archive(&archive);
            mz_zip_writer_end(&archive);
        }

        workbook* open_workbook(const char* name){
            auto it = find_if(workbooks.begin(), workbooks.end(), [name](workbook* p) { return p->name == name; });
            return (it != workbooks.end()) ? *it : nullptr;
        }

        vector<workbook*> all_workbooks(lua_State* L) {
            return workbooks;
        }

    private:
        XmlDocument* open_xml(mz_zip_archive* archive, const char* filename) {
            auto it = excelfiles.find(filename);
            if (it != excelfiles.end()) return it->second;
            size_t size = 0;
            XmlDocument* doc = new XmlDocument();
            uint32_t index = mz_zip_reader_locate_file(archive, filename, nullptr, 0);
            auto data = (const char*)mz_zip_reader_extract_to_heap(archive, index, &size, 0);
            if (!data || doc->Parse(data, size) != XML_SUCCESS) {
                delete doc;
                throw luakit::lua_exception("open %s error: ", filename);
            }
            excelfiles.emplace(filename, doc);
            delete[] data;
            return doc;
        }

        void read_worksheet(mz_zip_archive* archive, workbook* book) {
            XMLElement* root = book->doc->FirstChildElement("worksheet");
            XMLElement* dim = root->FirstChildElement("dimension");
            XMLElement* shdata = root->FirstChildElement("sheetData");
            parse_range(dim, shdata, book);
            book->cells.resize(book->last_col * book->last_row, nullptr);
            XMLElement* row = shdata->FirstChildElement("row");
            while (row) {
                uint32_t row_idx = row->IntAttribute("r");
                XMLElement* c = row->FirstChildElement("c");
                while (c) {
                    uint32_t col_idx = 0;
                    cell* cel = book->new_cell(c->DeepClone(book->doc));
                    parse_cell(c->Attribute("r"), row_idx, col_idx);
                    parse_cell_fmt(cel, c->Attribute("s"), c->Attribute("t"), c->FirstChildElement("v"));
                    book->add_cell(row_idx, col_idx, cel);
                    c = c->NextSiblingElement("c");
                }
                row = row->NextSiblingElement("row");
            }
            if (auto mcell = root->FirstChildElement("mergeCells"); mcell) {
                mcell = mcell->FirstChildElement("mergeCell");
                while (mcell) {
                    merge_cells(book, mcell->Attribute("ref"));
                    mcell = mcell->NextSiblingElement("mergeCell");
                }
            }
            //删除现有cell节点，方便写回
            shdata->DeleteChildren();
        }

        void read_styles(mz_zip_archive* archive, const char* filename) {
            XmlDocument* doc = open_xml(archive, filename);
            XMLElement* styleSheet = doc->FirstChildElement("styleSheet");
            if (styleSheet == nullptr) return;
            XMLElement* numFmts = styleSheet->FirstChildElement("numFmts");
            if (numFmts == nullptr) return;

            unordered_map<int, string> custom_date_formats;
            for (XMLElement* numFmt = numFmts->FirstChildElement(); numFmt; numFmt = numFmt->NextSiblingElement()) {
                uint32_t id = atoi(numFmt->Attribute("numFmtId"));
                string fmt = numFmt->Attribute("formatCode");
                custom_date_formats.insert(make_pair(id, fmt));
            }
            XMLElement* cellXfs = styleSheet->FirstChildElement("cellXfs");
            if (cellXfs == nullptr) return;

            uint32_t i = 0;
            for (XMLElement* cellXf = cellXfs->FirstChildElement(); cellXf; cellXf = cellXf->NextSiblingElement()) {
                if (auto fi = cellXf->Attribute("numFmtId"); fi) {
                    string fmt;
                    uint32_t formatId = atoi(fi);
                    auto iter = custom_date_formats.find(formatId);
                    if (iter != custom_date_formats.end()) {
                        fmt = iter->second;
                    }
                    form_ids.insert(make_pair(i, formatId));
                    fmt_codes.insert(make_pair(formatId, fmt));
                }
                ++i;
            }
        }

        void read_workbook(mz_zip_archive* archive, const char* filename) {
            XmlDocument* doc = open_xml(archive, filename);
            XMLElement* e = doc->FirstChildElement("workbook");
            e = e->FirstChildElement("sheets")->FirstChildElement("sheet");
            auto docs = read_rels(archive, "xl/_rels/workbook.xml.rels", "xl/");
            while (e) {
                workbook* book = new workbook();
                book->rid = e->Attribute("r:id");
                book->name = e->Attribute("name");
                book->visible = (e->Attribute("state") && !strcmp(e->Attribute("state"), "hidden"));
                book->doc = docs[book->rid];
                workbooks.push_back(book);
                read_worksheet(archive, book);
                e = e->NextSiblingElement("sheet");
            }
        }

        void read_sstrings(mz_zip_archive* archive, const char* filename) {
            XmlDocument* doc = open_xml(archive, filename);
            XMLElement* e = doc->FirstChildElement("sst");
            e = e->FirstChildElement("si");
            while (e) {
                XMLElement* t = e->FirstChildElement("t");
                if (t) {
                    const char* text = t->GetText();
                    shared_string.push_back(text ? text : "");
                    e = e->NextSiblingElement("si");
                    continue;
                }
                string value;
                XMLElement* r = e->FirstChildElement("r");
                while (r) {
                    t = r->FirstChildElement("t");
                    const char* text = t->GetText();
                    if (text) value.append(text);
                    r = r->NextSiblingElement("r");
                }
                shared_string.push_back(value);
                e = e->NextSiblingElement("si");
            }
        }

        map<string, XmlDocument*> read_rels(mz_zip_archive* archive, const char* filename, string path = "") {
            map<string, XmlDocument*> xml_docs;
            XmlDocument* doc = open_xml(archive, filename);
            XMLElement* e = doc->FirstChildElement("Relationships")->FirstChildElement("Relationship");
            while (e) {
                string target = e->Attribute("Target");
                if (target.substr(target.size() - 4) == ".xml") {
                    string rid = e->Attribute("Id");
                    xml_docs[rid] = open_xml(archive, (path + target).c_str());
                }
                e = e->NextSiblingElement("Relationship");
            }
            return xml_docs;
        }

        void parse_cell_fmt(cell* c, const char* s, const char* t, XMLElement* v){
            if (!v || !v->GetText()) return;
            if (s && (!t || !strcmp(t, "n"))) {
                uint32_t idx = atoi(s);
                auto it = form_ids.find(idx);
                if (it == form_ids.end()) return;
                c->fmt_id = it->second;
                auto it2 = fmt_codes.find(c->fmt_id);
                if (it2 == fmt_codes.end()) return;
                c->fmt_code = it2->second;
            }
            if (t && !strcmp(t, "s")) {
                c->shared = shared_string[atoi(v->GetText())];
            }
        }

        void parse_cell(const string& value, uint32_t& row, uint32_t& col) {
            col = 0;
            uint32_t index = 0;
            for (char ch : value) {
                if (isdigit(ch)) break;
                col = col * 26 + (ch - 'A' + 1);
                index++;
            }
            row = atol(value.c_str() + index);
        }

        void merge_cells(workbook* sh, const string& value) {
            if (auto index = value.find_first_of(':'); index != string::npos) {
                uint32_t first_row = 0, first_col = 0, last_row = 0, last_col = 0;
                parse_cell(value.substr(0, index), first_row, first_col);
                parse_cell(value.substr(index + 1), last_row, last_col);
                cell* valc = sh->get_cell(first_row, first_col);
                if (valc) {
                    for (uint32_t i = first_row;  i <= last_row; ++i) {
                        for (uint32_t j = first_col; j <= last_col; ++j) {
                            if (i != first_row || j != first_col) {
                                cell* curc = sh->get_cell(i, j);
                                if (curc) curc->merge(valc);
                                else sh->add_cell(i, j, valc);
                            }
                        }
                    }
                }
            }
        }

        void parse_range(XMLElement* dim, XMLElement* shdata, workbook* sh) {
            if (dim) {
                std::string value = dim->Attribute("ref");
                size_t index = value.find_first_of(':');
                if (index != string::npos) {
                    parse_cell(value.substr(0, index), sh->first_row, sh->first_col);
                    parse_cell(value.substr(index + 1), sh->last_row, sh->last_col);
                    return;
                }
            }
            string last_cell;
            XMLElement* row = shdata->FirstChildElement("row");
            while (row) {
                XMLElement* c = row->FirstChildElement("c");
                while (c ) {
                    last_cell = c->Attribute("r");
                    if (sh->first_row == 0) parse_cell(last_cell, sh->first_row, sh->first_col);
                    c = c->NextSiblingElement("c");
                }
                row = row->NextSiblingElement("row");
            }
            parse_cell(last_cell, sh->last_row, sh->last_col);
        }

        vector<workbook*> workbooks;
        vector<string> shared_string;
        unordered_map<uint32_t, string> fmt_codes;
        unordered_map<uint32_t, uint32_t> form_ids;
        unordered_map<string, XmlDocument*> excelfiles;
    };
}
