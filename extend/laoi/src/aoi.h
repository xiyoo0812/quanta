#ifndef __AOI_H__
#define __AOI_H__

#include <set>
#include <list>
#include <vector>

#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace laoi {

    const uint16_t zero = 0;

    enum class aoi_type : uint16_t
    {
        WATCHER     = 0,    //观察者
        MARKER      = 1,    //被观察者
    };
    using enum aoi_type;

    class aoi;
    #pragma pack(2)
    struct aoi_obj
    {
        aoi_type type;
        uint64_t eid = 0;
        uint16_t grid_x = 0;
        uint16_t grid_z = 0;
        aoi* aoi_inst = nullptr; 
        void set_grid(uint16_t x, uint16_t z) {
            grid_x = x;
            grid_z = z;
        }
        aoi_obj(uint64_t id, aoi_type typ) : type(typ), eid(id){}
    };
    #pragma pack()

    typedef set<aoi_obj*> object_set;
    typedef vector<object_set*> grid_array;
    typedef vector<grid_array> grid_map;
    typedef unordered_map<uint32_t, uint16_t> hotarea_map;
    thread_local list<object_set*> grid_pools = {};

    class aoi
    {
    public:
        aoi(uint32_t w, uint32_t h, uint16_t glen, uint16_t aoi_len, bool offset, bool dynamic) {
            m_grid_len = glen;
            m_dynamic = dynamic;
            m_aoi_radius = aoi_len;
            m_xgrid_num = w / glen;
            m_zgrid_num = h / glen;
            m_grids.resize(m_zgrid_num);
            for (int i = 0; i < m_zgrid_num; ++i) {
                m_grids[i].resize(m_xgrid_num);
                for (int j = 0; j < m_zgrid_num; ++j) {
                    m_grids[i][j] = (!dynamic ) ? get_grid_set() : nullptr;
                }
            }
            if (offset) {
                m_offset_w = w / 2;
                m_offset_h = h / 2;
            }
        }
        ~aoi(){
            for (auto garray : m_grids) {
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
            return (inoout_x + m_offset_w) / glen;
        }

        uint16_t convert_z(int32_t inoout_z, uint16_t glen){
            return (inoout_z + m_offset_h) / glen;
        }

        uint16_t find_hotarea_id(int32_t x, int32_t z) {
            uint16_t nxgrid = convert_x(x, m_grid_hot);
            uint16_t nzgrid = convert_z(z, m_grid_hot);
            uint32_t index = nxgrid << 16 | nzgrid;
            if (auto it = m_hotmaps.find(index); it != m_hotmaps.end()) {
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
            m_grid_hot = ghl;
            uint16_t nxgrid = convert_x(x, ghl);
            uint16_t nzgrid = convert_z(z, ghl);
            m_hotmaps[nxgrid << 16 | nzgrid] = id;
        }

        void get_rect_objects(object_set& objs, uint16_t lx, uint16_t rx, uint16_t lz, uint16_t rz) {
            uint16_t minX = max<uint16_t>(zero, lx);
            uint16_t minZ = max<uint16_t>(zero, lz);
            uint16_t maxX = min<uint16_t>(m_xgrid_num - 1, rx);
            uint16_t maxZ = min<uint16_t>(m_zgrid_num - 1, rz);
            for(uint16_t z = minZ; z <= maxZ; z++) {
                for(uint16_t x = minX; x <= maxX; x++) {
                    copy(objs, m_grids[z][x]);
                }
            }
        }

        void get_around_objects(object_set& enters, object_set& leaves, uint16_t oxgrid, uint16_t ozgrid, uint16_t nxgrid, uint16_t nzgrid) {
            int16_t offsetX = nxgrid - oxgrid;
            int16_t offsetZ = nzgrid - ozgrid;
            if (offsetX < 0) {
                get_rect_objects(enters, nxgrid - m_aoi_radius, nxgrid - m_aoi_radius, nzgrid - m_aoi_radius, nzgrid + m_aoi_radius);
                get_rect_objects(leaves, oxgrid + m_aoi_radius, oxgrid + m_aoi_radius, ozgrid - m_aoi_radius, ozgrid + m_aoi_radius);
            }
            else if (offsetX > 0){
                get_rect_objects(enters, nxgrid + m_aoi_radius, nxgrid + m_aoi_radius, nzgrid - m_aoi_radius, nzgrid + m_aoi_radius);
                get_rect_objects(leaves, oxgrid - m_aoi_radius, oxgrid - m_aoi_radius, ozgrid - m_aoi_radius, ozgrid + m_aoi_radius);
            }
            if (offsetZ < 0) {
                get_rect_objects(enters, nxgrid - m_aoi_radius, nxgrid + m_aoi_radius, nzgrid - m_aoi_radius, nzgrid - m_aoi_radius);
                get_rect_objects(leaves, oxgrid - m_aoi_radius, oxgrid + m_aoi_radius, ozgrid + m_aoi_radius, ozgrid + m_aoi_radius);
            }
            else if (offsetZ > 0){
                get_rect_objects(enters, nxgrid - m_aoi_radius, nxgrid + m_aoi_radius, nzgrid + m_aoi_radius, nzgrid + m_aoi_radius);
                get_rect_objects(leaves, oxgrid - m_aoi_radius, oxgrid + m_aoi_radius, ozgrid - m_aoi_radius, ozgrid - m_aoi_radius);
            }
        }

        bool attach(lua_State* L, aoi_obj* obj, int32_t x, int32_t z){
            uint16_t nxgrid = convert_x(x, m_grid_len);
            uint16_t nzgrid = convert_z(z, m_grid_len);
            if ((nxgrid >= m_xgrid_num) || (nzgrid >= m_zgrid_num)) {
                return false;
            }
            if (obj->aoi_inst) {
                obj->aoi_inst->detach(L, obj);
            }
            obj->aoi_inst = this;
            //查询节点
            object_set objs;
            kit_state kit_state(L);
            get_rect_objects(objs, nxgrid - m_aoi_radius, nxgrid + m_aoi_radius, nzgrid - m_aoi_radius, nzgrid + m_aoi_radius);
            std::vector<uint64_t> eenters;
            for (auto cobj : objs) {
                if (obj == cobj) continue;
                if (cobj->type == WATCHER) {
                    eenters.push_back(cobj->eid);
                    eenters.push_back(obj->eid);
                }
                if (obj->type == WATCHER) {
                    eenters.push_back(obj->eid);
                    eenters.push_back(cobj->eid);
                }
            }
            //消息通知
            if (!eenters.empty() ) {
                kit_state.object_call(this, "on_enter", nullptr, std::tie(), eenters);
            }
            //放入格子
            insert(obj, nxgrid, nzgrid);
            return true;
        }

        void insert(aoi_obj* obj, uint16_t nxgrid, uint16_t nzgrid) {
            obj->set_grid(nxgrid, nzgrid);
            auto cur_set = m_grids[nzgrid][nxgrid];
            if (!cur_set) {
                cur_set = get_grid_set();
                m_grids[nzgrid][nxgrid] = cur_set;
            }
            cur_set->insert(obj);
        }

        bool detach(lua_State* L, aoi_obj* obj) {
            object_set objs;
            kit_state kit_state(L);
            get_rect_objects(objs, obj->grid_x - m_aoi_radius, obj->grid_x + m_aoi_radius, obj->grid_z - m_aoi_radius, obj->grid_z + m_aoi_radius);
            //清空aoi_inst
            obj->aoi_inst = nullptr;
            //移除
            remove(obj);
            //消息通知
            std::vector<uint64_t> eleaves;
            for (auto cobj : objs) {
                if (obj == cobj) continue;
                if (cobj->type == WATCHER) {
                    eleaves.push_back(cobj->eid);
                    eleaves.push_back(obj->eid);
                }
                if (obj->type == WATCHER) {
                    eleaves.push_back(obj->eid);
                    eleaves.push_back(cobj->eid);
                }
            }
            if (!eleaves.empty() ) {
                kit_state.object_call(this, "on_leave", nullptr, std::tie(), eleaves);
            }
            return true;
        }

        void remove(aoi_obj* obj) {
            auto gset = m_grids[obj->grid_z][obj->grid_x];
            if (gset) {
                gset->erase(obj);
                if (m_dynamic && gset->empty()) {
                    grid_pools.push_back(gset);
                    m_grids[obj->grid_z][obj->grid_x] = nullptr;
                }
            }
        }

        uint32_t move(lua_State* L, aoi_obj* obj, int32_t x, int32_t z) {
            uint16_t nxgrid = convert_x(x, m_grid_len);
            uint16_t nzgrid = convert_z(z, m_grid_len);
            if ((nxgrid >= m_xgrid_num) || (nzgrid >= m_zgrid_num)) {
                return -1;
            }
            if (nxgrid == obj->grid_x && nzgrid == obj->grid_z){
                return 0;
            }
            remove(obj);
            //消息通知
            kit_state kit_state(L);
            object_set enters, leaves;
            get_around_objects(enters, leaves, obj->grid_x, obj->grid_z, nxgrid, nzgrid);
            //进入视野
            std::vector<uint64_t> eenters, eleaves;
            for (auto cobj : enters) {
                if (obj == cobj) continue;
                if (cobj->type == WATCHER) {
                    eenters.push_back(cobj->eid);
                    eenters.push_back(obj->eid);
                }
                if (obj->type == WATCHER) {
                    eenters.push_back(obj->eid);
                    eenters.push_back(cobj->eid);
                }
            }
            //退出视野
            for (auto cobj : leaves) {
                if (obj == cobj) continue;
                if (cobj->type == WATCHER) {
                    eleaves.push_back(cobj->eid);
                    eleaves.push_back(obj->eid);
                }
                if (obj->type == WATCHER) {
                    eleaves.push_back(obj->eid);
                    eleaves.push_back(cobj->eid);
                }
            }
            if (!eleaves.empty() ) {
                kit_state.object_call(this, "on_leave", nullptr, std::tie(), eleaves);
            }
            if (!eenters.empty()) {
                kit_state.object_call(this, "on_enter", nullptr, std::tie(), eenters);
            }
            //插入
            insert(obj, nxgrid, nzgrid);
            return find_hotarea_id(x, z);
        }

    private:
        bool m_dynamic = false;
        int32_t m_offset_w = 0;     //x轴坐标偏移
        int32_t m_offset_h = 0;     //y轴坐标偏移
        uint16_t m_grid_len = 1;    //AOI格子长度
        uint16_t m_grid_hot = 1;    //热区格子长度
        uint16_t m_xgrid_num = 1;   //x轴的格子数
        uint16_t m_zgrid_num = 1;   //y轴的格子数
        uint16_t m_aoi_radius = 1;  //视野格子数
        //格子信息
        grid_map m_grids;           //二维数组保存将地图xy轴切割后的格子
        hotarea_map m_hotmaps = {};
    };
}

#endif
