
#define LUA_LIB

#include "aoi.h"

namespace laoi {

    static aoi_obj* create_object(uint64_t id, uint8_t typ) {
        return new aoi_obj(id, (aoi_type)typ);
    }

    static aoi* create_aoi(uint32_t w, uint32_t h, uint16_t grid, uint16_t aoi_len, bool offset, bool dynamic) {
        return new aoi(w, h, grid, aoi_len, offset, dynamic);
    }

    luakit::lua_table open_laoi(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llaoi = kit_state.new_table();
        llaoi.set_function("create_aoi", create_aoi);
        llaoi.set_function("create_object", create_object);
        llaoi.new_enum("aoi_type", "watcher", aoi_type::watcher, "marker", aoi_type::marker);
        kit_state.new_class<aoi_obj>(
            "x", &aoi_obj::grid_x,
            "z", &aoi_obj::grid_z
        );
        kit_state.new_class<aoi>(
            "move", &aoi::move,
            "attach", &aoi::attach,
            "detach", &aoi::detach,
            "add_hotarea", &aoi::add_hotarea
            );
        return llaoi;
    }
}

extern "C" {
    LUALIB_API int luaopen_laoi(lua_State* L) {
        auto llaoi = laoi::open_laoi(L);
        return llaoi.push_stack();
    }
}
