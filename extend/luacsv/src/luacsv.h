#pragma once

#include "rapidcsv.h"
#include "lua_kit.h"

using namespace std;
using namespace rapidcsv;
using fspath = std::filesystem::path;

namespace luacsv {

    class workbook {
    public:
        void __gc() {}
        bool load(cstring& filename) {
            try {
                doc = make_unique<Document>(filename);
                name = fspath(filename).stem().string();
                last_col = doc->GetColumnCount();
                last_row = doc->GetRowCount() + 1;
                return true;
            } catch (...) {
                return false;
            }
        }

        int get_cell_value(lua_State* L, uint32_t row, uint32_t col) {
            if (doc && row >= 1 && row <= last_row && col >= 1 && col <= last_col) {
                sstring val;
                if (row == 1) {
                    auto colNames = doc->GetColumnNames();
                    val = colNames[col - 1];
                } else {
                    val = doc->GetCell<sstring>(static_cast<int>(col - 1), static_cast<int>(row - 2));
                }
                lua_pushstring(L, val.c_str());
                return 1;
            }
            return 0;
        }

        string name;
        uint32_t last_row = 0;
        uint32_t last_col = 0;
        unique_ptr<Document> doc;
    };

    class csv_file {
    public:
        ~csv_file() {
            workbooks.clear();
        }

        void __gc() {}

        bool open(cpchar filename) {
            auto book = make_shared<workbook>();
            if (book->load(filename)) {
                workbooks.push_back(std::move(book));
                return true;
            }
            return false;
        }

        workbook* open_workbook(cpchar name){
            auto it = find_if(workbooks.begin(), workbooks.end(), [name](const shared_ptr<workbook>& p) { 
                return p && p->name == name; 
            });
            return (it != workbooks.end()) ? it->get() : nullptr;
        }

        const vector<shared_ptr<workbook>>& all_workbooks() const {
            return workbooks;
        }

    private:
        vector<shared_ptr<workbook>> workbooks;
    };
}
