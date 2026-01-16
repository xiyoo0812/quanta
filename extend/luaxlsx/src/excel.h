#pragma once

#include <map>
#include <vector>
#include <unordered_map>

#include "miniz.h"
#include "pugixml.hpp"

#include "lua_kit.h"

using namespace std;
using namespace pugi;

namespace lxlsx {
    constexpr int SECOND_HOUR8 = 28800;    //3600 * 8
    constexpr int SECOND_DAY = 86400;    //3600 * 24
    constexpr int SECOND_ROOT = 25569;    //1970.1.1 0:0:0

    bool is_date_ime(uint32_t id) {
        return (id >= 14 && id <= 22) || (id >= 27 && id <= 36) || (id >= 45 && id <= 47)
            || (id >= 50 && id <= 58) || (id >= 71 && id <= 81);
    }

    bool is_custom(uint32_t id) {
        return id > 165;
    }

    bool check_local(xml_node& node, cpchar local_name) {
        if (cpchar name = node.name(); name) {
            cpchar colon = strchr(name, ':');
            cpchar actual = colon ? colon + 1 : name;
            return strcmp(actual, local_name) == 0;
        }
        return false;
    }

    void local_range(xml_node& node, cpchar local_name, std::function<void(xml_node&)> lambda) {
        for (xml_node child = node.first_child(); child; child = child.next_sibling()) {
            if (check_local(child, local_name)) lambda(child);
        }
    }

    xml_node local_child(xml_node& parent, cpchar local_name) {
        for (xml_node child = parent.first_child(); child; child = child.next_sibling()) {
            if (check_local(child, local_name)) return child;
        }
        return xml_node();
    }

    class cell {
    public:
        cell(xml_node n) : elem(n) {}

        void merge(cell* cell) {
            mirror = cell->elem;
            fmt_id = cell->fmt_id;
            shared = cell->shared;
            fmt_code = cell->fmt_code;
        }

        int set_value(lua_State* L) {
            xml_node e = mirror ? mirror : elem;
            xml_node ev = local_child(e, "v");
            if (!ev) ev = e.append_child("v");
            e.remove_attribute("t");
            switch (lua_type(L, 3)) {
            case LUA_TBOOLEAN:
                ev.text().set(lua_toboolean(L, 3) ? "true" : "false");
                e.append_attribute("t") = "b";
                break;
            case LUA_TNUMBER:
                ev.text().set(lua_tonumber(L, 3));
                break;
            case LUA_TSTRING:
                ev.text().set(lua_tostring(L, 3));
                e.append_attribute("t") = "str";
                break;
            }
            return 0;
        }

        int get_value(lua_State* L) {
            xml_node e = mirror ? mirror : elem;
            if (auto ev = local_child(e, "v"); ev) {
                cpchar v = ev.text().as_string();
                if (!v || strlen(v) == 0) return 0;
                if (fmt_id > 0) {
                    if (is_date_ime(fmt_id)) {
                        lua_pushinteger(L, SECOND_DAY * (atoi(v) - SECOND_ROOT) - SECOND_HOUR8);
                        return 1;
                    }
                    if (is_custom(fmt_id)) {
                        if (fmt_code.find_first_of("yy") != string::npos) {
                            lua_pushinteger(L, SECOND_DAY * (atoi(v) - SECOND_ROOT) - SECOND_HOUR8);
                            return 1;
                        }
                        if (fmt_code.find_first_of("mm:ss") != string::npos) {
                            lua_pushnumber(L, atof(v) * SECOND_DAY);
                            return 1;
                        }
                    }
                    lua_pushstring(L, v);
                    lua_pushinteger(L, fmt_id);
                    lua_pushstring(L, fmt_code.c_str());
                    return 3;
                }
                if (auto t = e.attribute("t"); t && !strcmp(t.value(), "s")) {
                    lua_pushlstring(L, shared.c_str(), shared.size());
                    return 1;
                }
                lua_pushstring(L, v);
                return 1;
            }
            if (auto is = local_child(e, "is"); is) {
                if (auto t = local_child(is, "t"); t) {
                    lua_pushstring(L, t.text().as_string());
                    return 1;
                }
            }
            return 0;
        }

        string shared = "";
        string fmt_code = "";
        uint32_t fmt_id = 0;
        xml_node elem;
        xml_node mirror;
    };

    class workbook {
    public:
        ~workbook() { for (auto cell : pools) { delete cell; } }

        void __gc() {}

        cell* get_cell(uint32_t row, uint32_t col) {
            if (row < 1 || row > last_row || col < 1 || col > last_col)
                return nullptr;
            return cells[row - 1][col - 1];
        }

        void add_cell(uint32_t row, uint32_t col, cell* co) {
            if (row < 1 || row > last_row || col < 1 || col > last_col)
                return;
            cells[row - 1][col - 1] = co;
        }

        int get_cell_value(lua_State* L, uint32_t row, uint32_t col) {
            if (auto cell = get_cell(row, col);  cell) return cell->get_value(L);
            return 0;
        }

        int set_cell_value(lua_State* L, uint32_t row, uint32_t col) {
            cell* cell = get_cell(row, col);
            if (lua_isnil(L, 3)) {
                if (cell) cell->elem.remove_children();
                return 0;
            }
            if (!cell) {
                if (row <= 0 || col <= 0) return 0;
                extend_cells(row, col);
                auto elem = sheet_node.append_child("c");
                elem.append_attribute("r").set_value(gen_excel_id(row, col).c_str());
                cell = new_cell(elem);
                add_cell(row, col, cell);
            }
            cell->set_value(L);
            return 0;
        }

        void save() {
            if (cells.empty()) return;
            sheetdata.remove_children();
            for (uint32_t row = 1; row <= last_row; ++row) {
                auto& row_cells = cells[row - 1];
                if (!row_cells.empty()) {
                    xml_node xrow = sheetdata.append_child("row");
                    xrow.append_attribute("r").set_value(row);
                    for (auto cell : row_cells) {
                        if (cell) xrow.append_copy(cell->elem);
                    }
                }
            }
            xml_node dim = local_child(worksheet, "dimension");
            if (!dim) dim = worksheet.append_child("dimension");
            string ref = "A1:" + gen_excel_id(last_row, last_col);
            dim.attribute("ref").set_value(ref.c_str());
        }

        cell* new_cell(xml_node e) {
            cell* c = new cell(e);
            pools.push_back(c);
            return c;
        }

        void extend_cells(uint32_t row, uint32_t col) {
            if (col > last_col) {
                last_col = col;
                for (auto& row_cells : cells) {
                    row_cells.resize(col, nullptr);
                }
            }
            if (row > last_row) {
                last_row = row;
                cells.resize(row, {});
                for (auto& row_cells : cells) {
                    row_cells.resize(last_col, nullptr);
                }
            }
        }

        string gen_excel_id(uint32_t row, uint32_t col) {
            string col_part;
            while (col > 0) {
                uint32_t remainder = (col - 1) % 26;
                col_part += 'A' + remainder;
                col = (col - 1) / 26;
            }
            reverse(col_part.begin(), col_part.end());
            return col_part + to_string(row);
        }

        string rid;
        string name;
        bool visible = true;
        uint32_t last_row = 0;
        uint32_t last_col = 0;
        vector<cell*> pools = {};
        vector<vector<cell*>> cells = {};
        xml_document* doc = nullptr;
        xml_node sheet_node;
        xml_node worksheet;
        xml_node sheetdata;
    };

    class excel_file {
    public:
        ~excel_file() {
            for (auto book : workbooks) { delete book; }
            for (auto& [_, doc] : excelfiles) { delete doc; }
        }

        void open(cpchar filename) {
            mz_zip_archive archive = {};
            if (!mz_zip_reader_init_file(&archive, filename, 0)) {
                throw runtime_error("read zip error");
            }
            read_rels(&archive, "_rels/.rels");
            read_styles(&archive, "xl/styles.xml");
            read_sstrings(&archive, "xl/sharedStrings.xml");
            read_workbook(&archive, "xl/workbook.xml");
            open_xml(&archive, "[Content_Types].xml");
            mz_zip_reader_end(&archive);
        }

        void save(cpchar filename) {
            mz_zip_archive archive = {};
            if (!mz_zip_writer_init_file(&archive, filename, 0)) {
                throw runtime_error("save zip error");
            }
            for (auto book : workbooks) book->save();
            for (auto& [path, doc] : excelfiles) {
                ostringstream oss;
                doc->save(oss);
                string data = oss.str();
                mz_zip_writer_add_mem(&archive, path.c_str(), data.c_str(), data.size(), 5);
            }
            mz_zip_writer_finalize_archive(&archive);
            mz_zip_writer_end(&archive);
        }

        workbook* open_workbook(cpchar name) {
            auto it = find_if(workbooks.begin(), workbooks.end(),
                [name](workbook* p) { return p->name == name; });
            return (it != workbooks.end()) ? *it : nullptr;
        }

        vector<workbook*> all_workbooks(lua_State* L) {
            return workbooks;
        }

    private:
        xml_document* open_xml(mz_zip_archive* archive, cpchar filename, bool notfoundexception = true) {
            if (auto it = excelfiles.find(filename); it != excelfiles.end()) return it->second;
            auto index = mz_zip_reader_locate_file(archive, filename, nullptr, 0);
            if (index < 0) {
                if (notfoundexception) throw luakit::lua_exception("open {} error: ", filename);
                return nullptr;
            }
            size_t size = 0;
            char* data = (char*)mz_zip_reader_extract_to_heap(archive, index, &size, 0);
            if (!data) throw luakit::lua_exception("extract {} error: ", filename);
            xml_document* doc = new xml_document();
            if (auto result = doc->load_buffer(data, size); !result) {
                delete doc;
                delete[] data;
                throw luakit::lua_exception("parse {} error at offset {}: {}", filename, result.offset, result.description());
            }
            excelfiles.emplace(filename, doc);
            delete[] data;
            return doc;
        }

        void read_worksheet(mz_zip_archive* archive, workbook* book) {
            xml_node worksheet = local_child(*book->doc, "worksheet");
            xml_node sheetdata = local_child(worksheet, "sheetData");
            if (!worksheet || !sheetdata) throw runtime_error("invalid worksheet format");
            xml_node dim = local_child(worksheet, "dimension");
            parse_range(dim, sheetdata, book);
            local_range(sheetdata, "row", [&](xml_node& row) {
                uint32_t row_idx = row.attribute("r").as_uint();
                local_range(row, "c", [&](xml_node& c) {
                    uint32_t col_idx = 0;
                    cell* cel = book->new_cell(c);
                    parse_cell(c.attribute("r").as_string(), row_idx, col_idx);
                    parse_cell_fmt(cel, c.attribute("s"), c.attribute("t"), local_child(c, "v"));
                    book->add_cell(row_idx, col_idx, cel);
                });
            });
            if (auto mergecell = local_child(worksheet,"mergeCells"); mergecell) {
                local_range(mergecell, "mergeCell", [&](xml_node& mcell) {
                    merge_cells(book, mcell.attribute("ref").as_string());
                });
            }
            //删除现有cell节点，方便写回
            sheetdata.remove_children();
            book->worksheet = worksheet;
            book->sheetdata = sheetdata;
        }

        void read_styles(mz_zip_archive* archive, cpchar filename) {
            auto doc = open_xml(archive, filename);
            if (auto stylesheet = local_child(*doc, "styleSheet"); stylesheet) {
                if (auto numfmts = local_child(stylesheet, "numFmts"); numfmts) {
                    unordered_map<int, string> custom_date_fmts;
                    for (xml_node numfmt = numfmts.first_child(); numfmt; numfmt = numfmt.next_sibling()) {
                        uint32_t id = numfmt.attribute("numFmtId").as_uint();
                        string fmt = numfmt.attribute("formatCode").as_string();
                        custom_date_fmts[id] = fmt;
                    }
                    if (auto cellxfs = local_child(stylesheet, "cellXfs"); cellxfs) {
                        uint32_t i = 0;
                        for (xml_node cellxf = cellxfs.first_child(); cellxf; cellxf = cellxf.next_sibling()) {
                            if (auto fi = cellxf.attribute("numFmtId"); fi) {
                                string fmt;
                                uint32_t formatId = fi.as_uint();
                                if (auto iter = custom_date_fmts.find(formatId); iter != custom_date_fmts.end()) {
                                    fmt = iter->second;
                                }
                                form_ids[i] = formatId;
                                fmt_codes[formatId] = fmt;
                            }
                            ++i;
                        }
                    }
                }
            }
        }

        void read_workbook(mz_zip_archive* archive, cpchar filename) {
            xml_document* doc = open_xml(archive, filename);
            xml_node wkbook = local_child(*doc, "workbook");
            if (!wkbook) throw runtime_error("invalid workbook format");
            xml_node sheets = local_child(wkbook, "sheets");
            if (!sheets) throw runtime_error("no sheets found in workbook");
            auto docs = read_rels(archive, "xl/_rels/workbook.xml.rels", "xl/");
            local_range(sheets, "sheet", [&](xml_node& sheet) {
                workbook* book = new workbook();
                book->rid = sheet.attribute("r:id").as_string();
                book->name = sheet.attribute("name").as_string();
                xml_attribute state = sheet.attribute("state");
                book->visible = (!state || string(state.as_string()) != "hidden");
                auto it = docs.find(book->rid);
                if (it == docs.end()) throw runtime_error("worksheet not found: " + book->rid);
                book->doc = it->second;
                workbooks.push_back(book);
                read_worksheet(archive, book);
            });
        }

        void read_sstrings(mz_zip_archive* archive, cpchar filename) {
            if (auto doc = open_xml(archive, filename, false); doc) {
                if (auto sst = local_child(*doc, "sst"); sst) {
                    local_range(sst, "si", [&](xml_node& si) {
                        if (auto t = local_child(si, "t"); t) {
                            cpchar text = t.text().as_string();
                            shared_string.push_back(text ? text : "");
                            return;
                        }
                        string value;
                        local_range(si, "r", [&](xml_node& r) {
                            if (auto t = local_child(r, "t"); t) {
                                cpchar text = t.text().as_string();
                                if (text) value.append(text);
                            }
                        });
                        shared_string.push_back(value);
                    });
                }
            }
        }

        map<string, xml_document*> read_rels(mz_zip_archive* archive, cpchar filename, string path = "") {
            map<string, xml_document*> xml_docs;
            xml_document* doc = open_xml(archive, filename);
            xml_node relationships = local_child(*doc, "Relationships");
            if (!relationships) return xml_docs;
            local_range(relationships, "Relationship", [&](xml_node& rel) {
                string target = rel.attribute("Target").as_string();
                if (target.size() >= 4 && target.substr(target.size() - 4) == ".xml") {
                    string rid = rel.attribute("Id").as_string();
                    if (auto tdoc = open_xml(archive, target.c_str(), false); tdoc) xml_docs[rid] = tdoc;
                    if (auto tdoc = open_xml(archive, (path + target).c_str(), false); tdoc) xml_docs[rid] = tdoc;
                }
            });
            return xml_docs;
        }

        void parse_cell_fmt(cell* c, xml_attribute s, xml_attribute t, xml_node v) {
            if (!v || v.text().empty()) return;
            if (s && (!t || strcmp(t.as_string(), "n") == 0)) {
                uint32_t idx = s.as_int();
                auto it = form_ids.find(idx);
                if (it == form_ids.end()) return;
                c->fmt_id = it->second;
                auto it2 = fmt_codes.find(c->fmt_id);
                if (it2 == fmt_codes.end()) return;
                c->fmt_code = it2->second;
            }
            if (t && strcmp(t.as_string(), "s") == 0) {
                c->shared = shared_string[v.text().as_int()];
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
                if (cell* valc = sh->get_cell(first_row, first_col); valc) {
                    for (uint32_t i = first_row; i <= last_row; ++i) {
                        for (uint32_t j = first_col; j <= last_col; ++j) {
                            if (i != first_row || j != first_col) {
                                if (cell* curc = sh->get_cell(i, j); curc) curc->merge(valc);
                                else sh->add_cell(i, j, valc);
                            }
                        }
                    }
                }
            }
        }

        void parse_range(xml_node& dim, xml_node& shdata, workbook* sh) {
            uint32_t last_row = 0, last_col = 0;
            if (dim) {
                string value = dim.attribute("ref").as_string();
                if (size_t index = value.find_first_of(':'); index != string::npos) {
                    parse_cell(value.substr(index + 1), last_row, last_col);
                    sh->extend_cells(last_row, last_col);
                    return;
                }
            }
            string last_cell;

            local_range(shdata, "row", [&](xml_node& row) {
                local_range(row, "c", [&](xml_node& c) {
                    last_cell = c.attribute("r").as_string();
                });
            });
            if (!last_cell.empty()) {
                parse_cell(last_cell, last_row, last_col);
                sh->extend_cells(last_row, last_col);
            }
        }

        vector<workbook*> workbooks;
        vector<string> shared_string;
        unordered_map<uint32_t, string> fmt_codes;
        unordered_map<uint32_t, uint32_t> form_ids;
        unordered_map<string, xml_document*> excelfiles;
    };
}