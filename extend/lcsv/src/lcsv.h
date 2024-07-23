#pragma once
#include  <filesystem>

#include "csv.hpp"
#include "lua_kit.h"

using namespace std;
using namespace csv2;
using fspath = std::filesystem::path;

namespace lcsv {
    using csv_reader = Reader<delimiter<','>, quote_character<'"'>, first_row_is_header<true>, trim_policy::trim_characters<' ', '\t', '\r', '\n'>>;

    class cell {
    public:
        void __gc() {}
        string type = "string";
        string value = "";

        void read(const csv_reader::Cell& c) {
            c.read_value(value);
            if (value.size() == 0) {
                type = "blank";
            }
        }

        cell* clone() {
            cell* cl = new cell();
            cl->type = type;
            cl->value = value;
            return cl;
        }
    };

    class sheet {
    public:
        ~sheet() {
            for (auto cell : cells){ if (cell) delete cell; }
        }

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

        string name;
        uint32_t last_row = 0;
        uint32_t last_col = 0;
        uint32_t first_row = 0;
        uint32_t first_col = 0;
        vector<cell*> cells = {};
    };

    class csv_file {
    public:
        ~csv_file() { 
            for (auto sh : csv_sheets) { if (sh) delete sh; }
        }

        bool open(const char* filename) {
            csv_reader csv;
            if (!csv.mmap(filename)) {
                return false;
            }
            sheet* s = new sheet();
            const auto header = csv.header();
            if (header.length() > 0) {
                s->first_row = 1;
                s->first_col = 1;
                s->name = fspath(filename).stem().string();
                s->last_col = header.length();
                s->last_row = csv.rows() + 1;
                s->cells.resize(s->last_col * s->last_row);
                int irow = 1, icol = 1;
                for (const auto& cel : header) {
                    cell* co = new cell;
                    co->read(cel);
                    s->add_cell(irow, icol++, co);
                }
                for (const auto& row : csv) {
                    irow++; icol = 1;
                    for (const auto& cel : row) {
                        cell* co = new cell;
                        co->read(cel);
                        s->add_cell(irow, icol++, co);
                    }
                }
            }
            csv_sheets.push_back(s);
            return true;
        }

        sheet* get_sheet(const char* name){
            for (auto sh : csv_sheets) {
                if (sh->name == name) return sh;
            }
            return nullptr;
        }

        luakit::reference sheets(lua_State* L) { 
            luakit::kit_state kit_state(L);
            return kit_state.new_reference(csv_sheets);
        }

    private:
        vector<sheet*> csv_sheets;
    };
}
