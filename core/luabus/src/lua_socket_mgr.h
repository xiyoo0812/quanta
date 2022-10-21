#pragma once
#include <memory>
#include <array>
#include <vector>
#include "socket_mgr.h"
#include "socket_router.h"

struct lua_socket_mgr final
{
public:
    ~lua_socket_mgr(){}
    bool setup(int max_fd);
    int wait(int ms) { return m_mgr->wait(ms); }
    void map_token(uint32_t node_id, uint32_t token);
    void set_master(uint32_t service_id, uint32_t token);
    luakit::variadic_results listen(lua_State* L, const char* ip, int port);
    luakit::variadic_results connect(lua_State* L, const char* ip, const char* port, int timeout);

private:
    lua_State* m_lvm;
    std::shared_ptr<socket_mgr> m_mgr;
    std::shared_ptr<socket_router> m_router;
};

