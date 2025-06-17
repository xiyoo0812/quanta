#define LUA_LIB

#include <sstream>

#include "lua_kit.h"
#include "lcsv.h"

using namespace std;
using namespace csv2;
using namespace luakit;

namespace lcsv {

    inline void decode_value(lua_State* L, string key) {
        const char* value = key.data();
        if (lua_stringtonumber(L, value) == 0) {
            lua_pushlstring(L, value, key.length());
        }
    }

    inline int decode_reader(lua_State* L, csv_reader& reader) {
        vector<string> headers;
        for (const auto& cell : reader.header()) {
            string value;
            cell.read_value(value);
            headers.push_back(value);
        }
        int index = 1;
        int keyidx = luaL_optinteger(L, 2, 0) - 1;
        lua_createtable(L, 0, 4);
        for (const auto& row : reader) {
            if (row.length() <= 0) {
                continue;
            }
            vector<string> values;
            for (const auto& cell : row) {
                string value;
                cell.read_value(value);
                values.push_back(value);
            }
            lua_createtable(L, 0, 4);
            string* key = nullptr;
            for (int i = 0; i < values.size(); ++i) {
                if (i < headers.size()) {
                    if (i == keyidx) key = &values[i];
                    decode_value(L, headers[i]);
                    decode_value(L, values[i]);
                    lua_rawset(L, -3);
                }
            }
            if (key) {
                decode_value(L, *key);
                lua_insert(L, -2);
                lua_rawset(L, -3);
            }
            else {
                lua_seti(L, -2, index++);
            }
        }
        return 1;
    }

    inline int decode_csv(lua_State* L, string doc) {
        csv_reader csv;
        if (!csv.parse(doc)) {
            luaL_error(L, "parse csv failed!");
            return 0;
        }
        return decode_reader(L, csv);
    }

    inline int read_csv(lua_State* L, const char* csvfile) {
        csv_reader csv;
        if (!csv.mmap(csvfile)) {
            luaL_error(L, "parse csv failed!");
            return 0;
        }
        return decode_reader(L, csv);
    }

    inline const char* encode_value(lua_State* L, int index) {
        switch (lua_type(L, index)) {
        case LUA_TNUMBER:
        case LUA_TSTRING:
            return lua_tostring(L, index);
            break;
        default:
            luaL_error(L, "unsuppert lua type");
        }
        return "";
    }

    inline void encode_header(lua_State* L, int index, vector<string>& header) {
        lua_pushnil(L);
        while (lua_next(L, index) != 0) {
            header.push_back(encode_value(L, -2));
            lua_pop(L, 1);
        }
    }

    inline void encode_row(lua_State* L, int index, vector<string>& row, vector<string>& header) {
        if (is_lua_array(L, index)) {
            size_t len = lua_rawlen(L, index);
            for (size_t i = 1; i <= len; ++i) {
                lua_geti(L, index, i);
                row.push_back(encode_value(L, -1));
                lua_pop(L, 1);
            }
        } else if (header.empty()) {
            lua_pushnil(L);
            while (lua_next(L, index) != 0) {
                row.push_back(encode_value(L, -1));
                lua_pop(L, 1);
            }
        } else {
            for (string head : header) {
                lua_getfield(L, index, head.c_str());
                row.push_back(encode_value(L, -1));
                lua_pop(L, 1);
            }
        }
    }

    inline void encode_rows(lua_State* L, vector<vector<string>>& rows) {
        lua_pushnil(L);
        bool header_load = false;
        vector<string> header;
        while (lua_next(L, -2) != 0) {
            if (lua_type(L, -1) == LUA_TTABLE) {
                if (!is_lua_array(L, -1) && !header_load) {
                    header_load = true;
                    encode_header(L, lua_absindex(L, -1), header);
                    rows.push_back(header);
                }
                vector<string> row;
                encode_row(L, lua_absindex(L, -1), row, header);
                rows.push_back(row);
            }
            lua_pop(L, 1);
        }
    }

    inline int encode_csv(lua_State* L) {
        vector<vector<string>> rows;
        encode_rows(L, rows);
        stringstream stm;
        Writer writer(stm);
        writer.write_rows(rows);
        lua_pushlstring(L, stm.str().c_str(), stm.str().length());
        return 1;
    }

    static int save_csv(lua_State* L, const char* csvfile) {
        vector<vector<string>> rows;
        encode_rows(L, rows);
        ofstream fstm(csvfile);
        Writer writer(fstm);
        writer.write_rows(rows);
        fstm.close();
        lua_pushboolean(L, true);
        return 1;
    }

    static csv_file* open_csv(const char* filename) {
        auto excel = new csv_file();
        if (!excel->open(filename)) {
            delete excel;
            return nullptr;
        }
        return excel;
    }

    lua_table open_lcsv(lua_State* L) {
        kit_state kit_state(L);
        lua_table csv = kit_state.new_table("csv");
        csv.set_function("decode", decode_csv);
        csv.set_function("encode", encode_csv);
        csv.set_function("read", read_csv);
        csv.set_function("save", save_csv);
        csv.set_function("open", open_csv);
        kit_state.new_class<workbook>(
            "name", &workbook::name,
            "last_row", &workbook::last_row,
            "last_col", &workbook::last_col,
            "first_row", &workbook::first_row,
            "first_col", &workbook::first_col,
            "get_cell_value", &workbook::get_cell_value
        );
        kit_state.new_class<csv_file>(
            "open", &csv_file::open_workbook,
            "workbooks", &csv_file::all_workbooks
        );
        return csv;
    }
}

extern "C" {
    LUALIB_API int luaopen_lcsv(lua_State* L) {
        auto yaml = lcsv::open_lcsv(L);
        return yaml.push_stack();
    }
}
