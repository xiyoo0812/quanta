#ifndef __AOI_H__
#define __AOI_H__
#include "lua_kit.h"

#include <set>
#include <map>
#include <vector>
#include <algorithm>
#include <stdlib.h>

using namespace std;

namespace laoi {

enum class aoi_type : int
{
    watcher     = 0,    //观察者
    marker      = 1,    //被观察者
};

class hot_area
{
public:
    long pos_x;     //位置
    long pos_y;     //位置
    long pos_z;     //位置
    long radius;    //半径
    long hid;       //hid

    bool in(long x, long y, long z) {
        return (abs(x - pos_x) < radius || abs(y - pos_y) < radius || abs(z - pos_z) < radius);
    }

    hot_area(long id, long r, long x, long y, long z) : hid(id), radius(r), pos_x(x), pos_y(y), pos_z(z) {}
};

class aoi_obj
{
public:
    uint64_t eid;
    long grid_x;
    long grid_z;
    aoi_type type;

    void set_grid(long x, long z) {
        grid_x = x;
        grid_z = z;
    }

    aoi_obj(uint64_t id, aoi_type typ) : eid(id), type(typ) {}
};

typedef set<aoi_obj*> object_set;

class aoi_grid
{
public:
    ~aoi_grid() {
        if (hotarea) {
            delete hotarea;
            hotarea = nullptr;
        }
    }
    hot_area* hotarea = nullptr;
    object_set objs;
};

typedef vector<aoi_grid> grid_axis;
typedef vector<grid_axis> grid_map;

class aoi
{ 
public:
    aoi(lua_State* L, long w, long h, long glen, long aoi_len, bool offset) {	
        mL = L;
        grid_len = glen;
        aoi_radius = aoi_len;
        xgrid_num = w / glen;
        zgrid_num = h / glen;
        grids.resize(zgrid_num);
        for (long i = 0; i <= zgrid_num; i++) {
            grids[i].resize(xgrid_num);
        }
        if (offset) {
            offset_w = w / 2;
            offset_h = h / 2;
        }
    }
    ~aoi(){};

    void copy(object_set& o1, object_set& o2) {
        for(auto o : o2) {
            o1.insert(o);
        }
    }

    long convert_x(long inoout_x){
        return (inoout_x + offset_w) / grid_len;
    }

    long convert_z(long inoout_z){
        return (inoout_z + offset_h) / grid_len;
    }
    
    void add_hotarea(long id, long r, long x, long y, long z) {
        hot_area* hobj = new hot_area(id, r, x, y, z);
        long grid_num = r / grid_len;
        long nxgrid = convert_x(x);
        long nzgrid = convert_z(z);
        long minX = max<long>(0, nxgrid - grid_num);
        long maxX = min(xgrid_num, nxgrid + grid_num);
        long minZ = max<long>(0, nzgrid - grid_num);
        long maxZ = min(zgrid_num, nzgrid + grid_num);
        for(int z = minZ; z <= maxZ; z++) {
            for(int x = minX; x <= maxX; x++) {
                grids[nzgrid][nxgrid].hotarea = hobj;
            }
        }
    }

    long in_hotarea(aoi_grid& grid, long x, long y, long z) {
        auto hotarea = grid.hotarea;
        if (hotarea && hotarea->in(x, y, z)) {
            return hotarea->hid;
        }
        return 0;
    }
    
    void get_rect_objects(object_set& objs, long minX, long maxX, long minZ, long maxZ) {
        for(int z = minZ; z <= maxZ; z++) {
            for(int x = minX; x <= maxX; x++) {
                copy(objs, grids[z][x].objs);
            }
        }
    }

    void get_objects(object_set& objs, long nxgrid, long nzgrid) {
        long minX = max<long>(0, nxgrid - aoi_radius);
        long maxX = min(xgrid_num, nxgrid + aoi_radius);
        long minZ = max<long>(0, nzgrid - aoi_radius);
        long maxZ = min(zgrid_num, nzgrid + aoi_radius);
        get_rect_objects(objs, minX, maxX, minZ, maxZ);
    }

    void get_around_objects(object_set& enters, object_set& leaves, long oxgrid, long ozgrid, long nxgrid, long nzgrid) {
        long offsetX = nxgrid - oxgrid;
        long offsetZ = nzgrid - ozgrid;
        if (offsetX < 0) {
            get_rect_objects(enters, nxgrid - aoi_radius, oxgrid - aoi_radius, max<long>(0, nzgrid - aoi_radius), min(zgrid_num, nzgrid + aoi_radius));
            get_rect_objects(leaves, nxgrid + aoi_radius, oxgrid + aoi_radius, max<long>(0, ozgrid - aoi_radius), min(zgrid_num, ozgrid + aoi_radius));
        }
        else if (offsetX > 0){
            get_rect_objects(enters, oxgrid + aoi_radius, nxgrid + aoi_radius, max<long>(0, nzgrid - aoi_radius), min(zgrid_num, nzgrid + aoi_radius));
            get_rect_objects(leaves, oxgrid - aoi_radius, nxgrid - aoi_radius, max<long>(0, ozgrid - aoi_radius), min(zgrid_num, ozgrid + aoi_radius));
        }
        if (offsetZ < 0) {
            get_rect_objects(enters, max<long>(0, nxgrid - aoi_radius), min(xgrid_num, nxgrid + aoi_radius), nzgrid - aoi_radius, ozgrid - aoi_radius);
            get_rect_objects(leaves, max<long>(0, oxgrid - aoi_radius), min(xgrid_num, oxgrid + aoi_radius), nzgrid + aoi_radius, ozgrid + aoi_radius);
        }
        else if (offsetZ > 0){
            get_rect_objects(enters, max<long>(0, nxgrid - aoi_radius), min(xgrid_num, nxgrid + aoi_radius), ozgrid + aoi_radius, nzgrid + aoi_radius);
            get_rect_objects(leaves, max<long>(0, oxgrid - aoi_radius), min(xgrid_num, oxgrid + aoi_radius), ozgrid - aoi_radius, nzgrid - aoi_radius);
        }
    }

    bool attach(aoi_obj* obj, long x, long z){
        long nxgrid = convert_x(x);
        long nzgrid = convert_z(z);
        if ((nxgrid < 0) || (nxgrid > xgrid_num) || (nzgrid < 0) || (nzgrid > zgrid_num)) {
            return false;
        }
        //查询节点
        object_set objs;
        get_objects(objs, nxgrid, nzgrid);
        //消息通知
        luakit::kit_state kit_state(mL);
        for (auto cobj : objs) {
            if (cobj->type == aoi_type::watcher) {
                kit_state.object_call(this, "on_enter", nullptr, std::tie(), cobj->eid, obj->eid);
            }
            if (obj->type == aoi_type::watcher) {
                kit_state.object_call(this, "on_enter", nullptr, std::tie(), obj->eid, cobj->eid);
            }
        }
        //放入格子
        obj->set_grid(nxgrid, nzgrid);
        grids[nzgrid][nxgrid].objs.insert(obj);
        return true;
    }

    bool detach(aoi_obj* obj) {
        grids[obj->grid_z][obj->grid_x].objs.erase(obj);
        return true;
    }

    long move(aoi_obj* obj, long x, long y, long z) {
        long nxgrid = convert_x(x);
        long nzgrid = convert_z(z);
        if ((nxgrid < 0) || (nxgrid > xgrid_num) || (nzgrid < 0) || (nzgrid > zgrid_num)) {
            return -1;
        }
        if (nxgrid == obj->grid_x && nzgrid == obj->grid_z){
            return 0;
        }
        grids[obj->grid_z][obj->grid_x].objs.erase(obj);
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
        aoi_grid& grid = grids[nzgrid][nxgrid];
        obj->set_grid(nxgrid, nzgrid);
        grid.objs.insert(obj);
        return in_hotarea(grid, x, y, z);
    }

private:
    lua_State* mL;
    long offset_w = 0;    //x轴坐标偏移
    long offset_h = 0;    //y轴坐标偏移
    long grid_len = 50;   //格子长度
    long xgrid_num = 1;   //x轴的格子数
    long zgrid_num = 1;   //y轴的格子数
    long aoi_radius = 1;    //视野格子数
    grid_map grids;         //二维数组保存将地图xy轴切割后的格子
};

}

#endif
