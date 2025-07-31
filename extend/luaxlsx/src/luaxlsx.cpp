#define LUA_LIB

#include "excel.h"

namespace lxlsx {

    static excel_file* open_excel(lua_State* L, const char* filename) {
        auto excel = new excel_file();
        try {
            excel->open(filename);
            return excel;
        } catch (const std::exception& e) {
            delete excel;
            luaL_error(L, "open excel failed: %s", e.what());
        }
        return nullptr;
    }

    luakit::lua_table open_luaxlsx(lua_State* L) {
        luakit::kit_state kit_state(L);
        luakit::lua_table luaxlsx = kit_state.new_table("xlsx");
        luaxlsx.set_function("open", open_excel);
        kit_state.new_class<workbook>(
            "name", &workbook::name,
            "last_row", &workbook::last_row,
            "last_col", &workbook::last_col,
            "get_cell_value", &workbook::get_cell_value,
            "set_cell_value", &workbook::set_cell_value
        );
        kit_state.new_class<excel_file>(
            "save", &excel_file::save,
            "open", &excel_file::open_workbook,
            "workbooks", &excel_file::all_workbooks
        );
        return luaxlsx;
    }
}

extern "C" {
    LUALIB_API int luaopen_luaxlsx(lua_State* L) {
        auto luaxlsx = lxlsx::open_luaxlsx(L);
        return luaxlsx.push_stack();
    }
}
