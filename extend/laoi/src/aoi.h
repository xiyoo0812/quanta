#ifndef __AOI_H__
#define __AOI_H__
#include "lua_kit.h"

#include <set>
#include <map>
#include <list>
#include <vector>
#include <algorithm>
#include <stdlib.h>

using namespace std;

namespace laoi {

    const uint16_t zero = 0;

    enum class aoi_type : uint16_t
    {
        watcher     = 0,    //观察者
        marker      = 1,    //被观察者
    };

    #pragma pack(2)
    struct aoi_obj
    {
        uint64_t eid;
        aoi_type type;
        uint16_t grid_x = 0;
        uint16_t grid_z = 0;
        void set_grid(uint16_t x, uint16_t z) {
            grid_x = x;
            grid_z = z;
        }
        aoi_obj(uint64_t id, aoi_type typ) : eid(id), type(typ) {}
    };
    #pragma pack()

    typedef set<aoi_obj*> object_set;
    typedef vector<object_set*> grid_array;
    typedef vector<grid_array> grid_map;
    typedef map<uint32_t, uint16_t> hotarea_map;
    thread_local list<object_set*> grid_pools = {};

    class aoi
    {
    public:
        aoi(lua_State* L, uint32_t w, uint32_t h, uint16_t glen, uint16_t aoi_len, bool offset, bool dyni) {
            mL = L;
            dynamic = dyni;
            grid_len = glen;
            aoi_radius = aoi_len;
            xgrid_num = w / glen;
            zgrid_num = h / glen;
            grids.resize(zgrid_num);
            for (int i = 0; i < zgrid_num; ++i) {
                grids[i].resize(xgrid_num);
                for (int j = 0; j < zgrid_num; ++j) {
                    grids[i][j] = (!dynamic ) ? get_grid_set() : nullptr;
                }
            }
            if (offset) {
                offset_w = w / 2;
                offset_h = h / 2;
            }
        }
        ~aoi(){
            for (auto garray : grids) {
                for (auto oset : garray) {
                    if (oset) {
                        oset->clear();
                        grid_pools.push_back(oset);
                    }
                }
            }
        };

        void copy(object_set& dst, object_set* src) {
            if (src) {
                for (auto o : *src) {
                    dst.insert(o);
                }
            }
        }

        uint16_t convert_x(int32_t inoout_x, uint16_t glen){
            return (inoout_x + offset_w) / glen;
        }

        uint16_t convert_z(int32_t inoout_z, uint16_t glen){
            return (inoout_z + offset_h) / glen;
        }

        uint16_t find_hotarea_id(int32_t x, int32_t z) {
            uint16_t nxgrid = convert_x(x, grid_hot);
            uint16_t nzgrid = convert_z(z, grid_hot);
            uint32_t index = nxgrid << 16 | nzgrid;
            auto it = hotmaps.find(index);
            if (it != hotmaps.end()) {
                return it->second;
            }
            return 0;
        }

        object_set* get_grid_set() {
            if (grid_pools.empty()) {
                return new object_set();
            }
            object_set* obj = grid_pools.front();
            grid_pools.pop_front();
            return obj;
        }

        void add_hotarea(uint16_t id, uint16_t ghl, int32_t x, int32_t z) {
            grid_hot = ghl;
            uint16_t nxgrid = convert_x(x, ghl);
            uint16_t nzgrid = convert_z(z, ghl);
            hotmaps[nxgrid << 16 | nzgrid] = id;
        }

        void get_rect_objects(object_set& objs, uint16_t lx, uint16_t rx, uint16_t lz, uint16_t rz) {
            uint16_t minX = max<uint16_t>(zero, lx);
            uint16_t minZ = max<uint16_t>(zero, lz);
            uint16_t maxX = min<uint16_t>(xgrid_num, rx);
            uint16_t maxZ = min<uint16_t>(zgrid_num, rz);
            for(uint16_t z = minZ; z < maxZ; z++) {
                for(uint16_t x = minX; x < maxX; x++) {
                    copy(objs, grids[z][x]);
                }
            }
        }

        void get_around_objects(object_set& enters, object_set& leaves, uint16_t oxgrid, uint16_t ozgrid, uint16_t nxgrid, uint16_t nzgrid) {
            int16_t offsetX = nxgrid - oxgrid;
            int16_t offsetZ = nzgrid - ozgrid;
            if (offsetX < 0) {
                get_rect_objects(enters, nxgrid - aoi_radius, oxgrid - aoi_radius, nzgrid - aoi_radius, nzgrid + aoi_radius);
                get_rect_objects(leaves, nxgrid + aoi_radius, oxgrid + aoi_radius, ozgrid - aoi_radius, ozgrid + aoi_radius);
            }
            else if (offsetX > 0){
                get_rect_objects(enters, oxgrid + aoi_radius, nxgrid + aoi_radius, nzgrid - aoi_radius, nzgrid + aoi_radius);
                get_rect_objects(leaves, oxgrid - aoi_radius, nxgrid - aoi_radius, ozgrid - aoi_radius, ozgrid + aoi_radius);
            }
            if (offsetZ < 0) {
                get_rect_objects(enters, nxgrid - aoi_radius, nxgrid + aoi_radius, nzgrid - aoi_radius, ozgrid - aoi_radius);
                get_rect_objects(leaves, oxgrid - aoi_radius, oxgrid + aoi_radius, nzgrid + aoi_radius, ozgrid + aoi_radius);
            }
            else if (offsetZ > 0){
                get_rect_objects(enters, nxgrid - aoi_radius, nxgrid + aoi_radius, ozgrid + aoi_radius, nzgrid + aoi_radius);
                get_rect_objects(leaves, oxgrid - aoi_radius, oxgrid + aoi_radius, ozgrid - aoi_radius, nzgrid - aoi_radius);
            }
        }

        bool attach(aoi_obj* obj, int32_t x, int32_t z){
            uint16_t nxgrid = convert_x(x, grid_len);
            uint16_t nzgrid = convert_z(z, grid_len);
            if ((nxgrid < 0) || (nxgrid >= xgrid_num) || (nzgrid < 0) || (nzgrid >= zgrid_num)) {
                return false;
            }
            //查询节点
            object_set objs;
            get_rect_objects(objs, nxgrid - aoi_radius, nxgrid + aoi_radius, nzgrid - aoi_radius, nzgrid + aoi_radius);
            //消息通知
            luakit::kit_state kit_state(mL);
            for (auto cobj : objs) {
                if (obj == cobj) continue;
                if (cobj->type == aoi_type::watcher) {
                    kit_state.object_call(this, "on_enter", nullptr, std::tie(), cobj->eid, obj->eid);
                }
                if (obj->type == aoi_type::watcher) {
                    kit_state.object_call(this, "on_enter", nullptr, std::tie(), obj->eid, cobj->eid);
                }
            }
            //放入格子
            insert(obj, nxgrid, nzgrid);
            return true;
        }

        void insert(aoi_obj* obj, uint16_t nxgrid, uint16_t nzgrid) {
            obj->set_grid(nxgrid, nzgrid);
            auto cur_set = grids[nzgrid][nxgrid];
            if (!cur_set) {
                cur_set = get_grid_set();
                grids[nzgrid][nxgrid] = cur_set;
            }
            cur_set->insert(obj);
        }

        void detach(aoi_obj* obj) {
            auto gset = grids[obj->grid_z][obj->grid_x];
            if (gset) {
                gset->erase(obj);
                if (dynamic && gset->empty()) {
                    grid_pools.push_back(gset);
                }
            }
        }

        uint32_t move(aoi_obj* obj, int32_t x, int32_t z) {
            uint16_t nxgrid = convert_x(x, grid_len);
            uint16_t nzgrid = convert_z(z, grid_len);
            if ((nxgrid < 0) || (nxgrid >= xgrid_num) || (nzgrid < 0) || (nzgrid >= zgrid_num)) {
                return -1;
            }
            if (nxgrid == obj->grid_x && nzgrid == obj->grid_z){
                return 0;
            }
            detach(obj);
            //消息通知
            object_set enters, leaves;
            get_around_objects(enters, leaves, obj->grid_x,  obj->grid_z, nxgrid, nzgrid);
            //进入视野
            luakit::kit_state kit_state(mL);
            for (auto cobj : enters) {
                if (cobj->type == aoi_type::watcher) {
                    kit_state.object_call(this, "on_enter", nullptr, std::tie(), cobj->eid, obj->eid);
                }
                if (obj->type == aoi_type::watcher) {
                    kit_state.object_call(this, "on_enter", nullptr, std::tie(), obj->eid, cobj->eid);
                }
            }
            //退出事视野
            for (auto cobj : leaves) {
               if (cobj->type == aoi_type::watcher) {
                    kit_state.object_call(this, "on_leave", nullptr, std::tie(), cobj->eid, obj->eid);
                }
                if (obj->type == aoi_type::watcher) {
                    kit_state.object_call(this, "on_leave", nullptr, std::tie(), obj->eid, cobj->eid);
                }
            }
            //插入
            insert(obj, nxgrid, nzgrid);
            return find_hotarea_id(x, z);
        }

    private:
        lua_State* mL;
        bool dynamic = false;
        int32_t offset_w = 0;       //x轴坐标偏移
        int32_t offset_h = 0;       //y轴坐标偏移
        uint16_t grid_len = 1;      //AOI格子长度
        uint16_t grid_hot = 1;      //热区格子长度
        uint16_t xgrid_num = 1;     //x轴的格子数
        uint16_t zgrid_num = 1;     //y轴的格子数
        uint16_t aoi_radius = 1;    //视野格子数
        //格子信息
        grid_map grids;             //二维数组保存将地图xy轴切割后的格子
        hotarea_map hotmaps = {};
    };
}

#endif
