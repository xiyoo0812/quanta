#pragma once

#include "csv.hpp"
#include "lua_kit.h"

using namespace std;
using namespace csv2;

using fspath = std::filesystem::path;

namespace lcsv {
    using csv_reader = Reader<delimiter<','>, quote_character<'"'>, first_row_is_header<true>, trim_policy::trim_characters<' ', '\t', '\r', '\n'>>;

    class cell {
    public:
        string value = "";
        void read(const csv_reader::Cell& c) {
            c.read_value(value);
        }
    };

    class workbook {
    public:
        ~workbook() {
            for (auto rcells : cells){
                for (auto cell : rcells) {
                    if (cell) delete cell;
                }
            }
        }

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
            if (cell* cell = get_cell(row, col); cell) {
                lua_pushstring(L, cell->value.c_str());
                return 1;
            }
            return 0;
        }

        string name;
        uint32_t last_row = 0;
        uint32_t last_col = 0;
        vector<vector<cell*>> cells = {};
    };

    class csv_file {
    public:
        ~csv_file() {
            for (auto book : workbooks) { delete book; }
        }

        bool open(const char* filename) {
            csv_reader csv;
            if (!csv.mmap(filename)) {
                return false;
            }
            auto ncol = 0;
            const auto header = csv.header();
            for (const auto& cel : header) ncol++;
            workbook* book = new workbook();
            if (ncol > 0) {
                book->last_col = ncol;
                book->last_row = csv.rows() + 1;
                book->name = fspath(filename).stem().string();
                int irow = 1, icol = 1;
                book->cells.resize(book->last_row, {});
                for (int i = 0; i < book->last_row; i++) {
                    book->cells[i].resize(book->last_col, nullptr);
                }
                for (const auto& cel : header) {
                    cell* co = new cell;
                    co->read(cel);
                    book->add_cell(irow, icol++, co);
                }
                for (const auto& row : csv) {
                    irow++; icol = 1;
                    for (const auto& cel : row) {
                        cell* co = new cell;
                        co->read(cel);
                        book->add_cell(irow, icol++, co);
                    }
                }
            }
            workbooks.push_back(book);
            return true;
        }

        workbook* open_workbook(const char* name){
            auto it = find_if(workbooks.begin(), workbooks.end(), [name](workbook* p) { return p->name == name; });
            return (it != workbooks.end()) ? *it : nullptr;
        }

        vector<workbook*> all_workbooks(lua_State* L) {
            return workbooks;
        }

    private:
        vector<workbook*> workbooks;
    };
}
